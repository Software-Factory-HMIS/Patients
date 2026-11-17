import 'patient_age_context.dart';

// Canonical units (aligned with EMR.sp_SavePatientVitals / PatientVitals DTOs):
// - Height: centimeters (UI + JSON `height`; DB Height; BMI uses height_m = height_cm/100)
// - Weight: kilograms (`weight`)
// - Temperature: Celsius in API/DB (`temperature`); NurseVitalScreen UI uses °F and converts on save
// - BP: mmHg systolic/diastolic; Pulse/RR: /min; SpO2: %; BSR: mg/dL

/// Evidence-based expected ranges for triage coloring (not diagnostic).
/// HR/RR: PALS reference ranges (AHA) by age; temp: typical clinical axillary/oral norms;
/// SpO2: room air screening; BSR: common fasting/random screening window.
class VitalReferenceRanges {
  VitalReferenceRanges._();

  /// Min/max °F considered "in range" for display (green).
  static (double min, double max) temperatureNormalRangeF(PatientAgeContext ctx) {
    switch (ctx.cohort) {
      case VitalCohort.neonate:
        // Narrower core; flag low temps (96.0°F ≈ 35.6°C).
        return (96.0, 99.9);
      case VitalCohort.infant:
        return (96.4, 99.5);
      case VitalCohort.child:
      case VitalCohort.adolescent:
        return (97.0, 99.5);
      case VitalCohort.adult:
        return (97.0, 99.5);
    }
  }

  static (int min, int max) pulseRange(PatientAgeContext ctx) {
    switch (ctx.cohort) {
      case VitalCohort.neonate:
        return (90, 180);
      case VitalCohort.infant:
        return (100, 160);
      case VitalCohort.child:
        final y = ctx.ageYears.floor().clamp(1, 12);
        if (y <= 2) return (90, 150);
        if (y <= 5) return (80, 140);
        return (70, 120);
      case VitalCohort.adolescent:
        return (60, 100);
      case VitalCohort.adult:
        return (60, 100);
    }
  }

  static (int min, int max) respiratoryRateRange(PatientAgeContext ctx) {
    switch (ctx.cohort) {
      case VitalCohort.neonate:
        return (30, 60);
      case VitalCohort.infant:
        return (30, 53);
      case VitalCohort.child:
        final y = ctx.ageYears.floor().clamp(1, 12);
        if (y <= 2) return (22, 37);
        if (y <= 5) return (20, 28);
        return (18, 25);
      case VitalCohort.adolescent:
        return (12, 20);
      case VitalCohort.adult:
        return (12, 20);
    }
  }

  /// SpO2 % (room air assumption for screening).
  static (double min, double max) oxygenSaturationRange(PatientAgeContext ctx) {
    if (ctx.cohort == VitalCohort.neonate) {
      return (93.0, 100.0);
    }
    return (95.0, 100.0);
  }

  /// mg/dL — broad screening window for random capillary glucose.
  static (double min, double max) bsrRange(PatientAgeContext ctx) {
    return (70.0, 140.0);
  }

  static bool isTemperatureNormalF(double tempF, PatientAgeContext ctx) {
    final r = temperatureNormalRangeF(ctx);
    return tempF >= r.$1 && tempF <= r.$2;
  }

  static bool isPulseNormal(int pulse, PatientAgeContext ctx) {
    final r = pulseRange(ctx);
    return pulse >= r.$1 && pulse <= r.$2;
  }

  static bool isRespiratoryRateNormal(int rr, PatientAgeContext ctx) {
    final r = respiratoryRateRange(ctx);
    return rr >= r.$1 && rr <= r.$2;
  }

  static bool isOxygenSaturationNormal(double o2, PatientAgeContext ctx) {
    final r = oxygenSaturationRange(ctx);
    return o2 >= r.$1 && o2 <= r.$2;
  }

  static bool isBsrNormal(double bsr, PatientAgeContext ctx) {
    final r = bsrRange(ctx);
    return bsr >= r.$1 && bsr <= r.$2;
  }

  /// Adult BMI 18.5–24.9 (WHO).
  static bool isAdultBmiNormal(double bmi) {
    return bmi >= 18.5 && bmi <= 24.9;
  }
}

/// Slider min/max for UI (not clinical norms).
class VitalSliderSpecs {
  VitalSliderSpecs({
    required this.heightCmMin,
    required this.heightCmMax,
    required this.weightKgMin,
    required this.weightKgMax,
    required this.systolicMin,
    required this.systolicMax,
    required this.diastolicMin,
    required this.diastolicMax,
    required this.pulseMin,
    required this.pulseMax,
    required this.respMin,
    required this.respMax,
    required this.tempFMin,
    required this.tempFMax,
    required this.spo2Min,
    required this.spo2Max,
    required this.bsrMin,
    required this.bsrMax,
  });

  final double heightCmMin;
  final double heightCmMax;
  final double weightKgMin;
  final double weightKgMax;
  final int systolicMin;
  final int systolicMax;
  final int diastolicMin;
  final int diastolicMax;
  final int pulseMin;
  final int pulseMax;
  final int respMin;
  final int respMax;
  final double tempFMin;
  final double tempFMax;
  final double spo2Min;
  final double spo2Max;
  final double bsrMin;
  final double bsrMax;

  static VitalSliderSpecs forContext(PatientAgeContext ctx) {
    switch (ctx.cohort) {
      case VitalCohort.neonate:
        return VitalSliderSpecs(
          heightCmMin: 35,
          heightCmMax: 62,
          weightKgMin: 0.5,
          weightKgMax: 6,
          systolicMin: 40,
          systolicMax: 110,
          diastolicMin: 20,
          diastolicMax: 70,
          pulseMin: 70,
          pulseMax: 200,
          respMin: 20,
          respMax: 70,
          tempFMin: 90,
          tempFMax: 104,
          spo2Min: 70,
          spo2Max: 100,
          bsrMin: 30,
          bsrMax: 180,
        );
      case VitalCohort.infant:
        return VitalSliderSpecs(
          heightCmMin: 45,
          heightCmMax: 95,
          weightKgMin: 2,
          weightKgMax: 15,
          systolicMin: 50,
          systolicMax: 130,
          diastolicMin: 30,
          diastolicMax: 85,
          pulseMin: 70,
          pulseMax: 200,
          respMin: 18,
          respMax: 70,
          tempFMin: 90,
          tempFMax: 105,
          spo2Min: 70,
          spo2Max: 100,
          bsrMin: 40,
          bsrMax: 250,
        );
      case VitalCohort.child:
        return VitalSliderSpecs(
          heightCmMin: 50,
          heightCmMax: 175,
          weightKgMin: 5,
          weightKgMax: 95,
          systolicMin: 60,
          systolicMax: 170,
          diastolicMin: 35,
          diastolicMax: 110,
          pulseMin: 50,
          pulseMax: 180,
          respMin: 10,
          respMax: 50,
          tempFMin: 90,
          tempFMax: 106,
          spo2Min: 70,
          spo2Max: 100,
          bsrMin: 40,
          bsrMax: 450,
        );
      case VitalCohort.adolescent:
        return VitalSliderSpecs(
          heightCmMin: 120,
          heightCmMax: 200,
          weightKgMin: 25,
          weightKgMax: 130,
          systolicMin: 60,
          systolicMax: 200,
          diastolicMin: 40,
          diastolicMax: 120,
          pulseMin: 40,
          pulseMax: 180,
          respMin: 8,
          respMax: 40,
          tempFMin: 90,
          tempFMax: 106,
          spo2Min: 70,
          spo2Max: 100,
          bsrMin: 40,
          bsrMax: 450,
        );
      case VitalCohort.adult:
        return VitalSliderSpecs(
          heightCmMin: 120,
          heightCmMax: 210,
          weightKgMin: 25,
          weightKgMax: 220,
          systolicMin: 60,
          systolicMax: 220,
          diastolicMin: 30,
          diastolicMax: 140,
          pulseMin: 35,
          pulseMax: 180,
          respMin: 8,
          respMax: 50,
          tempFMin: 90,
          tempFMax: 108,
          spo2Min: 60,
          spo2Max: 100,
          bsrMin: 40,
          bsrMax: 500,
        );
    }
  }
}
