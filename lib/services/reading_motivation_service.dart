import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:booqly/services/calendar_service.dart';

/// Schedules local notifications during calendar free time to nudge reading.
class ReadingMotivationService {
  ReadingMotivationService({
    CalendarService? calendarService,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _calendarService = calendarService ?? CalendarService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _prefEnabled = 'motivation_reminders_enabled';
  static const _channelId = 'booqly_reading_motivation';
  static const _channelName = 'Reading reminders';
  static const _notificationIdBase = 4200;

  final CalendarService _calendarService;
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  static const _messages = [
    'You have free time — open a book instead of scrolling.',
    'Your calendar just cleared. Perfect moment for a few pages.',
    'Skip the feed. Your current read is waiting.',
    'Free block ahead — trade screen time for story time.',
    'Small reading session now beats endless scrolling later.',
  ];

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminders to read during free time on your calendar',
      importance: Importance.defaultImportance,
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? true;
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, enabled);
    if (enabled) {
      await refreshSchedule();
    } else {
      await cancelAll();
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
    );
    return granted ?? true;
  }

  Future<void> refreshSchedule() async {
    await initialize();

    if (!await areRemindersEnabled()) return;
    if (!await _calendarService.isLinked()) return;

    final allowed = await requestNotificationPermission();
    if (!allowed) return;

    await cancelAll();

    final slots = await _calendarService.fetchTodayFreeSlots();
    final now = DateTime.now();
    var id = _notificationIdBase;
    final random = Random();

    for (final slot in slots) {
      var notifyAt = slot.start.add(const Duration(minutes: 2));
      if (notifyAt.isBefore(now)) {
        if (!slot.contains(now)) continue;
        notifyAt = now.add(const Duration(minutes: 1));
      }
      if (!notifyAt.isBefore(slot.end.subtract(const Duration(minutes: 5)))) {
        continue;
      }

      final minutes = slot.duration.inMinutes;
      final body = _messages[random.nextInt(_messages.length)];
      final title = minutes >= 60
          ? 'About $minutes minutes free'
          : '$minutes min of free time';

      await _schedule(
        id: id++,
        title: title,
        body: body,
        when: notifyAt,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Reminders to read during free time on your calendar',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    for (var id = _notificationIdBase; id < _notificationIdBase + 24; id++) {
      await _notifications.cancel(id);
    }
  }
}
