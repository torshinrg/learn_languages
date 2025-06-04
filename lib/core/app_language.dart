// File: lib/core/app_language.dart

enum AppLanguage {
  english,
  spanish,
  russian,
  french,
  german,
  italian,
  portuguese,
}

extension AppLanguageExtension on AppLanguage {
  /// Короткий код, который будем хранить в SharedPreferences / БД.
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.spanish:
        return 'es';
      case AppLanguage.russian:
        return 'ru';
      case AppLanguage.french:
        return 'fr';
      case AppLanguage.german:
        return 'de';
      case AppLanguage.italian:
        return 'it';
      case AppLanguage.portuguese:
        return 'pt';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Español';
      case AppLanguage.russian:
        return 'Русский';
      case AppLanguage.french:
        return 'Français';
      case AppLanguage.german:
        return 'Deutsch';
      case AppLanguage.italian:
        return 'Italiano';
      case AppLanguage.portuguese:
        return 'Português';
    }
  }

  static AppLanguage? fromCode(String code) {
    switch (code) {
      case 'en':
        return AppLanguage.english;
      case 'es':
        return AppLanguage.spanish;
      case 'ru':
        return AppLanguage.russian;
      case 'fr':
        return AppLanguage.french;
      case 'de':
        return AppLanguage.german;
      case 'it':
        return AppLanguage.italian;
      case 'pt':
        return AppLanguage.portuguese;
      default:
        return null;
    }
  }
}
