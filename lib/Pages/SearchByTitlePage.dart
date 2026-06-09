import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/theme/theme_extensions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

Widget buildCover(
  BuildContext context,
  String url, {
  double width = double.infinity,
  double height = double.infinity,
}) {
  final c = context.colors;

  if (url.trim().isEmpty) {
    return Container(
      width: width,
      height: height,
      color: c.surface,
      child: Icon(Icons.menu_book_rounded, color: c.textMuted),
    );
  }

  if (url.startsWith('http')) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          width: width,
          height: height,
          color: c.surface,
          child: Icon(Icons.broken_image, color: c.textMuted),
        );
      },
    );
  }

  if (kIsWeb) {
    return Container(
      width: width,
      height: height,
      color: c.surface,
      child: Icon(Icons.menu_book_rounded, color: c.textMuted),
    );
  }

  return Image.file(
    File(url),
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) {
      return Container(
        width: width,
        height: height,
        color: c.surface,
        child: Icon(Icons.broken_image, color: c.textMuted),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// CATEGORY MODEL
// ─────────────────────────────────────────────────────────────

class BookCategory {
  final String name;
  final List<BookModel> books;

  const BookCategory({required this.name, required this.books});
}

// ─────────────────────────────────────────────────────────────
// SEARCH PAGE
// ─────────────────────────────────────────────────────────────

class SearchByTitlePage extends StatefulWidget {
  const SearchByTitlePage({super.key});

  @override
  State<SearchByTitlePage> createState() => _SearchByTitlePageState();
}

class _SearchByTitlePageState extends State<SearchByTitlePage> {
  // Search controller
  final TextEditingController _controller = TextEditingController();

  final BookService _bookService = BookService();
  final PreferencesService _preferencesService = PreferencesService();

  String _query = '';
  List<BookModel> _books = [];
  List<String> _preferredGenres = [];
  bool _isLoading = true;

  // ───────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    listenToBooks();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await _preferencesService.getUserPreferences(uid);
    if (!mounted || prefs == null) return;

    setState(() {
      _preferredGenres = prefs.preferredGenres;
    });
  }

  // ───────────────────────────────────────────────────────────
  // REALTIME LISTENER
  // ───────────────────────────────────────────────────────────

  void listenToBooks() {
    _bookService.booksStream().listen((books) {
      if (!mounted) return;

      setState(() {
        _books = books;
        _isLoading = false;
      });
    });
  }

  // ───────────────────────────────────────────────────────────
  // FILTER BOOKS + GROUP BY CATEGORY
  // ───────────────────────────────────────────────────────────

  List<BookCategory> get _filtered {
    // Filter books
    final filteredBooks = _books.where((book) {
      return book.title.toLowerCase().contains(_query.toLowerCase()) ||
          book.author.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    // Group books
    final Map<String, List<BookModel>> grouped = {};

    for (var book in filteredBooks) {
      if (!grouped.containsKey(book.category)) {
        grouped[book.category] = [];
      }

      grouped[book.category]!.add(book);
    }

    final categories = grouped.entries.map((entry) {
      return BookCategory(name: entry.key, books: entry.value);
    }).toList();

    if (_preferredGenres.isEmpty) return categories;

    categories.sort((a, b) {
      final aPreferred = _preferredGenres.contains(a.name);
      final bPreferred = _preferredGenres.contains(b.name);
      if (aPreferred == bPreferred) return a.name.compareTo(b.name);
      return aPreferred ? -1 : 1;
    });

    return categories;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildTopBar(context),

            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: c.brand),
                    )
                  : _filtered.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount:
                          _filtered.length +
                          (_preferredGenres.isNotEmpty && _query.isEmpty
                              ? 1
                              : 0),
                      itemBuilder: (_, i) {
                        if (_preferredGenres.isNotEmpty &&
                            _query.isEmpty &&
                            i == 0) {
                          return _PickedForYouBanner(genres: _preferredGenres);
                        }

                        final index =
                            _preferredGenres.isNotEmpty && _query.isEmpty
                            ? i - 1
                            : i;

                        return _CategorySection(
                          category: _filtered[index],
                          isPreferred: _preferredGenres.contains(
                            _filtered[index].name,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TOP BAR
  // ───────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // HEADER
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),

                child: Container(
                  width: 32,
                  height: 32,

                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),

                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: c.textMuted,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Text(
                'Search a book',

                style: GoogleFonts.figtree(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: c.brand,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // SEARCH FIELD
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
              boxShadow: cardShadow(context),
            ),

            child: Row(
              children: [
                const SizedBox(width: 16),

                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: c.textMuted,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextField(
                    controller: _controller,

                    onChanged: (v) {
                      setState(() {
                        _query = v;
                      });
                    },

                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: c.text,
                    ),

                    decoration: InputDecoration(
                      hintText: 'Title, author or ISBN…',

                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: c.textMuted,
                      ),

                      border: InputBorder.none,

                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // CLEAR BUTTON
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();

                      setState(() {
                        _query = '';
                      });
                    },

                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),

                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: c.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // EMPTY STATE
  // ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(Icons.search_off_rounded, size: 48, color: c.textMuted),

          const SizedBox(height: 12),

          Text(
            'No books found',

            style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted),
          ),

          const SizedBox(height: 6),

          Text(
            'Try a different title or author',

            style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CATEGORY SECTION
// ─────────────────────────────────────────────────────────────

class _PickedForYouBanner extends StatelessWidget {
  const _PickedForYouBanner({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.brandSoft, c.surface],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.brand.withValues(alpha: 0.2)),
          boxShadow: cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Picked for you',
              style: GoogleFonts.figtree(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Based on your tastes: ${genres.take(4).join(', ')}${genres.length > 4 ? '…' : ''}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, this.isPreferred = false});

  final BookCategory category;
  final bool isPreferred;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const SizedBox(height: 28),

        // CATEGORY HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Row(
                children: [
                  Text(
                    category.name,
                    style: GoogleFonts.amiko(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (isPreferred) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Your pick',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: c.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              Text(
                '${category.books.length} books',

                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: c.brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // BOOKS LIST
        SizedBox(
          height: 230,

          child: ListView.separated(
            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 22),

            itemCount: category.books.length,

            separatorBuilder: (context, index) => const SizedBox(width: 14),

            itemBuilder: (_, i) {
              return _BookCard(book: category.books[i]);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOOK CARD
// ─────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final BookModel book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
        );
      },

      child: SizedBox(
        width: 120,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // BOOK COVER
            Hero(
              tag: book.id,

              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),

                child: buildCover(context, book.coverUrl, width: 120, height: 170),
              ),
            ),

            const SizedBox(height: 10),

            // TITLE
            Text(
              book.title,

              maxLines: 2,
              overflow: TextOverflow.ellipsis,

              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSub,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 3),

            // AUTHOR
            Text(
              book.author,

              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: GoogleFonts.outfit(
                fontSize: 10,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
