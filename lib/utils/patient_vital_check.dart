import '../l10n/app_localizations.dart';
import 'vitals/patient_age_context.dart';
import 'vitals/pediatric_bp_percentile.dart';
import 'vitals/vital_reference_ranges.dart';

class VitalChip {
  final String label;
  final String value;
  final bool outOfRange;

  const VitalChip({
    required this.label,
    required this.value,
    required this.outOfRange,
  });
}

class LatestVitalReading {
  final DateTime? when;
  final List<VitalChip> chips;

  const LatestVitalReading({required this.when, required this.chips});
}

class VitalMarks {
  final bool bp;
  final bool pulse;
  final bool temperature;
  final bool oxygen;
  final bool breathing;
  final bool bmi;
  final bool sugar;

  const VitalMarks({
    required this.bp,
    required this.pulse,
    required this.temperature,
    required this.oxygen,
    required this.breathing,
    required this.bmi,
    required this.sugar,
  });
}

class PatientVitalCheck {
  static Map<String, dynamic> asMap(Map patient) {
    if (patient is Map<String, dynamic>) return patient;
    return Map<String, dynamic>.from(patient);
  }

  static PatientAgeContext ageOf(Map patient) =>
      PatientAgeContext.fromPatientMap(asMap(patient));

  static VitalMarks marks({
    required Map patient,
    required String bp,
    required String pulse,
    required String temperatureC,
    required String oxygen,
    required String breathing,
    required String weight,
    required String height,
    required String sugar,
  }) {
    final person = asMap(patient);
    final age = ageOf(person);
    final gender = (person['gender'] ?? person['Gender'])?.toString();
    final heightCm = double.tryParse(height) ?? 0;

    double? systolic;
    double? diastolic;
    if (bp.contains('/')) {
      final parts = bp.split('/');
      if (parts.length == 2) {
        systolic = double.tryParse(parts[0].trim());
        diastolic = double.tryParse(parts[1].trim());
      }
    }
    final bpOut = systolic != null &&
        diastolic != null &&
        systolic > 0 &&
        diastolic > 0 &&
        !isBpDisplayNormal(
          ctx: age,
          gender: gender,
          heightCm: heightCm,
          systolic: systolic.round(),
          diastolic: diastolic.round(),
        );

    final pulseValue = double.tryParse(pulse);
    final tempC = double.tryParse(temperatureC);
    final tempF = tempC == null ? null : (tempC * 9 / 5) + 32;
    final oxygenValue = double.tryParse(oxygen);
    final breathValue = double.tryParse(breathing);
    final sugarValue = double.tryParse(sugar);
    final bmi = _bmi(weight, height);

    return VitalMarks(
      bp: bpOut,
      pulse: pulseValue != null &&
          !VitalReferenceRanges.isPulseNormal(pulseValue.round(), age),
      temperature: tempF != null &&
          !VitalReferenceRanges.isTemperatureNormalF(tempF, age),
      oxygen: oxygenValue != null &&
          !VitalReferenceRanges.isOxygenSaturationNormal(oxygenValue, age),
      breathing: breathValue != null &&
          !VitalReferenceRanges.isRespiratoryRateNormal(breathValue.round(), age),
      bmi: bmi != null && age.showBmi && !VitalReferenceRanges.isAdultBmiNormal(bmi),
      sugar: sugarValue != null && !VitalReferenceRanges.isBsrNormal(sugarValue, age),
    );
  }

  static List<VitalChip> chipsFromRow(
    Map patient,
    Map row,
    AppLocalizations l,
  ) {
    final fields = _fields(row);
    final mark = marks(
      patient: patient,
      bp: fields.bp,
      pulse: fields.pulse,
      temperatureC: fields.temperature,
      oxygen: fields.oxygen,
      breathing: fields.breathing,
      weight: fields.weight,
      height: fields.height,
      sugar: fields.sugar,
    );
    final bmi = _bmi(fields.weight, fields.height);
    return [
      if (fields.bp.isNotEmpty)
        VitalChip(label: l.vitalBp, value: fields.bp, outOfRange: mark.bp),
      if (fields.pulse.isNotEmpty)
        VitalChip(label: l.vitalHr, value: fields.pulse, outOfRange: mark.pulse),
      if (fields.temperature.isNotEmpty)
        VitalChip(
          label: l.vitalTemp,
          value: formatTemperature(fields.temperature),
          outOfRange: mark.temperature,
        ),
      if (fields.oxygen.isNotEmpty)
        VitalChip(label: l.vitalSpo2, value: fields.oxygen, outOfRange: mark.oxygen),
      if (fields.breathing.isNotEmpty)
        VitalChip(
          label: l.vitalRr,
          value: fields.breathing,
          outOfRange: mark.breathing,
        ),
      if (fields.weight.isNotEmpty)
        VitalChip(label: l.vitalWt, value: fields.weight, outOfRange: false),
      if (fields.height.isNotEmpty)
        VitalChip(label: l.vitalHt, value: fields.height, outOfRange: false),
      if (bmi != null)
        VitalChip(
          label: l.vitalBmi,
          value: bmi.toStringAsFixed(1),
          outOfRange: mark.bmi,
        ),
      if (fields.sugar.isNotEmpty)
        VitalChip(label: l.vitalBsr, value: fields.sugar, outOfRange: mark.sugar),
    ];
  }

  /// Newest vital row, including values that are inside the normal range.
  static LatestVitalReading? latestReading(
    Map patient,
    List rows,
    AppLocalizations l,
  ) {
    final sorted = rows.whereType<Map>().map(asMap).toList();
    sorted.sort((a, b) {
      final da = _when(a);
      final db = _when(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    for (final row in sorted) {
      final chips = chipsFromRow(patient, row, l);
      if (chips.isEmpty) continue;
      return LatestVitalReading(when: _when(row), chips: chips);
    }
    return null;
  }

  /// `38.5°C (101.3°F)`. Stored values are Celsius.
  static String formatTemperature(String rawCelsius) {
    final celsius = double.tryParse(rawCelsius.trim());
    if (celsius == null) return rawCelsius.trim();
    final fahrenheit = (celsius * 9 / 5) + 32;
    return '${celsius.toStringAsFixed(1)}°C (${fahrenheit.toStringAsFixed(1)}°F)';
  }

  static String bmiText(Map row) {
    final stored = row['bmi'] ?? row['BMI'];
    final parsed = double.tryParse(stored?.toString() ?? '');
    final fields = _fields(row);
    final value = parsed ?? _bmi(fields.weight, fields.height);
    if (value == null) return '-';
    return value.toStringAsFixed(1);
  }

  static bool cellOutOfRange({
    required Map patient,
    required int column,
    required String cell,
    Map? row,
  }) {
    if (cell.trim().isEmpty || cell.trim() == '-') return false;
    final age = ageOf(patient);
    final person = asMap(patient);
    final gender = (person['gender'] ?? person['Gender'])?.toString();
    switch (column) {
      case 1:
        final parts = cell.split('/');
        if (parts.length != 2) return false;
        final systolic = int.tryParse(parts[0].trim());
        final diastolic = int.tryParse(parts[1].trim());
        if (systolic == null || diastolic == null) return false;
        return !isBpDisplayNormal(
          ctx: age,
          gender: gender,
          heightCm: _heightCm(row),
          systolic: systolic,
          diastolic: diastolic,
        );
      case 2:
        final pulse = double.tryParse(_number(cell));
        if (pulse == null) return false;
        return !VitalReferenceRanges.isPulseNormal(pulse.round(), age);
      case 3:
        final tempF = _fahrenheit(cell);
        if (tempF == null) return false;
        return !VitalReferenceRanges.isTemperatureNormalF(tempF, age);
      case 4:
        final breathing = double.tryParse(_number(cell));
        if (breathing == null) return false;
        return !VitalReferenceRanges.isRespiratoryRateNormal(breathing.round(), age);
      case 5:
        final oxygen = double.tryParse(_number(cell));
        if (oxygen == null) return false;
        return !VitalReferenceRanges.isOxygenSaturationNormal(oxygen, age);
      case 6:
        final sugar = double.tryParse(_number(cell));
        if (sugar == null) return false;
        return !VitalReferenceRanges.isBsrNormal(sugar, age);
      case 7:
        final bmi = double.tryParse(_number(cell));
        if (bmi == null || !age.showBmi) return false;
        return !VitalReferenceRanges.isAdultBmiNormal(bmi);
      default:
        return false;
    }
  }

  static double _heightCm(Map? row) {
    if (row == null) return 0;
    final raw = row['height'] ?? row['Height'];
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static double? _fahrenheit(String cell) {
    final inParens = RegExp(r'\(([\d.]+)\)').firstMatch(cell);
    if (inParens != null && cell.toUpperCase().contains('F')) {
      return double.tryParse(inParens.group(1)!);
    }
    final number = double.tryParse(_number(cell));
    if (number == null) return null;
    if (cell.toUpperCase().contains('C') && !cell.toUpperCase().contains('F')) {
      return (number * 9 / 5) + 32;
    }
    return number;
  }

  static String _number(String value) =>
      value.replaceAll(RegExp(r'[^\d.]'), '');

  static DateTime? _when(Map<String, dynamic> row) {
    final raw = row['recordedDate'] ??
        row['RecordedDate'] ??
        row['recordedAt'] ??
        row['createdAt'];
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  static double? _bmi(String weight, String height) {
    final kg = double.tryParse(weight);
    final cm = double.tryParse(height);
    if (kg == null || cm == null || kg <= 0 || cm <= 0) return null;
    final meters = cm / 100;
    return kg / (meters * meters);
  }

  static ({
    String bp,
    String pulse,
    String temperature,
    String oxygen,
    String breathing,
    String weight,
    String height,
    String sugar,
  }) _fields(Map row) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = row[key];
        if (value == null) continue;
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty && trimmed != 'null') return trimmed;
      }
      return '';
    }

    final systolic = text(['bpSystolic', 'BPSystolic', 'bloodPressureSystolic']);
    final diastolic = text(['bpDiastolic', 'BPDiastolic', 'bloodPressureDiastolic']);
    final bp = systolic.isNotEmpty && diastolic.isNotEmpty
        ? '$systolic/$diastolic'
        : text(['bloodPressure', 'BloodPressure']);
    return (
      bp: bp,
      pulse: text(['pulse', 'Pulse', 'heartRate', 'HeartRate']),
      temperature: text(['temperature', 'Temperature']),
      oxygen: text(['spo2', 'SPO2', 'oxygenSaturation', 'OxygenSaturation']),
      breathing: text(['respiratoryRate', 'RespiratoryRate', 'respiratory_rate']),
      weight: text(['weight', 'Weight']),
      height: text(['height', 'Height']),
      sugar: text(['bsr', 'BSR', 'bloodSugar', 'BloodSugar']),
    );
  }
}
