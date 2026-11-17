/// Shared DOB parsing for patient maps (API may return ISO strings or DateTime).
DateTime? parsePatientDateOfBirth(dynamic dateValue) {
  if (dateValue == null) return null;
  if (dateValue is DateTime) return dateValue;
  if (dateValue is String) {
    try {
      return DateTime.parse(dateValue);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Parses "5", "5y", "3 months" style age when DOB is missing. Returns years (approx) or null.
double? parseApproximateAgeYears(dynamic ageValue) {
  if (ageValue == null) return null;
  if (ageValue is num) {
    final y = ageValue.toDouble();
    return y >= 0 && y <= 130 ? y : null;
  }
  final s = ageValue.toString().trim().toLowerCase();
  final numMatch = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(s);
  if (numMatch == null) return null;
  final n = double.tryParse(numMatch.group(1)!);
  if (n == null) return null;
  if (s.contains('month')) return n / 12.0;
  if (s.contains('day') || s.contains('d ')) return n / 365.25;
  if (s.contains('week')) return n * 7 / 365.25;
  return n;
}
