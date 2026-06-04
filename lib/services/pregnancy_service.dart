import '../utils/emr_api_client.dart';

/// Encounters, allergy/risk APIs, pregnancy list (via MRN), and surgeries share this façade for legacy screens.
class PregnancyService {
  final EmrApiClient _api = EmrApiClient();

  Future<List<Map<String, dynamic>>> getPatientSurgeries(int patientId) =>
      _api.getPatientSurgeries(patientId);

  Future<List<Map<String, dynamic>>> getPatientAllergies(dynamic patientId) async {
    final id = patientId is int ? patientId : int.parse(patientId.toString());
    return _api.getPatientAllergies(id);
  }

  Future<List<Map<String, dynamic>>> getPatientRiskFactors(dynamic patientId) async {
    final id = patientId is int ? patientId : int.parse(patientId.toString());
    return _api.getPatientRiskFactors(id);
  }

  Future<List<Map<String, dynamic>>> getPregnancyHistory(int patientId) async {
    try {
      final patient = await _api.fetchPatient(patientId.toString());
      final mrn = patient['mrn'] ?? patient['MRN'] ?? patient['mrnNumber'];
      if (mrn == null) return [];
      final raw = await _api.fetchPregnancy(mrn.toString());
      final out = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          out.add(e);
        } else if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActivePregnancy(int patientId) async {
    final list = await getPregnancyHistory(patientId);
    for (final m in list) {
      final active = m['isActive'] ?? m['IsActive'] ?? m['active'];
      if (active == true) return m;
    }
    if (list.isNotEmpty) return list.first;
    return null;
  }
}
