import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:booqly/Pages/WelcomePage.dart';
import 'package:booqly/services/reading_motivation_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'assets/config.env');
  } catch (_) {
    // Key can also be passed via --dart-define=GEMINI_API_KEY=...
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Avoid first-frame stalls on tablet when fonts download.
  GoogleFonts.config.allowRuntimeFetching = true;
  await GoogleFonts.pendingFonts([
    GoogleFonts.outfit(),
    GoogleFonts.cormorantGaramond(),
    GoogleFonts.merriweather(),
  ]);

  final motivationService = ReadingMotivationService();
  await motivationService.initialize();
  await motivationService.refreshSchedule();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0C0A),
      ),
      home: const WelcomePage(),
    );
  }
}