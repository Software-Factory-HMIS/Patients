import 'patient_age_context.dart';

/// NHLBI Fourth Report on Pediatric BP (Pediatrics 2004;114:555–76).
/// Tables: BP at [90th percentile] by age (year), sex, and height percentile column (5th–95th).
/// Height reference cm per column from NHLBI pocket guide / Fourth Report Table 3 (boys/girls).
/// Normal screening: SBP &lt; 90th and DBP &lt; 90th for age/sex/height (prehypertension begins at ≥90th).

/// Boys: stature (cm) at height percentiles by age (years 1–17). Sources: Fourth Report / NHLBI pocket guide.
const List<List<double>> _boysHeightCm = [
  [72, 74, 76, 78, 80, 82, 85],
  [81, 83, 85, 87, 90, 92, 95],
  [92, 94, 96, 99, 102, 104, 106],
  [99, 100, 103, 106, 109, 112, 113],
  [104, 106, 109, 112, 116, 119, 120],
  [110, 112, 115, 119, 122, 126, 127],
  [116, 118, 121, 125, 129, 132, 134],
  [121, 123, 127, 131, 135, 139, 141],
  [126, 128, 132, 136, 141, 145, 147],
  [130, 133, 137, 141, 146, 150, 153],
  [135, 137, 142, 146, 151, 156, 159],
  [140, 143, 148, 153, 158, 163, 166],
  [147, 150, 155, 160, 166, 171, 173],
  [154, 157, 162, 167, 173, 177, 180],
  [159, 162, 167, 172, 177, 182, 184],
  [162, 165, 170, 175, 180, 184, 186],
  [164, 166, 171, 176, 181, 185, 187],
];

const List<List<double>> _girlsHeightCm = [
  [70, 72, 74, 76, 78, 80, 83],
  [79, 81, 83, 85, 88, 90, 93],
  [91, 92, 95, 98, 100, 103, 105],
  [97, 99, 101, 104, 108, 110, 112],
  [104, 105, 108, 111, 115, 118, 120],
  [110, 112, 115, 118, 122, 126, 128],
  [116, 118, 121, 125, 129, 132, 135],
  [121, 123, 127, 131, 135, 139, 141],
  [125, 128, 131, 136, 140, 144, 147],
  [130, 132, 136, 141, 146, 150, 153],
  [136, 138, 143, 148, 153, 157, 160],
  [143, 146, 150, 155, 160, 164, 166],
  [148, 151, 155, 159, 164, 168, 170],
  [151, 153, 157, 161, 166, 170, 172],
  [152, 154, 158, 162, 167, 171, 173],
  [152, 154, 158, 163, 167, 171, 173],
  [152, 155, 159, 163, 167, 171, 174],
];

/// SBP at 90th BP percentile (mmHg) — boys.
const List<List<double>> _boysSbp90 = [
  [94, 95, 97, 99, 100, 102, 103],
  [97, 99, 100, 102, 104, 105, 106],
  [100, 101, 103, 105, 107, 108, 109],
  [102, 103, 105, 107, 109, 110, 111],
  [104, 105, 106, 108, 110, 111, 112],
  [105, 106, 108, 110, 111, 113, 113],
  [106, 107, 109, 111, 113, 114, 115],
  [107, 109, 110, 112, 114, 115, 116],
  [109, 110, 112, 114, 115, 117, 118],
  [111, 112, 114, 115, 117, 119, 119],
  [113, 114, 115, 117, 119, 120, 121],
  [115, 116, 118, 120, 121, 123, 123],
  [117, 118, 120, 122, 124, 125, 126],
  [120, 121, 123, 125, 126, 128, 128],
  [122, 124, 125, 127, 129, 130, 131],
  [125, 126, 128, 130, 131, 133, 134],
  [127, 128, 130, 132, 134, 135, 136],
];

const List<List<double>> _boysDbp90 = [
  [49, 50, 51, 52, 53, 53, 54],
  [54, 55, 56, 57, 58, 58, 59],
  [59, 59, 60, 61, 62, 63, 63],
  [62, 63, 64, 65, 66, 66, 67],
  [65, 66, 67, 68, 69, 69, 70],
  [68, 68, 69, 70, 71, 72, 72],
  [70, 70, 71, 72, 73, 74, 74],
  [71, 72, 72, 73, 74, 75, 76],
  [72, 73, 74, 75, 76, 76, 77],
  [73, 73, 74, 75, 76, 77, 78],
  [74, 74, 75, 76, 77, 78, 78],
  [74, 75, 75, 76, 77, 78, 79],
  [75, 75, 76, 77, 78, 79, 79],
  [75, 76, 77, 78, 79, 79, 80],
  [76, 77, 78, 79, 80, 80, 81],
  [78, 78, 79, 80, 81, 82, 82],
  [80, 80, 81, 82, 83, 84, 84],
];

const List<List<double>> _girlsSbp90 = [
  [97, 97, 98, 100, 101, 102, 103],
  [98, 99, 100, 101, 103, 104, 105],
  [100, 100, 102, 103, 104, 106, 106],
  [101, 102, 103, 104, 106, 107, 108],
  [103, 103, 105, 106, 107, 109, 109],
  [104, 105, 106, 108, 109, 110, 111],
  [106, 107, 108, 109, 111, 112, 113],
  [108, 109, 110, 111, 113, 114, 114],
  [110, 110, 112, 113, 114, 116, 116],
  [112, 112, 114, 115, 116, 118, 118],
  [114, 114, 116, 117, 118, 119, 120],
  [116, 116, 117, 119, 120, 121, 122],
  [117, 118, 119, 121, 122, 123, 124],
  [119, 120, 121, 122, 124, 125, 125],
  [120, 121, 122, 123, 125, 126, 127],
  [121, 122, 123, 124, 126, 127, 128],
  [122, 122, 123, 125, 126, 127, 128],
];

const List<List<double>> _girlsDbp90 = [
  [52, 53, 53, 54, 55, 55, 56],
  [57, 58, 58, 59, 60, 61, 61],
  [61, 62, 62, 63, 64, 64, 65],
  [64, 64, 65, 66, 67, 67, 68],
  [66, 67, 67, 68, 69, 69, 70],
  [68, 68, 69, 70, 70, 71, 72],
  [69, 70, 70, 71, 72, 72, 73],
  [71, 71, 71, 72, 73, 74, 74],
  [72, 72, 72, 73, 74, 75, 75],
  [73, 73, 73, 74, 75, 76, 76],
  [74, 74, 74, 75, 76, 77, 77],
  [75, 75, 75, 76, 77, 78, 78],
  [76, 76, 76, 77, 78, 79, 79],
  [77, 77, 77, 78, 79, 80, 80],
  [78, 78, 78, 79, 80, 81, 81],
  [78, 78, 79, 80, 81, 81, 82],
  [78, 79, 79, 80, 81, 81, 82],
];

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

/// Interpolate [values] over [heights] (monotonic) at [heightCm].
double _interpHeight(List<double> heights, List<double> values, double heightCm) {
  if (heightCm <= heights.first) return values.first;
  if (heightCm >= heights.last) return values.last;
  for (var i = 0; i < heights.length - 1; i++) {
    final h0 = heights[i];
    final h1 = heights[i + 1];
    if (heightCm >= h0 && heightCm <= h1) {
      final t = (heightCm - h0) / (h1 - h0);
      return _lerp(values[i], values[i + 1], t);
    }
  }
  return values.last;
}

/// Fourth Report BP 90th percentile thresholds (mmHg) at this age/sex/height.
(double sbp90, double dbp90) fourthReportBp90Thresholds({
  required bool male,
  required double ageYears,
  required double heightCm,
}) {
  final age = ageYears.clamp(1.0, 17.0);
  final i0 = age.floor() - 1;
  final i1 = age.ceil() - 1;
  final t = age - age.floor();
  if (i0 == i1) {
    final idx = i0.clamp(0, 16);
    final h = male ? _boysHeightCm[idx] : _girlsHeightCm[idx];
    final sbp = male ? _boysSbp90[idx] : _girlsSbp90[idx];
    final dbp = male ? _boysDbp90[idx] : _girlsDbp90[idx];
    return (_interpHeight(h, sbp, heightCm), _interpHeight(h, dbp, heightCm));
  }
  final h0 = male ? _boysHeightCm[i0] : _girlsHeightCm[i0];
  final h1 = male ? _boysHeightCm[i1] : _girlsHeightCm[i1];
  final sbp0 = male ? _boysSbp90[i0] : _girlsSbp90[i0];
  final sbp1 = male ? _boysSbp90[i1] : _girlsSbp90[i1];
  final dbp0 = male ? _boysDbp90[i0] : _girlsDbp90[i0];
  final dbp1 = male ? _boysDbp90[i1] : _girlsDbp90[i1];
  final a = _interpHeight(h0, sbp0, heightCm);
  final b = _interpHeight(h1, sbp1, heightCm);
  final c = _interpHeight(h0, dbp0, heightCm);
  final d = _interpHeight(h1, dbp1, heightCm);
  return (_lerp(a, b, t), _lerp(c, d, t));
}

/// 50th height-percentile column (cm) for BP lookup when height not yet entered.
double medianHeightCmForAgeSex(bool male, double ageYears) {
  final age = ageYears.clamp(1.0, 17.0);
  final idx = age.floor() - 1;
  final h = male ? _boysHeightCm[idx] : _girlsHeightCm[idx];
  return h[3];
}

bool _parseMale(String? gender) {
  if (gender == null) return true;
  final g = gender.toString().trim().toLowerCase();
  if (g == 'female' || g == 'f' || g == '2' || g.contains('female')) return false;
  if (g == 'male' || g == 'm' || g == '1' || g.contains('male')) return true;
  return true;
}

/// True if both SBP and DBP are strictly below the Fourth Report 90th percentile for age/sex/height.
bool isPediatricBpNormalFourthReport({
  required double ageYears,
  required bool male,
  required double heightCm,
  required int systolic,
  required int diastolic,
}) {
  final th = fourthReportBp90Thresholds(male: male, ageYears: ageYears, heightCm: heightCm);
  return systolic < th.$1 && diastolic < th.$2;
}

/// Neonatal expected ranges by day of life (term infants, screening — wide bands).
/// Sources: common nursery references; outside → red in UI only.
bool isNeonatalBpNormalByDol(int dayOfLife, int systolic, int diastolic) {
  final dol = dayOfLife.clamp(0, 28);
  int sbpMin;
  int sbpMax;
  int dbpMin;
  int dbpMax;
  if (dol <= 3) {
    sbpMin = 55;
    sbpMax = 88;
    dbpMin = 28;
    dbpMax = 58;
  } else if (dol <= 7) {
    sbpMin = 58;
    sbpMax = 92;
    dbpMin = 30;
    dbpMax = 62;
  } else {
    sbpMin = 60;
    sbpMax = 96;
    dbpMin = 32;
    dbpMax = 65;
  }
  return systolic >= sbpMin && systolic <= sbpMax && diastolic >= dbpMin && diastolic <= dbpMax;
}

/// Adult screening (office BP, mmHg).
bool isAdultBpNormal(int systolic, int diastolic) {
  return systolic >= 90 && systolic <= 140 && diastolic >= 60 && diastolic <= 90;
}

/// Combined assessment for nurse vitals coloring.
bool isBpDisplayNormal({
  required PatientAgeContext ctx,
  required String? gender,
  required double heightCm,
  required int systolic,
  required int diastolic,
}) {
  if (systolic <= 0 || diastolic <= 0) return true;
  final male = _parseMale(gender);
  if (ctx.useNeonatalBp) {
    return isNeonatalBpNormalByDol(ctx.ageDays, systolic, diastolic);
  }
  if (ctx.ageYears >= 18.0) {
    return isAdultBpNormal(systolic, diastolic);
  }
  if (ctx.useInfantBpSimplified) {
    final hc = heightCm > 0 ? heightCm : medianHeightCmForAgeSex(male, 1.0);
    return isPediatricBpNormalFourthReport(
      ageYears: 1.0,
      male: male,
      heightCm: hc,
      systolic: systolic,
      diastolic: diastolic,
    );
  }
  if (ctx.usePediatricBpPercentile) {
    final hc = heightCm > 0 ? heightCm : medianHeightCmForAgeSex(male, ctx.ageYears);
    return isPediatricBpNormalFourthReport(
      ageYears: ctx.ageYears.clamp(1.0, 17.0),
      male: male,
      heightCm: hc,
      systolic: systolic,
      diastolic: diastolic,
    );
  }
  return isAdultBpNormal(systolic, diastolic);
}
