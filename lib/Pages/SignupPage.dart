import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/Pages/LoginPage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors (same as welcome page) ──
const _bg = Color(0xFF0E0C0A);
const _gold = Color(0xFFD4A96A);
const _ink = Color(0xFFF5F0E8);
const _muted = Color(0xFF888580);
const _surf = Color(0xFF1A1713);

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: SignupPage()),
);

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

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

              // ── Title ──
              RichText(
                text: TextSpan(
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 70,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.2,
                  ),
                  children: const [
                    // TextSpan(text: 'Welcome\n'),
                    TextSpan(
                      text: 'SignUp,',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Sign Up to continue your reading journey.',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: _muted,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 28),

              // ── Fields ──
              const SizedBox(height: 18),
              const _Field(
                hint: 'First Name',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 18),
              const _Field(
                hint: 'Last Name',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 18),
              const _Field(
                hint: 'Email address',
                icon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 18),
              const _Field(
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),
              const SizedBox(height: 18),
              const _Field(
                hint: 'Confirm Password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),

              const SizedBox(height: 42),

              // ── Login Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _bg,
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
                    child: Text(
                      'or',
                      style: GoogleFonts.outfit(fontSize: 13, color: _muted),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFF2A2520))),
                ],
              ),

              const SizedBox(height: 20),

              // ── Google Button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: Text(
                    'Continue with Google',
                    style: GoogleFonts.outfit(fontSize: 16, color: _ink),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF2A2520)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Sign up link ──
              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(fontSize: 14, color: _muted),
                    children: [
                      const TextSpan(text: "Already have an account?  "),
                      TextSpan(
                        text: 'Sign in',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    },
                    child: Text(
                      'Skip For Now',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: _gold.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable text field ──
class _Field extends StatelessWidget {
  const _Field({required this.hint, required this.icon, this.obscure = false});
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      style: GoogleFonts.outfit(fontSize: 14, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(fontSize: 16, color: _muted),
        prefixIcon: Icon(icon, size: 20, color: _muted),
        filled: true,
        fillColor: _surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
