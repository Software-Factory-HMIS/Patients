import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();

  AppSettings._();

  static const _themeModeKey = 'theme_mode';
  static const _languageCodeKey = 'language_code';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<String> languageCode = ValueNotifier('en'); // en | ur

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final themeStr = prefs.getString(_themeModeKey);
    themeMode.value = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' || null => ThemeMode.system,
      _ => ThemeMode.system,
    };

    languageCode.value = prefs.getString(_languageCodeKey) ?? 'en';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, str);
  }

  Future<void> setLanguageCode(String code) async {
    languageCode.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }
}
