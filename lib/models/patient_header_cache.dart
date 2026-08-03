/// Cache for patient header data (chronic conditions, allergies, risk factors).
class PatientHeaderCache {
  final List<dynamic> chronicConditions;
  final List<dynamic> allergies;
  final List<dynamic> riskFactors;

  const PatientHeaderCache({
    required this.chronicConditions,
    required this.allergies,
    required this.riskFactors,
  });

  bool get isEmpty =>
      chronicConditions.isEmpty && allergies.isEmpty && riskFactors.isEmpty;
}
