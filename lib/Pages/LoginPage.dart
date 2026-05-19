import 'package:booqly/Pages/SignupPage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors ──
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
  // ── Controllers (store user input) ──
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Firebase services
  final AuthService authService = AuthService();
  final PreferencesService preferencesService = PreferencesService();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
              const SizedBox(height: 48),

              // ── Title ──
              Text(
                "Login",
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 70,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Sign in to continue your reading journey.',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: _muted,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 48),

              // ── EMAIL FIELD ──
              TextField(
                controller: emailController,
                style: GoogleFonts.outfit(color: _ink),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: _muted,
                  ),
                  filled: true,
                  fillColor: _surf,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── PASSWORD FIELD ──
              TextField(
                controller: passwordController,
                obscureText: true,
                style: GoogleFonts.outfit(color: _ink),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: _muted,
                  ),
                  filled: true,
                  fillColor: _surf,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.outfit(fontSize: 14, color: _gold),
                ),
              ),

              const SizedBox(height: 32),

              // ── LOGIN BUTTON ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await authService.signIn(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );

                    if (!context.mounted) return;

                    if (result.isSuccess) {
                      await preferencesService.navigateAfterLogin(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Invalid email or password',
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: Text(
                    'Sign in',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _bg,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await authService.signInWithGoogle();

                    if (!context.mounted) return;

                    if (result.isSuccess) {
                      await preferencesService.navigateAfterLogin(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Google sign-in failed',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, color: _gold),
                  label: Text(
                    'Continue with Google',
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

              const SizedBox(height: 20),
              
              // ── Divider ──
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

              // ── Go to Sign Up ──
              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(color: _muted),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: "Sign up",
                        style: const TextStyle(color: _gold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupPage(),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
