import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────────────

class AppColors {
  static const bg = Color(0xFF0E0C0A);
  static const surface = Color(0xFF1A1713);

  static const border = Color(0xFF2A2520);

  static const textPrimary = Color(0xFFF5F0E8);
  static const textSecondary = Color(0xFFE0D8CC);
  static const textMuted = Color(0xFF888580);

  static const gold = Color(0xFFD4A96A);
}

// ─────────────────────────────────────────────────────────────
// CATEGORY MODEL
// ─────────────────────────────────────────────────────────────

class BookCategory {
  final String name;
  final List<BookModel> books;

  const BookCategory({
    required this.name,
    required this.books,
  });
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

  // Firebase service
  final BookService _bookService = BookService();

  // Search query
  String _query = '';

  // Books list
  List<BookModel> _books = [];

  // Loading
  bool _isLoading = true;

  // ───────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // REALTIME FIRESTORE LISTENER
    listenToBooks();
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

    // Convert map → list
    return grouped.entries.map((entry) {
      return BookCategory(
        name: entry.key,
        books: entry.value,
      );
    }).toList();
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
    return Scaffold(
      backgroundColor: AppColors.bg,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildTopBar(context),

            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                      ),
                    )
                  : _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            return _CategorySection(
                              category: _filtered[i],
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
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),

                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Text(
                'Search a book',

                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // SEARCH FIELD
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),

            child: Row(
              children: [
                const SizedBox(width: 16),

                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textMuted,
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
                      color: AppColors.textPrimary,
                    ),

                    decoration: InputDecoration(
                      hintText: 'Title, author or ISBN…',

                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),

                      border: InputBorder.none,

                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
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

                    child: const Padding(
                      padding: EdgeInsets.only(right: 14),

                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textMuted,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),

          const SizedBox(height: 12),

          Text(
            'No books found',

            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Try a different title or author',

            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CATEGORY SECTION
// ─────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
  });

  final BookCategory category;

  @override
  Widget build(BuildContext context) {
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
              Text(
                category.name,

                style: GoogleFonts.amiko(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              Text(
                '${category.books.length} books',

                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.gold,
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

            separatorBuilder: (_, __) => const SizedBox(width: 14),

            itemBuilder: (_, i) {
              return _BookCard(
                book: category.books[i],
              );
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
  const _BookCard({
    required this.book,
  });

  final BookModel book;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookDetailPage(book: book),
          ),
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

                child: Image.network(
                  book.coverUrl,

                  width: 120,
                  height: 170,

                  fit: BoxFit.cover,

                  // LOADING
                  loadingBuilder: (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Container(
                      width: 120,
                      height: 170,

                      color: AppColors.surface,

                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                        ),
                      ),
                    );
                  },

                  // ERROR
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      width: 120,
                      height: 170,

                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
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
                color: AppColors.textSecondary,
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
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}