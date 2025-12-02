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
    final uri = Uri.parse('$baseUrl/api/patient/$mrn');
    try {
      print('🔍 Fetching patient from: $uri');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final patient = json.decode(res.body) as Map<String, dynamic>;
        // Verify the returned patient's MRN matches the requested MRN
        final returnedMrn = patient['mrn'] as String?;
        if (returnedMrn != mrn) {
          throw Exception('MRN mismatch: requested $mrn but got $returnedMrn');
        }
        print('✅ Patient loaded successfully: ${patient['name']}');
        return patient;
      }
      throw Exception('Failed to load patient (${res.statusCode}): ${res.body}');
    } catch (e) {
      print('❌ Error fetching patient: $e');
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
}


