import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/feedback_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:booqly/services/feedback_service.dart';
import 'package:booqly/services/preferences_service.dart';

class GeminiApiException implements Exception {
  GeminiApiException(
    this.message, {
    this.isInvalidKey = false,
    this.isQuotaExceeded = false,
  });

  final String message;
  final bool isInvalidKey;
  final bool isQuotaExceeded;

  @override
  String toString() => message;
}

class LibraryBookEntry {
  final BookModel book;
  final String status;
  final double progress;

  const LibraryBookEntry({
    required this.book,
    required this.status,
    required this.progress,
  });
}

class BookChatContext {
  final List<LibraryBookEntry> libraryBooks;
  final List<BookModel> catalogBooks;
  final List<String> preferredGenres;
  final Map<String, BookFeedbackSummary> feedbackByBookId;

  const BookChatContext({
    required this.libraryBooks,
    required this.catalogBooks,
    required this.preferredGenres,
    this.feedbackByBookId = const {},
  });

  BookFeedbackSummary? feedbackFor(String bookId) => feedbackByBookId[bookId];
}

class GeminiChatService {
  GeminiChatService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final BookService _bookService = BookService();
  final FeedbackService _feedbackService = FeedbackService();
  final PreferencesService _preferencesService = PreferencesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _http;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  // ── In-app key persistence ───────────────────────────────────────────────
  static const _prefKey = 'gemini_api_key';
  static String? _cachedApiKey;

  /// Call once at app startup to restore any key the user saved in Settings.
  static Future<void> loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedApiKey = prefs.getString(_prefKey);
  }

  /// Save [key] so it persists across restarts and takes highest priority.
  static Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    _cachedApiKey = trimmed.isEmpty ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, trimmed);
    }
  }

  /// Remove any in-app saved key (falls back to config.env / dart-define).
  static Future<void> clearSavedApiKey() async {
    _cachedApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// True when a key is saved in-app (not just from config.env).
  static bool get hasSavedApiKey =>
      _cachedApiKey != null && _cachedApiKey!.isNotEmpty;

  /// The raw in-app saved key (null if none). Used by SettingsPage to mask it.
  static String? get savedApiKey => _cachedApiKey;

  /// Models tried in order until one works.
  /// gemini-2.0-flash is first — highest free-tier quota (1500 req/day).
  /// gemini-2.5-flash is last — lower free quota, only used as last resort.
  static const _modelIds = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
  ];

  String? _systemPrompt;
  String? _activeModel;
  BookChatContext? _context;
  final List<Map<String, dynamic>> _history = [];

  String? get preferredModel {
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();

    final fromEnv = dotenv.env['GEMINI_MODEL']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  String get apiKey {
    // 1. In-app saved key (highest priority — user entered it in Settings)
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    // 2. --dart-define at build time
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();

    // 3. assets/config.env
    var key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
      key = key.substring(1, key.length - 1).trim();
    }
    return key;
  }

  bool get isConfigured => apiKey.isNotEmpty;

  BookChatContext? get context => _context;

  Future<BookChatContext> loadContext() async {
    final user = _auth.currentUser;
    final catalog = await _bookService.getBooks();
    final libraryBooks = <LibraryBookEntry>[];
    var preferredGenres = <String>[];

    if (user != null) {
      final prefs = await _preferencesService.getUserPreferences(user.uid);
      preferredGenres = prefs?.preferredGenres ?? [];

      final librarySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .get();

      for (final doc in librarySnapshot.docs) {
        final libraryData = doc.data();
        final bookDoc =
            await _firestore.collection('books').doc(doc.id).get();
        if (!bookDoc.exists) continue;

        final book = BookModel.fromMap(bookDoc.data()!, bookDoc.id);
        libraryBooks.add(
          LibraryBookEntry(
            book: book,
            status: libraryData['status'] as String? ?? 'want_to_read',
            progress: (libraryData['progress'] ?? 0).toDouble(),
          ),
        );
      }
    }

    final feedbackByBookId = await _feedbackService.getSummariesForBooks(
      catalog.map((b) => b.id).toList(),
    );

    final loaded = BookChatContext(
      libraryBooks: libraryBooks,
      catalogBooks: catalog,
      preferredGenres: preferredGenres,
      feedbackByBookId: feedbackByBookId,
    );
    _context = loaded;
    return loaded;
  }

  String buildSystemPrompt(BookChatContext context) {
    final buffer = StringBuffer()
      ..writeln(
        'You are Booqly\'s reading companion. Your job is to help the user decide '
        'what to read and give honest, friendly feedback about books.',
      )
      ..writeln()
      ..writeln('WHAT YOU DO:')
      ..writeln(
        '- Suggest what to read next based on mood, goals, and their library — '
        'prefer books from the BOOQLY CATALOG below.',
      )
      ..writeln(
        '- When they ask about a book (by name or photo), give useful feedback: '
        'what it\'s about, who it suits, strengths, possible downsides, and '
        '1–2 similar picks from the catalog if relevant.',
      )
      ..writeln(
        '- When they ask about ratings, reviews, or scores, use READER FEEDBACK '
        'below. Quote the average rating and summarize real reader comments — '
        'do not invent ratings or reviews.',
      )
      ..writeln(
        '- For photos of a physical book: identify title and author if visible, '
        'then focus on feedback and reading advice. Briefly note if that book '
        'appears in their library or the Booqly catalog.',
      )
      ..writeln(
        '- Do not invent catalog titles. Only recommend books listed in BOOQLY CATALOG.',
      )
      ..writeln('- Keep answers warm, clear, and under ~200 words unless they ask for more.')
      ..writeln();

    if (context.preferredGenres.isNotEmpty) {
      buffer.writeln(
        'USER PREFERRED GENRES: ${context.preferredGenres.join(', ')}',
      );
      buffer.writeln();
    }

    buffer.writeln('USER LIBRARY:');
    if (context.libraryBooks.isEmpty) {
      buffer.writeln('(empty)');
    } else {
      for (final entry in context.libraryBooks) {
        final b = entry.book;
        buffer.writeln(
          '- [${_statusLabel(entry.status)}] "${b.title}" by ${b.author} '
          '(${b.category})',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('BOOQLY CATALOG:');
    for (final book in context.catalogBooks) {
      final summary = context.feedbackFor(book.id);
      final ratingPart = summary != null && summary.hasReviews
          ? ' — ${summary.averageRatingLabel}/5 (${summary.count} reviews)'
          : ' — no reviews yet';
      buffer.writeln(
        '- "${book.title}" by ${book.author} (${book.category})$ratingPart — '
        '${book.description}',
      );
    }

    buffer.writeln();
    buffer.writeln('READER FEEDBACK (use for rating/review questions):');
    var anyFeedback = false;
    for (final book in context.catalogBooks) {
      final summary = context.feedbackFor(book.id);
      if (summary == null || !summary.hasReviews) continue;
      anyFeedback = true;
      buffer.writeln(
        summary.formatForChat(title: book.title, author: book.author),
      );
      buffer.writeln();
    }
    if (!anyFeedback) {
      buffer.writeln('(no reader feedback in the database yet)');
    }

    return buffer.toString();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return 'Currently reading';
      case 'completed':
        return 'Completed';
      case 'want_to_read':
        return 'Want to read';
      default:
        return status;
    }
  }

  /// Verifies the API key with a minimal request before starting chat.
  Future<void> validateApiKey() async {
    if (!isConfigured) {
      throw GeminiApiException(
        'GEMINI_API_KEY is missing. Add it to assets/config.env and restart the app.',
      );
    }

    await _generate(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Reply with exactly: OK'},
          ],
        },
      ],
    );
  }

  Future<void> startSession(BookChatContext context) async {
    if (!isConfigured) {
      throw GeminiApiException(
        'GEMINI_API_KEY is missing. Add it to assets/config.env and restart the app.',
      );
    }

    _systemPrompt = buildSystemPrompt(context);
    _context = context;
    _history.clear();
    _activeModel = null;
  }

  Future<String> sendMessage(
    String message, {
    String? lookupHint,
  }) async {
    final text = _appendLookup(message, lookupHint);
    _history.add({
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    });

    try {
      final reply = await _generate(contents: List.from(_history));
      _history.add({
        'role': 'model',
        'parts': [
          {'text': reply},
        ],
      });
      return reply;
    } catch (e) {
      if (_history.isNotEmpty) {
        _history.removeLast();
      }
      rethrow;
    }
  }

  Future<String> sendMessageWithImage({
    required Uint8List imageBytes,
    required String mimeType,
    String? userText,
    String? lookupHint,
  }) async {
    final prompt = userText?.trim().isNotEmpty == true
        ? userText!.trim()
        : 'This is a photo of a physical book. Identify the title and author if '
            'you can, then give me feedback: what it is about, who it is for, '
            'and whether you think it is worth reading. Mention if it matches '
            'anything in my Booqly library or catalog.';

    final text = _appendLookup(prompt, lookupHint);
    final parts = <Map<String, dynamic>>[
      {'text': text},
      {
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Encode(imageBytes),
        },
      },
    ];

    _history.add({
      'role': 'user',
      'parts': parts,
    });

    try {
      final reply = await _generate(contents: List.from(_history));
      _history.add({
        'role': 'model',
        'parts': [
          {'text': reply},
        ],
      });
      return reply;
    } catch (e) {
      if (_history.isNotEmpty) {
        _history.removeLast();
      }
      rethrow;
    }
  }

  String _appendLookup(String message, String? lookupHint) {
    if (lookupHint == null || lookupHint.isEmpty) return message;
    return '$message\n\n---\nApp lookup (use in your answer): $lookupHint';
  }

  Future<String> _generate({
    required List<Map<String, dynamic>> contents,
  }) async {
    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': _systemPrompt},
        ],
      };
    }

    final fallbackModels = preferredModel != null
        ? [
            preferredModel!,
            ..._modelIds.where((m) => m != preferredModel),
          ]
        : _modelIds;

    final modelsToTry = _activeModel != null
        ? [_activeModel!, ...fallbackModels.where((m) => m != _activeModel)]
        : fallbackModels;

    Object? lastError;

    for (final model in modelsToTry) {
      try {
        final text = await _postGenerate(model, body);
        _activeModel = model;
        return text;
      } on GeminiApiException catch (e) {
        if (e.isInvalidKey) rethrow;
        if (e.isQuotaExceeded && _activeModel == model) {
          _activeModel = null;
        }
        lastError = e;
        debugPrint('Gemini model $model failed: ${e.message}');
      } catch (e) {
        lastError = e;
        debugPrint('Gemini model $model failed: $e');
      }
    }

    // Check if all failures were quota-related
    final isAllQuota = lastError is GeminiApiException &&
        (lastError as GeminiApiException).isQuotaExceeded;
    throw GeminiApiException(
      isAllQuota
          ? 'You\'ve used up the free quota for today. It resets at midnight (Pacific Time). Try again tomorrow or wait a few minutes — limits reset hourly on the free tier.'
          : 'Could not get a response from Gemini. ${lastError ?? "Try again later."}',
      isQuotaExceeded: isAllQuota,
    );
  }

  Future<String> _postGenerate(
    String model,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/models/$model:generateContent?key=${Uri.encodeComponent(apiKey)}',
    );

    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    return _parseResponse(response, model);
  }

  String _parseResponse(http.Response response, String model) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw GeminiApiException(
        'Invalid response from Gemini (${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final error = json['error'];
      final message = error is Map
          ? (error['message'] as String? ?? response.body)
          : response.body;

      final lower = message.toLowerCase();
      if (lower.contains('api key not valid') ||
          lower.contains('api_key_invalid')) {
        throw GeminiApiException(
          'Your Gemini API key is invalid or expired.\n\n'
          'Create a new key at aistudio.google.com/apikey, '
          'paste it in assets/config.env as GEMINI_API_KEY=..., '
          'then fully restart the app.',
          isInvalidKey: true,
        );
      }

      if (response.statusCode == 404 ||
          lower.contains('not found') ||
          lower.contains('not supported')) {
        throw GeminiApiException('Model $model unavailable: $message');
      }

      if (response.statusCode == 429 || lower.contains('quota')) {
        throw GeminiApiException(
          'Quota exceeded for $model',
          isQuotaExceeded: true,
        );
      }

      if (response.statusCode == 503 ||
          lower.contains('high demand') ||
          lower.contains('unavailable')) {
        throw GeminiApiException('Model $model busy (trying another…)');
      }

      throw GeminiApiException('Gemini error (${response.statusCode}): $message');
    }

    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiApiException('No response from Gemini (empty candidates).');
    }

    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      final reason = first['finishReason'] as String?;
      throw GeminiApiException(
        'No text in response${reason != null ? " ($reason)" : ""}.',
      );
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw GeminiApiException('Empty text in Gemini response.');
    }
    return text;
  }

  void resetSession() {
    _history.clear();
    _systemPrompt = null;
    _activeModel = null;
    _context = null;
  }

  void dispose() {
    _http.close();
  }
}
