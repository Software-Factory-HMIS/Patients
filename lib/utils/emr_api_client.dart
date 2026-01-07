import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class EmrApiClient {
  final String baseUrl;
  final http.Client _client;

  EmrApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? resolveEmrBaseUrl(),
        _client = client ?? http.Client();

  // Factory constructor for async initialization with fallback
  static Future<EmrApiClient> create({String? baseUrl, http.Client? client}) async {
    if (baseUrl != null) {
      return EmrApiClient(baseUrl: baseUrl, client: client);
    }
    
    // Use fallback mechanism to determine the best URL
    final resolvedUrl = await resolveEmrBaseUrlWithFallback();
    return EmrApiClient(baseUrl: resolvedUrl, client: client);
  }

  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      print('🔍 Testing connection to: $uri');
      final res = await _client.get(uri).timeout(const Duration(seconds: 5));
      print('📡 Health check response: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchPatient(String identifier) async {
    // Clean the identifier - remove any non-digit characters
    final cleaned = identifier.replaceAll(RegExp(r'[^\d]'), '').trim();
    
    if (cleaned.isEmpty) {
      throw Exception('Invalid identifier: identifier cannot be empty');
    }
    
    // Determine the type of identifier and try appropriate endpoints
    final List<Uri> uris = [];
    
    // If it's 13 digits, it's likely a CNIC
    if (cleaned.length == 13) {
      final encodedCnic = Uri.encodeComponent(cleaned);
      uris.add(Uri.parse('$baseUrl/api/min-patients/by-cnic/$encodedCnic'));
    }
    // If it's 11 digits or less, it could be a phone number
    else if (cleaned.length <= 11 && cleaned.length >= 7) {
      final encodedPhone = Uri.encodeComponent(cleaned);
      uris.add(Uri.parse('$baseUrl/api/min-patients/by-phone/$encodedPhone'));
    }
    // If it's numeric and could be a patient ID (typically 1-6 digits)
    else if (RegExp(r'^\d+$').hasMatch(cleaned) && cleaned.length <= 6) {
      try {
        final patientId = int.parse(cleaned);
        uris.add(Uri.parse('$baseUrl/api/min-patients/$patientId'));
      } catch (e) {
        // Not a valid integer, skip
      }
    }
    
    // If no specific format matched, try all possible endpoints
    if (uris.isEmpty) {
      // Try as CNIC (13 digits)
      final encodedCnic = Uri.encodeComponent(cleaned);
      uris.add(Uri.parse('$baseUrl/api/min-patients/by-cnic/$encodedCnic'));
      
      // Try as phone
      final encodedPhone = Uri.encodeComponent(cleaned);
      uris.add(Uri.parse('$baseUrl/api/min-patients/by-phone/$encodedPhone'));
      
      // Try as patient ID if it's numeric
      if (RegExp(r'^\d+$').hasMatch(cleaned)) {
        try {
          final patientId = int.parse(cleaned);
          uris.add(Uri.parse('$baseUrl/api/min-patients/$patientId'));
        } catch (e) {
          // Not a valid integer
        }
      }
    }
    
    Exception? lastError;
    
    for (final uri in uris) {
      try {
        print('🔍 Fetching patient from: $uri');
        final res = await _client.get(uri).timeout(const Duration(seconds: 10));
        print('📡 Response status: ${res.statusCode}');
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = json.decode(res.body);
          
          // Handle both single object and array responses
          Map<String, dynamic> patient;
          if (response is List && response.isNotEmpty) {
            // If it's a list, take the first patient
            patient = response[0] as Map<String, dynamic>;
          } else if (response is Map<String, dynamic>) {
            patient = response;
          } else {
            throw Exception('Unexpected response format');
          }
          
          print('✅ Patient loaded successfully: ${patient['FullName'] ?? patient['fullName'] ?? 'Unknown'}');
          return patient;
        }
        
        // If 400 or 404, try next format
        if (res.statusCode == 400 || res.statusCode == 404) {
          print('⚠️ Patient not found with format: $uri');
          lastError = Exception('Failed to load patient (${res.statusCode}): ${res.body}');
          continue; // Try next format
        }
        
        // For other errors, throw immediately
        throw Exception('Failed to load patient (${res.statusCode}): ${res.body}');
      } catch (e) {
        if (e.toString().contains('400') || e.toString().contains('404')) {
          lastError = e as Exception;
          continue; // Try next format
        }
        print('❌ Error fetching patient: $e');
        rethrow;
      }
    }
    
    // If all formats failed, throw the last error
    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to load patient: All formats failed');
  }

  // Login with CNIC and password - returns list of patients with matching CNIC and verified password
  Future<List<Map<String, dynamic>>> loginByCnic(String cnic, {String? password}) async {
    // Clean and normalize CNIC - remove any non-digit characters
    final cleanedCnic = cnic.replaceAll(RegExp(r'[^\d]'), '').trim();
    
    if (cleanedCnic.isEmpty) {
      throw Exception('Invalid CNIC: CNIC cannot be empty');
    }
    
    if (cleanedCnic.length != 13) {
      throw Exception('Invalid CNIC: CNIC must be exactly 13 digits');
    }
    
    print('🔍 [loginByCnic] Original CNIC: "$cnic", Cleaned: "$cleanedCnic"');
    
    // Use POST endpoint for login with password, or GET if no password provided
    if (password != null && password.isNotEmpty) {
      // POST request with CNIC and password
      final uri = Uri.parse('$baseUrl/api/patient-auth/login');
      
      try {
        print('🔍 [loginByCnic] Attempting login with CNIC and password');
        
        final body = json.encode({
          'cnic': cleanedCnic,
          'password': password,
        });
        
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(seconds: 15));
        
        print('📡 [loginByCnic] Response status: ${res.statusCode}');
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = json.decode(res.body) as Map<String, dynamic>;
          
          // Handle API response wrapper
          List<dynamic> patientsList;
          if (response.containsKey('data')) {
            final data = response['data'];
            patientsList = data is List ? data : [data];
          } else {
            patientsList = [response];
          }
          
          // Convert to List<Map<String, dynamic>>
          final patients = patientsList
              .map((p) => p as Map<String, dynamic>)
              .toList();
          
          print('✅ Found ${patients.length} patient(s) with CNIC: $cnic');
          return patients;
        }
        
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw Exception('Invalid CNIC or password');
        }
        
        if (res.statusCode == 404) {
          print('⚠️ No patients found with CNIC: $cnic');
          return [];
        }
        
        throw Exception('Failed to login (${res.statusCode}): ${res.body}');
      } catch (e) {
        print('❌ Error logging in with CNIC and password: $e');
        rethrow;
      }
    } else {
      // Fallback to GET endpoint if no password provided (for backward compatibility)
      final encodedCnic = Uri.encodeComponent(cleanedCnic);
      final uri = Uri.parse('$baseUrl/api/min-patients/by-cnic/$encodedCnic');
      
      try {
        print('🔍 [loginByCnic] Requesting: $uri');
        print('🆔 [loginByCnic] CNIC being searched: "$cleanedCnic"');
        
        final res = await _client.get(uri).timeout(const Duration(seconds: 15));
        
        print('📡 [loginByCnic] Response status: ${res.statusCode}');
        print('📡 [loginByCnic] Response body length: ${res.body.length}');
        
        if (res.statusCode >= 400 && res.statusCode < 500) {
          print('📡 [loginByCnic] Response body: ${res.body}');
        }
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = json.decode(res.body);
          
          // Handle both single object and array responses
          List<dynamic> patientsList;
          if (response is List) {
            patientsList = response;
          } else if (response is Map<String, dynamic> && response.containsKey('data')) {
            // Handle API response wrapper
            final data = response['data'];
            patientsList = data is List ? data : [data];
          } else {
            // Single patient object
            patientsList = [response];
          }
          
          // Convert to List<Map<String, dynamic>>
          final patients = patientsList
              .map((p) => p as Map<String, dynamic>)
              .toList();
          
          print('✅ Found ${patients.length} patient(s) with CNIC: $cnic');
          return patients;
        }
        
        if (res.statusCode == 404) {
          print('⚠️ No patients found with CNIC: $cnic');
          return [];
        }
        
        throw Exception('Failed to login with CNIC (${res.statusCode}): ${res.body}');
      } catch (e) {
        print('❌ Error logging in with CNIC: $e');
        rethrow;
      }
    }
  }

  // Login with phone number - returns list of patients with matching phone number
  Future<List<Map<String, dynamic>>> loginByPhoneNumber(String phoneNumber) async {
    // Clean and normalize phone number - remove any non-digit characters
    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '').trim();
    
    if (cleanedPhone.isEmpty) {
      throw Exception('Invalid phone number: phone number cannot be empty');
    }
    
    print('🔍 [loginByPhoneNumber] Original phone: "$phoneNumber", Cleaned: "$cleanedPhone"');
    
    // URL encode the phone number to handle special characters
    final encodedPhone = Uri.encodeComponent(cleanedPhone);
    final uri = Uri.parse('$baseUrl/api/min-patients/by-phone/$encodedPhone');
    
    try {
      print('🔍 [loginByPhoneNumber] Requesting: $uri');
      print('📱 [loginByPhoneNumber] Phone number being searched: "$cleanedPhone"');
      
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      
      print('📡 [loginByPhoneNumber] Response status: ${res.statusCode}');
      print('📡 [loginByPhoneNumber] Response body length: ${res.body.length}');
      
      if (res.statusCode >= 400 && res.statusCode < 500) {
        print('📡 [loginByPhoneNumber] Response body: ${res.body}');
      }
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body);
        
        // Handle both single object and array responses
        List<dynamic> patientsList;
        if (response is List) {
          patientsList = response;
        } else if (response is Map<String, dynamic> && response.containsKey('data')) {
          // Handle API response wrapper
          final data = response['data'];
          patientsList = data is List ? data : [data];
        } else {
          // Single patient object
          patientsList = [response];
        }
        
        // Convert to List<Map<String, dynamic>>
        final patients = patientsList
            .map((p) => p as Map<String, dynamic>)
            .toList();
        
        print('✅ Found ${patients.length} patient(s) with phone number: $phoneNumber');
        return patients;
      }
      
      if (res.statusCode == 404) {
        print('⚠️ No patients found with phone number: $phoneNumber');
        return [];
      }
      
      throw Exception('Failed to login with phone number (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error logging in with phone number: $e');
      rethrow;
    }
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Register a new patient
  Future<Map<String, dynamic>> registerPatient({
    required String fullName,
    required String cnic,
    required String phone,
    String? email, // Optional
    required DateTime dateOfBirth,
    required String gender,
    String? address, // Optional
    String? bloodGroup, // Optional
    String? password, // Optional - only for Self registration
    String? registrationType, // 'Self' or 'Others'
    String? parentType, // 'Father' or 'Mother' when Others
    int? createdBy, // User ID who created the patient
  }) async {
    // Use /api/min-patients endpoint like hmis_flutter
    final uri = Uri.parse('$baseUrl/api/min-patients');
    try {
      print('🔍 Registering patient: $uri');
      
      // Remove dashes from CNIC for API
      final cleanCnic = cnic.replaceAll(RegExp(r'[^0-9]'), '');
      
      // createdBy is required by database - use provided value or default to 1 (system user)
      // Send as integer (JSON will serialize it correctly)
      // Try both camelCase and PascalCase to ensure API receives it
      final createdByValue = (createdBy ?? 1) as int;
      
      // Trim password before checking
      final trimmedPassword = password?.trim();
      
      // Build patient data matching hmis_flutter structure
      final body = <String, dynamic>{
        'fullName': fullName.trim(),
        'cnic': cleanCnic,
        'contactNumber': phone.trim(), // Use contactNumber instead of phone
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'source': 'Flutter', // Add source field like hmis_flutter
        // Only include optional fields if they have values
        if (email != null && email.trim().isNotEmpty) 
          'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 
          'address': address.trim(),
        if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Not Known') 
          'bloodGroup': bloodGroup,
        if (registrationType != null && registrationType.isNotEmpty) 
          'registrationType': registrationType,
        if (parentType != null && parentType.isNotEmpty) 
          'parentType': parentType,
        // Send both formats to ensure API receives it
        'createdBy': createdByValue,
        'CreatedBy': createdByValue, // Also send PascalCase in case API is case-sensitive
      };
      
      // Include password if provided and not empty (hash it before sending)
      // Backend will detect it's already hashed and store as-is
      if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
        // Hash the password using SHA-256 before sending to server
        final hashedPassword = _hashPassword(trimmedPassword);
        body['passwordHash'] = hashedPassword;
        body['password'] = hashedPassword; // Also send as 'password' for backward compatibility
        body['isPasswordHashed'] = true; // Flag to indicate password is already hashed
        print('✅ Password hashed and included in request body (original length: ${trimmedPassword.length}, hash length: ${hashedPassword.length})');
      } else {
        print('⚠️ Password NOT included - password: ${password != null ? "provided but empty/whitespace" : "null"}, trimmed: ${trimmedPassword != null ? "empty" : "null"}');
      }
      
      // Verify createdBy is in the body and is not null
      assert(body.containsKey('createdBy'), 'createdBy must be in request body');
      assert(body['createdBy'] != null, 'createdBy must not be null');
      assert(body['createdBy'] is int, 'createdBy must be an integer');
      
      print('📤 Request body: $body');
      print('🔍 createdBy value: ${body['createdBy']} (type: ${body['createdBy'].runtimeType})');
      print('🔍 CreatedBy value: ${body['CreatedBy']} (type: ${body['CreatedBy'].runtimeType})');
      print('🔍 Password provided: ${password != null}');
      print('🔍 Password length: ${password?.length ?? 0}');
      print('🔍 PasswordHash in body: ${body.containsKey('passwordHash')}');
      print('🔍 Password in body: ${body.containsKey('password')}');
      final jsonBody = json.encode(body);
      print('🔍 JSON body contains createdBy: ${jsonBody.contains('createdBy')}');
      print('🔍 JSON body contains CreatedBy: ${jsonBody.contains('CreatedBy')}');
      print('🔍 JSON body contains passwordHash: ${jsonBody.contains('passwordHash')}');
      print('🔍 JSON body contains password: ${jsonBody.contains('"password"')}');
      print('🔍 Full JSON body: $jsonBody');
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      // Handle 409 Conflict - Patient already exists
      if (res.statusCode == 409) {
        try {
          final errorResponse = json.decode(res.body) as Map<String, dynamic>;
          final conflictMessage = errorResponse['message'] as String? ?? 
                                 errorResponse['error'] as String? ??
                                 'Patient with this CNIC already exists';
          throw Exception('Patient already exists: $conflictMessage');
        } catch (e) {
          if (e is Exception && e.toString().contains('already exists')) {
            rethrow;
          }
          throw Exception('Patient with this CNIC already exists');
        }
      }
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as Map<String, dynamic>;
        }
        print('✅ Patient registered successfully');
        return response;
      }
      
      // Parse error message from response
      String errorMessage = 'Failed to register patient';
      String? detailedError;
      try {
        final errorResponse = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = errorResponse['message'] as String? ?? 
                      errorResponse['error'] as String? ?? 
                      errorResponse['title'] as String? ??
                      errorResponse['detail'] as String? ??
                      res.body;
        
        // Extract detailed error information if available
        if (errorResponse.containsKey('errors')) {
          detailedError = errorResponse['errors'].toString();
        } else if (errorResponse.containsKey('traceId')) {
          detailedError = 'Trace ID: ${errorResponse['traceId']}';
        }
      } catch (e) {
        errorMessage = res.body;
      }
      
      // Check for specific database errors
      if (errorMessage.toLowerCase().contains('database trigger') || 
          errorMessage.toLowerCase().contains('dbupdateexception')) {
        errorMessage = 'Database Configuration Error: The API server needs to be configured to handle database triggers.\n\n'
            'This is a backend API issue that needs to be fixed by the API developer.\n\n'
            'Full error: ${detailedError ?? errorMessage}';
      } else if (errorMessage.toLowerCase().contains('dbnull') || 
                 errorMessage.toLowerCase().contains('store type mapping')) {
        errorMessage = 'Database Mapping Error: The API server encountered an issue mapping data to the database.\n\n'
            'This might be due to:\n'
            '- Missing or invalid field values\n'
            '- Database schema mismatch\n'
            '- Null value handling issues\n\n'
            'Please check the data you entered and try again.\n\n'
            'Full error: ${detailedError ?? errorMessage}';
      }
      
      final fullError = detailedError != null 
          ? '$errorMessage\n\nDetails: $detailedError'
          : errorMessage;
      
      throw Exception('Failed to register patient (${res.statusCode}): $fullError');
    } catch (e) {
      print('❌ Error registering patient: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchVitals(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/vitals');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load vitals (${res.statusCode})');
  }

  Future<List<dynamic>> fetchMedications(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/medications');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load medications (${res.statusCode})');
  }

  Future<List<dynamic>> fetchOPD(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/opd');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load OPD records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchIPD(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/ipd');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load IPD records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchLabs(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/labs');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load lab results (${res.statusCode})');
  }

  Future<List<dynamic>> fetchRadiology(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/radiology');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load radiology records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchSurgery(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/surgery');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load surgery records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchPregnancy(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/pregnancy');
    final res = await _client.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load pregnancy records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchHospitals() async {
    final uri = Uri.parse('$baseUrl/api/hospitals');
    try {
      print('🔍 Fetching hospitals from: $uri');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as List<dynamic>;
        }
        return response['hospitals'] as List<dynamic>? ?? [];
      }
      throw Exception('Failed to load hospitals (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error fetching hospitals: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchDepartments() async {
    final uri = Uri.parse('$baseUrl/api/departments');
    try {
      print('🔍 Fetching departments from: $uri');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as List<dynamic>;
        }
        return response['departments'] as List<dynamic>? ?? [];
      }
      throw Exception('Failed to load departments (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error fetching departments: $e');
      rethrow;
    }
  }

  // Fetch hospital departments by hospital ID (returns hospitalDepartmentID)
  Future<List<dynamic>> fetchHospitalDepartments(int hospitalId) async {
    final uri = Uri.parse('$baseUrl/api/hospital-setup/hospital-departments?hospitalId=$hospitalId');
    try {
      print('🔍 Fetching hospital departments for hospital ID $hospitalId: $uri');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body);
        // Handle both list and wrapped responses
        if (response is List) {
          return response;
        } else if (response is Map<String, dynamic>) {
          if (response.containsKey('data')) {
            return response['data'] as List<dynamic>;
          }
        }
        return [];
      }
      throw Exception('Failed to load hospital departments (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error fetching hospital departments: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addPatientToQueue({
    required int patientId,
    required int hospitalId,
    required int hospitalDepartmentId,
    required int createdBy,
    String priority = 'Normal',
    String queueType = 'OPD',
    String visitPurpose = 'Check-Up',
    String patientSource = 'SELF_CHECKIN',
    int? assignedToUserId,
    int? assignedToOpdId,
    int? referralId,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-queue');
    try {
      print('🔍 Adding patient to queue: $uri');
      
      final body = {
        'patientId': patientId,
        'hospitalId': hospitalId,
        'hospitalDepartmentId': hospitalDepartmentId,
        'createdBy': createdBy,
        'priority': priority,
        'queueType': queueType,
        'visitPurpose': visitPurpose,
        'patientSource': patientSource,
        if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
        if (assignedToOpdId != null) 'assignedToOpdId': assignedToOpdId,
        if (referralId != null) 'referralId': referralId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      if (res.statusCode == 409) {
        // Patient already in queue - return existing queue info
        final response = json.decode(res.body) as Map<String, dynamic>;
        throw Exception('Patient already in queue. Queue ID: ${response['queueId']}, Token: ${response['tokenNumber']}');
      }
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as Map<String, dynamic>;
        }
        return response;
      }
      throw Exception('Failed to add patient to queue (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error adding patient to queue: $e');
      rethrow;
    }
  }

  // Print queue receipt - returns receipt data as it appears in the print API
  Future<Map<String, dynamic>> printQueueReceipt({
    required int queueId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/queue/$queueId/print');
    try {
      print('🖨️ Printing queue receipt for queue ID: $queueId');
      print('🔍 Print endpoint: $uri');
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Print response status: ${res.statusCode}');
      print('📡 Print response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Parse and return the receipt data
        try {
          final receiptData = json.decode(res.body) as Map<String, dynamic>;
          print('✅ Queue receipt data retrieved successfully');
          return receiptData;
        } catch (e) {
          // If response is not JSON, return empty map
          print('⚠️ Print API response is not JSON, returning empty receipt data');
          return {};
        }
      }
      throw Exception('Failed to print queue receipt (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error printing queue receipt: $e');
      // Return empty map instead of throwing - allows UI to still show appointment details
      return {};
    }
  }

  // Request OTP for patient authentication
  Future<Map<String, dynamic>> requestOtp({required String cnic}) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/otp/request');
    try {
      print('🔍 Requesting OTP for CNIC: $cnic');
      
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 OTP request response status: ${res.statusCode}');
      print('📡 OTP request response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as Map<String, dynamic>;
        }
        return response;
      }
      
      // Parse error message
      String errorMessage = 'Failed to request OTP';
      try {
        final errorResponse = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = errorResponse['message'] as String? ?? 
                      errorResponse['error'] as String? ?? 
                      errorMessage;
      } catch (e) {
        errorMessage = res.body;
      }
      
      throw Exception('$errorMessage (${res.statusCode})');
    } catch (e) {
      print('❌ Error requesting OTP: $e');
      rethrow;
    }
  }

  // Verify OTP for patient authentication
  Future<Map<String, dynamic>> verifyOtp({
    required String cnic,
    required String otpCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/verify');
    try {
      print('🔍 Verifying OTP for CNIC: $cnic');
      
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
        'code': otpCode.trim(),
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 OTP verify response status: ${res.statusCode}');
      print('📡 OTP verify response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as Map<String, dynamic>;
        }
        return response;
      }
      
      // Parse error message
      String errorMessage = 'Invalid OTP';
      try {
        final errorResponse = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = errorResponse['message'] as String? ?? 
                      errorResponse['error'] as String? ?? 
                      errorMessage;
      } catch (e) {
        errorMessage = res.body;
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      rethrow;
    }
  }

  // Send registration OTP SMS
  Future<void> sendRegistrationOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/send-registration');
    try {
      print('🔍 Sending registration OTP to: $phoneNumber');
      
      final body = {
        'phoneNumber': phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''), // Clean phone
        'otp': otp,
      };
      
      // Increase timeout to 30 seconds for SMS operations
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));
      
      print('📡 Registration OTP send response status: ${res.statusCode}');
      print('📡 Registration OTP send response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        final data = response['data'] as Map<String, dynamic>?;
        final message = response['message'] as String? ?? 'OTP sent successfully';
        final smsStatus = data?['smsStatus'] as String?;
        final canProceed = data?['canProceed'] as bool? ?? false;
        
        print('✅ Registration OTP response: $message');
        
        // Check if we can proceed regardless of SMS status
        if (canProceed) {
          print('✅ Can proceed to OTP entry screen (CanProceed: true)');
          if (smsStatus == 'Failed' || smsStatus == 'Timeout' || smsStatus == 'Error') {
            print('⚠️ SMS delivery failed or timed out, but user can proceed');
          }
          return; // Success - allow user to proceed
        }
        
        // Check SMS status from response (only if CanProceed is false)
        if (smsStatus != null) {
          print('📡 SMS Status: $smsStatus');
          if (smsStatus == 'Failed' || smsStatus == 'Timeout' || smsStatus == 'Error') {
            print('⚠️ SMS delivery failed or timed out');
            // Extract OTP from message if available
            final otpMatch = RegExp(r'OTP:\s*(\d{4})').firstMatch(message);
            if (otpMatch != null) {
              print('📝 OTP from response: ${otpMatch.group(1)}');
            }
            // Throw exception to indicate SMS failed (only if CanProceed is false)
            throw Exception('SMS delivery failed: $message');
          } else if (smsStatus == 'Sent') {
            print('✅ SMS sent successfully');
          }
        } else if (message.contains('OTP:') || message.contains('OTP generated') || 
                   message.contains('SMS delivery') || message.contains('timed out') ||
                   message.contains('not sent')) {
          print('⚠️ SMS may have failed, but OTP is available in response');
          // Only throw if CanProceed is false
          if (!canProceed) {
            throw Exception('SMS delivery issue: $message');
          }
        }
        
        return;
      }
      
      // Parse error message
      String errorMessage = 'Failed to send registration OTP';
      try {
        final errorResponse = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = errorResponse['message'] as String? ?? 
                      errorResponse['error'] as String? ?? 
                      errorMessage;
      } catch (e) {
        errorMessage = res.body;
      }
      
      throw Exception('$errorMessage (${res.statusCode})');
    } catch (e) {
      print('❌ Error sending registration OTP: $e');
      // Don't rethrow - let the fallback mechanism handle it
      // The backend now returns success even if SMS fails, with OTP in message
      if (e.toString().contains('TimeoutException')) {
        print('⚠️ Request timed out, but SMS may still be processing');
      }
      rethrow;
    }
  }

  /// Test SMS service without requiring a valid phone number
  /// Returns detailed information about the SMS API call
  Future<Map<String, dynamic>> testSmsService({
    String? phoneNumber,
    String? message,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/test-sms');
    try {
      print('🧪 Testing SMS service...');
      
      final body = <String, dynamic>{};
      if (phoneNumber != null) {
        body['phoneNumber'] = phoneNumber;
      }
      if (message != null) {
        body['message'] = message;
      }
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 20));
      
      print('📡 SMS Test response status: ${res.statusCode}');
      print('📡 SMS Test response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        print('✅ SMS Test completed. Check server logs for detailed API information.');
        return response;
      }
      
      throw Exception('SMS test failed: ${res.statusCode} - ${res.body}');
    } catch (e) {
      print('❌ Error testing SMS service: $e');
      rethrow;
    }
  }
}

