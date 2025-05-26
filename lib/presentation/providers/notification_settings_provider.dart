// File: lib/presentation/providers/notification_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import '../../services/notification_service.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  static const _kTimesKey = 'notification_times';
  final NotificationService _service = GetIt.instance<NotificationService>();

  List<TimeOfDay> _times = [];
  List<TimeOfDay> get times => List.unmodifiable(_times);

  NotificationSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kTimesKey) ?? [];
    _times = stored.map((s) {
      final parts = s.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }).toList();
    print('🔔 [NotificationSettingsProvider] Loaded times: ${_times.map((t) => '${t.hour}:${t.minute}').join(', ')}');
    notifyListeners();
    await _service.scheduleDailyNotifications(_times);
  }

  Future<void> addTime(TimeOfDay t) async {
    print('🔔 [NotificationSettingsProvider] Adding time: ${t.hour}:${t.minute}');
    _times.add(t);
    await _saveAndReschedule();
  }

  Future<void> updateTime(int index, TimeOfDay t) async {
    print('🔔 [NotificationSettingsProvider] Updating index $index to: ${t.hour}:${t.minute}');
    _times[index] = t;
    await _saveAndReschedule();
  }

  Future<void> removeTime(int index) async {
    print('🔔 [NotificationSettingsProvider] Removing time at index $index: ${_times[index].hour}:${_times[index].minute}');
    _times.removeAt(index);
    await _saveAndReschedule();
  }

  Future<void> _saveAndReschedule() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _times.map((t) => '${t.hour}:${t.minute}').toList();
    await prefs.setStringList(_kTimesKey, serialized);

    print('🔔 [NotificationSettingsProvider] Saving times: ${serialized.join(', ')}');
    print('🔔 [NotificationSettingsProvider] Scheduling notifications...');
    await _service.scheduleDailyNotifications(_times);
    print('🔔 [NotificationSettingsProvider] Completed scheduling notifications');

    notifyListeners();
  }
}