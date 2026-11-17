import '../patient_date_parse.dart';

/// Clinical cohort for vital sign reference ranges (Fourth Report / PALS / neonatal norms).
enum VitalCohort {
  neonate,
  infant,
  child,
  adolescent,
  adult,
}

/// Resolved age for vitals UI and range selection.
class PatientAgeContext {
  PatientAgeContext({
    required this.cohort,
    required this.ageDays,
    required this.ageMonths,
    required this.ageYears,
    required this.dateOfBirth,
    required this.ageIsEstimated,
  });

  final VitalCohort cohort;
  final int ageDays;
  final int ageMonths;
  final double ageYears;
  final DateTime? dateOfBirth;

  /// True when DOB was missing and age was guessed from `age` field or defaulted.
  final bool ageIsEstimated;

  bool get showBmi => ageYears >= 18;

  /// Fourth Report BP tables apply for age >= 1 year through 17; neonates/young infants use other rules.
  bool get usePediatricBpPercentile =>
      cohort != VitalCohort.neonate &&
      cohort != VitalCohort.adult &&
      ageYears >= 1.0 &&
      ageYears < 18.0;

  bool get useNeonatalBp => cohort == VitalCohort.neonate;

  bool get useAdultBp => cohort == VitalCohort.adult || ageYears >= 18.0;

  /// Infants 29d–364d: interpolate toward 1y BP tables using length; handled in BP module.
  bool get useInfantBpSimplified =>
      cohort == VitalCohort.infant && ageYears < 1.0;

  String get cohortLabel {
    switch (cohort) {
      case VitalCohort.neonate:
        return 'Neonate';
      case VitalCohort.infant:
        return 'Infant';
      case VitalCohort.child:
        return 'Child';
      case VitalCohort.adolescent:
        return 'Adolescent';
      case VitalCohort.adult:
        return 'Adult';
    }
  }

  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static int _monthsFloor(DateTime dob, DateTime now) {
    int m = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) m--;
    return m < 0 ? 0 : m;
  }

  static double _yearsFractional(DateTime dob, DateTime now) {
    final days = _daysBetween(dob, now);
    return days / 365.25;
  }

  /// 0–28 days → neonate; 29d–364d → infant; 1–12y child; 13–17 adolescent; 18+ adult.
  static VitalCohort cohortFromAgeDaysAndMonths(int ageDays, int ageMonths) {
    if (ageDays <= 28) return VitalCohort.neonate;
    if (ageDays < 365) return VitalCohort.infant;
    final years = ageMonths ~/ 12;
    if (years <= 12) return VitalCohort.child;
    if (years <= 17) return VitalCohort.adolescent;
    return VitalCohort.adult;
  }

  static PatientAgeContext fromPatientMap(Map<String, dynamic> patient, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final dobValue = patient['dateOfBirth'] ?? patient['DateOfBirth'];
    final dob = parsePatientDateOfBirth(dobValue);

    if (dob != null) {
      final days = _daysBetween(dob, clock);
      final months = _monthsFloor(dob, clock);
      final years = _yearsFractional(dob, clock);
      final cohort = cohortFromAgeDaysAndMonths(days, months);
      return PatientAgeContext(
        cohort: cohort,
        ageDays: days,
        ageMonths: months,
        ageYears: years,
        dateOfBirth: dob,
        ageIsEstimated: false,
      );
    }

    final approxYears = parseApproximateAgeYears(patient['age'] ?? patient['Age']);
    if (approxYears != null) {
      final estDays = (approxYears * 365.25).round();
      final estMonths = (approxYears * 12).floor();
      final cohort = cohortFromAgeDaysAndMonths(estDays, estMonths);
      return PatientAgeContext(
        cohort: cohort,
        ageDays: estDays,
        ageMonths: estMonths,
        ageYears: approxYears,
        dateOfBirth: null,
        ageIsEstimated: true,
      );
    }

    return PatientAgeContext(
      cohort: VitalCohort.adult,
      ageDays: 30 * 365,
      ageMonths: 30 * 12,
      ageYears: 30.0,
      dateOfBirth: null,
      ageIsEstimated: true,
    );
  }
}
