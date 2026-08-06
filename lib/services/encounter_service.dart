import '../utils/emr_api_client.dart';

/// Thin wrapper around [EmrApiClient] for encounter and clinical data (used by history / IPD screens).
class EncounterService {
  final EmrApiClient _api = EmrApiClient();

  Future<List<dynamic>> getPatientVitals(
    int patientId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _api.getPatientVitals(patientId, fromDate: fromDate, toDate: toDate);

  Future<List<Map<String, dynamic>>> getAllPatientEncounters(
    int patientId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _api.getAllPatientEncounters(patientId, fromDate: fromDate, toDate: toDate);

  Future<Map<String, dynamic>> getPatientClinicalHistory(
    int patientId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _api.getPatientClinicalHistory(patientId, fromDate: fromDate, toDate: toDate);

  Future<Map<String, dynamic>> getEncounterDetails(int encounterId) =>
      _api.getEncounterDetails(encounterId);

  Future<Map<String, dynamic>> getEncounterConsultationData(
    int encounterId, {
    int? patientId,
  }) =>
      _api.getEncounterConsultationData(encounterId, patientId: patientId);

  Future<List<Map<String, dynamic>>> getEncountersByAdmissionId(int admissionId) =>
      _api.getEncountersByAdmissionId(admissionId);

  Future<List<dynamic>> getPatientChronicConditions(dynamic patientId) async {
    final id = patientId is int ? patientId : int.parse(patientId.toString());
    return _api.getPatientChronicConditions(id);
  }
}
