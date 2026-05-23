import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:booqly/models/free_time_slot.dart';
import 'package:booqly/services/calendar_service.dart';
import 'package:booqly/services/push_notification_service.dart';

/// Schedules local notifications during calendar free time and syncs slots to
/// Firestore so a Cloud Function can send push + email every 15 minutes while
/// the app is closed.
class ReadingMotivationService {
  ReadingMotivationService({
    CalendarService? calendarService,
    FlutterLocalNotificationsPlugin? notifications,
    PushNotificationService? pushNotificationService,
  })  : _calendarService = calendarService ?? CalendarService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _pushNotificationService =
            pushNotificationService ?? PushNotificationService();

  static const _prefEnabled = 'motivation_reminders_enabled';
  static const _channelId = 'booqly_reading_motivation';
  static const _channelName = 'Reading reminders';
  static const _notificationIdBase = 4200;
  static const _maxScheduledNotifications = 96;
  static const _nudgeInterval = Duration(minutes: 15);

  final CalendarService _calendarService;
  final FlutterLocalNotificationsPlugin _notifications;
  final PushNotificationService _pushNotificationService;
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

    await _pushNotificationService.initialize();
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
      await _pushNotificationService.requestPermission();
      await refreshSchedule();
    } else {
      await cancelAll();
      await _syncServerNudgeState(enabled: false, slots: const []);
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (!status.isGranted) return false;

      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
    );
    if (granted == false) return false;

    return _pushNotificationService.requestPermission();
  }

  Future<void> refreshSchedule() async {
    await initialize();

    if (!await areRemindersEnabled()) return;
    if (!await _calendarService.isLinked()) {
      debugPrint('ReadingMotivationService.refreshSchedule: calendar not linked');
      return;
    }

    final allowed = await requestNotificationPermission();
    if (!allowed) {
      debugPrint('ReadingMotivationService.refreshSchedule: notifications denied');
      return;
    }

    await cancelAll();

    await _calendarService.restoreGoogleSession();
    final slots = await _calendarService.fetchTodayFreeSlots();
    debugPrint(
      'ReadingMotivationService.refreshSchedule: ${slots.length} free slot(s) today',
    );
    await _syncServerNudgeState(enabled: true, slots: slots);

    final now = DateTime.now();
    var id = _notificationIdBase;
    final random = Random();
    var scheduledCount = 0;

    for (final slot in slots) {
      var notifyAt = slot.start.isBefore(now)
          ? now.add(const Duration(minutes: 1))
          : slot.start.add(const Duration(minutes: 2));

      while (notifyAt.isBefore(slot.end.subtract(const Duration(minutes: 5))) &&
          id < _notificationIdBase + _maxScheduledNotifications) {
        if (!notifyAt.isBefore(now)) {
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
          scheduledCount++;
        }
        notifyAt = notifyAt.add(_nudgeInterval);
      }
    }

    debugPrint(
      'ReadingMotivationService.refreshSchedule: scheduled $scheduledCount notification(s)',
    );
  }

  Future<void> _syncServerNudgeState({
    required bool enabled,
    required List<FreeTimeSlot> slots,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final email = user.email?.trim();
      var firstName =
          (user.displayName ?? '').trim().split(RegExp(r'\s+')).first;
      if (firstName.isEmpty) {
        try {
          final doc =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          firstName = (doc.data()?['firstName'] as String?)?.trim() ?? '';
        } catch (e) {
          debugPrint('ReadingMotivationService: profile fetch failed: $e');
        }
      }

      String timezoneName;
      try {
        timezoneName = await FlutterTimezone.getLocalTimezone();
      } catch (_) {
        timezoneName = tz.local.name;
      }

      final today = _dayKey(DateTime.now());
      final payload = <String, dynamic>{
        'motivationRemindersEnabled': enabled,
        'timezone': timezoneName,
        'freeSlotsDate': today,
        'freeSlotsToday': slots
            .map(
              (slot) => {
                'start': slot.start.toUtc().toIso8601String(),
                'end': slot.end.toUtc().toIso8601String(),
              },
            )
            .toList(),
      };

      if (email != null && email.isNotEmpty) {
        payload['email'] = email;
      }
      if (firstName.isNotEmpty) {
        payload['firstName'] = firstName;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (enabled) {
        await _pushNotificationService.syncTokenForCurrentUser();
      }
    } catch (e) {
      debugPrint('ReadingMotivationService._syncServerNudgeState: $e');
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    for (var id = _notificationIdBase;
        id < _notificationIdBase + _maxScheduledNotifications;
        id++) {
      await _notifications.cancel(id);
    }
  }

  Future<void> disableServerNudgesOnSignOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _pushNotificationService.clearServerPushRegistration(uid);
  }
}

/// Shared instance wired from [main.dart] and refreshed after sign-in.
ReadingMotivationService? _globalMotivationService;

ReadingMotivationService get motivationService =>
    _globalMotivationService ??= ReadingMotivationService();

void bindMotivationService(ReadingMotivationService service) {
  _globalMotivationService = service;
}
