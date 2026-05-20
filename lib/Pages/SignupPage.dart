import 'package:booqly/Pages/LoginPage.dart';
import 'package:booqly/Pages/ReadingPreferencesPage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/email_service.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';



// ── Colors ──

const _bg = Color(0xFF0E0C0A);

const _gold = Color(0xFFD4A96A);

const _ink = Color(0xFFF5F0E8);

const _muted = Color(0xFF888580);

const _surf = Color(0xFF1A1713);



/// Signup with email verification code and welcome email.

class SignupPage extends StatefulWidget {

  const SignupPage({super.key});



  @override

  State<SignupPage> createState() => _SignupPageState();

}



class _SignupPageState extends State<SignupPage> {

  final TextEditingController firstNameController = TextEditingController();

  final TextEditingController lastNameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =

      TextEditingController();

  final TextEditingController verificationCodeController =

      TextEditingController();



  final AuthService authService = AuthService();
  final EmailService emailService = EmailService();
  final PreferencesService preferencesService = PreferencesService();



  bool _awaitingVerification = false;

  bool _isLoading = false;

  String? _pendingVerificationCode;

  DateTime? _codeExpiresAt;



  @override

  void dispose() {

    firstNameController.dispose();

    lastNameController.dispose();

    emailController.dispose();

    passwordController.dispose();

    confirmPasswordController.dispose();

    verificationCodeController.dispose();

    super.dispose();

  }



  Future<void> _sendVerificationCode() async {

    final email = emailController.text.trim();

    final firstName = firstNameController.text.trim();

    final lastName = lastNameController.text.trim();



    if (firstName.isEmpty || lastName.isEmpty) {

      _showMessage('Please enter your first and last name.');

      return;

    }



    if (!authService.isValidEmailFormat(email)) {

      _showMessage('Please enter a valid email address.');

      return;

    }



    if (passwordController.text != confirmPasswordController.text) {

      _showMessage('Passwords do not match');

      return;

    }



    if (passwordController.text.length < 6) {

      _showMessage('Password must be at least 6 characters.');

      return;

    }



    setState(() => _isLoading = true);



    if (await authService.emailIsRegistered(email)) {

      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage('This email is already registered. Try signing in.');

      return;

    }



    final code = emailService.generateVerificationCode();

    final sendResult = await emailService.sendVerificationCode(

      toEmail: email,

      code: code,

      firstName: firstName,

    );



    if (!mounted) return;



    if (!sendResult.success) {
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
        'Email queued. If nothing arrives in 2 minutes, install Trigger Email in Firebase (firebase/EMAIL_SETUP.md).',
      );
    } else {
      _showMessage('Verification code sent to $email');
    }

    if (kDebugMode && kIsWeb && !sendResult.delivered) {
      _showMessage('Dev: your code is $code (email may not have been delivered).');
    }

  }



  Future<void> _verifyAndSignUp() async {

    final entered = verificationCodeController.text.trim();

    final email = emailController.text.trim();

    final firstName = firstNameController.text.trim();

    final lastName = lastNameController.text.trim();



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



    final result = await authService.signUp(

      email: email,

      password: passwordController.text.trim(),

      firstName: firstName,

      lastName: lastName,

    );



    if (!mounted) return;



    if (!result.isSuccess) {

      setState(() => _isLoading = false);

      _showMessage(result.errorMessage ?? 'Signup failed');

      return;

    }



    final welcomeResult = await emailService.sendWelcomeEmail(

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



  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showMessage(result.errorMessage ?? 'Google sign-up failed');
      return;
    }

    if (result.isNewUser) {
      final email = result.user?.email ?? '';
      final name = result.user?.displayName ?? 'Reader';
      final firstName = name.split(' ').first;

      final welcomeResult = await emailService.sendWelcomeEmail(
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

      await preferencesService.navigateAfterLogin(context);
      return;
    }

    setState(() => _isLoading = false);
    _showMessage('You already have an account. Signed you in.');
    await preferencesService.navigateAfterLogin(context);
  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: _bg,

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.symmetric(horizontal: 32),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const SizedBox(height: 28),

              Text(

                'SignUp',

                style: GoogleFonts.cormorantGaramond(

                  fontSize: 70,

                  fontWeight: FontWeight.w600,

                  color: _gold,

                ),

              ),

              if (_awaitingVerification) ...[

                const SizedBox(height: 12),

                Text(

                  'Enter the 6-digit code sent to ${emailController.text.trim()}',

                  style: GoogleFonts.outfit(color: _muted, fontSize: 15),

                ),

              ],

              const SizedBox(height: 28),

              if (!_awaitingVerification) ...[

                TextField(

                  controller: firstNameController,

                  enabled: !_isLoading,

                  style: GoogleFonts.outfit(color: _ink),

                  decoration: _input('First Name', Icons.person_outline_rounded),

                ),

                const SizedBox(height: 18),

                TextField(

                  controller: lastNameController,

                  enabled: !_isLoading,

                  style: GoogleFonts.outfit(color: _ink),

                  decoration: _input('Last Name', Icons.person_outline_rounded),

                ),

                const SizedBox(height: 18),

                TextField(

                  controller: emailController,

                  enabled: !_isLoading,

                  keyboardType: TextInputType.emailAddress,

                  style: GoogleFonts.outfit(color: _ink),

                  decoration: _input('Email address', Icons.mail),

                ),

                const SizedBox(height: 18),

                TextField(

                  controller: passwordController,

                  enabled: !_isLoading,

                  obscureText: true,

                  style: GoogleFonts.outfit(color: _ink),

                  decoration: _input('Password', Icons.lock),

                ),

                const SizedBox(height: 18),

                TextField(

                  controller: confirmPasswordController,

                  enabled: !_isLoading,

                  obscureText: true,

                  style: GoogleFonts.outfit(color: _ink),

                  decoration: _input('Confirm Password', Icons.lock),

                ),

              ] else ...[

                TextField(

                  controller: verificationCodeController,

                  enabled: !_isLoading,

                  keyboardType: TextInputType.number,

                  maxLength: 6,

                  style: GoogleFonts.outfit(color: _ink, letterSpacing: 4),

                  decoration: _input('Verification code', Icons.pin_outlined),

                ),

                const SizedBox(height: 12),

                TextButton(

                  onPressed: _isLoading

                      ? null

                      : () {

                          verificationCodeController.clear();

                          _sendVerificationCode();

                        },

                  child: Text(

                    'Resend code',

                    style: GoogleFonts.outfit(color: _gold),

                  ),

                ),

              ],

              const SizedBox(height: 40),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  onPressed: _isLoading

                      ? null

                      : (_awaitingVerification

                            ? _verifyAndSignUp

                            : _sendVerificationCode),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: _gold,

                    disabledBackgroundColor: _gold.withValues(alpha: 0.5),

                    padding: const EdgeInsets.symmetric(vertical: 16),

                  ),

                  child: _isLoading

                      ? const SizedBox(

                          height: 22,

                          width: 22,

                          child: CircularProgressIndicator(

                            strokeWidth: 2,

                            color: _bg,

                          ),

                        )

                      : Text(

                          _awaitingVerification

                              ? 'Verify & create account'

                              : 'Send verification code',

                          style: GoogleFonts.outfit(color: _bg),

                        ),

                ),

              ),

              if (_awaitingVerification) ...[

                const SizedBox(height: 12),

                Center(

                  child: TextButton(

                    onPressed: _isLoading

                        ? null

                        : () {

                            setState(() {

                              _awaitingVerification = false;

                              _pendingVerificationCode = null;

                              _codeExpiresAt = null;

                              verificationCodeController.clear();

                            });

                          },

                    child: Text(

                      'Edit signup details',

                      style: GoogleFonts.outfit(color: _muted),

                    ),

                  ),

                ),

              ],

              if (!_awaitingVerification) ...[
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, color: _gold),
                    label: Text(
                      'Sign up with Google',
                      style: GoogleFonts.outfit(color: _ink, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _gold),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('Already have an account? Sign in'),
                ),
              ),

            ],

          ),

        ),

      ),

    );

  }



  InputDecoration _input(String hint, IconData icon) {

    return InputDecoration(

      hintText: hint,

      prefixIcon: Icon(icon, color: _muted),

      filled: true,

      fillColor: _surf,

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide.none,

      ),

      counterText: '',

    );

  }

}

