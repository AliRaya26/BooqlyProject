import 'package:booqly/Pages/SignupPage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/google_oauth_config.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/widgets/auth_gate.dart';
import 'package:booqly/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFF0E0C0A);
const _gold = Color(0xFFD4A96A);
const _ink = Color(0xFFF5F0E8);
const _muted = Color(0xFF888580);
const _surf = Color(0xFF1A1713);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _preferencesService = PreferencesService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _handleForgotPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;

    setState(() => _isLoading = true);
    final error = await _authService.sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    _showMessage(
          error ??
              'Reset email sent to $email. Check inbox and spam (may come from Firebase).',
    );
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final result = await _authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showMessage(result.errorMessage ?? 'Invalid email or password');
      return;
    }

    await _preferencesService.navigateAfterLogin(context);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoading) return;

    final configError = GoogleOAuthConfig.mismatchMessage;
    if (configError != null) {
      _showMessage(configError);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showMessage(result.errorMessage ?? 'Google sign-in failed');
      return;
    }

    if (result.errorMessage != null) {
      _showMessage(result.errorMessage!);
    }

    await _preferencesService.navigateAfterLogin(context);
    if (mounted) setState(() => _isLoading = false);
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _muted),
      filled: true,
      fillColor: _surf,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBackButton = Navigator.canPop(context) ||
        AuthNavigationController.instance.showLoginScreen.value;

    return AuthScaffold(
      showBackButton: showBackButton,
      onBack: AuthNavigationController.instance.showLoginScreen.value
          ? () => AuthNavigationController.instance.clearLoginScreenRequest()
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Login',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 56,
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to continue your reading journey.',
            style: GoogleFonts.outfit(
              fontSize: 17,
              color: _muted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            style: GoogleFonts.outfit(color: _ink, fontSize: 16),
            decoration: _fieldDecoration('Email address', Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            style: GoogleFonts.outfit(color: _ink, fontSize: 16),
            decoration: _fieldDecoration('Password', Icons.lock_outline_rounded),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: Text(
                'Forgot password?',
                style: GoogleFonts.outfit(fontSize: 14, color: _gold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Sign in',
            isLoading: _isLoading,
            onPressed: _signIn,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, color: _gold, size: 28),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.outfit(color: _ink, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFF2A2520))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: GoogleFonts.outfit(color: _muted)),
              ),
              const Expanded(child: Divider(color: Color(0xFF2A2520))),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.outfit(color: _muted, fontSize: 15),
                  children: [
                    const TextSpan(text: "Don't have an account? "),
                    TextSpan(
                      text: 'Sign up',
                      style: GoogleFonts.outfit(
                        color: _gold,
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

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _emailController.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surf,
      title: Text(
        'Reset password',
        style: GoogleFonts.cormorantGaramond(color: _gold, fontSize: 28),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your account email. We will send a link to reset your password.',
            style: GoogleFonts.outfit(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.outfit(color: _ink),
            decoration: InputDecoration(
              hintText: 'Email address',
              hintStyle: GoogleFonts.outfit(color: _muted),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.outfit(color: _muted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Send link', style: GoogleFonts.outfit(color: _gold)),
        ),
      ],
    );
  }
}
