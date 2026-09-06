import '../utils/emr_api_client.dart';

class SurgeryService {
  SurgeryService._();

  static final EmrApiClient _api = EmrApiClient();

  static Future<List<Map<String, dynamic>>> getPatientSurgeries(
    int patientId,
  ) => _api.getPatientSurgeries(patientId);
}
