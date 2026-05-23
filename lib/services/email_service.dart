import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Sends transactional emails (signup, book completed). All platforms call the
/// `sendAuthEmail` Cloud Function, which delivers via Gmail SMTP (nodemailer).
/// On mobile, Resend is kept as a legacy fallback in case the function is
/// unavailable. On web, the Firestore mail queue (Trigger Email extension) is
/// the secondary fallback.
class EmailService {
  static const _callableName = 'sendAuthEmail';
  static const _passwordResetCallableName = 'sendPasswordResetEmail';
  static const _mailCollection = 'mail';
  static const _resendUrl = 'https://api.resend.com/emails';

  String? get _apiKey {
    const fromDefine = String.fromEnvironment('RESEND_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['RESEND_API_KEY']?.trim();
  }

  String get _fromAddress {
    const fromDefine = String.fromEnvironment('EMAIL_FROM');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['EMAIL_FROM']?.trim() ??
        'Booqly <noreply@yourdomain.com>';
  }

  bool get isConfigured => true;

  String generateVerificationCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  /// Password reset via Cloud Function (Resend + Firebase Admin reset link).
  Future<EmailSendResult> sendPasswordResetEmail({
    required String toEmail,
  }) async {
    // Normalize to lowercase. Firebase Auth's getUserByEmail is already case-
    // insensitive, but Google sign-up sometimes hands us mixed-case emails
    // and being defensive avoids hard-to-debug "not-found" responses.
    final normalized = toEmail.trim().toLowerCase();
    try {
      debugPrint(
        'EmailService.sendPasswordResetEmail: invoking '
        '"$_passwordResetCallableName" for "$normalized"',
      );
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable(
        _passwordResetCallableName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      await callable.call<Map<String, dynamic>>({
        'email': normalized,
      });

      debugPrint(
        'EmailService.sendPasswordResetEmail: callable OK for "$normalized"',
      );
      return const EmailSendResult(success: true, delivered: true);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'EmailService.sendPasswordResetEmail: FAILED code=${e.code} '
        'message="${e.message}" for "$normalized"',
      );
      return EmailSendResult(
        success: false,
        errorMessage: _mapPasswordResetFunctionsError(e),
        functionsErrorCode: e.code,
      );
    } catch (e) {
      debugPrint(
        'EmailService.sendPasswordResetEmail: unexpected error '
        'for "$normalized": $e',
      );
      return EmailSendResult(
        success: false,
        errorMessage:
            'Could not send reset email. Deploy Cloud Functions (scripts/deploy-email.ps1) and try again.',
      );
    }
  }

  String? _mapPasswordResetFunctionsError(FirebaseFunctionsException e) {
    final msg = e.message?.trim();
    if (msg != null &&
        msg.isNotEmpty &&
        msg != 'internal' &&
        msg != 'NOT_FOUND') {
      return msg;
    }
    return switch (e.code) {
      'not-found' => 'No Booqly account found for this email.',
      'failed-precondition' => 'This account cannot reset password by email.',
      'invalid-argument' => 'Please enter a valid email address.',
      'unavailable' =>
        'Reset email service is not deployed. Run scripts/deploy-email.ps1',
      'internal' =>
        'Reset email service error. Run scripts/deploy-email.ps1 and try again.',
      _ =>
        _mapFunctionsError(e) ?? 'Could not send reset email (${e.code}).',
    };
  }

  Future<EmailSendResult> sendVerificationCode({
    required String toEmail,
    required String code,
    required String firstName,
  }) {
    final greeting = firstName.isNotEmpty ? firstName : 'there';
    return _send(
      to: toEmail,
      subject: 'Your Booqly verification code',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;">
  <h1 style="color:#D4A96A;">Verify your email</h1>
  <p>Hi $greeting,</p>
  <p>Use this code to finish signing up for Booqly:</p>
  <p style="font-size:28px;letter-spacing:6px;font-weight:bold;color:#D4A96A;">$code</p>
  <p style="color:#888580;">This code expires in 15 minutes. If you did not sign up, you can ignore this email.</p>
</body>
</html>''',
    );
  }

  Future<EmailSendResult> sendWelcomeEmail({
    required String toEmail,
    required String firstName,
  }) {
    final greeting = firstName.isNotEmpty ? firstName : 'Reader';
    return _send(
      to: toEmail,
      subject: 'Welcome to Booqly',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;">
  <h1 style="color:#D4A96A;">Welcome to Booqly</h1>
  <p>Hi $greeting,</p>
  <p>Your account is ready. Start exploring books, track your reading, and build your library.</p>
  <p style="color:#888580;">Happy reading,<br>The Booqly team</p>
</body>
</html>''',
    );
  }

  /// Free-time nudge email: sent in parallel with the local notification when
  /// the user has a calendar gap. [message] is the same one-liner that goes in
  /// the notification, so the two stay consistent.
  Future<EmailSendResult> sendFreeTimeNudgeEmail({
    required String toEmail,
    required String firstName,
    required DateTime slotStart,
    required Duration slotDuration,
    required String message,
  }) {
    final greeting = firstName.isNotEmpty ? firstName : 'Reader';
    final minutes = slotDuration.inMinutes;
    final h24 = slotStart.hour;
    final hour12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final mm = slotStart.minute.toString().padLeft(2, '0');
    final amPm = h24 >= 12 ? 'PM' : 'AM';
    final timeLabel = '$hour12:$mm $amPm';
    final slotLabel = minutes >= 60
        ? '~${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} hours'
        : '$minutes minutes';

    return _send(
      to: toEmail,
      subject: '$minutes min of free time — open a book instead',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;margin:0;">
  <div style="max-width:520px;margin:0 auto;">
    <p style="font-size:40px;margin:0 0 8px;">📖</p>
    <h1 style="color:#D4A96A;font-style:italic;margin:0 0 12px;font-weight:600;">A quiet moment, ${_escapeHtml(greeting)}</h1>
    <p style="font-size:17px;line-height:1.6;margin:0 0 16px;">${_escapeHtml(message)}</p>
    <div style="background:#1A1713;border:1px solid #2A2520;border-radius:16px;padding:18px 22px;margin:24px 0;">
      <p style="margin:0;color:#888580;font-size:13px;text-transform:uppercase;letter-spacing:1.5px;">Free block</p>
      <p style="margin:6px 0 0;font-size:20px;font-weight:bold;color:#F5F0E8;">$timeLabel · $slotLabel</p>
    </div>
    <p style="font-size:15px;line-height:1.6;color:#888580;margin:24px 0 0;">A few pages now beats endlessly scrolling later. Booqly is right where you left off.</p>
    <p style="color:#5a5853;margin-top:32px;font-size:12px;">You're getting this because Free-time nudges are enabled in Booqly settings. Turn them off any time from Settings → Free-time nudges.</p>
  </div>
</body>
</html>''',
    );
  }

  Future<EmailSendResult> sendBookCompletedEmail({
    required String toEmail,
    required String firstName,
    required String bookTitle,
    required String author,
    required int totalPages,
    String? coverUrl,
    DateTime? completedAt,
  }) {
    final greeting = _escapeHtml(
      firstName.isNotEmpty ? firstName : 'Reader',
    );
    final title = _escapeHtml(bookTitle);
    final hasAuthor = author.trim().isNotEmpty;
    final authorHtml = hasAuthor
        ? '<p style="margin:6px 0 0;color:#888580;font-size:14px;font-style:italic;">by ${_escapeHtml(author)}</p>'
        : '';

    final cover = coverUrl?.trim() ?? '';
    final hasCover = cover.startsWith('https://');
    final coverCell = hasCover
        ? '''
                <td valign="top" width="96" style="padding:18px 0 18px 18px;">
                  <img src="${_escapeHtml(cover)}" alt="$title cover" width="80" height="120" style="display:block;width:80px;height:120px;border-radius:6px;border:1px solid #2A2520;object-fit:cover;background:#0E0C0A;" />
                </td>'''
        : '';
    final bookCellPadding = hasCover ? '18px' : '20px 24px';

    final finished = completedAt ?? DateTime.now();
    final completedLabel = _escapeHtml(_shortDateLabel(finished));

    final pagesStat = totalPages > 0 ? '$totalPages' : '—';

    return _send(
      to: toEmail,
      subject: 'You finished $bookTitle — congratulations',
      html: '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Congratulations from Booqly</title>
</head>
<body style="margin:0;padding:0;background:#0E0C0A;font-family:Georgia,'Times New Roman',serif;color:#F5F0E8;-webkit-font-smoothing:antialiased;">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#0E0C0A;">
    You finished $title. A real accomplishment — celebrate the chapter you just closed.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#0E0C0A;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;width:100%;background:#1A1713;border:1px solid #2A2520;border-radius:24px;overflow:hidden;">
          <tr>
            <td bgcolor="#D4A96A" height="6" style="height:6px;line-height:6px;font-size:0;">&nbsp;</td>
          </tr>
          <tr>
            <td align="center" style="padding:44px 32px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" width="96" height="96" bgcolor="#2C200F" style="width:96px;height:96px;background:#2C200F;border-radius:48px;font-size:48px;line-height:96px;text-align:center;">
                    &#127942;
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:8px 32px 0;">
              <p style="margin:24px 0 0;font-family:Georgia,'Times New Roman',serif;font-style:italic;font-size:36px;font-weight:bold;color:#D4A96A;letter-spacing:0.5px;line-height:1.1;">Congratulations!</p>
              <p style="margin:10px 0 0;color:#888580;font-size:12px;letter-spacing:2.5px;text-transform:uppercase;">A new book finished</p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 36px 0;">
              <p style="margin:0;font-size:17px;line-height:1.7;color:#F5F0E8;">Hi $greeting,</p>
              <p style="margin:12px 0 0;font-size:17px;line-height:1.7;color:#E0D8CC;">You just closed the last page — and that's no small thing. Every book finished is hours reclaimed for your imagination, and a story that will keep walking with you.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 36px 0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#0E0C0A;border:1px solid #2A2520;border-radius:16px;">
                <tr>
$coverCell
                  <td valign="middle" style="padding:$bookCellPadding;">
                    <p style="margin:0;color:#888580;font-size:11px;letter-spacing:2px;text-transform:uppercase;">You finished</p>
                    <p style="margin:6px 0 0;font-family:Georgia,'Times New Roman',serif;font-size:20px;font-weight:bold;color:#F5F0E8;line-height:1.3;">$title</p>
                    $authorHtml
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 36px 0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" width="33%" bgcolor="#0E0C0A" style="background:#0E0C0A;border:1px solid #2A2520;border-radius:14px;padding:18px 6px;">
                    <p style="margin:0;font-family:Georgia,serif;font-size:24px;font-weight:bold;color:#D4A96A;line-height:1;">$pagesStat</p>
                    <p style="margin:6px 0 0;font-size:10px;color:#888580;letter-spacing:1.5px;text-transform:uppercase;">Pages read</p>
                  </td>
                  <td width="8" style="font-size:0;line-height:0;">&nbsp;</td>
                  <td align="center" width="33%" bgcolor="#0E0C0A" style="background:#0E0C0A;border:1px solid #2A2520;border-radius:14px;padding:18px 6px;">
                    <p style="margin:0;font-family:Georgia,serif;font-size:24px;font-weight:bold;color:#D4A96A;line-height:1;">100%</p>
                    <p style="margin:6px 0 0;font-size:10px;color:#888580;letter-spacing:1.5px;text-transform:uppercase;">Completed</p>
                  </td>
                  <td width="8" style="font-size:0;line-height:0;">&nbsp;</td>
                  <td align="center" width="33%" bgcolor="#0E0C0A" style="background:#0E0C0A;border:1px solid #2A2520;border-radius:14px;padding:18px 6px;">
                    <p style="margin:0;font-family:Georgia,serif;font-size:20px;font-weight:bold;color:#D4A96A;line-height:1;">$completedLabel</p>
                    <p style="margin:6px 0 0;font-size:10px;color:#888580;letter-spacing:1.5px;text-transform:uppercase;">Finished on</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 36px 0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding:0 0 0 16px;border-left:3px solid #D4A96A;">
                    <p style="margin:0;font-family:Georgia,serif;font-style:italic;color:#E0D8CC;font-size:16px;line-height:1.6;">&ldquo;A reader lives a thousand lives before he dies. The man who never reads lives only one.&rdquo;</p>
                    <p style="margin:8px 0 0;color:#888580;font-size:13px;">&mdash; George R.R. Martin</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:36px 36px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td bgcolor="#D4A96A" align="center" style="background:#D4A96A;border-radius:12px;">
                    <span style="display:inline-block;padding:14px 30px;color:#0E0C0A;font-family:Georgia,serif;font-weight:bold;font-size:15px;letter-spacing:0.5px;">Open Booqly &middot; Pick your next read</span>
                  </td>
                </tr>
              </table>
              <p style="margin:14px 0 0;font-size:13px;color:#888580;">Your library is waiting with the next chapter.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 36px 0;">
              <div style="height:1px;background:#2A2520;font-size:0;line-height:0;">&nbsp;</div>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 36px 36px;">
              <p style="margin:0;color:#888580;font-size:13px;line-height:1.7;">Happy reading,<br/><span style="color:#D4A96A;font-style:italic;font-family:Georgia,serif;">&mdash; The Booqly team</span></p>
            </td>
          </tr>
        </table>
        <p style="margin:18px 0 0;color:#5a5853;font-size:11px;font-family:Georgia,serif;">You're getting this because you finished a book on Booqly.</p>
      </td>
    </tr>
  </table>
</body>
</html>''',
    );
  }

  static const _monthAbbreviations = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _shortDateLabel(DateTime date) {
    final local = date.toLocal();
    final month = _monthAbbreviations[local.month - 1];
    return '$month ${local.day}';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  Future<EmailSendResult> _send({
    required String to,
    required String subject,
    required String html,
  }) async {
    debugPrint(
      'EmailService._send: platform=${kIsWeb ? "web" : "mobile"} '
      'to="$to" subject="$subject" htmlLen=${html.length}',
    );

    if (kIsWeb) {
      final callable = await _sendViaCallable(
        to: to,
        subject: subject,
        html: html,
      );
      if (callable.success) {
        debugPrint('EmailService._send: callable OK (web)');
        return const EmailSendResult(success: true, delivered: true);
      }

      // Function exists but failed (e.g. Resend rejected recipient) — do not
      // pretend queuing in Firestore sent the email.
      if (!_shouldFallbackToFirestoreMail(callable.functionsErrorCode)) {
        debugPrint(
          'EmailService._send: callable rejected (web), not falling back '
          '(code=${callable.functionsErrorCode}, error="${callable.errorMessage}")',
        );
        return EmailSendResult(
          success: false,
          errorMessage: callable.errorMessage ?? _webSetupHint,
        );
      }

      debugPrint(
        'EmailService: callable unavailable (${callable.functionsErrorCode}), trying Firestore mail',
      );
      final mail = await _sendViaFirestoreMail(
        to: to,
        subject: subject,
        html: html,
      );
      if (mail.success) {
        debugPrint('EmailService._send: queued in Firestore mail collection');
        return const EmailSendResult(
          success: true,
          delivered: false,
          queuedInFirestore: true,
        );
      }

      debugPrint(
        'EmailService._send: web fallback failed: ${mail.errorMessage}',
      );
      return EmailSendResult(
        success: false,
        errorMessage: mail.errorMessage ??
            callable.errorMessage ??
            _webSetupHint,
      );
    }
    // Mobile: prefer the Cloud Function (Gmail SMTP) since it sends to any
    // recipient. Resend is kept as a legacy fallback for offline-Function cases.
    final callable = await _sendViaCallable(
      to: to,
      subject: subject,
      html: html,
    );
    if (callable.success) {
      debugPrint('EmailService._send: callable OK (mobile)');
      return const EmailSendResult(success: true, delivered: true);
    }

    // Only fall back to Resend when the function itself is missing/unreachable.
    // If the function ran and rejected the send (e.g. bad Gmail password), do
    // not silently try a different provider — surface the real error.
    if (!_shouldFallbackFromCallable(callable.functionsErrorCode)) {
      debugPrint(
        'EmailService._send: callable rejected (mobile), not falling back '
        '(code=${callable.functionsErrorCode}, error="${callable.errorMessage}")',
      );
      return EmailSendResult(
        success: false,
        errorMessage: callable.errorMessage ??
            'Could not send email. Deploy the Cloud Function with scripts/deploy-email.ps1',
      );
    }

    debugPrint(
      'EmailService._send: callable unreachable (mobile, '
      'code=${callable.functionsErrorCode}), trying Resend fallback',
    );
    final resend = await _sendViaResend(to: to, subject: subject, html: html);
    if (resend.success) {
      debugPrint('EmailService._send: Resend fallback OK');
      return resend;
    }

    debugPrint(
      'EmailService._send: all transports failed. '
      'callable="${callable.errorMessage}" resend="${resend.errorMessage}"',
    );
    return EmailSendResult(
      success: false,
      errorMessage:
          callable.errorMessage ??
          resend.errorMessage ??
          'Could not send email. Check connection and firebase/EMAIL_SETUP.md',
    );
  }

  bool _shouldFallbackFromCallable(String? code) {
    return code == null ||
        code == 'not-found' ||
        code == 'unavailable' ||
        code == 'unauthenticated';
  }

  bool _shouldFallbackToFirestoreMail(String? code) {
    return code == 'not-found' ||
        code == 'unavailable' ||
        code == 'unauthenticated';
  }

  static const _webSetupHint =
      'Email not configured for web. Install the Firebase "Trigger Email" extension '
      '(see firebase/EMAIL_SETUP.md) or run: firebase login && firebase deploy --only functions';

  Future<EmailSendResult> _sendViaFirestoreMail({
    required String to,
    required String subject,
    required String html,
  }) async {
    try {
      await FirebaseFirestore.instance.collection(_mailCollection).add({
        'to': to.trim(),
        'message': {
          'subject': subject,
          'html': html,
        },
      });
      return const EmailSendResult(success: true);
    } on FirebaseException catch (e) {
      debugPrint('EmailService._sendViaFirestoreMail: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return const EmailSendResult(
          success: false,
          errorMessage:
              'Firestore blocked outbound email. Publish firestore.rules and install Trigger Email (firebase/EMAIL_SETUP.md).',
        );
      }
      return EmailSendResult(
        success: false,
        errorMessage: e.message ?? 'Could not queue email.',
      );
    } catch (e) {
      debugPrint('EmailService._sendViaFirestoreMail: $e');
      return const EmailSendResult(
        success: false,
        errorMessage: 'Could not queue email.',
      );
    }
  }

  Future<EmailSendResult> _sendViaCallable({
    required String to,
    required String subject,
    required String html,
  }) async {
    try {
      debugPrint(
        'EmailService._sendViaCallable: invoking "$_callableName" '
        '(region=us-central1) for "$to"',
      );
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable(
        _callableName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      await callable.call<Map<String, dynamic>>({
        'to': to.trim(),
        'subject': subject,
        'html': html,
      });

      debugPrint('EmailService._sendViaCallable: callable returned OK');
      return const EmailSendResult(success: true, delivered: true);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'EmailService._sendViaCallable: FAILED code=${e.code} '
        'message="${e.message}" details=${e.details}',
      );
      return EmailSendResult(
        success: false,
        errorMessage: _mapFunctionsError(e),
        functionsErrorCode: e.code,
      );
    } catch (e) {
      debugPrint('EmailService._sendViaCallable: unexpected error: $e');
      return const EmailSendResult(success: false, errorMessage: null);
    }
  }

  Future<EmailSendResult> _sendViaResend({
    required String to,
    required String subject,
    required String html,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return const EmailSendResult(
        success: false,
        errorMessage:
            'Email Cloud Function is not deployed. Run scripts/deploy-email.ps1 '
            'after setting GMAIL_USER + GMAIL_APP_PASSWORD in functions/.env '
            '(see firebase/EMAIL_SETUP.md).',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(_resendUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromAddress,
          'to': [to.trim()],
          'subject': subject,
          'html': html,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const EmailSendResult(success: true, delivered: true);
      }

      debugPrint(
        'EmailService._sendViaResend ${response.statusCode}: ${response.body}',
      );
      return EmailSendResult(
        success: false,
        errorMessage: _parseResendError(response.statusCode, response.body),
      );
    } catch (e) {
      debugPrint('EmailService._sendViaResend: $e');
      return const EmailSendResult(
        success: false,
        errorMessage: 'Could not send email. Check your connection.',
      );
    }
  }

  String _parseResendError(int statusCode, String body) {
    String? message;
    try {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      message = parsed['message']?.toString().trim();
    } catch (_) {}

    // Resend's free tier 403 ("You can only send testing emails to your own
    // email address ...") is informative for devs but useless to end users.
    // Collapse it to a single actionable line.
    if (statusCode == 403 &&
        (message?.toLowerCase().contains('testing emails') ?? false)) {
      return 'Email service is in test mode and cannot send to this address. '
          'Deploy the Cloud Function (scripts/deploy-email.ps1) or verify a '
          'domain at resend.com/domains.';
    }

    if (message != null && message.isNotEmpty) return message;

    if (statusCode == 403) {
      return 'Resend blocked this recipient. Verify a domain at resend.com/domains '
          'and set EMAIL_FROM to an address on that domain (see firebase/EMAIL_SETUP.md).';
    }
    return 'Could not send email ($statusCode).';
  }

  String? _mapFunctionsError(FirebaseFunctionsException e) {
    final msg = e.message?.trim();
    if (msg != null && msg.isNotEmpty && msg != 'internal') {
      return msg;
    }
    return switch (e.code) {
      'failed-precondition' =>
        'Email could not be sent. Set GMAIL_USER + GMAIL_APP_PASSWORD in functions/.env and redeploy with scripts/deploy-email.ps1.',
      'unavailable' || 'not-found' => null,
      'invalid-argument' => e.message ?? 'Invalid email request.',
      'internal' =>
        'Email service error on the server. Run: firebase login, then .\\scripts\\deploy-email.ps1',
      _ => null,
    };
  }
}

class EmailSendResult {
  final bool success;
  final String? errorMessage;
  /// True when Resend/Cloud Function confirmed delivery.
  final bool delivered;
  /// True when a `mail` doc was written for Trigger Email (delivery not guaranteed).
  final bool queuedInFirestore;
  final String? functionsErrorCode;

  const EmailSendResult({
    required this.success,
    this.errorMessage,
    this.delivered = false,
    this.queuedInFirestore = false,
    this.functionsErrorCode,
  });
}
