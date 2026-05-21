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
import 'package:booqly/services/email_service.dart';

/// Schedules local notifications during calendar free time to nudge reading.
/// Also sends a parallel email per slot (deduped per day, capped) so the user
/// gets a heads-up even when their phone is on silent.
class ReadingMotivationService {
  ReadingMotivationService({
    CalendarService? calendarService,
    FlutterLocalNotificationsPlugin? notifications,
    EmailService? emailService,
  })  : _calendarService = calendarService ?? CalendarService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _emailService = emailService ?? EmailService();

  static const _prefEnabled = 'motivation_reminders_enabled';
  static const _prefEmailedSlots = 'motivation_emailed_slots';
  static const _prefEmailedDate = 'motivation_emailed_date';
  static const _channelId = 'booqly_reading_motivation';
  static const _channelName = 'Reading reminders';
  static const _notificationIdBase = 4200;
  static const _maxEmailsPerDay = 3;

  final CalendarService _calendarService;
  final FlutterLocalNotificationsPlugin _notifications;
  final EmailService _emailService;
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

    // Resolve recipient once per refresh; null when not signed in or email
    // unknown (e.g. anonymous Google auth without profile). Email send is
    // best-effort and never blocks notification scheduling.
    final emailTarget = await _resolveEmailTarget();

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

      if (emailTarget != null) {
        await _maybeSendNudgeEmail(
          target: emailTarget,
          slot: slot,
          message: body,
        );
      }
    }
  }

  Future<_EmailTarget?> _resolveEmailTarget() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) return null;

      var firstName = (user.displayName ?? '').trim().split(RegExp(r'\s+')).first;
      if (firstName.isEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final data = doc.data();
          firstName = (data?['firstName'] as String?)?.trim() ?? '';
        } catch (e) {
          debugPrint('ReadingMotivationService: profile fetch failed: $e');
        }
      }

      return _EmailTarget(email: email, firstName: firstName);
    } catch (e) {
      debugPrint('ReadingMotivationService._resolveEmailTarget: $e');
      return null;
    }
  }

  Future<void> _maybeSendNudgeEmail({
    required _EmailTarget target,
    required FreeTimeSlot slot,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    final storedDate = prefs.getString(_prefEmailedDate);
    var sentToday = prefs.getStringList(_prefEmailedSlots) ?? const <String>[];
    if (storedDate != today) {
      sentToday = const <String>[];
      await prefs.setString(_prefEmailedDate, today);
      await prefs.setStringList(_prefEmailedSlots, sentToday);
    }

    if (sentToday.length >= _maxEmailsPerDay) return;
    final slotKey = slot.start.toIso8601String();
    if (sentToday.contains(slotKey)) return;

    try {
      final result = await _emailService.sendFreeTimeNudgeEmail(
        toEmail: target.email,
        firstName: target.firstName,
        slotStart: slot.start,
        slotDuration: slot.duration,
        message: message,
      );

      if (!result.success) {
        debugPrint(
          'ReadingMotivationService: nudge email skipped (${result.errorMessage})',
        );
        return;
      }

      final updated = [...sentToday, slotKey];
      await prefs.setStringList(_prefEmailedSlots, updated);
    } catch (e) {
      debugPrint('ReadingMotivationService: nudge email failed: $e');
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

  /// Sends a single nudge email to the currently-signed-in user *now*,
  /// bypassing all Calendar/slot gating. Returns a [TestNudgeEmailResult]
  /// describing what actually happened (delivered, queued in Firestore for the
  /// Trigger Email extension, or failed with a reason).
  Future<TestNudgeEmailResult> sendTestNudgeEmail() async {
    final target = await _resolveEmailTarget();
    if (target == null) {
      return const TestNudgeEmailResult(
        status: TestNudgeEmailStatus.notSignedIn,
        detail: 'No signed-in user with an email. Sign in first.',
      );
    }

    final now = DateTime.now();
    final slot = FreeTimeSlot(
      start: now,
      end: now.add(const Duration(minutes: 45)),
    );
    final message = _messages[Random().nextInt(_messages.length)];

    final result = await _emailService.sendFreeTimeNudgeEmail(
      toEmail: target.email,
      firstName: target.firstName,
      slotStart: slot.start,
      slotDuration: slot.duration,
      message: message,
    );

    if (!result.success) {
      return TestNudgeEmailResult(
        status: TestNudgeEmailStatus.failed,
        detail: result.errorMessage ?? 'Could not send email.',
        recipient: target.email,
      );
    }
    if (result.delivered) {
      return TestNudgeEmailResult(
        status: TestNudgeEmailStatus.delivered,
        detail: 'Sent to ${target.email}. Check inbox (and spam).',
        recipient: target.email,
      );
    }
    if (result.queuedInFirestore) {
      return TestNudgeEmailResult(
        status: TestNudgeEmailStatus.queuedInFirestore,
        detail:
            'Queued in Firestore for ${target.email}. The "Trigger Email" '
            'Firebase Extension must be installed to actually send it '
            '(firebase/EMAIL_SETUP.md).',
        recipient: target.email,
      );
    }
    return TestNudgeEmailResult(
      status: TestNudgeEmailStatus.delivered,
      detail: 'Sent to ${target.email}.',
      recipient: target.email,
    );
  }
}

enum TestNudgeEmailStatus { delivered, queuedInFirestore, failed, notSignedIn }

class TestNudgeEmailResult {
  const TestNudgeEmailResult({
    required this.status,
    required this.detail,
    this.recipient,
  });

  final TestNudgeEmailStatus status;
  final String detail;
  final String? recipient;

  bool get isSuccess => status == TestNudgeEmailStatus.delivered;
}

class _EmailTarget {
  const _EmailTarget({required this.email, required this.firstName});

  final String email;
  final String firstName;
}
