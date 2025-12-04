import 'dart:convert';
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

  Future<Map<String, dynamic>> fetchPatient(String mrn) async {
    // Try both with and without dashes
    final cleanMrn = mrn.replaceAll('-', '');
    final uris = [
      Uri.parse('$baseUrl/api/patient/$mrn'),      // Try with dashes first
      Uri.parse('$baseUrl/api/patient/$cleanMrn'), // Then without dashes
    ];
    
    Exception? lastError;
    
    for (final uri in uris) {
      try {
        print('🔍 Fetching patient from: $uri');
        final res = await _client.get(uri).timeout(const Duration(seconds: 10));
        print('📡 Response status: ${res.statusCode}');
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final patient = json.decode(res.body) as Map<String, dynamic>;
          print('✅ Patient loaded successfully: ${patient['name'] ?? 'Unknown'}');
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

  // Register a new patient
  Future<Map<String, dynamic>> registerPatient({
    required String fullName,
    required String cnic,
    required String phone,
    required String email,
    required DateTime dateOfBirth,
    required String gender,
    required String address,
    String? bloodGroup,
  }) async {
    final uri = Uri.parse('$baseUrl/api/patient');
    try {
      print('🔍 Registering patient: $uri');
      
      // Remove dashes from CNIC for API
      final cleanCnic = cnic.replaceAll('-', '');
      
      final body = {
        'fullName': fullName,
        'cnic': cleanCnic,
        'phone': phone,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'address': address,
        if (bloodGroup != null && bloodGroup.isNotEmpty) 'bloodGroup': bloodGroup,
      };
      
      print('📤 Request body: $body');
      
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = json.decode(res.body) as Map<String, dynamic>;
        // Handle API response wrapper if present
        if (response.containsKey('data')) {
          return response['data'] as Map<String, dynamic>;
        }
        print('✅ Patient registered successfully');
        return response;
      }
      throw Exception('Failed to register patient (${res.statusCode}): ${res.body}');
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
}

