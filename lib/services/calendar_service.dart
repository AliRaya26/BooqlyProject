import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booqly/models/free_time_slot.dart';
import 'package:booqly/services/google_oauth_config.dart';

class CalendarLinkResult {
  const CalendarLinkResult({
    required this.success,
    this.email,
    this.errorMessage,
    this.needsWebSignInButton = false,
  });

  final bool success;
  final String? email;
  final String? errorMessage;

  /// Web: [signIn] popup is unreliable — show [CalendarLinkWebDialog] instead.
  final bool needsWebSignInButton;
}

/// Google Calendar read access for detecting free time between events.
class CalendarService {
  static const _prefLinked = 'calendar_linked';
  static const _prefEmail = 'calendar_email';
  static const _minFreeMinutes = 25;
  static const _dayStartHour = 8;
  /// Include evening free time (e.g. gaps after a 9pm event, before midnight).
  static const _dayEndHour = 24;

  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _signIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: [cal.CalendarApi.calendarReadonlyScope],
      // Web requires clientId (not serverClientId). Mobile uses serverClientId.
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
    return _googleSignIn!;
  }

  String? get _webClientId => GoogleOAuthConfig.webClientId;

  bool get hasOAuthConfig =>
      GoogleOAuthConfig.hasWebClientId && GoogleOAuthConfig.isBooqlyWebClient;

  /// Current web origin (e.g. http://localhost:54141) — must be in Google Cloud OAuth origins.
  String? get webOrigin => kIsWeb && Uri.base.origin.isNotEmpty ? Uri.base.origin : null;

  Future<bool> _isLinkedPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefLinked) == true;
  }

  /// Restores the Google account session after app restart (silent sign-in).
  Future<bool> restoreGoogleSession() async {
    if (!await _isLinkedPref()) return false;
    if (_signIn.currentUser != null) return true;

    try {
      final account = await _signIn.signInSilently();
      return account != null;
    } catch (e) {
      debugPrint('CalendarService.restoreGoogleSession: $e');
      return false;
    }
  }

  /// True when the user has linked Calendar in Settings (persists across app restarts).
  Future<bool> isLinked() async {
    if (!await _isLinkedPref()) return false;
    await restoreGoogleSession();
    return true;
  }

  Future<String?> linkedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefEmail);
  }

  Future<CalendarLinkResult> linkAccount() async {
    final configError = GoogleOAuthConfig.mismatchMessage;
    if (configError != null) {
      return CalendarLinkResult(success: false, errorMessage: configError);
    }

    try {
      if (kIsWeb) {
        return await _linkAccountWeb();
      }

      final account = await _signIn.signIn();
      if (account == null) {
        return const CalendarLinkResult(
          success: false,
          errorMessage: 'Google sign-in was cancelled.',
        );
      }

      return _finalizeLink(account);
    } catch (e, st) {
      debugPrint('CalendarService.linkAccount: $e\n$st');
      return CalendarLinkResult(
        success: false,
        errorMessage: _mapLinkError(e),
      );
    }
  }

  /// Web: One Tap / silent sign-in, then scope authorization (no deprecated popup).
  Future<CalendarLinkResult> _linkAccountWeb() async {
    final account = await _signIn.signInSilently();
    if (account != null) {
      return _finalizeLink(account);
    }

    return const CalendarLinkResult(
      success: false,
      needsWebSignInButton: true,
      errorMessage:
          'Tap the Google button to sign in, then allow Calendar access.',
    );
  }

  /// Call after the user signs in via the web Google button.
  Future<CalendarLinkResult> finalizeWebLink() async {
    final account = _signIn.currentUser;
    if (account == null) {
      return const CalendarLinkResult(
        success: false,
        errorMessage: 'Sign in with Google first, then try Link again.',
      );
    }

    try {
      return await _finalizeLink(account);
    } catch (e, st) {
      debugPrint('CalendarService.finalizeWebLink: $e\n$st');
      return CalendarLinkResult(
        success: false,
        errorMessage: _mapLinkError(e),
      );
    }
  }

  Future<CalendarLinkResult> _finalizeLink(GoogleSignInAccount account) async {
    const calendarScope = cal.CalendarApi.calendarReadonlyScope;

    if (kIsWeb) {
      final hasScope = await _signIn.canAccessScopes([calendarScope]);
      if (!hasScope) {
        final granted = await _signIn.requestScopes([calendarScope]);
        if (!granted) {
          return const CalendarLinkResult(
            success: false,
            errorMessage:
                'Calendar access was not granted. Try Link again and allow '
                '“See your calendars”.',
          );
        }
      }
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
  }

  GoogleSignIn get signInForWebUi => _signIn;

  String _mapLinkError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('popup_closed') || text.contains('cancelled')) {
      return 'Google sign-in was cancelled or blocked.\n\n'
          'Allow popups for localhost, then use the Google sign-in button on the '
          'link screen (do not rely on the popup-only flow).';
    }
    if (text.contains('invalid_client') ||
        text.contains('no registered origin') ||
        text.contains('origin_mismatch')) {
      final origin = webOrigin;
      final clientHint = _webClientId != null
          ? 'Client ID in use: ${_webClientId!.substring(0, 20)}… (must match web/index.html meta tag and Google Cloud Web client).'
          : '';
      return 'Calendar OAuth blocked (no registered origin).\n\n'
          'This Link button uses google_sign_in with calendar scopes — not Firebase login.\n\n'
          '${origin != null ? 'Add this exact URL to Google Cloud → Credentials → OAuth Web client → Authorized JavaScript origins:\n$origin\n\n' : ''}'
          'Also add under Authorized redirect URIs if prompted.\n'
          'Run: .\\scripts\\run-web.ps1 (port 54141).\n'
          '$clientHint\n'
          'See firebase/GOOGLE_CALENDAR_SETUP.md';
    }
    if (text.contains('idtoken') || text.contains('id_token')) {
      final origin = webOrigin;
      return 'Google did not return a token.${origin != null ? ' Add $origin to OAuth Web client → Authorized JavaScript origins.' : ''}';
    }
    if (text.contains('access_denied') || text.contains('403')) {
      return 'Calendar access denied. Enable Google Calendar API and add the '
          'calendar.readonly scope on the OAuth consent screen (see firebase/GOOGLE_CALENDAR_SETUP.md).';
    }
    return 'Could not link Google Calendar. Check OAuth setup (firebase/GOOGLE_CALENDAR_SETUP.md).';
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
    if (!await _isLinkedPref()) return [];

    await restoreGoogleSession();

    final client = await _signIn.authenticatedClient();
    if (client == null) return [];

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day, _dayStartHour);
    final dayEnd =
        DateTime(now.year, now.month, now.day).add(const Duration(hours: 24));

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
