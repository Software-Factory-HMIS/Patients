import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/user_storage.dart';

enum AppThemeMode {
  light,
  dark,
  system,
  highContrastLight,
  highContrastDark,
}

extension AppThemeModeExtension on AppThemeMode {
  String get storageKey {
    switch (this) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.highContrastLight:
        return 'highContrastLight';
      case AppThemeMode.highContrastDark:
        return 'highContrastDark';
    }
  }

  static AppThemeMode fromStorageKey(String? key) {
    switch (key) {
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      case 'highContrastLight':
        return AppThemeMode.highContrastLight;
      case 'highContrastDark':
        return AppThemeMode.highContrastDark;
      case 'light':
      default:
        return AppThemeMode.light;
    }
  }
}

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<AppThemeMode> themeNotifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.light);

  Future<void> init() async {
    final saved = await UserStorage.getThemeMode();
    themeNotifier.value = AppThemeModeExtension.fromStorageKey(saved);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (themeNotifier.value == mode) return;
    themeNotifier.value = mode;
    await UserStorage.saveThemeMode(mode.storageKey);
  }

  ThemeData getTheme() {
    switch (themeNotifier.value) {
      case AppThemeMode.light:
        return AppTheme.lightTheme;
      case AppThemeMode.highContrastLight:
        return AppTheme.highContrastLightTheme;
      case AppThemeMode.dark:
      case AppThemeMode.highContrastDark:
      case AppThemeMode.system:
        return AppTheme.lightTheme;
    }
  }

  ThemeData getDarkTheme() {
    switch (themeNotifier.value) {
      case AppThemeMode.dark:
        return AppTheme.darkTheme;
      case AppThemeMode.highContrastDark:
        return AppTheme.highContrastDarkTheme;
      default:
        return AppTheme.darkTheme;
    }
  }

  ThemeMode getThemeMode() {
    switch (themeNotifier.value) {
      case AppThemeMode.light:
      case AppThemeMode.highContrastLight:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.highContrastDark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
