import 'package:booqly/Pages/LoginPage.dart';
import 'package:booqly/Pages/ReadingPreferencesPage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/email_service.dart';
import 'package:booqly/services/google_oauth_config.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/theme/theme_extensions.dart';
import 'package:booqly/widgets/auth_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  final _authService = AuthService();
  final _emailService = EmailService();
  final _preferencesService = PreferencesService();

  bool _awaitingVerification = false;
  bool _isLoading = false;
  String? _pendingVerificationCode;
  DateTime? _codeExpiresAt;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
    );
  }

  bool _validateSignupFields() {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _showMessage('Please enter your first and last name.');
      return false;
    }
    final email = _emailController.text.trim();
    if (!_authService.isValidEmailFormat(email)) {
      _showMessage('Please enter a valid email address.');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match');
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return false;
    }
    return true;
  }

  Future<void> _sendVerificationCode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoading || !_validateSignupFields()) return;

    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();

    setState(() => _isLoading = true);

    final registered = await _authService.emailIsRegistered(email);
    if (!mounted) return;

    if (registered == null) {
      setState(() => _isLoading = false);
      _showMessage('Could not check email (network). Connect to Wi‑Fi and try again.');
      return;
    }

    if (registered) {
      setState(() => _isLoading = false);
      _showMessage('This email is already registered. Try signing in.');
      return;
    }

    final code = _emailService.generateVerificationCode();
    final sendResult = await _emailService.sendVerificationCode(
      toEmail: email,
      code: code,
      firstName: firstName,
    );

    if (!mounted) return;

    if (!sendResult.success) {
      if (kDebugMode) {
        setState(() {
          _isLoading = false;
          _awaitingVerification = true;
          _pendingVerificationCode = code;
          _codeExpiresAt = DateTime.now().add(const Duration(minutes: 15));
        });
        _showMessage(
          'Email send failed (${sendResult.errorMessage ?? "unknown"}). '
          'DEV bypass code: $code',
        );
        return;
      }
      setState(() => _isLoading = false);
      _showMessage(sendResult.errorMessage ?? 'Could not send verification email.');
      return;
    }

    setState(() {
      _isLoading = false;
      _awaitingVerification = true;
      _pendingVerificationCode = code;
      _codeExpiresAt = DateTime.now().add(const Duration(minutes: 15));
    });

    if (sendResult.queuedInFirestore) {
      _showMessage(
        'Email queued. If nothing arrives in 2 minutes, check spam or firebase/EMAIL_SETUP.md.',
      );
    } else {
      _showMessage('Verification code sent to $email');
    }

    if (kDebugMode && !sendResult.delivered) {
      _showMessage('Dev code (if email delayed): $code');
    }
  }

  Future<void> _verifyAndSignUp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoading) return;

    final entered = _verificationCodeController.text.trim();
    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (_pendingVerificationCode == null) {
      _showMessage('Request a verification code first.');
      return;
    }

    if (_codeExpiresAt != null && DateTime.now().isAfter(_codeExpiresAt!)) {
      _showMessage('Verification code expired. Tap Resend code.');
      return;
    }

    if (entered != _pendingVerificationCode) {
      _showMessage('Incorrect verification code. Try again.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signUp(
      email: email,
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showMessage(result.errorMessage ?? 'Signup failed');
      return;
    }

    final welcomeResult = await _emailService.sendWelcomeEmail(
      toEmail: email,
      firstName: firstName,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!welcomeResult.success) {
      _showMessage(
        welcomeResult.errorMessage ??
            'Account created, but welcome email could not be sent.',
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReadingPreferencesPage()),
    );
  }

  Future<void> _signUpWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoading) return;

    final configError = GoogleOAuthConfig.mismatchMessage;
    if (configError != null) {
      _showMessage(configError);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signInWithGoogle(forceAccountPicker: true);

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showMessage(result.errorMessage ?? 'Google sign-up failed');
      return;
    }

    if (result.errorMessage != null) {
      _showMessage(result.errorMessage!);
    }

    final email = result.user?.email?.trim() ?? '';
    final name = result.user?.displayName?.trim() ?? '';
    final firstName = name.isNotEmpty ? name.split(RegExp(r'\s+')).first : 'Reader';

    debugPrint(
      'SignupPage._signUpWithGoogle: sending welcome email to "$email" '
      '(firstName="$firstName", isNewUser=${result.isNewUser})',
    );

    if (email.isEmpty) {
      setState(() => _isLoading = false);
      _showMessage(
        'Signed in, but Google did not return an email so no welcome email was sent.',
      );
      await _preferencesService.navigateAfterLogin(context);
      return;
    }

    final welcomeResult = await _emailService.sendWelcomeEmail(
      toEmail: email,
      firstName: firstName,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (welcomeResult.success) {
      _showMessage(
        result.isNewUser
            ? 'Welcome to Booqly! Confirmation sent to $email.'
            : 'Welcome back! Confirmation sent to $email.',
      );
    } else {
      _showMessage(
        welcomeResult.errorMessage ??
            'Signed in, but the welcome email could not be sent.',
      );
    }

    await _preferencesService.navigateAfterLogin(context);
  }

  InputDecoration _fieldDecoration(AppPalette c, String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: c.textMuted, fontSize: 15),
      prefixIcon: Icon(icon, color: c.textMuted, size: 20),
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.brand, width: 1.5),
      ),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AuthScaffold(
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create account',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          if (_awaitingVerification) ...[
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to ${_emailController.text.trim()}',
              style: GoogleFonts.outfit(color: c.textSub, fontSize: 14),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Start tracking your reading journey.',
              style: GoogleFonts.outfit(color: c.textSub, fontSize: 15),
            ),
          ],
          const SizedBox(height: 24),
          if (!_awaitingVerification) ...[
            TextField(
              controller: _firstNameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.outfit(color: c.text, fontSize: 15),
              decoration:
                  _fieldDecoration(c, 'First name', Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.outfit(color: c.text, fontSize: 15),
              decoration:
                  _fieldDecoration(c, 'Last name', Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: GoogleFonts.outfit(color: c.text, fontSize: 15),
              decoration:
                  _fieldDecoration(c, 'Email address', Icons.mail_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              style: GoogleFonts.outfit(color: c.text, fontSize: 15),
              decoration:
                  _fieldDecoration(c, 'Password', Icons.lock_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendVerificationCode(),
              autofillHints: const [AutofillHints.newPassword],
              style: GoogleFonts.outfit(color: c.text, fontSize: 15),
              decoration: _fieldDecoration(
                  c, 'Confirm password', Icons.lock_outline_rounded),
            ),
          ] else ...[
            TextField(
              controller: _verificationCodeController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyAndSignUp(),
              style: GoogleFonts.outfit(
                color: c.text,
                letterSpacing: 4,
                fontSize: 18,
              ),
              decoration:
                  _fieldDecoration(c, 'Verification code', Icons.pin_outlined),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _verificationCodeController.clear();
                      _sendVerificationCode();
                    },
              child: Text(
                'Resend code',
                style: GoogleFonts.outfit(color: c.brand),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: _awaitingVerification
                ? 'Verify & create account'
                : 'Send verification code',
            isLoading: _isLoading,
            onPressed: _awaitingVerification ? _verifyAndSignUp : _sendVerificationCode,
          ),
          if (_awaitingVerification) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _awaitingVerification = false;
                          _pendingVerificationCode = null;
                          _codeExpiresAt = null;
                          _verificationCodeController.clear();
                        });
                      },
                child: Text(
                  'Edit signup details',
                  style: GoogleFonts.outfit(color: c.textSub),
                ),
              ),
            ),
          ],
          if (!_awaitingVerification) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: c.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: GoogleFonts.outfit(color: c.textMuted),
                  ),
                ),
                Expanded(child: Divider(color: c.border)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signUpWithGoogle,
                icon: Icon(Icons.g_mobiledata, color: c.brand, size: 28),
                label: Text(
                  'Sign up with Google',
                  style: GoogleFonts.outfit(color: c.text, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.outfit(color: c.textSub, fontSize: 15),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign in',
                      style: GoogleFonts.outfit(
                        color: c.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
