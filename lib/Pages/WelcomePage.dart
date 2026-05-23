import 'package:booqly/widgets/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const _ink   = Color(0xFFF5F0E8);
  static const _gold  = Color(0xFFD4A96A);
  static const _muted = Color(0xFF888580);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 600 ? 480 : 560,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      const _BookIllustration(),
                      RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.merriweather (
                    fontSize: 30,
                    height: 1.25,
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.25,
                  ),
                  children: const [
                    TextSpan(text: 'Every time I open a book,\nI open a '),
                    TextSpan(
                      text: 'new window',
                      style: TextStyle(color: _gold, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    TextSpan(text: ' onto a world\nI never knew existed.'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Subtitle ──
              Text(
                'Track what you read, discover what\nyou\'ll love next.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: _muted, height: 1.6),
              ),

              const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            AuthNavigationController.instance
                                .requestLoginScreen();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Get started',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0E0C0A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Asset image with a soft gold glow behind it ──

class _BookIllustration extends StatelessWidget {
  const _BookIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow circle behind the image
        Container(
          width: 220,
          height: 220,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.fromARGB(112, 212, 170, 106), // gold centre
                Color.fromARGB(5, 212, 170, 106), // transparent edge
              ],
            ),
          ),
        ),

        // PNG image
        Image.asset(
          'lib/assets/images/book.png',
          width: 360,
          height: 320,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}