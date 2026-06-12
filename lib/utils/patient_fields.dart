/// Shared helpers for reading patient profile fields from API / saved data maps.
class PatientFields {
  PatientFields._();

  static String displayName(
    Map<String, dynamic> patient, [
    Map<String, dynamic>? savedUserData,
  ]) {
    const keys = [
      'fullName',
      'FullName',
      'name',
      'Name',
      'patientName',
      'PatientName',
    ];

    for (final key in keys) {
      final fromPatient = patient[key];
      if (fromPatient != null && fromPatient.toString().trim().isNotEmpty) {
        return fromPatient.toString().trim();
      }
      final fromSaved = savedUserData?[key];
      if (fromSaved != null && fromSaved.toString().trim().isNotEmpty) {
        return fromSaved.toString().trim();
      }
    }

    return 'Patient';
  }
}
