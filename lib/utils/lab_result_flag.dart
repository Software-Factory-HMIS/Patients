bool labResultIsAbnormal({
  String? result,
  String? range,
  String? flags,
  String? status,
  bool isCritical = false,
}) {
  if (isCritical) return true;
  final flag = (flags ?? '').toUpperCase().trim();
  if (flag == 'H' ||
      flag == 'L' ||
      flag == 'HH' ||
      flag == 'LL' ||
      flag == 'A' ||
      flag == 'AA') {
    return true;
  }
  final text = (status ?? '').toLowerCase();
  if (text.contains('abnormal') ||
      text.contains('high') ||
      text.contains('low') ||
      text.contains('elevated') ||
      text.contains('critical')) {
    return true;
  }
  return valueOutsideReference(result ?? '', range ?? '');
}

bool valueOutsideReference(String result, String range) {
  final resultNum = double.tryParse(result.trim().replaceAll(RegExp(r'[^\d.]'), ''));
  final band = range.trim();
  if (resultNum == null || band.isEmpty || band == '-') return false;

  final between = RegExp(r'([\d.]+)\s*-\s*([\d.]+)').firstMatch(band);
  if (between != null) {
    final low = double.tryParse(between.group(1) ?? '');
    final high = double.tryParse(between.group(2) ?? '');
    if (low == null || high == null) return false;
    return resultNum < low || resultNum > high;
  }

  final upper = RegExp(r'^[<≤]\s*=?\s*([\d.]+)').firstMatch(band);
  if (upper != null) {
    final high = double.tryParse(upper.group(1) ?? '');
    if (high == null) return false;
    return band.contains('=') ? resultNum > high : resultNum >= high;
  }

  final lower = RegExp(r'^[>≥]\s*=?\s*([\d.]+)').firstMatch(band);
  if (lower != null) {
    final low = double.tryParse(lower.group(1) ?? '');
    if (low == null) return false;
    return band.contains('=') ? resultNum < low : resultNum <= low;
  }
  return false;
}
