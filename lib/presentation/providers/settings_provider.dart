// File: lib/presentation/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kDailyCountKey = 'dailyCount';
  static const _kStudiedCountKey = 'studiedCount';
  static const _kStudiedDateKey = 'studiedDate';
  static const _kStreakCountKey = 'streakCount';
  static const _kLastStreakDateKey = 'lastStreakDate';
  static const _kLocaleKey = 'localeCode';

  int _dailyCount = kDefaultDailyCount;
  int get dailyCount => _dailyCount;

  int _studiedCount = 0;
  int get studiedCount => _studiedCount;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  String _localeCode = 'en';
  Locale get locale => Locale(_localeCode);

  SettingsProvider() {
    _loadAll();
  }

  /// Internal load/reset logic.
  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Locale handling ---
    _localeCode = prefs.getString(_kLocaleKey) ?? 'en';

    final today = DateTime.now().toIso8601String().split('T').first;
    final yesterday = DateTime.now()
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
    _dailyCount = prefs.getInt(_kDailyCountKey) ?? kDefaultDailyCount;

    // --- Studied count reset if new day ---
    final savedStudiedDate = prefs.getString(_kStudiedDateKey);
    if (savedStudiedDate != today) {
      _studiedCount = 0;
      await prefs.setString(_kStudiedDateKey, today);
      await prefs.setInt(_kStudiedCountKey, 0);
    } else {
      _studiedCount = prefs.getInt(_kStudiedCountKey) ?? 0;
    }

    notifyListeners();
  }

  Future<void> setDailyCount(int count) async {
    _dailyCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyCountKey, count);
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
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      final oldStreak = prefs.getInt(_kStreakCountKey) ?? 0;
      final newStreak =
      (lastStreakDate == yesterday) ? oldStreak + 1 : 1;
      _streakCount = newStreak;
      await prefs.setInt(_kStreakCountKey, newStreak);
      await prefs.setString(_kLastStreakDateKey, today);
    }

    notifyListeners();
  }

  /// Public API to force a full reload (e.g. on resume).
  Future<void> reload() async {
    await _loadAll();
  }

  /// NEW: Change the interface language and persist
  Future<void> setLocale(String code) async {
    _localeCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, code);
    notifyListeners();
  }
}
