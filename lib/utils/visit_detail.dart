import '../l10n/app_localizations.dart';
import 'clinical_notes_format.dart';
import 'lab_result_flag.dart';

class VisitDetail {
  final String title;
  final String? when;
  final String doctor;
  final List<Map<String, dynamic>> vitalRows;
  final List<String> complaints;
  final List<String> symptoms;
  final List<String> diagnoses;
  final List<String> labs;
  final List<VisitLabLine> labLines;
  final List<String> radiology;
  final List<String> medicines;
  final List<String> notes;

  const VisitDetail({
    required this.title,
    this.when,
    required this.doctor,
    required this.vitalRows,
    required this.complaints,
    required this.symptoms,
    required this.diagnoses,
    required this.labs,
    this.labLines = const [],
    required this.radiology,
    required this.medicines,
    required this.notes,
  });

  factory VisitDetail.fromBundle(Map<String, dynamic> data) {
    final encounter = _map(data['encounter']);
    final type = _text(encounter, const [
      'encounterType',
      'EncounterType',
    ]);
    final doctor = _text(encounter, const [
      'doctorName',
      'DoctorName',
      'doctor',
    ]);
    final whenRaw = encounter['encounterDate'] ??
        encounter['EncounterDate'] ??
        encounter['checkInTime'] ??
        encounter['CheckInTime'];
    final when = whenRaw?.toString();

    final labLines = _list(data['labOrders'])
        .map(_visitLab)
        .where((line) => line.name.isNotEmpty)
        .toList();

    return VisitDetail(
      title: type,
      when: when == null || when.isEmpty || when == 'null' ? null : when,
      doctor: doctor.isEmpty ? '' : doctor,
      vitalRows: _list(data['vitals']),
      complaints: _names(_list(data['complaints'])),
      symptoms: _names(_list(data['symptoms'])),
      diagnoses: _list(data['diagnoses']).map((d) {
        final name = _text(d, const [
          'diagnosisName',
          'icd10Description',
          'ICD10Description',
        ]);
        if (name.isEmpty) return '';
        final confirmed = d['isConfirmed'] == true || d['IsConfirmed'] == true;
        return confirmed ? '$name (Confirmed)' : name;
      }).where((e) => e.isNotEmpty).toList(),
      labs: labLines.map((line) => line.plain).toList(),
      labLines: labLines,
      radiology: _list(data['radiologyOrders']).map(_radLine).where((e) => e.isNotEmpty).toList(),
      medicines: _list(data['medicines']).map(_medLine).where((e) => e.isNotEmpty).toList(),
      notes: extractClinicalNoteTexts(
        data['clinicalNotes'],
        fallbackNotes: data['notes'] is List ? data['notes'] as List : null,
      ),
    );
  }

  List<String> vitalLines(AppLocalizations l) {
    return vitalRows.map((row) => _vitalLine(row, l)).where((e) => e.isNotEmpty).toList();
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String _text(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

String _vitalLine(Map<String, dynamic> v, AppLocalizations l) {
  String g(List<String> keys) => _text(v, keys);
  final parts = <String>[];
  final sys = g(['bpSystolic', 'BPSystolic', 'systolic']);
  final dia = g(['bpDiastolic', 'BPDiastolic', 'diastolic']);
  if (sys.isNotEmpty || dia.isNotEmpty) parts.add('${l.vitalBp} $sys/$dia');
  final hr = g(['heartRate', 'pulse', 'HeartRate', 'Pulse']);
  if (hr.isNotEmpty) parts.add('${l.vitalHr} $hr');
  final temp = g(['temperature', 'Temperature']);
  if (temp.isNotEmpty) parts.add('${l.vitalTemp} $temp');
  final rr = g(['respiratoryRate', 'RespiratoryRate', 'rr']);
  if (rr.isNotEmpty) parts.add('${l.vitalRr} $rr');
  final spo2 = g(['oxygenSaturation', 'spo2', 'SpO2', 'O2Saturation']);
  if (spo2.isNotEmpty) parts.add('${l.vitalSpo2} $spo2');
  final weight = g(['weight', 'Weight']);
  if (weight.isNotEmpty) parts.add('${l.vitalWt} $weight');
  final height = g(['height', 'Height']);
  if (height.isNotEmpty) parts.add('${l.vitalHt} $height');
  final bmi = g(['bmi', 'BMI']);
  if (bmi.isNotEmpty) parts.add('${l.vitalBmi} $bmi');
  final bsr = g(['bsr', 'BSR', 'bloodSugar']);
  if (bsr.isNotEmpty) parts.add('${l.vitalBsr} $bsr');
  return parts.join(' · ');
}

VisitLabLine _visitLab(Map<String, dynamic> order) {
  final name = _text(order, const ['testName', 'packageName', 'TestName']);
  final value = _text(order, const ['resultValue', 'ResultValue', 'result']);
  final units = _text(order, const ['units', 'Units']);
  final range = _text(order, const [
    'referenceRange',
    'ReferenceRange',
    'normalRange',
  ]);
  final flags = _text(order, const ['abnormalFlags', 'AbnormalFlags']);
  final status = _text(order, const ['resultStatus', 'status', 'Status']);
  return VisitLabLine(
    name: name,
    value: value,
    units: units,
    range: range,
    abnormal: value.isNotEmpty &&
        labResultIsAbnormal(
          result: value,
          range: range,
          flags: flags,
          status: status,
          isCritical: order['isCritical'] == true || order['IsCritical'] == true,
        ),
  );
}

class VisitLabLine {
  final String name;
  final String value;
  final String units;
  final String range;
  final bool abnormal;

  const VisitLabLine({
    required this.name,
    required this.value,
    required this.units,
    required this.range,
    required this.abnormal,
  });

  String get plain {
    if (value.isEmpty) return name;
    final unit = units.isEmpty ? '' : ' $units';
    final band = range.isEmpty ? '' : ' ($range)';
    return '$name: $value$unit$band';
  }
}

String _radLine(Map<String, dynamic> rad) {
  final name = _text(rad, const ['testName', 'clinicalDisplayName', 'TestName']);
  final impression = _text(rad, const ['impression', 'Impression']);
  final findings = _text(rad, const ['finalFindings', 'preliminaryFindings', 'findings']);
  final body = impression.isNotEmpty ? impression : findings;
  if (name.isEmpty) return body;
  if (body.isEmpty) return name;
  return '$name — $body';
}

List<String> _names(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) => _text(row, const [
            'diagnosisName',
            'icd10Description',
            'ICD10Description',
            'name',
            'Name',
          ]))
      .where((e) => e.isNotEmpty)
      .toList();
}

String _medLine(Map<String, dynamic> med) {
  final nested = med['medicine'] ?? med['Medicine'];
  final nestedMap = nested is Map ? Map<String, dynamic>.from(nested) : <String, dynamic>{};
  final name = _text(med, const ['medicineName', 'MedicineName']).isNotEmpty
      ? _text(med, const ['medicineName', 'MedicineName'])
      : _text(nestedMap, const ['name', 'Name']);
  if (name.isEmpty) return '';
  final dose = _text(med, const ['dosageAmount', 'dosageValue', 'dosage']);
  final unit = _text(med, const ['dosageUnit', 'DosageUnit']);
  final frequency = _text(med, const ['frequency', 'Frequency', 'instructions']);
  final times = _text(med, const ['timesPerDay', 'TimesPerDay']);
  final duration = _text(med, const ['duration', 'Duration', 'durationValue']);
  final durationUnit = _text(med, const ['durationUnit', 'DurationUnit']);
  final parts = <String>[name];
  if (dose.isNotEmpty) parts.add(unit.isEmpty ? dose : '$dose $unit');
  if (frequency.isNotEmpty) {
    parts.add(frequency);
  } else if (times.isNotEmpty) {
    parts.add('${times}x');
  }
  if (duration.isNotEmpty) {
    parts.add(durationUnit.isEmpty ? duration : '$duration $durationUnit');
  }
  var line = parts.join(' · ');
  if (med['discontinuedDate'] != null || med['DiscontinuedDate'] != null) {
    line = '$line · Stopped';
  }
  return line;
}
