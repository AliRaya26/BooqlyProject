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
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable(
        _passwordResetCallableName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      await callable.call<Map<String, dynamic>>({
        'email': toEmail.trim(),
      });

      return const EmailSendResult(success: true, delivered: true);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'EmailService.sendPasswordResetEmail: ${e.code} ${e.message}',
      );
      return EmailSendResult(
        success: false,
        errorMessage: _mapPasswordResetFunctionsError(e),
        functionsErrorCode: e.code,
      );
    } catch (e) {
      debugPrint('EmailService.sendPasswordResetEmail: $e');
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
  }) {
    final greeting = firstName.isNotEmpty ? firstName : 'Reader';
    final title = _escapeHtml(bookTitle);
    final authorLine = author.trim().isNotEmpty
        ? '<p style="color:#888580;margin:0;">by ${_escapeHtml(author)}</p>'
        : '';
    final pagesLine = totalPages > 0
        ? '<p style="margin:16px 0 0;color:#D4A96A;font-size:15px;">$totalPages pages read</p>'
        : '';

    return _send(
      to: toEmail,
      subject: 'Congratulations — you finished $bookTitle',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;">
  <div style="max-width:520px;margin:0 auto;">
    <p style="font-size:40px;margin:0 0 8px;">🏆</p>
    <h1 style="color:#D4A96A;font-style:italic;margin:0 0 12px;">Congratulations!</h1>
    <p style="font-size:17px;line-height:1.6;">Hi ${_escapeHtml(greeting)},</p>
    <p style="font-size:17px;line-height:1.6;">You did it — you finished a book on Booqly. That is a real accomplishment worth celebrating.</p>
    <div style="background:#1A1713;border:1px solid #2A2520;border-radius:16px;padding:22px 24px;margin:24px 0;">
      <p style="margin:0;font-size:20px;font-weight:bold;color:#F5F0E8;">$title</p>
      $authorLine
      $pagesLine
    </div>
    <p style="font-size:17px;line-height:1.6;">Take a moment to enjoy it. When you are ready, your library is waiting with the next adventure.</p>
    <p style="color:#888580;margin-top:28px;">Happy reading,<br>The Booqly team</p>
  </div>
</body>
</html>''',
    );
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
    if (kIsWeb) {
      final callable = await _sendViaCallable(
        to: to,
        subject: subject,
        html: html,
      );
      if (callable.success) {
        return const EmailSendResult(success: true, delivered: true);
      }

      // Function exists but failed (e.g. Resend rejected recipient) — do not
      // pretend queuing in Firestore sent the email.
      if (!_shouldFallbackToFirestoreMail(callable.functionsErrorCode)) {
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
        return const EmailSendResult(
          success: true,
          delivered: false,
          queuedInFirestore: true,
        );
      }

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
      return const EmailSendResult(success: true, delivered: true);
    }

    // Only fall back to Resend when the function itself is missing/unreachable.
    // If the function ran and rejected the send (e.g. bad Gmail password), do
    // not silently try a different provider — surface the real error.
    if (!_shouldFallbackFromCallable(callable.functionsErrorCode)) {
      return EmailSendResult(
        success: false,
        errorMessage: callable.errorMessage ??
            'Could not send email. Deploy the Cloud Function with scripts/deploy-email.ps1',
      );
    }

    final resend = await _sendViaResend(to: to, subject: subject, html: html);
    if (resend.success) return resend;

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

      return const EmailSendResult(success: true, delivered: true);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'EmailService._sendViaCallable: ${e.code} ${e.message} ${e.details}',
      );
      return EmailSendResult(
        success: false,
        errorMessage: _mapFunctionsError(e),
        functionsErrorCode: e.code,
      );
    } catch (e) {
      debugPrint('EmailService._sendViaCallable: $e');
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
