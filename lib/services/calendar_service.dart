import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booqly/models/free_time_slot.dart';

class CalendarLinkResult {
  const CalendarLinkResult({
    required this.success,
    this.email,
    this.errorMessage,
  });

  final bool success;
  final String? email;
  final String? errorMessage;
}

/// Google Calendar read access for detecting free time between events.
class CalendarService {
  static const _prefLinked = 'calendar_linked';
  static const _prefEmail = 'calendar_email';
  static const _minFreeMinutes = 25;
  static const _dayStartHour = 8;
  static const _dayEndHour = 22;

  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _signIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: [cal.CalendarApi.calendarReadonlyScope],
      serverClientId: _webClientId,
    );
    return _googleSignIn!;
  }

  String? get _webClientId {
    final fromEnv = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  bool get hasOAuthConfig => _webClientId != null;

  Future<bool> isLinked() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefLinked) == true) {
      final account = _signIn.currentUser;
      if (account != null) return true;
    }
    return false;
  }

  Future<String?> linkedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefEmail);
  }

  Future<CalendarLinkResult> linkAccount() async {
    if (!hasOAuthConfig) {
      return const CalendarLinkResult(
        success: false,
        errorMessage:
            'Add GOOGLE_WEB_CLIENT_ID in assets/config.env (Google Cloud OAuth web client).',
      );
    }

    try {
      final account = await _signIn.signIn();
      if (account == null) {
        return const CalendarLinkResult(
          success: false,
          errorMessage: 'Google sign-in was cancelled.',
        );
      }

      final client = await _signIn.authenticatedClient();
      if (client == null) {
        return const CalendarLinkResult(
          success: false,
          errorMessage: 'Could not authorize Calendar access.',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLinked, true);
      await prefs.setString(_prefEmail, account.email);

      return CalendarLinkResult(success: true, email: account.email);
    } catch (e, st) {
      debugPrint('CalendarService.linkAccount: $e\n$st');
      return CalendarLinkResult(
        success: false,
        errorMessage: 'Could not link Google Calendar. Check OAuth setup.',
      );
    }
  }

  Future<void> unlinkAccount() async {
    try {
      await _signIn.signOut();
      await _signIn.disconnect();
    } catch (e) {
      debugPrint('CalendarService.unlink: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLinked, false);
    await prefs.remove(_prefEmail);
  }

  Future<List<FreeTimeSlot>> fetchTodayFreeSlots() async {
    if (!await isLinked()) return [];

    final client = await _signIn.authenticatedClient();
    if (client == null) return [];

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day, _dayStartHour);
    final dayEnd = DateTime(now.year, now.month, now.day, _dayEndHour);

    final api = cal.CalendarApi(client);
    final response = await api.events.list(
      'primary',
      timeMin: dayStart.toUtc(),
      timeMax: dayEnd.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    final busy = <({DateTime start, DateTime end})>[];
    for (final event in response.items ?? <cal.Event>[]) {
      if (event.status == 'cancelled') continue;
      final start = _eventTime(event.start, dayStart);
      final end = _eventTime(event.end, dayEnd);
      if (start == null || end == null) continue;
      if (!end.isAfter(start)) continue;
      busy.add((start: start, end: end));
    }

    busy.sort((a, b) => a.start.compareTo(b.start));
    return _gapsBetween(dayStart, dayEnd, busy, now);
  }

  DateTime? _eventTime(cal.EventDateTime? value, DateTime fallback) {
    if (value == null) return null;
    if (value.dateTime != null) return value.dateTime!.toLocal();
    final d = value.date;
    if (d != null) {
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  List<FreeTimeSlot> _gapsBetween(
    DateTime windowStart,
    DateTime windowEnd,
    List<({DateTime start, DateTime end})> busy,
    DateTime now,
  ) {
    final slots = <FreeTimeSlot>[];
    var cursor = windowStart.isBefore(now) ? now : windowStart;

    for (final block in busy) {
      var blockStart = block.start.isBefore(windowStart) ? windowStart : block.start;
      var blockEnd = block.end.isAfter(windowEnd) ? windowEnd : block.end;
      if (blockEnd.isBefore(cursor) || !blockEnd.isAfter(windowStart)) continue;

      if (blockStart.isAfter(cursor)) {
        final gapEnd = blockStart.isBefore(windowEnd) ? blockStart : windowEnd;
        _maybeAddSlot(slots, cursor, gapEnd);
      }
      if (blockEnd.isAfter(cursor)) cursor = blockEnd;
    }

    if (cursor.isBefore(windowEnd)) {
      _maybeAddSlot(slots, cursor, windowEnd);
    }

    return slots;
  }

  void _maybeAddSlot(List<FreeTimeSlot> slots, DateTime start, DateTime end) {
    if (!end.isAfter(start)) return;
    if (end.difference(start).inMinutes < _minFreeMinutes) return;
    slots.add(FreeTimeSlot(start: start, end: end));
  }
}
