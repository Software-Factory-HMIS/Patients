import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'user_session_service.dart';

class WardService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Get hospital departments
  static Future<List<Map<String, dynamic>>> getHospitalDepartments(int hospitalId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/hospital-setup/hospital-departments?hospitalId=$hospitalId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get hospital departments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting hospital departments: $e');
    }
  }

  // Get active wards by hospital department
  static Future<List<Map<String, dynamic>>> getActiveWardsByDepartment(int hospitalDepartmentId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/wards/getActiveWardsByDepartment/$hospitalDepartmentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> wards = data['data'];
          return wards.cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        throw Exception('Failed to get active wards: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting active wards: $e');
    }
  }

  // Get patient admission status (queue or admitted)
  static Future<Map<String, dynamic>?> getPatientAdmissionStatus(int patientId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/wards/getPatientAdmissionStatus/$patientId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get patient admission history (WardAdmissions with surgery details)
  static Future<List<Map<String, dynamic>>> getPatientAdmissionHistory(int patientId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final url = '${ApiConfig.baseUrl}/wards/getPatientAdmissionHistory/$patientId';
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(
            (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      if (response.statusCode != 200) {
        print('[WardService] getPatientAdmissionHistory failed: ${response.statusCode} ${response.body}');
      }
      return [];
    } catch (e) {
      print('[WardService] getPatientAdmissionHistory error: $e');
      return [];
    }
  }

  // Get discharge slip data for printing
  static Future<Map<String, dynamic>?> getDischargeSlipData(int admissionId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/wards/getDischargeSlipData/$admissionId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get ward by name
  static Future<Map<String, dynamic>?> getWardByName(String wardName, int hospitalId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('$baseUrl/Wards/getWardByName').replace(
        queryParameters: {'wardName': wardName},
      );
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get ward patient queue (pending admission requests for a ward)
  static Future<List<Map<String, dynamic>>> getWardPatientQueue(int wardId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final response = await http.get(
        Uri.parse('$baseUrl/wards/getWardPatientQueue/$wardId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final raw = data['data'] as List;
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Cancel a ward queue entry (set status to Cancelled)
  static Future<void> cancelWardQueue(int queueId) async {
    final token = await UserSessionService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final response = await http.post(
      Uri.parse('$baseUrl/wards/cancelWardQueue'),
      headers: headers,
      body: json.encode({'queueID': queueId}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to cancel queue entry');
      }
      return;
    }
    final errorData = json.decode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to cancel queue entry: ${response.statusCode}');
  }

  // Get ward beds
  static Future<List<Map<String, dynamic>>> getWardBeds(int wardId) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final uri = Uri.parse('$baseUrl/Wards/getAllWardBedsByWardId').replace(
        queryParameters: {'WardId': wardId.toString(), 'PageNumber': '1', 'PageSize': '500'},
      );
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> raw = data['data'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Admit patient to bed
  static Future<Map<String, dynamic>> admitPatient({
    required int queueId,
    required int wardId,
    required int bedId,
    required int patientId,
    String? notes,
  }) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final body = {
        'admissionID': 0,
        'queueID': queueId,
        'wardID': wardId,
        'bedID': bedId,
        'patientID': patientId,
        'admissionDatetime': DateTime.now().toUtc().toIso8601String(),
        'dischargeDatetime': null,
        'notes': notes ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/Wards/admitPatient'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] != null
              ? data['data'] as Map<String, dynamic>
              : <String, dynamic>{};
        }
        throw Exception(data['message'] ?? 'Failed to admit patient');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to admit patient: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error admitting patient: $e');
    }
  }

  // Create admission request
  static Future<Map<String, dynamic>> createAdmissionRequest({
    required int patientId,
    required int wardId,
    required int? encounterId,
    String? priority,
    String? notes,
    String? admissionDiagnosis,
  }) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/wards/createAdmissionRequest'),
        headers: headers,
        body: json.encode({
          'patientID': patientId,
          'wardID': wardId,
          'encounterId': encounterId,
          'priority': priority ?? 'Normal',
          'notes': notes,
          'admissionDiagnosis': admissionDiagnosis,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
        throw Exception(data['message'] ?? 'Failed to create admission request');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create admission request: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating admission request: $e');
    }
  }

  /// Returns discharge outcomes with optional outcomeGroup for UI grouping.
  static Future<List<Map<String, dynamic>>> getDischargeOutcomes() async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/DropDowns/getAllDischargeOutcomes'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          return list
              .map((e) {
                final type = (e['outcomeType'] ?? e['OutcomeType'] ?? '').toString();
                final group = (e['outcomeGroup'] ?? e['OutcomeGroup'] ?? '').toString();
                return type.isNotEmpty ? {'outcomeType': type, 'outcomeGroup': group} : null;
              })
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> dischargePatient({
    required int admissionId,
    required String dischargeNotes,
    required String dischargeOutcome,
  }) async {
    try {
      final token = await UserSessionService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final body = {
        'admissionID': admissionId,
        'dischargeNotes': dischargeNotes,
        'dischargeOutcome': dischargeOutcome,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/wards/dischargePatient'),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to discharge patient');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to discharge patient: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error discharging patient: $e');
    }
  }

  static Future<void> transferPatient({
    required int admissionId,
    required int fromBedId,
    required int toBedId,
    required int wardId,
    required int departmentId,
    required int patientId,
    required String transferReason,
    String? reasonDetails,
    String? notes,
  }) async {
    try {
      final token = await UserSessionService.getToken();
      final userId = await UserSessionService.getUserId() ?? 0;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final body = {
        'transferID': 0,
        'departmentID': departmentId,
        'wardID': wardId,
        'patientID': patientId,
        'admissionID': admissionId,
        'fromBedId': fromBedId,
        'toBedId': toBedId,
        'transferDatetime': DateTime.now().toUtc().toIso8601String(),
        'transferReason': transferReason,
        'reasonDetails': reasonDetails ?? '',
        'requestedBy': userId,
        'approvedBy': userId,
        'status': 'Completed',
        'notes': notes ?? '',
      };
      final response = await http.post(
        Uri.parse('$baseUrl/wards/transferPatient'),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to transfer patient');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to transfer patient: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error transferring patient: $e');
    }
  }
}


