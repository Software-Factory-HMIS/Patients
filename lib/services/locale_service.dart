import 'package:flutter/material.dart';
import '../utils/user_storage.dart';

enum AppLanguage {
  english,
  urdu,
}

extension AppLanguageExtension on AppLanguage {
  String get storageKey => this == AppLanguage.urdu ? 'ur' : 'en';

  Locale get locale => Locale(storageKey);

  String get displayName => this == AppLanguage.urdu ? 'اردو' : 'English';

  static AppLanguage fromStorageKey(String? key) {
    if (key == 'ur') return AppLanguage.urdu;
    return AppLanguage.english;
  }
}

class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  static const supportedLocales = [
    Locale('en'),
    Locale('ur'),
  ];

  Future<void> init() async {
    final saved = await UserStorage.getLocale();
    localeNotifier.value = AppLanguageExtension.fromStorageKey(saved).locale;
  }

  Future<void> setLanguage(AppLanguage language) async {
    final locale = language.locale;
    if (localeNotifier.value == locale) return;
    localeNotifier.value = locale;
    await UserStorage.saveLocale(language.storageKey);
  }

  AppLanguage get currentLanguage =>
      AppLanguageExtension.fromStorageKey(localeNotifier.value.languageCode);
}
