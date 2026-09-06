import '../utils/emr_api_client.dart';

class PharmacyService {
  PharmacyService._();

  static final EmrApiClient _api = EmrApiClient();

  static Future<List<Map<String, dynamic>>> getActivePatientMedicines({
    required int patientId,
    bool getAllHistory = false,
  }) => _api.getActivePatientMedicines(
    patientId: patientId,
    getAllHistory: getAllHistory,
  );
}
