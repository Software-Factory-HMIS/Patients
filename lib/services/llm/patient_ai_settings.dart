import 'package:flutter/foundation.dart';

import '../../utils/app_secure_storage.dart';

/// Device settings for patient voice booking.
///
/// Production uses HMIS `POST /api/patient-ai/live-token` only — the Gemini
/// API key never ships on the phone. Device key / model overrides are debug.
class PatientAiSettings {
  static const _storage = appSecureStorage;
  static const _kProvider = 'patient_ai_provider';
  static const _kModel = 'patient_ai_model';
  static const _kKey = 'patient_ai_key';

  static const defaultProvider = 'gemini';
  static const defaultModel = 'gemini-3.8-live';
  static const fallbackLiveModel =
      'gemini-2.5-flash-native-audio-preview-12-2025';

  /// Live API models that can hold a spoken conversation and call tools, best
  /// first. Transcribe and translate Live models are excluded: they do not
  /// speak a reply, so they cannot run the booking flow.
  static const liveModels = <String, String>{
    defaultModel: 'Gemini 3.8 Live (recommended)',
    'gemini-3.8-live-extended-thinking': 'Gemini 3.8 Live — extended thinking',
    'gemini-3.1-flash-live-preview': 'Gemini 3.1 Flash Live (legacy)',
    fallbackLiveModel: 'Gemini 2.5 Flash Live',
  };

  /// Debug/profile only. Release always uses the HMIS ephemeral Live token.
  static bool get allowDeviceApiKey => !kReleaseMode;

  final String provider;
  final String model;
  final String apiKey;

  const PatientAiSettings({
    required this.provider,
    required this.model,
    required this.apiKey,
  });

  bool get isReady =>
      allowDeviceApiKey &&
      provider.toLowerCase() == 'gemini' &&
      apiKey.trim().isNotEmpty;

  static Future<PatientAiSettings> load() async {
    final provider = (await _storage.read(key: _kProvider))?.trim();
    final model = (await _storage.read(key: _kModel))?.trim();
    final key = allowDeviceApiKey
        ? (await _storage.read(key: _kKey))?.trim()
        : null;
    return PatientAiSettings(
      provider:
          (provider == null || provider.isEmpty) ? defaultProvider : provider,
      model: (model == null || model.isEmpty) ? defaultModel : model,
      apiKey: key ?? '',
    );
  }

  static Future<void> save({
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    await _storage.write(key: _kProvider, value: provider.trim());
    await _storage.write(key: _kModel, value: model.trim());
    if (!allowDeviceApiKey) {
      await _storage.delete(key: _kKey);
      return;
    }
    await _storage.write(key: _kKey, value: apiKey.trim());
  }
}
