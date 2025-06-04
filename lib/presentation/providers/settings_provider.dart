// File: lib/presentation/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import 'package:flutter/material.dart';
import '../../core/app_language.dart';

class SettingsProvider extends ChangeNotifier {
  static const kDailyCountKey = 'dailyCount';
  static const _kStudiedCountKey = 'studiedCount';
  static const _kStudiedDateKey = 'studiedDate';
  static const _kStreakCountKey = 'streakCount';
  static const _kLastStreakDateKey = 'lastStreakDate';
  static const _kLocaleKey = 'localeCode';

  /// **Новые ключи** для хранения языковой настройки:
  static const _kNativeLanguageKey = 'nativeLanguage'; // String, например 'en'
  static const _kLearningLanguagesKey =
      'learningLanguages'; // List<String>, например ['es','de']

  int _dailyCount = kDefaultDailyCount;
  int get dailyCount => _dailyCount;

  int _studiedCount = 0;
  int get studiedCount => _studiedCount;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  String _localeCode = 'en';
  Locale get locale => Locale(_localeCode);

  /// **Новые поля для языков**:
  String? _nativeLanguageCode; // код родного языка: 'en','ru', ...
  List<String> _learningLanguageCodes =
      []; // список изучаемых языков: ['es','de', ...]
  bool _isLoaded = false;

  /// Геттеры:
  String? get nativeLanguageCode => _nativeLanguageCode;
  List<String> get learningLanguageCodes =>
      List.unmodifiable(_learningLanguageCodes);
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _loadAll();
  }

  /// Internal load/reset logic.
  Future<void> _loadAll() async {
    _isLoaded = false;
    final prefs = await SharedPreferences.getInstance();

    // --- Locale (интерфейс приложения) ---
    _localeCode = prefs.getString(_kLocaleKey) ?? 'en';

    // --- Родной язык ---
    _nativeLanguageCode = prefs.getString(_kNativeLanguageKey);

    // --- Изучаемые языки ---
    _learningLanguageCodes = prefs.getStringList(_kLearningLanguagesKey) ?? [];

    // --- Счётчики, серия и т. д. (как было) ---
    final today = DateTime.now().toIso8601String().split('T').first;
    final yesterday =
        DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first;

    // --- Streak handling ---
    final lastStreakDate = prefs.getString(_kLastStreakDateKey);
    var streak = prefs.getInt(_kStreakCountKey) ?? 0;
    if (lastStreakDate != today && lastStreakDate != yesterday) {
      streak = 0;
      await prefs.setInt(_kStreakCountKey, 0);
    }
    _streakCount = streak;

    // --- Daily count ---
    _dailyCount = prefs.getInt(kDailyCountKey) ?? kDefaultDailyCount;

    // --- Studied count reset if new day ---
    final savedStudiedDate = prefs.getString(_kStudiedDateKey);
    if (savedStudiedDate != today) {
      _studiedCount = 0;
      await prefs.setString(_kStudiedDateKey, today);
      await prefs.setInt(_kStudiedCountKey, 0);
    } else {
      _studiedCount = prefs.getInt(_kStudiedCountKey) ?? 0;
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setDailyCount(int count) async {
    _dailyCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kDailyCountKey, count);
    notifyListeners();
  }

  Future<void> incrementStudiedCount() async {
    _studiedCount++;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastStreakDate = prefs.getString(_kLastStreakDateKey);

    await prefs.setInt(_kStudiedCountKey, _studiedCount);
    await prefs.setString(_kStudiedDateKey, today);

    if (lastStreakDate != today) {
      final yesterday =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')
              .first;
      final oldStreak = prefs.getInt(_kStreakCountKey) ?? 0;
      final newStreak = (lastStreakDate == yesterday) ? oldStreak + 1 : 1;
      _streakCount = newStreak;
      await prefs.setInt(_kStreakCountKey, newStreak);
      await prefs.setString(_kLastStreakDateKey, today);
    }

    notifyListeners();
  }

  /// Сохранить родной язык
  Future<void> setNativeLanguage(String code) async {
    _nativeLanguageCode = code;
    // Здесь сразу меняем язык UI
    await setLocale(code);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNativeLanguageKey, code);
    notifyListeners();
  }

  /// Сохранить список изучаемых языков (list of codes)
  Future<void> setLearningLanguages(List<String> codes) async {
    _learningLanguageCodes = List.from(codes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLearningLanguagesKey, codes);
    notifyListeners();
  }

  /// Add a new learning language to the front of the list if not already
  /// present. The new language becomes the active learning language.
  Future<void> addLearningLanguage(String code) async {
    if (_learningLanguageCodes.contains(code)) return;
    _learningLanguageCodes.insert(0, code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLearningLanguagesKey, _learningLanguageCodes);
    notifyListeners();
  }

  /// Change the active learning language. The provided [code] must already
  /// exist in the list; it will be moved to the front so that callers using
  /// `learningLanguageCodes.first` see the new language.
  Future<void> switchLearningLanguage(String code) async {
    if (!_learningLanguageCodes.contains(code) ||
        _learningLanguageCodes.first == code) {
      return;
    }

    _learningLanguageCodes
      ..remove(code)
      ..insert(0, code);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLearningLanguagesKey, _learningLanguageCodes);
    notifyListeners();
  }

  /// Public API to force a full reload (e.g. on resume).
  Future<void> reload() async {
    await _loadAll();
  }

  Future<void> setLocale(String code) async {
    _localeCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, code);
    notifyListeners();
  }
}
