import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'user_session_service.dart';

class EncounterService {

  // Get Today's Patient List
  Future<List<Map<String, dynamic>>> getTodayPatients({
    int? doctorId,
    int? hospitalId,
    String type = 'All',
  }) async {
    try {
      final queryParams = <String, String>{
        'type': type,
      };
      
      if (doctorId != null) queryParams['doctorId'] = doctorId.toString();
      if (hospitalId != null) queryParams['hospitalId'] = hospitalId.toString();

      final uri = Uri.parse('${ApiConfig.encountersEndpoint}${ApiConfig.todayPatientsPath}').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['patients'] ?? []);
      } else {
        throw Exception('Failed to load today\'s patients: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting today\'s patients: $e');
      rethrow;
    }
  }

  // Search Patient for Encounter
  Future<List<Map<String, dynamic>>> searchPatient({
    required String type,
    required String value,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.encountersEndpoint}${ApiConfig.searchPatientPath}').replace(
        queryParameters: {
          'type': type,
          'value': value,
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['patients'] ?? []);
      } else {
        throw Exception('Failed to search patient: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching patient: $e');
      rethrow;
    }
  }

  // Create New Encounter
  Future<Map<String, dynamic>> createEncounter(Map<String, dynamic> encounterData) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.encountersEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(encounterData),
      );

      if (response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          throw Exception('Empty response from server');
        }
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create encounter: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating encounter: $e');
      rethrow;
    }
  }

  // Update Encounter Status
  Future<Map<String, dynamic>> updateEncounterStatus(
    int encounterId,
    Map<String, dynamic> statusData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.encountersEndpoint}/$encounterId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(statusData),
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          throw Exception('Empty response from server');
        }
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update encounter status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating encounter status: $e');
      rethrow;
    }
  }

  // Get Encounter Details
  Future<Map<String, dynamic>> getEncounterDetails(int encounterId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/$encounterId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          throw Exception('Empty response from server');
        }
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get encounter details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting encounter details: $e');
      rethrow;
    }
  }

  // Get encounter consultation data (complaints, symptoms, diagnosis, orders)
  Future<Map<String, dynamic>> getEncounterConsultationData(
    int encounterId, {
    int? patientId,
  }) async {
    try {
      var uri = Uri.parse('${ApiConfig.consultationEndpoint}/encounter/$encounterId');
      if (patientId != null) {
        uri = uri.replace(queryParameters: {'patientId': patientId.toString()});
      }

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          throw Exception('Empty response from server');
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return {};
      } else {
        throw Exception('Failed to load encounter consultation data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting encounter consultation data: $e');
      rethrow;
    }
  }

  // Get Patient Encounter History (with optional doctorId and hospitalId filters)
  Future<List<Map<String, dynamic>>> getPatientEncounterHistory(
    int patientId, {
    int? doctorId,
    int? hospitalId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (doctorId != null) queryParams['doctorId'] = doctorId.toString();
      if (hospitalId != null) queryParams['hospitalId'] = hospitalId.toString();
      
      final uri = Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['encounters'] ?? []);
      } else {
        throw Exception('Failed to get patient encounter history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting patient encounter history: $e');
      rethrow;
    }
  }

  // Get All Patient Encounters (without doctorId and hospitalId filters)
  // This calls a new endpoint that returns all encounters for a patient
  Future<List<Map<String, dynamic>>> getAllPatientEncounters(
    int patientId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (fromDate != null) {
        queryParams['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        queryParams['toDate'] = toDate.toIso8601String();
      }

      final uri = Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId/all')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['encounters'] ?? []);
      } else {
        throw Exception('Failed to get all patient encounters: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting all patient encounters: $e');
      rethrow;
    }
  }

  // Get Patient Vitals
  // Purpose: Retrieves all vital signs records for a patient
  // Output: List of vital signs records with timestamps and values
  Future<List<dynamic>> getPatientVitals(
    int patientId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (fromDate != null) {
        queryParams['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        queryParams['toDate'] = toDate.toIso8601String();
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/patient-queue/patient-vitals/$patientId')
          .replace(queryParameters: queryParams);
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is List) {
          return List<dynamic>.from(data);
        } else if (data is Map && data['data'] != null) {
          return List<dynamic>.from(data['data']);
        } else if (data is Map && data['vitalSigns'] != null) {
          return List<dynamic>.from(data['vitalSigns']);
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error getting patient vitals: $e');
      return [];
    }
  }

  // Get Patient Medications
  // Purpose: Retrieves all medication records for a patient
  // Output: List of medication records with dosages and prescriptions
  Future<List<dynamic>> getPatientMedications(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId${ApiConfig.medicationsPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['medications'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient medications: $e');
      return [];
    }
  }

  // Get Patient OPD Visits
  // Purpose: Retrieves all OPD visit records for a patient
  // Output: List of OPD visit records with diagnoses and treatments
  Future<List<dynamic>> getPatientOPDVisits(int patientId) async {
    try {
      final uri = Uri.parse('${ApiConfig.emrEndpoint}/opd-records').replace(
        queryParameters: {'patientId': patientId.toString()},
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['opdRecords'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient OPD visits: $e');
      return [];
    }
  }

  // Get Patient IPD Admissions
  // Purpose: Retrieves all IPD admission records for a patient
  // Output: List of IPD admission records with admission/discharge details
  Future<List<dynamic>> getPatientIPDAdmissions(int patientId) async {
    try {
      final uri = Uri.parse('${ApiConfig.emrEndpoint}/ipd-records').replace(
        queryParameters: {'patientId': patientId.toString()},
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['ipdRecords'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient IPD admissions: $e');
      return [];
    }
  }

  // Get Patient Lab Results
  // Purpose: Retrieves all lab test results for a patient
  // Output: List of lab results with test values and reference ranges
  // API: GET /api/encounters/patient/{patientId}/labs
  // Response: { labs: [...] } with fields: date, test, result, normalRange, status, orderedBy, 
  //          sampleDate, resultId, sampleId, testId, isCritical, abnormalFlags
  Future<List<dynamic>> getPatientLabResults(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId${ApiConfig.labsPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        // Backend returns { labs: [...] } not { labResults: [...] }
        return List<dynamic>.from(data['labs'] ?? data['labResults'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient lab results: $e');
      return [];
    }
  }

  // Get Patient Radiology
  // Purpose: Retrieves all radiology reports for a patient
  // Output: List of radiology reports with findings and impressions
  Future<List<dynamic>> getPatientRadiology(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId${ApiConfig.radiologyPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['radiology'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient radiology: $e');
      return [];
    }
  }

  // Get Patient Surgery
  // Purpose: Retrieves all surgery records for a patient
  // Output: List of surgery records with procedures and outcomes
  Future<List<dynamic>> getPatientSurgery(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/patient/$patientId${ApiConfig.surgeryPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['surgery'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient surgery: $e');
      return [];
    }
  }

  // Get Patient Chronic Conditions
  // Purpose: Retrieves all chronic conditions for a patient
  // Output: List of chronic conditions with names and codes
  Future<List<dynamic>> getPatientChronicConditions(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.patientChronicConditionsPath}/$patientId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<dynamic>.from(data['chronicConditions'] ?? data['conditions'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting patient chronic conditions: $e');
      return [];
    }
  }

  // Get Encounter by QueueId
  // Purpose: Retrieves encounter associated with a specific queueId
  // Output: Encounter details if found, null otherwise
  Future<Map<String, dynamic>?> getEncounterByQueueId(int queueId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/queue/$queueId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return null;
        }
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get encounter by queueId: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting encounter by queueId: $e');
      return null;
    }
  }

  // Get Encounters by Admission ID
  // Purpose: Retrieves all encounters associated with a specific admission ID
  // Output: List of encounters for the admission
  Future<List<Map<String, dynamic>>> getEncountersByAdmissionId(int admissionId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.encountersEndpoint}/admission/$admissionId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return [];
        }
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['encounters'] ?? data['data'] ?? []);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to get encounters by admission ID: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting encounters by admission ID: $e');
      return [];
    }
  }
}
