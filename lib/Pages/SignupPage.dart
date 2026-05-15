import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/Pages/LoginPage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors ──
const _bg = Color(0xFF0E0C0A);
const _gold = Color(0xFFD4A96A);
const _ink = Color(0xFFF5F0E8);
const _muted = Color(0xFF888580);
const _surf = Color(0xFF1A1713);

/// Signup Page with Firebase Authentication
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // ── Controllers: store user input from text fields ──
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Firebase auth service instance
  final AuthService authService = AuthService();

  @override
  void dispose() {
    // Clean memory when page is closed
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
              const SizedBox(height: 28),

              // ── Title ──
              Text(
                'SignUp',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 70,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 28),

              // ── First Name (UI only, not used in Firebase yet) ──
              TextField(
                controller: firstNameController,
                style: GoogleFonts.outfit(color: _ink),
                decoration: _input('First Name', Icons.person_outline_rounded),
              ),

              const SizedBox(height: 18),

              // ── Last Name (UI only) ──
              TextField(
                controller: lastNameController,
                style: GoogleFonts.outfit(color: _ink),
                decoration: _input('Last Name', Icons.person_outline_rounded),
              ),

              const SizedBox(height: 18),

              // ── Email field (connected to controller) ──
              TextField(
                controller: emailController,
                style: GoogleFonts.outfit(color: _ink),
                decoration: _input('Email address', Icons.mail),
              ),

              const SizedBox(height: 18),

              // ── Password field ──
              TextField(
                controller: passwordController,
                obscureText: true,
                style: GoogleFonts.outfit(color: _ink),
                decoration: _input('Password', Icons.lock),
              ),

              const SizedBox(height: 18),

              // ── Confirm Password field ──
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: GoogleFonts.outfit(color: _ink),
                decoration: _input('Confirm Password', Icons.lock),
              ),

              const SizedBox(height: 40),

              // ── SIGN UP BUTTON ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // ── Check if passwords match ──
                    if (passwordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Passwords do not match")),
                      );
                      return;
                    }

                    // ── Call Firebase signup ──
                    final user = await authService.signUp(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                    );

                    // ── If signup successful ──
                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                      );
                    }
                    // ── If signup failed ──
                    else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Signup failed")),
                      );
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),

                  child: Text("Sign Up", style: GoogleFonts.outfit(color: _bg)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Navigate to Login Page ──
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text("Already have an account? Sign in"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Simple reusable field (UI only, no controller) ──
  Widget _field(String hint, IconData icon) {
    return TextField(
      style: GoogleFonts.outfit(color: _ink),
      decoration: _input(hint, icon),
    );
  }

  // ── Shared decoration for all inputs ──
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
    );
  }
}
