import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/services/reading_session_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/utils/book_cover_url.dart';
import 'package:booqly/widgets/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/library_service.dart';
import 'package:booqly/services/preferences_service.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _preferencesService = PreferencesService();
  final _libraryService = LibraryService();

  bool _isLoading = true;
  List<BookModel> _readingBooks = [];
  List<BookModel> _wantToReadBooks = [];
  List<BookModel> _completedBooks = [];
  List<BookModel> _suggestedBooks = [];
  List<String> _preferredGenres = [];
  bool _loadingSuggestions = true;
  Set<String> _selected = {};

  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    _listenToLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookModel> get _currentList => [
        _readingBooks,
        _wantToReadBooks,
        _completedBooks,
      ][_tabController.index];

  void _listenToLibrary() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots()
        .listen((snapshot) async {
      List<BookModel> reading = [], want = [], completed = [];

      for (final doc in snapshot.docs) {
        final libraryData = doc.data();
        final bookDoc =
            await _firestore.collection('books').doc(doc.id).get();
        final catalogData =
            bookDoc.exists ? bookDoc.data()! : <String, dynamic>{};

        // Prefer catalog; fall back to library doc; use doc id as title last resort.
        var title = (catalogData['title'] ?? libraryData['title'] ?? doc.id)
            .toString()
            .trim();
        if (title.isEmpty) continue;

        final coverFromCatalog = coverUrlFromMap(catalogData);
        final coverFromLibrary = coverUrlFromMap(libraryData);
        final storedCover =
            coverFromCatalog.isNotEmpty ? coverFromCatalog : coverFromLibrary;
        final isbn =
            (catalogData['isbn'] ?? libraryData['isbn'] ?? '').toString();

        final book = BookModel(
          id: doc.id,
          title: title,
          author: (catalogData['author'] ?? libraryData['author'] ?? '')
              .toString(),
          description:
              (catalogData['description'] ?? libraryData['description'] ?? '')
                  .toString(),
          category:
              (catalogData['category'] ?? libraryData['category'] ?? '')
                  .toString(),
          coverUrl: effectiveCoverUrl(
            coverUrl: storedCover,
            title: title,
            isbn: isbn.isNotEmpty ? isbn : null,
          ),
          pdfUrl: (catalogData['pdfUrl'] ?? libraryData['pdfUrl'] ?? '')
              .toString(),
          totalPages: (catalogData['totalPages'] as num?)?.toInt() ??
              (libraryData['totalPages'] as num?)?.toInt() ??
              0,
          progress: (libraryData['progress'] ?? 0).toDouble(),
          currentPage: (libraryData['currentPage'] as num?)?.toInt() ?? 0,
        );
        switch (libraryData['status'] as String? ?? '') {
          case 'reading':
            reading.add(book);
          case 'want_to_read':
            want.add(book);
          case 'completed':
            completed.add(book);
        }

        // Backfill missing display fields on library docs (older entries).
        if (coverFromLibrary.isEmpty && book.coverUrl.isNotEmpty) {
          doc.reference.set(
            LibraryService.bookMetadata(
              title: book.title,
              author: book.author,
              coverUrl: book.coverUrl,
              category: book.category,
            ),
            SetOptions(merge: true),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _readingBooks = reading;
        _wantToReadBooks = want;
        _completedBooks = completed;
        _isLoading = false;
      });
      _refreshSuggestions();
    });
  }

  Set<String> get _libraryIds => {
        ..._readingBooks.map((b) => b.id),
        ..._wantToReadBooks.map((b) => b.id),
        ..._completedBooks.map((b) => b.id),
      };

  Future<void> _refreshSuggestions() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await _preferencesService.getUserPreferences(user.uid);
    final suggested = await _preferencesService.getSuggestedBooks(
        uid: user.uid, libraryBookIds: _libraryIds);
    if (!mounted) return;
    setState(() {
      _preferredGenres = prefs?.preferredGenres ?? [];
      _suggestedBooks = suggested;
      _loadingSuggestions = false;
    });
  }

  Future<void> _addSuggested(BookModel book) async {
    await _libraryService.addBook(
      bookId: book.id,
      status: 'want_to_read',
      totalPages: book.totalPages,
      title: book.title,
      author: book.author,
      coverUrl: effectiveCoverUrl(
        coverUrl: book.coverUrl,
        title: book.title,
      ),
      category: book.category,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${book.title}" to Want to read',
            style: GoogleFonts.outfit()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _refreshSuggestions();
  }

  Future<void> _deleteSelected() async {
    final user = _auth.currentUser;
    if (user == null) return;
    for (final id in _selected) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(id)
          .delete();
    }
    setState(() => _selected.clear());
  }

  void _confirmDelete(AppPalette c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${_selected.length} book${_selected.length == 1 ? '' : 's'}?',
            style: GoogleFonts.outfit(color: c.text, fontWeight: FontWeight.w600)),
        content: Text('They will be removed from your library.',
            style: GoogleFonts.outfit(color: c.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: c.textSub)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSelected();
            },
            style: FilledButton.styleFrom(backgroundColor: c.error),
            child: Text('Remove', style: GoogleFonts.outfit(color: c.onPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: c.surface,
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSelecting
                                ? '${_selected.length} selected'
                                : 'My Library',
                            style: GoogleFonts.figtree(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading
                                ? 'Loading…'
                                : '${_readingBooks.length + _wantToReadBooks.length + _completedBooks.length} books total',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (_isSelecting) ...[
                      _HeaderBtn(
                        icon: Icons.close_rounded,
                        color: c.textSub,
                        bg: c.surfaceAlt,
                        onTap: () => setState(() => _selected.clear()),
                      ),
                      const SizedBox(width: 8),
                      _HeaderBtn(
                        icon: Icons.delete_outline_rounded,
                        color: c.error,
                        bg: c.errorSoft,
                        onTap: () => _confirmDelete(c),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // ── Tabs ───────────────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  labelColor: c.brand,
                  unselectedLabelColor: c.textMuted,
                  indicatorColor: c.brand,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      GoogleFonts.outfit(fontSize: 14),
                  tabs: [
                    Tab(text: 'Reading (${_readingBooks.length})'),
                    Tab(text: 'Want to read (${_wantToReadBooks.length})'),
                    Tab(text: 'Done (${_completedBooks.length})'),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: c.brand))
                : CustomScrollView(
                    slivers: [
                      // Suggestions strip (only on Want to read tab)
                      if (_tabController.index == 1 &&
                          _preferredGenres.isNotEmpty)
                        SliverToBoxAdapter(
                            child: _SuggestionsStrip(
                          books: _suggestedBooks,
                          loading: _loadingSuggestions,
                          genres: _preferredGenres,
                          onAdd: _addSuggested,
                          onOpen: (b) => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: b)),
                          ),
                        )),

                      // Book grid
                      _currentList.isEmpty
                          ? SliverFillRemaining(
                              child: _EmptyState(
                                  tab: _tabController.index, c: c))
                          : SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) => _BookTile(
                                    book: _currentList[i],
                                    showProgress: _tabController.index == 0,
                                    isSelected:
                                        _selected.contains(_currentList[i].id),
                                    onTap: () {
                                      final book = _currentList[i];
                                      if (_isSelecting) {
                                        setState(() => _selected.contains(book.id)
                                            ? _selected.remove(book.id)
                                            : _selected.add(book.id));
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                BookDetailPage(book: book)),
                                      );
                                    },
                                    onLongPress: () => setState(
                                        () => _selected.add(_currentList[i].id)),
                                  ),
                                  childCount: _currentList.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.38,
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
}

// ── Header icon button ────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}

// ── Suggestions strip ─────────────────────────────────────────────────────────

class _SuggestionsStrip extends StatelessWidget {
  const _SuggestionsStrip({
    required this.books,
    required this.loading,
    required this.genres,
    required this.onAdd,
    required this.onOpen,
  });

  final List<BookModel> books;
  final bool loading;
  final List<String> genres;
  final void Function(BookModel) onAdd;
  final void Function(BookModel) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: c.brand),
              const SizedBox(width: 6),
              Text('Suggested for you',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '· ${genres.take(2).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: loading
                ? Center(child: CircularProgressIndicator(color: c.brand))
                : books.isEmpty
                    ? Center(
                        child: Text(
                          'Explore Discover to find books in your genres',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: c.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: books.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (_, i) => _SuggestCard(
                          book: books[i],
                          onAdd: () => onAdd(books[i]),
                          onOpen: () => onOpen(books[i]),
                        ),
                      ),
          ),
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
        ],
      ),
    );
  }
}

class _SuggestCard extends StatelessWidget {
  const _SuggestCard(
      {required this.book, required this.onAdd, required this.onOpen});
  final BookModel book;
  final VoidCallback onAdd, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: 96,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 0.68,
            child: Stack(children: [
              Positioned.fill(
                child: BookCoverImage(
                  url: book.coverUrl,
                  title: book.title,
                  fillParent: true,
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: c.brand, shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded,
                        size: 16, color: c.onPrimary),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 5),
          Text(book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w500, color: c.text)),
        ]),
      ),
    );
  }
}

// ── Book tile ─────────────────────────────────────────────────────────────────

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.showProgress,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final BookModel book;
  final bool showProgress, isSelected;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pct = (book.progress * 100).round();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        AspectRatio(
          aspectRatio: 0.68,
          child: Stack(children: [
            Positioned.fill(
              child: BookCoverImage(
                url: book.coverUrl,
                title: book.title,
                fillParent: true,
              ),
            ),
            // Favourite indicator
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('favorites')
                  .doc(book.id)
                  .snapshots(),
              builder: (_, snap) {
                if (!(snap.data?.exists ?? false)) return const SizedBox();
                return Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: c.surface, shape: BoxShape.circle),
                    child: Icon(Icons.favorite_rounded,
                        color: c.error, size: 12),
                  ),
                );
              },
            ),
            // Selection overlay
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.brand, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration:
                          BoxDecoration(color: c.brand, shape: BoxShape.circle),
                      child: Icon(Icons.check,
                          size: 16, color: c.onPrimary),
                    ),
                  ),
                ),
              ),
            // Start / Stop reading button (only for "reading" books)
            if (showProgress && !isSelected)
              Positioned(
                bottom: 6,
                right: 6,
                child: ValueListenableBuilder<ActiveSession?>(
                  valueListenable: ReadingSessionService.instance.active,
                  builder: (ctx, session, _) {
                    final isThisBook = session?.bookId == book.id;
                    return GestureDetector(
                      onTap: () {
                        if (isThisBook) {
                          showStopSessionSheet(context);
                        } else {
                          if (session != null) {
                            // Different book active — ask to switch
                            showStopSessionSheet(context);
                            return;
                          }
                          ReadingSessionService.instance.start(
                            bookId: book.id,
                            bookTitle: book.title,
                            coverUrl: book.coverUrl,
                            currentPage: book.currentPage,
                            totalPages: book.totalPages,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isThisBook
                              ? c.brand
                              : c.overlay,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isThisBook
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.stop_rounded,
                                    size: 11, color: c.onPrimary),
                                const SizedBox(width: 3),
                                Text(session!.elapsedLabel,
                                    style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: c.onPrimary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                              ])
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 11, color: c.onPrimary),
                                const SizedBox(width: 2),
                                Text('Read',
                                    style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: c.onPrimary)),
                              ]),
                      ),
                    );
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        if (showProgress) ...[
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: book.progress,
                  minHeight: 3,
                  backgroundColor: c.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(c.brand),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text('$pct%',
                style: GoogleFonts.outfit(fontSize: 9, color: c.brand)),
          ]),
          const SizedBox(height: 5),
        ],
        Text(book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w500, color: c.text)),
        const SizedBox(height: 1),
        Text(book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 10, color: c.textMuted)),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab, required this.c});
  final int tab;
  final AppPalette c;

  static const _messages = [
    ('No books in progress', 'Find something in Discover and start reading'),
    ('Nothing saved yet', 'Tap + to add books you want to read'),
    ('No finished books yet', 'Complete a book to see it here'),
  ];

  @override
  Widget build(BuildContext context) {
    final (title, sub) = _messages[tab];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            child: Icon(Icons.menu_book_rounded, size: 30, color: c.brand),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.text)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.outfit(fontSize: 13, color: c.textMuted)),
        ]),
      ),
    );
  }
}
