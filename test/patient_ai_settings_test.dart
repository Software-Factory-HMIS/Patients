import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patients/services/llm/patient_ai_settings.dart';

void main() {
  test('release builds never allow a device Gemini API key', () {
    // flutter test runs with kReleaseMode == false; document the gate.
    expect(PatientAiSettings.allowDeviceApiKey, isTrue);
    expect(kReleaseMode, isFalse);
    expect(PatientAiSettings.allowDeviceApiKey, !kReleaseMode);
  });

  test('default live model is a spoken Gemini Live id', () {
    expect(PatientAiSettings.defaultModel, contains('live'));
    expect(
      PatientAiSettings.liveModels.containsKey(PatientAiSettings.defaultModel),
      isTrue,
    );
  });
}
