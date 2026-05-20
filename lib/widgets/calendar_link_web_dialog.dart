import 'dart:async';

import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/services/calendar_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'calendar_link_web_button.dart' as web_button;

/// Web-only dialog: official Google Sign-In button + calendar scope authorization.
class CalendarLinkWebDialog extends StatefulWidget {
  const CalendarLinkWebDialog({super.key, required this.calendarService});

  final CalendarService calendarService;

  static Future<bool> show(
    BuildContext context, {
    required CalendarService calendarService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CalendarLinkWebDialog(calendarService: calendarService),
    ).then((value) => value ?? false);
  }

  @override
  State<CalendarLinkWebDialog> createState() => _CalendarLinkWebDialogState();
}

class _CalendarLinkWebDialogState extends State<CalendarLinkWebDialog> {
  StreamSubscription<GoogleSignInAccount?>? _userSub;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _userSub = widget.calendarService.signInForWebUi.onCurrentUserChanged
          .listen(_onGoogleUserChanged);
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _onGoogleUserChanged(GoogleSignInAccount? account) async {
    if (account == null || _busy) return;
    await _completeLink();
  }

  Future<void> _completeLink() async {
    setState(() {
      _busy = true;
      _status = 'Requesting Calendar access…';
    });

    final result = await widget.calendarService.finalizeWebLink();
    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _busy = false;
      _status = result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Link Google Calendar',
        style: GoogleFonts.outfit(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in with Google, then allow read access to your calendar. '
              'Popups must be allowed for this site.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            if (kIsWeb)
              SizedBox(
                height: 48,
                child: Center(child: web_button.buildGoogleSignInButton()),
              )
            else
              const Text('Web only'),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(
                _status!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.gold,
                ),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.outfit()),
        ),
      ],
    );
  }
}
