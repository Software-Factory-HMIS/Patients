import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/user_storage.dart';

enum AppThemeMode { light, dark }

extension AppThemeModeExtension on AppThemeMode {
  String get storageKey => this == AppThemeMode.dark ? 'dark' : 'light';

  static AppThemeMode fromStorageKey(String? key) {
    if (key == 'dark' || key == 'highContrastDark') return AppThemeMode.dark;
    return AppThemeMode.light;
  }
}

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<AppThemeMode> themeNotifier = ValueNotifier<AppThemeMode>(
    AppThemeMode.light,
  );

  Future<void> init() async {
    final saved = await UserStorage.getThemeMode();
    themeNotifier.value = AppThemeModeExtension.fromStorageKey(saved);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (themeNotifier.value == mode) return;
    themeNotifier.value = mode;
    await UserStorage.saveThemeMode(mode.storageKey);
  }

  ThemeData getTheme() => AppTheme.lightTheme;

  ThemeData getDarkTheme() => AppTheme.darkTheme;

  ThemeMode getThemeMode() {
    return themeNotifier.value == AppThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}
