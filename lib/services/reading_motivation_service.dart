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
import 'package:booqly/services/push_notification_service.dart';

// Conditionally import browser Notification API (web only)
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_web.dart';

/// Schedules local notifications during calendar free time and syncs slots to
/// Firestore so a Cloud Function can send push + email every 15 minutes while
/// the app is closed.
///
/// Only fires when a free slot has **at least 30 minutes** remaining.
class ReadingMotivationService {
  ReadingMotivationService({
    CalendarService? calendarService,
    FlutterLocalNotificationsPlugin? notifications,
    PushNotificationService? pushNotificationService,
    EmailService? emailService,
  })  : _calendarService = calendarService ?? CalendarService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _pushNotificationService =
            pushNotificationService ?? PushNotificationService(),
        _emailService = emailService ?? EmailService();

  static const _prefEnabled = 'motivation_reminders_enabled';
  static const _prefLastNudgedSlot = 'last_nudged_slot_start';
  static const _channelId = 'booqly_reading_motivation';
  static const _channelName = 'Reading reminders';
  static const _notificationIdBase = 4200;
  static const _maxScheduledNotifications = 1; // one notification per slot
  /// Free-slot duration range: 30 min → 24 hours.
  static const _minSlotMinutes = 30;
  static const _maxSlotMinutes = 1440; // 24 hours

  final CalendarService _calendarService;
  final FlutterLocalNotificationsPlugin _notifications;
  final PushNotificationService _pushNotificationService;
  final EmailService _emailService;
  bool _initialized = false;

  // ── Nudge messages ──────────────────────────────────────────────────────────

  static const _messages = [
    'Your calendar just cleared — your book has been patiently waiting.',
    'No meetings, no pings, no obligations. Just you and a good read right now.',
    'This gap in your day is a gift. Spend it with your book, not your feed.',
    'You have free time. Open Booqly before the notifications pull you back.',
    'A quiet pocket in your day — the best chapters get read exactly like this.',
    'Instead of scrolling, how about a chapter? Your future self will be grateful.',
    'Your calendar opened up. A few pages before it fills back in?',
    'Trade the feed for your book. You always feel better after reading.',
    'Free time detected. Your reading streak is waiting to grow.',
    "Right now there's nothing you have to do. That's rare — use it wisely.",
    'The scroll can wait. Your book cannot.',
    'A calm moment, just for you. The story is right where you left it.',
  ];

  String _nudgeTitle(int remainingMinutes) {
    if (remainingMinutes >= 90) {
      return '${(remainingMinutes / 60).toStringAsFixed(0)}h to read — your book is waiting 📖';
    }
    if (remainingMinutes >= 60) return 'An hour to yourself — open a book 📖';
    if (remainingMinutes >= 45) return '45 quiet minutes ahead 📖';
    return '$remainingMinutes minutes free — time for a chapter 📖';
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
      );
      await _notifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Reminders to read during free time on your calendar',
        importance: Importance.defaultImportance,
      );
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
    }

    await _pushNotificationService.initialize();
    _initialized = true;
  }

  // ── Prefs ───────────────────────────────────────────────────────────────────

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
    // Web: use browser Notification API
    if (kIsWeb) {
      return WebNotificationService.requestPermission();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (!status.isGranted) return false;
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true);
    if (granted == false) return false;

    return _pushNotificationService.requestPermission();
  }

  // ── Schedule ────────────────────────────────────────────────────────────────

  Future<void> refreshSchedule() async {
    await initialize();

    if (!await areRemindersEnabled()) return;
    if (!await _calendarService.isLinked()) {
      debugPrint(
          'ReadingMotivationService.refreshSchedule: calendar not linked');
      return;
    }

    final allowed = await requestNotificationPermission();
    if (!allowed) {
      debugPrint(
          'ReadingMotivationService.refreshSchedule: notifications denied');
    }

    await cancelAll();
    await _calendarService.restoreGoogleSession();
    final allSlots = await _calendarService.fetchTodayFreeSlots();

    // Only keep slots between 30 min and 24 hours total duration
    final slots = allSlots
        .where((s) =>
            s.duration.inMinutes >= _minSlotMinutes &&
            s.duration.inMinutes <= _maxSlotMinutes)
        .toList();

    debugPrint(
      'ReadingMotivationService.refreshSchedule: '
      '${allSlots.length} slots → ${slots.length} qualify (≥${_minSlotMinutes}min)',
    );

    await _syncServerNudgeState(enabled: true, slots: slots);

    // ── Send one notification + one email for the active slot (once per slot) ──
    final now = DateTime.now();
    final activeSlot = slots.where((s) => s.contains(now)).firstOrNull;
    if (activeSlot != null) {
      final remaining = activeSlot.end.difference(now).inMinutes;
      if (remaining >= _minSlotMinutes) {
        final alreadySent = await _alreadyNudgedSlot(activeSlot.start);
        if (!alreadySent) {
          await _sendImmediateNudge(activeSlot, remaining);
          await _markSlotNudged(activeSlot.start);
        }
      }
    }

    // ── Schedule one local notification for upcoming slots (once per slot) ────
    if (kIsWeb) return;

    final random = Random();
    var id = _notificationIdBase;

    for (final slot in slots) {
      if (slot.contains(now)) continue; // already handled above
      final remaining = slot.end.difference(slot.start).inMinutes;
      if (remaining < _minSlotMinutes) continue;

      final alreadySent = await _alreadyNudgedSlot(slot.start);
      if (alreadySent) continue;

      final notifyAt = slot.start.add(const Duration(minutes: 1));
      if (notifyAt.isAfter(now)) {
        final body = _messages[random.nextInt(_messages.length)];
        final title = _nudgeTitle(remaining);
        await _schedule(id: id++, title: title, body: body, when: notifyAt);
      }
    }

    debugPrint(
      'ReadingMotivationService.refreshSchedule: done',
    );
  }

  // ── Immediate nudge ─────────────────────────────────────────────────────────

  Future<void> _sendImmediateNudge(FreeTimeSlot slot, int remainingMinutes) async {
    final random = Random();
    final message = _messages[random.nextInt(_messages.length)];
    final title = _nudgeTitle(remainingMinutes);

    // 1. Browser notification on web
    if (kIsWeb) {
      await WebNotificationService.show(title: title, body: message);
    }

    // 2. Email via Cloud Function / Gmail
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      var firstName =
          (user?.displayName ?? '').trim().split(RegExp(r'\s+')).first;
      if (firstName.isEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
          firstName =
              (doc.data()?['firstName'] as String?)?.trim() ?? '';
        } catch (_) {}
      }

      unawaited(_emailService.sendFreeTimeNudgeEmail(
        toEmail: email,
        firstName: firstName,
        slotStart: slot.start,
        slotDuration: slot.duration,
        message: message,
      ));
    }
  }

  /// Returns true if this slot's start was already nudged (locally stored).
  Future<bool> _alreadyNudgedSlot(DateTime slotStart) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefLastNudgedSlot);
    return stored == slotStart.toUtc().toIso8601String();
  }

  /// Stores the slot start so we never nudge the same slot twice.
  Future<void> _markSlotNudged(DateTime slotStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefLastNudgedSlot, slotStart.toUtc().toIso8601String());
    // Also sync to Firestore so the Cloud Function stays in sync
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'lastNudgedSlotStart': slotStart.toUtc().toIso8601String(),
            'lastNudgeAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  // ── Server sync ─────────────────────────────────────────────────────────────

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
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          firstName =
              (doc.data()?['firstName'] as String?)?.trim() ?? '';
        } catch (e) {
          debugPrint(
              'ReadingMotivationService: profile fetch failed: $e');
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
            .map((slot) => {
                  'start': slot.start.toUtc().toIso8601String(),
                  'end': slot.end.toUtc().toIso8601String(),
                })
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

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

/// Fire-and-forget helper (avoids 'unawaited_futures' lint).
void unawaited(Future<dynamic> future) {
  future.catchError((e) => debugPrint('unawaited error: $e'));
}

/// Shared instance wired from [main.dart] and refreshed after sign-in.
ReadingMotivationService? _globalMotivationService;

ReadingMotivationService get motivationService =>
    _globalMotivationService ??= ReadingMotivationService();

void bindMotivationService(ReadingMotivationService service) {
  _globalMotivationService = service;
}
