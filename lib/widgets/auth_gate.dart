import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/Pages/LoginPage.dart';
import 'package:booqly/Pages/ReadingPreferencesPage.dart';
import 'package:booqly/Pages/WelcomePage.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/services/reading_motivation_service.dart';

/// Chooses the first screen from Firebase Auth session (stay signed in) and
/// optional [AuthNavigationController.showLoginScreen] after sign-out / switch.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthNavigationController.instance.showLoginScreen,
      builder: (context, showLoginScreen, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AuthLoadingScreen();
            }

            final user = snapshot.data;
            if (user == null) {
              AuthNavigationController.instance.clearSignedInCache();
              return showLoginScreen
                  ? const LoginPage()
                  : const WelcomePage();
            }

            // Defer the ValueNotifier mutation so it doesn't fire during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AuthNavigationController.instance.clearLoginScreenRequest();
            });
            return _SignedInScreen(uid: user.uid);
          },
        );
      },
    );
  }
}

class _SignedInScreen extends StatefulWidget {
  const _SignedInScreen({required this.uid});

  final String uid;

  @override
  State<_SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<_SignedInScreen> {
  final _preferencesService = PreferencesService();
  late Future<bool> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = _loadPreferencesCompleted();
    motivationService.refreshSchedule();
  }

  @override
  void didUpdateWidget(covariant _SignedInScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      setState(() {
        _preferencesFuture = _loadPreferencesCompleted();
      });
      motivationService.refreshSchedule();
    }
  }

  Future<bool> _loadPreferencesCompleted() async {
    final cached = AuthNavigationController.instance.cachedPreferencesCompleted;
    if (cached != null) return cached;

    try {
      final completed = await _preferencesService
          .hasCompletedPreferences(widget.uid)
          .timeout(const Duration(seconds: 12));
      AuthNavigationController.instance.cachePreferencesCompleted(completed);
      return completed;
    } catch (e) {
      debugPrint('AuthGate._loadPreferencesCompleted: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _preferencesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AuthLoadingScreen();
        }

        return snapshot.data!
            ? const HomePage()
            : const ReadingPreferencesPage();
      },
    );
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD4A96A)),
            const SizedBox(height: 16),
            Text(
              'Opening Booqly…',
              style: GoogleFonts.outfit(
                color: const Color(0xFF888580),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight navigation hints for auth screens shown by [AuthGate].
class AuthNavigationController {
  AuthNavigationController._();

  static final instance = AuthNavigationController._();

  final showLoginScreen = ValueNotifier<bool>(false);
  bool? cachedPreferencesCompleted;

  void requestLoginScreen() => showLoginScreen.value = true;

  void clearLoginScreenRequest() => showLoginScreen.value = false;

  void cachePreferencesCompleted(bool completed) {
    cachedPreferencesCompleted = completed;
  }

  void clearSignedInCache() {
    cachedPreferencesCompleted = null;
  }
}
