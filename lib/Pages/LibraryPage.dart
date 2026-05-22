import 'dart:io';

import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/library_service.dart';
import 'package:booqly/services/preferences_service.dart';

class AppColors {
  static const bg = Color(0xFF0E0C0A);
  static const surface = Color(0xFF1A1713);
  static const navBar = Color(0xFF141210);
  static const gold = Color(0xFFD4A96A);
  static const goldMuted = Color(0x1FD4A96A);
  static const goldDim = Color(0x4DD4A96A);
  static const textPrimary = Color(0xFFF5F0E8);
  static const textSecondary = Color(0x80FFFFFF);
  static const textMuted = Color(0x4DFFFFFF);
  static const border = Color(0x0FFFFFFF);
  static const borderDash = Color(0x4DD4A96A);
  static const dayDone = gold;
  static const chipBorder = Color(0x1FFFFFFF);

  // Book cover accents
  static const coverAmber = Color(0xFF2C1F0E);
  static const coverBlue = Color(0xFF151C24);
  static const coverPurple = Color(0xFF1A1424);
  static const coverGreen = Color(0xFF0F1F18);

  static const spineAmber = Color(0xFFD4A96A);
  static const spineBlue = Color(0xFF5B8DD9);
  static const spinePurple = Color(0xFF9B7FD4);
  static const spineGreen = Color(0xFF4A9E7A);
}

class BookCover extends StatelessWidget {
  final String url;

  const BookCover({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Icon(Icons.menu_book_rounded),
      );
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            color: AppColors.surface,
            child: const Icon(Icons.broken_image),
          );
        },
      );
    }

    return Image.file(
      File(url), // IMPORTANT for your manual entry case
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          color: AppColors.surface,
          child: const Icon(Icons.broken_image),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LIBRARY PAGE
// Displays:
// • Reading books
// • Want to read books
// • Completed books
//
// Features:
// • Realtime Firebase updates
// • Category filtering
// • Multi-selection
// • Delete selected books
// • Progress bars
// ─────────────────────────────────────────────────────────────

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

// Widget buildCover(String url) {
//   if (url.isEmpty) {
//     return Container(
//       color: AppColors.surface,
//       child: const Icon(Icons.menu_book_rounded),
//     );
//   }

//   if (url.startsWith('http')) {
//     return Image.network(url, fit: BoxFit.cover);
//   }

//   return Image.asset(url, fit: BoxFit.cover);
// }

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  // TAB CONTROLLER
  late final TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferencesService _preferencesService = PreferencesService();
  final LibraryService _libraryService = LibraryService();

  // CATEGORY FILTER
  int _selectedCategory = 0;

  // LOADING
  bool _isLoading = true;

  bool _showSuggestions = true;

  List<BookModel> _readingBooks = [];
  List<BookModel> _wantToReadBooks = [];
  List<BookModel> _completedBooks = [];
  List<BookModel> _suggestedBooks = [];
  List<String> _preferredGenres = [];
  bool _loadingSuggestions = true;

  // SELECTED BOOKS
  Set<String> selectedBooks = {};

  // SELECTION MODE
  bool get isSelectionMode => selectedBooks.isNotEmpty;

  // CATEGORIES
  static const List<String> _categories = [
    'All',
    'Motivation',
    'Programming',
    'Finance',
    'Psychology',
    'Productivity',
    'Philosophy',
  ];

  // CURRENT TAB BOOKS + FILTER
  List<BookModel> get _currentList {
    List<BookModel> books = [
      _readingBooks,
      _wantToReadBooks,
      _completedBooks,
    ][_tabController.index];

    // ALL CATEGORY
    if (_selectedCategory == 0) {
      return books;
    }

    // FILTERED CATEGORY
    final selectedCategory = _categories[_selectedCategory];

    return books.where((book) {
      return book.category == selectedCategory;
    }).toList();
  }

  // ───────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        setState(() {});
      });

    listenToLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────
  // REALTIME FIREBASE LISTENER
  // Automatically updates library instantly
  // ───────────────────────────────────────────────────────────

  void listenToLibrary() {
    final user = _auth.currentUser;

    if (user == null) return;

    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots()
        .listen((snapshot) async {
          List<BookModel> readingTemp = [];
          List<BookModel> wantTemp = [];
          List<BookModel> completedTemp = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            final status = data['status'] ?? '';

            // GET BOOK DATA
            final bookDoc = await _firestore
                .collection('books')
                .doc(doc.id)
                .get();

            if (!bookDoc.exists) continue;

            final bookData = bookDoc.data()!;

            final book = BookModel(
              id: bookDoc.id,
              title: bookData['title'] ?? '',
              author: bookData['author'] ?? '',
              description: bookData['description'] ?? '',
              category: bookData['category'] ?? '',
              coverUrl: bookData['coverUrl'] ?? '',
              pdfUrl: bookData['pdfUrl'] ?? '',
              totalPages: bookData['totalPages'] ?? 0,
              progress: (data['progress'] ?? 0).toDouble(),
            );

            // ADD TO CORRECT SECTION
            if (status == "reading") {
              readingTemp.add(book);
            } else if (status == "want_to_read") {
              wantTemp.add(book);
            } else if (status == "completed") {
              completedTemp.add(book);
            }
          }

          if (!mounted) return;

          setState(() {
            _readingBooks = readingTemp;
            _wantToReadBooks = wantTemp;
            _completedBooks = completedTemp;
            _isLoading = false;
          });

          _refreshSuggestions();
        });
  }

  Set<String> get _libraryBookIds => {
    ..._readingBooks.map((b) => b.id),
    ..._wantToReadBooks.map((b) => b.id),
    ..._completedBooks.map((b) => b.id),
  };

  Future<void> _refreshSuggestions() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _suggestedBooks = [];
          _preferredGenres = [];
          _loadingSuggestions = false;
        });
      }
      return;
    }

    final prefs = await _preferencesService.getUserPreferences(user.uid);
    final genres = prefs?.preferredGenres ?? [];

    final suggested = await _preferencesService.getSuggestedBooks(
      uid: user.uid,
      libraryBookIds: _libraryBookIds,
    );

    if (!mounted) return;
    setState(() {
      _preferredGenres = genres;
      _suggestedBooks = suggested;
      _loadingSuggestions = false;
    });
  }

  Future<void> _addSuggestedBook(BookModel book) async {
    await _libraryService.addBook(
      bookId: book.id,
      status: 'want_to_read',
      totalPages: book.totalPages,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${book.title} added to Want to read')),
    );
    _refreshSuggestions();
  }

  // ───────────────────────────────────────────────────────────
  // DELETE SELECTED BOOKS
  // ───────────────────────────────────────────────────────────

  Future<void> deleteSelectedBooks() async {
    final user = _auth.currentUser;

    if (user == null) return;

    for (String bookId in selectedBooks) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(bookId)
          .delete();
    }

    setState(() {
      selectedBooks.clear();
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Books removed from library")));
  }

  // ───────────────────────────────────────────────────────────
  // CONFIRM DELETE POPUP
  // ───────────────────────────────────────────────────────────

  void showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.surface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text(
            'Remove Books?',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          content: Text(
            'Do you want to remove the selected books from your library?',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                await deleteSelectedBooks();
              },

              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

              child: Text(
                'Delete',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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
          children: [
            _buildTopBar(),
            _buildTabBar(),
            if (_preferredGenres.isNotEmpty && _showSuggestions)
              _buildSuggestedSection(),
            _buildCategoryChips(),

            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TOP BAR
  // ───────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          // TITLE
          Text(
            isSelectionMode ? '${selectedBooks.length} selected' : 'My Library',

            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: AppColors.gold,
            ),
          ),

          // DELETE ICON
          if (isSelectionMode)
            GestureDetector(
              onTap: showDeleteDialog,

              child: Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),

                child: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
            ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSuggestions = !_showSuggestions;
              });
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showSuggestions
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TAB BAR
  // ───────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),

      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),

      child: TabBar(
        controller: _tabController,

        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.textMuted,

        indicatorColor: AppColors.gold,
        dividerColor: Colors.transparent,

        tabs: const [
          Tab(text: 'Reading'),
          Tab(text: 'Want to read'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildSuggestedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested for you',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loadingSuggestions
                    ? 'Loading picks…'
                    : 'Based on ${_preferredGenres.take(3).join(', ')}${_preferredGenres.length > 3 ? '…' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 188,
          child: _loadingSuggestions
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : _suggestedBooks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      'No new suggestions — explore Search to add books in your favorite genres.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: _suggestedBooks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final book = _suggestedBooks[i];
                    return _SuggestedBookCard(
                      book: book,
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailPage(book: book),
                          ),
                        );
                      },
                      onAdd: () => _addSuggestedBook(book),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  // CATEGORY CHIPS
  // ───────────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          height: 44,

          child: ListView.separated(
            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),

            itemCount: _categories.length,

            separatorBuilder: (context, index) => const SizedBox(width: 8),

            itemBuilder: (_, i) {
              final active = i == _selectedCategory;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = i;
                  });
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: active ? AppColors.gold : Colors.transparent,

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(
                      color: active ? AppColors.gold : AppColors.border,
                    ),
                  ),

                  child: Text(
                    _categories[i],

                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: active ? AppColors.bg : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),

          child: Text(
            '${_currentList.length} books',

            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  // GRID
  // ───────────────────────────────────────────────────────────

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    final books = _currentList;

    if (books.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 20,
        childAspectRatio: 0.52,
      ),

      itemCount: books.length,

      itemBuilder: (_, i) {
        final book = books[i];

        return _BookGridItem(
          book: book,
          showProgress: _tabController.index != 1,

          isSelected: selectedBooks.contains(book.id),

          onTap: () {
            // SELECTION MODE
            if (isSelectionMode) {
              setState(() {
                if (selectedBooks.contains(book.id)) {
                  selectedBooks.remove(book.id);
                } else {
                  selectedBooks.add(book.id);
                }
              });

              return;
            }

            // NORMAL OPEN
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
            );
          },

          onLongPress: () {
            setState(() {
              selectedBooks.add(book.id);
            });
          },
        );
      },
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
          Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textMuted),

          const SizedBox(height: 12),

          Text(
            'No books here yet',

            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SuggestedBookCard extends StatelessWidget {
  const _SuggestedBookCard({
    required this.book,
    required this.onOpen,
    required this.onAdd,
  });

  final BookModel book;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BookCover(url: book.coverUrl)
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: AppColors.bg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              book.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOOK ITEM
// ─────────────────────────────────────────────────────────────

class _BookGridItem extends StatelessWidget {
  const _BookGridItem({
    required this.book,
    required this.showProgress,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
  });

  final BookModel book;
  final bool showProgress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final pct = (book.progress * 100).round();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: Stack(
              children: [
                // COVER
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),

                    child: BookCover(url: book.coverUrl)
                  ),
                ),

                // FAVORITE HEART
                Positioned(
                  top: 8,
                  right: 8,

                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('favorites')
                        .doc(book.id)
                        .snapshots(),

                    builder: (context, snapshot) {
                      final isFavorite = snapshot.data?.exists ?? false;

                      if (!isFavorite) {
                        return const SizedBox();
                      }

                      return Container(
                        padding: const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 16,
                        ),
                      );
                    },
                  ),
                ),

                // SELECTION OVERLAY
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                    ),
                  ),

                // CHECK ICON
                if (isSelected)
                  const Positioned(
                    top: 8,
                    right: 8,

                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.gold,

                      child: Icon(Icons.check, size: 14, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          // PROGRESS
          if (showProgress) ...[
            Text(
              '$pct%',

              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.gold),
            ),

            const SizedBox(height: 4),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),

              child: LinearProgressIndicator(
                value: book.progress,
                minHeight: 4,

                backgroundColor: Colors.white10,

                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),

            const SizedBox(height: 6),
          ],

          // TITLE
          Text(
            book.title,

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 2),

          // AUTHOR
          Text(
            book.author,

            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
