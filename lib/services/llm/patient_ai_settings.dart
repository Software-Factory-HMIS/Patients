import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device settings for patient voice booking. Later these come from HMIS like hospital AI keys.
class PatientAiSettings {
  static const _storage = FlutterSecureStorage();
  static const _kProvider = 'patient_ai_provider';
  static const _kModel = 'patient_ai_model';
  static const _kKey = 'patient_ai_key';

  /// Test default — replace in Settings. Do not ship a real production key.
  static const defaultProvider = 'gemini';
  static const defaultModel = 'gemini-3.1-flash-live-preview';
  static const fallbackLiveModel = 'gemini-live-2.5-flash-native-audio';
  static const defaultTestApiKey = '';

  static const liveModels = [
    defaultModel,
    fallbackLiveModel,
  ];

  final String provider;
  final String model;
  final String apiKey;

  const PatientAiSettings({
    required this.provider,
    required this.model,
    required this.apiKey,
  });

  bool get isReady =>
      provider.toLowerCase() == 'gemini' && apiKey.trim().isNotEmpty;

  static Future<PatientAiSettings> load() async {
    final provider = (await _storage.read(key: _kProvider))?.trim();
    final model = (await _storage.read(key: _kModel))?.trim();
    final key = (await _storage.read(key: _kKey))?.trim();
    return PatientAiSettings(
      provider: (provider == null || provider.isEmpty) ? defaultProvider : provider,
      model: (model == null || model.isEmpty) ? defaultModel : model,
      apiKey: (key == null || key.isEmpty) ? defaultTestApiKey : key,
    );
  }

  static Future<void> save({
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    await _storage.write(key: _kProvider, value: provider.trim());
    await _storage.write(key: _kModel, value: model.trim());
    await _storage.write(key: _kKey, value: apiKey.trim());
  }
}
