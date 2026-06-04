import '../utils/emr_api_client.dart';

class PatientService {
  final EmrApiClient _api = EmrApiClient();

  Future<Map<String, dynamic>?> getPatientDetails(dynamic patientId) async {
    try {
      return await _api.fetchPatient(patientId.toString());
    } catch (_) {
      return null;
    }
  }
}
