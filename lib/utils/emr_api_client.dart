import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'http_client_factory.dart';
import '../services/auth_service.dart';

class EmrApiClient {
  final String baseUrl;
  final http.Client _client;

  EmrApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? resolveEmrBaseUrl(),
        _client = client ?? createHttpClient(baseUrl ?? resolveEmrBaseUrl());

  /// Test connection to the server
  /// Returns a map with connection status and diagnostic information
  Future<Map<String, dynamic>> testConnection() async {
    final testUri = Uri.parse('$baseUrl/api/test');
    final healthUri = Uri.parse('$baseUrl/api/test/health');
    
    final diagnostics = <String, dynamic>{
      'baseUrl': baseUrl,
      'testEndpoint': testUri.toString(),
      'healthEndpoint': healthUri.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'alternativesTested': <String>[],
    };
    
    try {
      print('🔍 Testing connection to: $testUri');
      
      // Try the test endpoint first
      try {
        final testRes = await _client
            .get(testUri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 10));
        
        diagnostics['testEndpointStatus'] = testRes.statusCode;
        diagnostics['testEndpointSuccess'] = testRes.statusCode >= 200 && testRes.statusCode < 300;
        
        if (testRes.statusCode >= 200 && testRes.statusCode < 300) {
          try {
            final response = json.decode(testRes.body) as Map<String, dynamic>;
            diagnostics['testResponse'] = response;
            diagnostics['connected'] = true;
            diagnostics['message'] = 'Successfully connected to server';
            return diagnostics;
          } catch (e) {
            diagnostics['testResponseParseError'] = e.toString();
          }
        } else {
          diagnostics['testResponseBody'] = testRes.body.length > 200 
              ? testRes.body.substring(0, 200) + '...' 
              : testRes.body;
        }
      } catch (e) {
        diagnostics['testEndpointError'] = e.toString();
        print('⚠️ Test endpoint failed: $e');
        
        // If it's a socket error, try alternative URL formats
        if (e.toString().contains('Socket') || e.toString().contains('Connection failed')) {
          diagnostics['socketError'] = true;
          await _testAlternativeUrls(diagnostics);
        }
      }
      
      // Try the health endpoint as fallback
      try {
        final healthRes = await _client
            .get(healthUri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 10));
        
        diagnostics['healthEndpointStatus'] = healthRes.statusCode;
        diagnostics['healthEndpointSuccess'] = healthRes.statusCode >= 200 && healthRes.statusCode < 300;
        
        if (healthRes.statusCode >= 200 && healthRes.statusCode < 300) {
          diagnostics['connected'] = true;
          diagnostics['message'] = 'Server is reachable (health check)';
          return diagnostics;
        }
      } catch (e) {
        diagnostics['healthEndpointError'] = e.toString();
        print('⚠️ Health endpoint failed: $e');
      }
      
      // If we get here, connection failed
      diagnostics['connected'] = false;
      if (!diagnostics.containsKey('message')) {
        diagnostics['message'] = 'Failed to connect to server';
      }
      
      return diagnostics;
    } on TimeoutException {
      diagnostics['connected'] = false;
      diagnostics['timeout'] = true;
      diagnostics['message'] = 'Connection timeout - server may be unreachable or slow';
      return diagnostics;
    } on http.ClientException catch (e) {
      diagnostics['connected'] = false;
      diagnostics['networkError'] = true;
      diagnostics['socketError'] = e.toString().contains('Socket') || e.toString().contains('Connection failed');
      diagnostics['error'] = e.toString();
      diagnostics['message'] = 'Network error: ${e.message}';
      
      // Test alternative URLs if socket error
      if (diagnostics['socketError'] == true) {
        await _testAlternativeUrls(diagnostics);
      }
      
      return diagnostics;
    } catch (e) {
      diagnostics['connected'] = false;
      diagnostics['error'] = e.toString();
      diagnostics['message'] = 'Unexpected error: $e';
      
      // Test alternative URLs if socket error
      if (e.toString().contains('Socket') || e.toString().contains('Connection failed')) {
        diagnostics['socketError'] = true;
        await _testAlternativeUrls(diagnostics);
      }
      
      return diagnostics;
    }
  }

  /// Test alternative URL formats when socket connection fails
  Future<void> _testAlternativeUrls(Map<String, dynamic> diagnostics) async {
    final alternatives = <String>[];
    final baseUri = Uri.parse(baseUrl);
    final host = baseUri.host;
    final path = baseUri.path;
    
    // Try different URL variations
    final urlVariations = [
      'http://$host:80$path',           // Explicit port 80
      'http://$host$path',               // Current (already tested)
      'http://$host:5287$path',         // HTTP port from config
      'http://$host:7287$path',         // HTTPS port (as HTTP)
      'https://$host:7287$path',         // HTTPS
      'http://$host',                    // Without path
      'http://$host:80',                 // Without path, explicit port
    ];
    
    for (final altUrl in urlVariations) {
      if (altUrl == baseUrl) continue; // Skip the one we already tested
      
      try {
        final testUri = Uri.parse('$altUrl/api/test/health');
        alternatives.add('Testing: $testUri');
        print('🔄 Trying alternative URL: $testUri');
        
        final testClient = createHttpClient(altUrl);
        final res = await testClient
            .get(testUri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 5));
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          alternatives.add('✅ SUCCESS: $altUrl');
          diagnostics['workingUrl'] = altUrl;
          diagnostics['message'] = 'Found working URL: $altUrl';
          break;
        } else {
          alternatives.add('❌ Failed ($altUrl): Status ${res.statusCode}');
        }
      } catch (e) {
        alternatives.add('❌ Failed ($altUrl): ${e.toString().split('\n').first}');
      }
    }
    
    diagnostics['alternativesTested'] = alternatives;
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    return await AuthService.instance.getAuthHeaders();
  }

  Future<http.Response> _authenticatedGet(Uri uri) async {
    final headers = await _getAuthHeaders();
    return await _client.get(uri, headers: headers);
  }

  Future<http.Response> _authenticatedPost(Uri uri, {Object? body}) async {
    final headers = await _getAuthHeaders();
    return await _client.post(uri, headers: headers, body: body is String ? body : json.encode(body));
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
        final res = await _client.get(uri).timeout(const Duration(seconds: 10));
        
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
          
          return patient;
        }
        
        // If 400 or 404, try next format
        if (res.statusCode == 400 || res.statusCode == 404) {
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
    
    
    // Use POST endpoint for login with password, or GET if no password provided
    if (password != null && password.isNotEmpty) {
      // POST request with CNIC and password
      final uri = Uri.parse('$baseUrl/api/patient-auth/login');
      
      try {
        print('📤 Login Request');
        print('   URL: $uri');
        print('   CNIC: $cleanedCnic');
        
        final body = json.encode({
          'cnic': cleanedCnic,
          'password': password,
        });
        
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(seconds: 15));
        
        print('📥 Login Response Status: ${res.statusCode}');
        print('   Body: ${res.body.length > 200 ? res.body.substring(0, 200) + "..." : res.body}');
        
        
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
          
          return patients;
        }
        
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw Exception('Invalid CNIC or password');
        }
        
        if (res.statusCode == 404) {
          return [];
        }
        
        throw Exception('Failed to login (${res.statusCode}): ${res.body}');
      } on TimeoutException {
        print('⏱️ Login timeout');
        throw Exception('Login request timeout. Please check your internet connection and try again.\n\nURL: $uri');
      } on http.ClientException catch (e) {
        print('🌐 Login network error: $e');
        final errorMsg = e.toString();
        if (errorMsg.contains('Socket') || errorMsg.contains('Connection failed')) {
          throw Exception('Cannot connect to server. Socket connection failed.\n\n'
              'This usually means:\n'
              '- Server is not running\n'
              '- Wrong server address\n'
              '- Network/firewall blocking connection\n'
              '- Incorrect URL path\n\n'
              'URL: $uri\n'
              'Error: ${e.message}');
        }
        throw Exception('Network error during login: ${e.message}\n\nPlease check your internet connection.\nURL: $uri');
      } catch (e) {
        if (e.toString().contains('Socket') || e.toString().contains('Connection failed')) {
          throw Exception('Cannot connect to server. Socket connection failed.\n\n'
              'URL: $uri\n'
              'Error: $e');
        }
        rethrow;
      }
    } else {
      // Fallback to GET endpoint if no password provided (for backward compatibility)
      final encodedCnic = Uri.encodeComponent(cleanedCnic);
      final uri = Uri.parse('$baseUrl/api/min-patients/by-cnic/$encodedCnic');
      
      try {
        
        final res = await _client.get(uri).timeout(const Duration(seconds: 15));
        
        
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
          
          return patients;
        }
        
        if (res.statusCode == 404) {
          return [];
        }
        
        throw Exception('Failed to login with CNIC (${res.statusCode}): ${res.body}');
      } catch (e) {
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
    
    
    // URL encode the phone number to handle special characters
    final encodedPhone = Uri.encodeComponent(cleanedPhone);
    final uri = Uri.parse('$baseUrl/api/min-patients/by-phone/$encodedPhone');
    
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      
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
        
        return patients;
      }
      
      if (res.statusCode == 404) {
        return [];
      }
      
      throw Exception('Failed to login with phone number (${res.statusCode}): ${res.body}');
    } catch (e) {
      rethrow;
    }
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Register a new patient using the new /api/patient-auth/register endpoint
  Future<Map<String, dynamic>> registerPatient({
    required String fullName,
    required String cnic,
    required String phone,
    String? email,
    required DateTime dateOfBirth,
    required String gender,
    String? address,
    String? bloodGroup,
    String? password,
    String? registrationType,
    String? parentType,
    int? createdBy,
  }) async {
    // Use new dedicated registration endpoint
    final uri = Uri.parse('$baseUrl/api/patient-auth/register');
    try {
      
      final cleanCnic = cnic.replaceAll(RegExp(r'[^0-9]'), '');
      final trimmedPassword = password?.trim();
      
      // Hash password before sending
      String? hashedPassword;
      if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
        hashedPassword = _hashPassword(trimmedPassword);
      }
      
      final body = <String, dynamic>{
        'cnic': cleanCnic,
        'fullName': fullName.trim(),
        'contactNumber': phone.trim(),
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'source': 'Flutter',
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Not Known') 'bloodGroup': bloodGroup,
        if (hashedPassword != null) 'passwordHash': hashedPassword,
      };
      
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      
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
      rethrow;
    }
  }

  Future<List<dynamic>> fetchVitals(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/vitals');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no vitals records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load vitals (${res.statusCode})');
  }

  Future<List<dynamic>> fetchMedications(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/medications');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no medications records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load medications (${res.statusCode})');
  }

  Future<List<dynamic>> fetchOPD(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/opd');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no OPD records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load OPD records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchIPD(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/ipd');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no IPD records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load IPD records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchLabs(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/labs');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no lab records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load lab results (${res.statusCode})');
  }

  Future<List<dynamic>> fetchRadiology(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/radiology');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no radiology records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
    }
    throw Exception('Failed to load radiology records (${res.statusCode})');
  }

  Future<List<dynamic>> fetchSurgery(String mrn) async {
    final uri = Uri.parse('$baseUrl/api/patient/$mrn/surgery');
    final res = await _authenticatedGet(uri);
    if (res.statusCode == 404) {
      // Patient has no surgery records - return empty list
      return <dynamic>[];
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as List<dynamic>;
      return data;
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
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      
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
      rethrow;
    }
  }

  Future<List<dynamic>> fetchDepartments() async {
    final uri = Uri.parse('$baseUrl/api/departments');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      
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
      rethrow;
    }
  }

  // Fetch hospital departments by hospital ID (returns hospitalDepartmentID)
  Future<List<dynamic>> fetchHospitalDepartments(int hospitalId) async {
    final uri = Uri.parse('$baseUrl/api/hospital-setup/hospital-departments?hospitalId=$hospitalId');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      
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
    
    // Retry logic for token generation failures (transient errors)
    const maxRetries = 2;
    Exception? lastError;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // Wait a bit before retrying to allow any concurrent operations to complete
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
        
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));
        
        if (res.statusCode == 409) {
          // Patient already in queue or other conflict - return existing queue info if available
          final response = json.decode(res.body) as Map<String, dynamic>;
          final message = response['message'] as String? ?? 'Patient already in queue';
          final queueId = response['queueId'];
          final tokenNumber = response['tokenNumber'];
          
          if (queueId != null && tokenNumber != null) {
            // Patient is already in queue - return the existing queue info
            return {
              'queueId': queueId,
              'tokenNumber': tokenNumber,
            };
          } else if (message.contains('Failed to generate token number') && attempt < maxRetries) {
            // Token generation failed - retry
            lastError = Exception('Token generation failed. Please try again.');
            continue;
          } else {
            // Other conflict or max retries reached
            throw Exception('$message${queueId != null ? ' Queue ID: $queueId' : ''}${tokenNumber != null ? ' Token: $tokenNumber' : ''}');
          }
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
        lastError = e is Exception ? e : Exception(e.toString());
        
        // If it's a token generation error and we haven't exhausted retries, continue
        if (e.toString().contains('Failed to generate token number') && attempt < maxRetries) {
          continue;
        }
        
        // For other errors or max retries reached, break and throw
        if (attempt >= maxRetries || !e.toString().contains('Failed to generate token number')) {
          break;
        }
      }
    }
    
    // If we get here, all retries failed
    throw lastError ?? Exception('Failed to add patient to queue after multiple attempts');
  }

  // Print queue receipt - returns receipt data as it appears in the print API
  Future<Map<String, dynamic>> printQueueReceipt({
    required int queueId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/queue/$queueId/print');
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Parse and return the receipt data
        try {
          final receiptData = json.decode(res.body) as Map<String, dynamic>;
          return receiptData;
        } catch (e) {
          // If response is not JSON, return empty map
          return {};
        }
      }
      throw Exception('Failed to print queue receipt (${res.statusCode}): ${res.body}');
    } catch (e) {
      // Return empty map instead of throwing - allows UI to still show appointment details
      return {};
    }
  }

  // Request OTP for patient authentication
  Future<Map<String, dynamic>> requestOtp({required String cnic}) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/otp/request');
    try {
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
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
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
        'code': otpCode.trim(),
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
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
      rethrow;
    }
  }

  // Request registration OTP (server-side generation)
  Future<Map<String, dynamic>> requestRegistrationOtp({
    required String phoneNumber,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/otp/request-registration');
    try {
      final body = {
        'phoneNumber': phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''), // Clean phone
      };
      
      final bodyJson = json.encode(body);
      print('📤 Request Registration OTP');
      print('   URL: $uri');
      print('   Body: $bodyJson');
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      ).timeout(const Duration(seconds: 15));
      
      print('📥 Response Status: ${res.statusCode}');
      print('   Headers: ${res.headers}');
      print('   Body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        try {
          final response = json.decode(res.body) as Map<String, dynamic>;
          // Handle API response wrapper if present
          if (response.containsKey('data')) {
            return response['data'] as Map<String, dynamic>;
          }
          return response;
        } catch (e) {
          print('⚠️ Error parsing success response: $e');
          throw Exception('Invalid response format from server');
        }
      }
      
      // Parse error message with detailed information
      String errorMessage = 'Failed to request registration OTP';
      String? detailedError;
      Map<String, dynamic>? errorData;
      
      try {
        final errorResponse = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = errorResponse['message'] as String? ?? 
                      errorResponse['error'] as String? ?? 
                      errorMessage;
        
        // Extract detailed error information
        if (errorResponse.containsKey('data')) {
          errorData = errorResponse['data'] as Map<String, dynamic>?;
        }
        
        // Build detailed error message
        final buffer = StringBuffer();
        buffer.writeln('HTTP ${res.statusCode} Error');
        buffer.writeln('URL: $uri');
        buffer.writeln('Message: $errorMessage');
        
        if (errorData != null) {
          buffer.writeln('Error Details:');
          errorData.forEach((key, value) {
            buffer.writeln('  $key: $value');
          });
        }
        
        if (res.body.length < 500) {
          buffer.writeln('Response Body: ${res.body}');
        }
        
        detailedError = buffer.toString();
      } catch (e) {
        detailedError = 'Status: ${res.statusCode}\nURL: $uri\nResponse: ${res.body.length > 200 ? res.body.substring(0, 200) + "..." : res.body}';
      }
      
      final fullError = '${errorMessage}\n\nDebug Info:\n$detailedError';
      throw Exception(fullError);
    } on TimeoutException {
      print('⏱️ Request timeout');
      throw Exception('Request timeout. Please check your internet connection and try again.\n\nURL: $uri');
    } on http.ClientException catch (e) {
      print('🌐 Network error: $e');
      throw Exception('Network error: ${e.message}\n\nPlease check your internet connection.\nURL: $uri');
    } catch (e) {
      print('❌ Error: $e');
      if (e is Exception && e.toString().contains('Debug Info:')) {
        rethrow; // Already has detailed info
      }
      throw Exception('Unexpected error: ${e.toString()}\n\nURL: $uri');
    }
  }

  // Verify registration OTP (server-side verification)
  Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/otp/verify-registration');
    try {
      final body = {
        'phoneNumber': phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''), // Clean phone
        'code': otpCode.trim(),
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
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
      rethrow;
    }
  }

  // Verify set-password OTP (server-side verification)
  Future<Map<String, dynamic>> verifySetPasswordOtp({
    required String cnic,
    required String otpCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/otp/verify-set-password');
    try {
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
        'code': otpCode.trim(),
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
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
      rethrow;
    }
  }

  // Set password for a patient by CNIC
  Future<void> setPasswordByCnic({
    required String cnic,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient-auth/set-password');
    try {
      final body = {
        'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''), // Clean CNIC
        'password': password,
      };
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }
      
      // Parse error message
      String errorMessage = 'Failed to set password';
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
      rethrow;
    }
  }

}

