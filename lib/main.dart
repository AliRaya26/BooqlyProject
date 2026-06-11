import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:booqly/theme/app_theme.dart';
import 'package:booqly/theme/theme_service.dart';
import 'package:booqly/widgets/auth_gate.dart';
import 'package:booqly/services/reading_motivation_service.dart';
import 'package:booqly/services/gemini_chat_service.dart';
import 'firebase_options.dart';

final ReadingMotivationService motivationService = ReadingMotivationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  try {
    try {
      await dotenv.load(fileName: 'assets/config.env');
    } catch (_) {
      // Key can also be passed via --dart-define=GEMINI_API_KEY=...
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    // Do not block first paint on Google Fonts network downloads.
    GoogleFonts.config.allowRuntimeFetching = true;
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.outfit(),
        GoogleFonts.figtree(),
        GoogleFonts.merriweather(),
      ]).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('GoogleFonts.pendingFonts skipped: $e');
    }

    await GeminiChatService.loadSavedApiKey();
    await ThemeService.instance.load();

    try {
      await motivationService.initialize();
      bindMotivationService(motivationService);
    } catch (e, stack) {
      debugPrint('ReadingMotivationService.initialize failed: $e\n$stack');
    }

    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint('Booqly startup failed: $e\n$stack');
    runApp(StartupErrorApp(message: e.toString()));
  }
}

/// Shown when [main] fails so the web page is not a blank white screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F7F4),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booqly could not start',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Try: stop the app, run flutter pub get, then flutter run -d chrome.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6C6479)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check free time when the user comes back to the app, but not more
    // than once every 10 minutes — refreshSchedule hits Google Calendar.
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (now.difference(_lastRefresh) >= const Duration(minutes: 10)) {
        _lastRefresh = now;
        motivationService.refreshSchedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.notifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}