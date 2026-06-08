import 'dart:convert';

import 'package:booqly/services/gemini_chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class IsbnBookResult {
  final bool found;
  final String title;
  final String author;
  final String description;
  final String category;
  final int totalPages;
  final String? coverUrl;
  final String isbn;

  const IsbnBookResult({
    required this.found,
    required this.title,
    required this.author,
    required this.description,
    required this.category,
    required this.totalPages,
    this.coverUrl,
    required this.isbn,
  });

  static IsbnBookResult notFound(String isbn) => IsbnBookResult(
        found: false,
        title: '',
        author: '',
        description: '',
        category: 'Other',
        totalPages: 0,
        isbn: isbn,
      );
}

/// Looks up a book by ISBN.
///
/// Strategy (in order):
///   1. Google Books API   — best coverage, free, returns cover image
///   2. Open Library API   — free fallback, no key required
///   3. Gemini             — last resort: ask the model if it knows the title
///
/// If a book is found via step 1 or 2 but has no description (or a very short
/// one), Gemini is called separately to generate a 2-3 sentence summary.
class GeminiIsbnService {
  static const _gbBase = 'https://www.googleapis.com/books/v1/volumes';
  static const _olBase = 'https://openlibrary.org/api/books';
  static const _geminiBase = 'https://generativelanguage.googleapis.com/v1beta';
  static const _geminiModel = 'gemini-2.0-flash';

  String get _apiKey => GeminiChatService().apiKey;
  bool get _geminiConfigured => GeminiChatService().isConfigured;

  // ── Public entry point ────────────────────────────────────────────────────

  Future<IsbnBookResult> lookupIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[\s\-]'), '');

    // 1. Google Books (best source)
    IsbnBookResult? result = await _lookupGoogleBooks(clean);

    // 2. Open Library fallback
    result ??= await _lookupOpenLibrary(clean);

    // 3. Gemini last-resort (only if still not found and key is set)
    if (result == null && _geminiConfigured) {
      result = await _lookupViaGemini(clean);
    }

    if (result == null) return IsbnBookResult.notFound(clean);

    // Enrich with Gemini if description is missing / very short
    if (_geminiConfigured &&
        result.found &&
        result.description.length < 80) {
      result = await _enrichDescription(result);
    }

    return result;
  }

  // ── Google Books ──────────────────────────────────────────────────────────

  Future<IsbnBookResult?> _lookupGoogleBooks(String isbn) async {
    try {
      final uri = Uri.parse('$_gbBase?q=isbn:$isbn&maxResults=1');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List?;
      if (items == null || items.isEmpty) return null;

      final vol = (items.first as Map<String, dynamic>)['volumeInfo']
          as Map<String, dynamic>;

      final title = vol['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final authors = (vol['authors'] as List?)
              ?.map((a) => a as String)
              .join(', ') ??
          '';
      final desc = vol['description'] as String? ?? '';
      final pages = (vol['pageCount'] as num?)?.toInt() ?? 0;
      final categories = (vol['categories'] as List?)
              ?.map((c) => c as String)
              .toList() ??
          [];

      // Prefer a high-resolution thumbnail; replace curl params for https
      final imageLinks = vol['imageLinks'] as Map<String, dynamic>?;
      String? cover = imageLinks?['extraLarge'] as String? ??
          imageLinks?['large'] as String? ??
          imageLinks?['medium'] as String? ??
          imageLinks?['thumbnail'] as String?;
      if (cover != null) {
        // Google returns http:// — upgrade to https and request a larger image
        cover = cover
            .replaceFirst('http://', 'https://')
            .replaceAll('&zoom=1', '')
            .replaceAll('zoom=1', 'zoom=3');
      }

      return IsbnBookResult(
        found: true,
        title: title,
        author: authors,
        description: desc,
        category: _categoryFromList(categories),
        totalPages: pages,
        coverUrl: cover,
        isbn: isbn,
      );
    } catch (e) {
      debugPrint('GeminiIsbnService: Google Books failed: $e');
      return null;
    }
  }

  // ── Open Library ──────────────────────────────────────────────────────────

  Future<IsbnBookResult?> _lookupOpenLibrary(String isbn) async {
    try {
      final uri = Uri.parse(
          '$_olBase?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final key = 'ISBN:$isbn';
      if (!json.containsKey(key)) return null;

      final data = json[key] as Map<String, dynamic>;
      final title = data['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final authors = (data['authors'] as List?)
              ?.map((a) => (a as Map)['name'] as String? ?? '')
              .join(', ') ??
          '';
      final pages = (data['number_of_pages'] as num?)?.toInt() ?? 0;
      final desc = (data['description'] is Map)
          ? (data['description'] as Map)['value'] as String? ?? ''
          : data['description'] as String? ?? '';
      final subjects = (data['subjects'] as List?)
              ?.map((s) => (s as Map)['name'] as String? ?? '')
              .toList() ??
          [];
      final cover = (data['cover'] as Map?)?['large'] as String? ??
          (data['cover'] as Map?)?['medium'] as String?;

      return IsbnBookResult(
        found: true,
        title: title,
        author: authors,
        description: desc,
        category: _categoryFromSubjects(subjects),
        totalPages: pages,
        coverUrl: cover,
        isbn: isbn,
      );
    } catch (e) {
      debugPrint('GeminiIsbnService: Open Library failed: $e');
      return null;
    }
  }

  // ── Gemini last-resort lookup ─────────────────────────────────────────────

  Future<IsbnBookResult?> _lookupViaGemini(String isbn) async {
    try {
      final prompt = '''
You are a book metadata assistant.
A user scanned the barcode ISBN $isbn.
If you know this ISBN with high confidence, respond ONLY with valid JSON —
no markdown fences, no extra text:

{
  "found": true,
  "title": "Exact Book Title",
  "author": "Author Name",
  "description": "Two or three sentences about what the book is about.",
  "category": "one of: Fiction, Non-Fiction, Economics, Health, Culture, Science, Philosophy, Psychology, Productivity, Motivation, Programming, History, Biography, Other",
  "totalPages": 320
}

If you do NOT know this ISBN with certainty, respond only with: {"found": false}
Do NOT guess or invent book details.
''';

      final raw = await _geminiGenerate(prompt);
      if (raw == null) return null;

      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      if (data['found'] != true) return null;

      return IsbnBookResult(
        found: true,
        title: data['title'] as String? ?? '',
        author: data['author'] as String? ?? '',
        description: data['description'] as String? ?? '',
        category: _normalizeCategory(data['category'] as String? ?? 'Other'),
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 0,
        coverUrl: null,
        isbn: isbn,
      );
    } catch (e) {
      debugPrint('GeminiIsbnService: Gemini last-resort failed: $e');
      return null;
    }
  }

  // ── Gemini description enrichment ─────────────────────────────────────────

  Future<IsbnBookResult> _enrichDescription(IsbnBookResult book) async {
    try {
      final prompt = '''
Write a concise 2-3 sentence description of the book titled "${book.title}" by ${book.author}.
Focus on what the book is about and who it is for.
Respond with ONLY the description text — no quotes, no preamble.
''';

      final desc = await _geminiGenerate(prompt);
      if (desc == null || desc.trim().isEmpty) return book;

      return IsbnBookResult(
        found: book.found,
        title: book.title,
        author: book.author,
        description: desc.trim(),
        category: book.category,
        totalPages: book.totalPages,
        coverUrl: book.coverUrl,
        isbn: book.isbn,
      );
    } catch (e) {
      debugPrint('GeminiIsbnService: description enrichment failed: $e');
      return book;
    }
  }

  // ── Gemini HTTP helper ────────────────────────────────────────────────────

  Future<String?> _geminiGenerate(String prompt) async {
    final uri = Uri.parse(
      '$_geminiBase/models/$_geminiModel:generateContent'
      '?key=${Uri.encodeComponent(_apiKey)}',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ],
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 512,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Gemini ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final parts = ((candidates.first as Map)['content'] as Map)['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;

    return (parts.first as Map)['text'] as String?;
  }

  // ── Category helpers ──────────────────────────────────────────────────────

  String _normalizeCategory(String raw) {
    const valid = [
      'Fiction', 'Non-Fiction', 'Economics', 'Health', 'Culture',
      'Science', 'Philosophy', 'Psychology', 'Productivity', 'Motivation',
      'Programming', 'History', 'Biography', 'Other',
    ];
    for (final v in valid) {
      if (raw.toLowerCase() == v.toLowerCase()) return v;
    }
    return 'Other';
  }

  String _categoryFromList(List<String> categories) {
    return _categoryFromSubjects(categories);
  }

  String _categoryFromSubjects(List<String> subjects) {
    final joined = subjects.join(' ').toLowerCase();
    if (joined.contains('fiction')) return 'Fiction';
    if (joined.contains('histor')) return 'History';
    if (joined.contains('biograph')) return 'Biography';
    if (joined.contains('science') || joined.contains('physics') ||
        joined.contains('chemistry') || joined.contains('biology')) { return 'Science'; }
    if (joined.contains('philosophy')) { return 'Philosophy'; }
    if (joined.contains('psychology') || joined.contains('self-help') ||
        joined.contains('mental health')) { return 'Psychology'; }
    if (joined.contains('economics') || joined.contains('finance') ||
        joined.contains('business') || joined.contains('investment')) { return 'Economics'; }
    if (joined.contains('health') || joined.contains('medicine') ||
        joined.contains('nutrition') || joined.contains('fitness')) { return 'Health'; }
    if (joined.contains('program') || joined.contains('software') ||
        joined.contains('computer') || joined.contains('coding')) { return 'Programming'; }
    if (joined.contains('motivat') || joined.contains('success') ||
        joined.contains('personal development')) { return 'Motivation'; }
    if (joined.contains('productiv') || joined.contains('habit') ||
        joined.contains('time management')) { return 'Productivity'; }
    if (joined.contains('culture') || joined.contains('society') ||
        joined.contains('social')) { return 'Culture'; }
    return 'Non-Fiction';
  }
}
