import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/widgets/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      const SizedBox(height: 24),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            height: 1.3,
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          children: const [
                            TextSpan(text: 'Every time I open a book,\nI open a '),
                            TextSpan(
                              text: 'new window',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: ' onto a world\nI never knew existed.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Track what you read, discover what\nyou\'ll love next.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppColors.textSub,
                          height: 1.6,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            AuthNavigationController.instance.requestLoginScreen();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Get started',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.2,
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

class _BookIllustration extends StatelessWidget {
  const _BookIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 220,
          height: 220,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color(0x40EEF2FF),
                Color(0x004F46E5),
              ],
            ),
          ),
        ),
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
