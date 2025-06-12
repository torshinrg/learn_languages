// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/navigation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> onDidReceiveNotification(
    NotificationResponse notificationResponse,
  ) async {}

  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings("@drawable/ic_notification");
    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: iOSInitializationSettings,
        );
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: androidInitializationSettings,
        iOS: iOSInitializationSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Only act on taps, not background messages
        if (response.payload == 'home') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveNotification,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'study_channel', // must match the id in your scheduleDailyNotifications
        'Study reminders', // visible channel name
        description: 'Daily language practice reminders',
        importance: Importance.high,
      ),
    );
  }

  void initTimeZones() {
    tz.initializeTimeZones();
  }

  /// Schedules one notification per TimeOfDay in [times].
  /// Keeps your provider calls intact (no context argument needed).
  Future<void> scheduleDailyNotifications(List<TimeOfDay> times) async {
    final ctx = navigatorKey.currentContext!;
    final loc = AppLocalizations.of(ctx)!;
    await flutterLocalNotificationsPlugin.cancelAll();
    final now = DateTime.now();
    for (var i = 0; i < times.length; i++) {
      final tod = times[i];
      var localDt = DateTime(
        now.year,
        now.month,
        now.day,
        tod.hour,
        tod.minute,
      );
      if (localDt.isBefore(now)) localDt = localDt.add(const Duration(days: 1));

      // 2) Convert to UTC
      final utcDt = localDt.toUtc();

      // 3) Wrap in TZDateTime in the UTC zone
      final tzSchedule = tz.TZDateTime.from(utcDt, tz.UTC);
      await flutterLocalNotificationsPlugin.zonedSchedule(
        i,
        loc.time_to_practice,
        loc.daily_review,
        tzSchedule,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_channel',
            'Study reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'home',
      );
    }
  }
}
