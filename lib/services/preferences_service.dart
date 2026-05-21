import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/Pages/ReadingPreferencesPage.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/reading_preferences_model.dart';
import 'package:booqly/services/book_service.dart';

class PreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookService _bookService = BookService();

  static const _configDoc = 'app_config/reading_preferences';
  static const _collection = 'preferences';

  DocumentReference<Map<String, dynamic>> _preferencesRef(String uid) {
    return _firestore.collection(_collection).doc(uid);
  }

  static PreferenceCatalog defaultCatalog = PreferenceCatalog(
    genres: const [
      PreferenceOption(id: 'Motivation', label: 'Motivation', emoji: '🔥'),
      PreferenceOption(id: 'Programming', label: 'Programming', emoji: '💻'),
      PreferenceOption(id: 'Finance', label: 'Finance', emoji: '📈'),
      PreferenceOption(
        id: 'Psychology',
        label: 'Psychology',
        emoji: '🧠',
      ),
      PreferenceOption(
        id: 'Productivity',
        label: 'Productivity',
        emoji: '⚡',
      ),
      PreferenceOption(
        id: 'Philosophy',
        label: 'Philosophy',
        emoji: '🏛️',
      ),
      PreferenceOption(id: 'Fiction', label: 'Fiction', emoji: '📖'),
      PreferenceOption(id: 'Science', label: 'Science', emoji: '🔬'),
      PreferenceOption(id: 'History', label: 'History', emoji: '🏺'),
    ],
    readingThemes: const [
      PreferenceOption(
        id: 'cozy_dark',
        label: 'Cozy Dark',
        subtitle: 'Warm gold on charcoal — the Booqly classic',
        emoji: '🌙',
      ),
      PreferenceOption(
        id: 'sepia_warm',
        label: 'Sepia Warm',
        subtitle: 'Paper-like tones for long evening reads',
        emoji: '📜',
      ),
      PreferenceOption(
        id: 'midnight_blue',
        label: 'Midnight Blue',
        subtitle: 'Cool, calm contrast for focused sessions',
        emoji: '🌌',
      ),
      PreferenceOption(
        id: 'paper_light',
        label: 'Paper Light',
        subtitle: 'Bright pages for daytime reading',
        emoji: '☀️',
      ),
    ],
    readingPaces: const [
      PreferenceOption(
        id: 'relaxed',
        label: 'Relaxed',
        subtitle: 'About 1–2 books per month',
        emoji: '🍃',
      ),
      PreferenceOption(
        id: 'steady',
        label: 'Steady',
        subtitle: 'About 3–5 books per month',
        emoji: '📚',
      ),
      PreferenceOption(
        id: 'avid',
        label: 'Avid',
        subtitle: '6+ books per month',
        emoji: '🚀',
      ),
    ],
  );

  List<PreferenceOption> _parseOptions(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => PreferenceOption.fromMap(Map<String, dynamic>.from(e)))
        .where((o) => o.id.isNotEmpty && o.label.isNotEmpty)
        .toList();
  }

  Future<PreferenceCatalog> getCatalog() async {
    try {
      final doc = await _firestore.doc(_configDoc).get();
      if (!doc.exists || doc.data() == null) {
        return defaultCatalog;
      }

      final data = doc.data()!;
      final genres = _parseOptions(data['genres']);
      final themes = _parseOptions(data['readingThemes']);
      final paces = _parseOptions(data['readingPaces']);

      return PreferenceCatalog(
        genres: genres.isNotEmpty ? genres : defaultCatalog.genres,
        readingThemes:
            themes.isNotEmpty ? themes : defaultCatalog.readingThemes,
        readingPaces:
            paces.isNotEmpty ? paces : defaultCatalog.readingPaces,
      );
    } catch (e) {
      debugPrint('PreferencesService.getCatalog: $e');
      return defaultCatalog;
    }
  }

  Future<ReadingPreferencesModel?> getUserPreferences(String uid) async {
    try {
      final prefsDoc = await _preferencesRef(uid).get();
      if (prefsDoc.exists && prefsDoc.data() != null) {
        return ReadingPreferencesModel.fromMap(prefsDoc.data());
      }

      // Legacy: users/{uid}/reading_preferences/settings
      final legacy = await _firestore
          .collection('users')
          .doc(uid)
          .collection('reading_preferences')
          .doc('settings')
          .get();
      if (legacy.exists && legacy.data() != null) {
        return ReadingPreferencesModel.fromMap(legacy.data());
      }

      // Legacy: fields on users/{uid}
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      return ReadingPreferencesModel.fromMap(userDoc.data());
    } catch (e) {
      debugPrint('PreferencesService.getUserPreferences: $e');
      return null;
    }
  }

  Future<bool> hasCompletedPreferences(String uid) async {
    final prefs = await getUserPreferences(uid);
    return prefs?.preferencesCompleted == true;
  }

  /// Saves to `preferences/{uid}` and mirrors fields on `users/{uid}`.
  Future<({bool ok, String? error})> saveUserPreferences(
    String uid,
    ReadingPreferencesModel prefs,
  ) async {
    try {
      final payload = prefs
          .copyWith(
            preferencesCompleted: true,
            updatedAt: DateTime.now(),
          )
          .toMap()
        ..['userId'] = uid
        ..['preferencesUpdatedAt'] = FieldValue.serverTimestamp();

      await _preferencesRef(uid).set(payload, SetOptions(merge: true));

      await _firestore.collection('users').doc(uid).set({
        'preferredGenres': prefs.preferredGenres,
        'readingTheme': prefs.readingTheme,
        'readingPace': prefs.readingPace,
        'preferencesCompleted': true,
        'preferencesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return (ok: true, error: null);
    } on FirebaseException catch (e) {
      final message = '${e.code}: ${e.message ?? "Firestore error"}';
      debugPrint('PreferencesService.saveUserPreferences: $message');
      return (ok: false, error: message);
    } catch (e) {
      debugPrint('PreferencesService.saveUserPreferences: $e');
      return (ok: false, error: e.toString());
    }
  }

  /// Books from catalog matching preferred genres, not already in the library.
  Future<List<BookModel>> getSuggestedBooks({
    required String uid,
    required Set<String> libraryBookIds,
    int limit = 12,
  }) async {
    final prefs = await getUserPreferences(uid);
    final genres = prefs?.preferredGenres ?? [];
    if (genres.isEmpty) return [];

    final catalog = await _bookService.getBooks();
    return _bookService.suggestBooks(
      catalog: catalog,
      preferredGenres: genres,
      excludeBookIds: libraryBookIds,
      limit: limit,
    );
  }

  Future<void> navigateAfterLogin(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !context.mounted) return;

    bool completed = false;
    try {
      completed = await hasCompletedPreferences(uid)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('PreferencesService.navigateAfterLogin: $e');
      // Auth succeeded; don't block the user on slow/offline Firestore.
      completed = false;
    }

    if (!context.mounted) return;

    if (completed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ReadingPreferencesPage(),
        ),
      );
    }
  }

  Stream<ReadingPreferencesModel?> preferencesStream(String uid) {
    return _preferencesRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReadingPreferencesModel.fromMap(doc.data());
    });
  }

  Future<void> createEmptyPreferences(String uid) async {
    await _preferencesRef(uid).set({
      'userId': uid,
      'preferredGenres': <String>[],
      'readingTheme': 'cozy_dark',
      'readingPace': 'steady',
      'preferencesCompleted': false,
      'preferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
