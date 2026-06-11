import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/reading_preferences_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:booqly/services/library_service.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/theme/theme_extensions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Netflix-style onboarding after sign-up: pick genres, theme, and pace.
class ReadingPreferencesPage extends StatefulWidget {
  const ReadingPreferencesPage({super.key});

  @override
  State<ReadingPreferencesPage> createState() => _ReadingPreferencesPageState();
}

class _ReadingPreferencesPageState extends State<ReadingPreferencesPage> {
  static const _minGenres = 3;
  static const _totalSteps = 3;

  final PreferencesService _preferencesService = PreferencesService();
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  final PageController _pageController = PageController();
  final TextEditingController _searchCtrl = TextEditingController();

  PreferenceCatalog? _catalog;
  bool _loadingCatalog = true;
  bool _saving = false;
  int _step = 0;

  // Step 1: genres
  final Set<String> _selectedGenres = {};
  String _readingTheme = 'cozy_dark';
  String _readingPace = 'steady';

  // Step 2: first book
  List<BookModel> _searchResults = [];
  bool _searchLoading = false;
  BookModel? _firstBookPicked;
  bool _addingBook = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSignedIn());
  }

  void _ensureSignedIn() {
    if (FirebaseAuth.instance.currentUser != null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign up or sign in to save your preferences.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final catalog = await _preferencesService.getCatalog();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _loadingCatalog = false;
    });
  }

  bool get _canContinueGenres => _selectedGenres.length >= _minGenres;

  void _toggleGenre(String id) {
    setState(() {
      if (_selectedGenres.contains(id)) {
        _selectedGenres.remove(id);
      } else {
        _selectedGenres.add(id);
      }
    });
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    setState(() => _step = step);
  }

  String? get _userName =>
      FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;

  ReadingPreferencesModel _buildPreferences() {
    return ReadingPreferencesModel(
      preferredGenres: _selectedGenres.toList()..sort(),
      readingTheme: _readingTheme,
      readingPace: _readingPace,
      preferencesCompleted: true,
    );
  }

  Future<void> _saveAndGoHome(ReadingPreferencesModel prefs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final c = ctx.colors;
          return AlertDialog(
            backgroundColor: c.surface,
            title: Text(
              'Not signed in',
              style: GoogleFonts.outfit(color: c.text, fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Sign up or sign in first. Your choices are saved to Firestore '
              'under preferences/your-user-id.',
              style: GoogleFonts.outfit(color: c.textMuted, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.outfit(color: c.brand)),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _preferencesService.saveUserPreferences(uid, prefs);
      if (!mounted) return;

      if (!result.ok) {
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final c = ctx.colors;
            return AlertDialog(
              backgroundColor: c.surface,
              title: Text(
                'Could not save',
                style: GoogleFonts.outfit(color: c.text, fontWeight: FontWeight.w600),
              ),
              content: Text(
                result.error ??
                    'Firestore rejected the save. In Firebase Console → Firestore → Rules, '
                    'publish the rules from firestore.rules in your project folder.',
                style: GoogleFonts.outfit(color: c.textMuted, height: 1.5, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('OK', style: GoogleFonts.outfit(color: c.brand)),
                ),
              ],
            );
          },
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _searchBooks(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final all = await _bookService.getBooks();
      final q = query.toLowerCase();
      setState(() {
        _searchResults = all
            .where((b) =>
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q))
            .take(8)
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _addFirstBookAndFinish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _firstBookPicked != null) {
      setState(() => _addingBook = true);
      try {
        await _libraryService.addBook(
          bookId: _firstBookPicked!.id,
          status: 'want_to_read',
          totalPages: _firstBookPicked!.totalPages,
          title: _firstBookPicked!.title,
          author: _firstBookPicked!.author,
          coverUrl: _firstBookPicked!.coverUrl,
          category: _firstBookPicked!.category,
        );
      } catch (_) {}
      setState(() => _addingBook = false);
    }
    await _saveAndGoHome(_buildPreferences());
  }

  Future<void> _finish() async {
    if (_step < _totalSteps - 1) {
      _goToStep(_step + 1);
    } else {
      await _addFirstBookAndFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loadingCatalog
            ? Center(
                child: CircularProgressIndicator(color: c.brand),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _step = i),
                      children: [
                        _buildWelcomeStep(),
                        _buildGenresStep(),
                        _buildFirstBookStep(),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final c = context.colors;

    // Step 0 = Welcome (no step label shown, no back button)
    if (_step == 0) return const SizedBox.shrink();

    final titles = [
      '',                          // step 0: welcome (hidden header)
      'What do you love to read?', // step 1
      'Add your first book',       // step 2
    ];
    final subtitles = [
      '',
      'Pick at least $_minGenres genres — we\'ll tailor discovery for you.',
      'Search for a book to start with. You can always add more later.',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _goToStep(_step - 1),
                icon: Icon(Icons.arrow_back_rounded, color: c.textMuted),
              ),
              const Spacer(),
              Text(
                'Step $_step of ${_totalSteps - 1}',
                style: GoogleFonts.outfit(color: c.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            titles[_step],
            style: GoogleFonts.figtree(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: c.brand,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitles[_step],
            style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
          _StepIndicator(current: _step, total: _totalSteps),
        ],
      ),
    );
  }

  Widget _buildGenresStep() {
    final genres = _catalog!.genres;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 520;
        final crossCount = wide ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: wide ? 3.4 : 4.6,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genre = genres[index];
            return _GenreListTile(
              option: genre,
              selected: _selectedGenres.contains(genre.id),
              onTap: () => _toggleGenre(genre.id),
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeStep() {
    final c = context.colors;
    final name = _userName;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Book emoji in a glowing circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.brand.withValues(alpha: 0.5), width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('📚', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 32),
            Text(
              name != null && name.isNotEmpty
                  ? 'Welcome to Booqly,\n$name!'
                  : 'Welcome to Booqly!',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 42,
                fontWeight: FontWeight.w600,
                color: c.brand,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your personal reading companion.\nLet\'s set things up so every '
              'recommendation feels made just for you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: c.textMuted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 48),
            // Three feature highlights
            _WelcomeFeatureTile(
              emoji: '🎯',
              title: 'Smart Recommendations',
              subtitle: 'We pick books based on what you actually enjoy.',
            ),
            const SizedBox(height: 16),
            _WelcomeFeatureTile(
              emoji: '⏱️',
              title: 'Session Tracking',
              subtitle: 'Start a timer, log your pages, watch your progress grow.',
            ),
            const SizedBox(height: 16),
            _WelcomeFeatureTile(
              emoji: '🔔',
              title: 'Reading Nudges',
              subtitle: 'We remind you when you have free time — not at random.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstBookStep() {
    final c = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.outfit(color: c.text, fontSize: 15),
            onChanged: _searchBooks,
            decoration: InputDecoration(
              hintText: 'Search by title or author…',
              hintStyle: GoogleFonts.outfit(color: c.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
              suffixIcon: _searchLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.brand)),
                    )
                  : null,
              filled: true,
              fillColor: c.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.brand, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty && _searchCtrl.text.length < 2
              ? Center(
                  child: Text(
                    'Type a book title or author name\nto search the catalogue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: c.textMuted, fontSize: 14, height: 1.6),
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        'No results found.',
                        style: GoogleFonts.outfit(color: c.textMuted, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, i) {
                        final book = _searchResults[i];
                        final picked = _firstBookPicked?.id == book.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _firstBookPicked = picked ? null : book),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: picked ? c.brandSoft : c.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: picked ? c.brand : c.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: book.coverUrl.isNotEmpty
                                        ? Image.network(
                                            book.coverUrl,
                                            width: 46,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _BookPlaceholder(book: book),
                                          )
                                        : _BookPlaceholder(book: book),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: c.text,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          book.author,
                                          style: GoogleFonts.outfit(
                                              fontSize: 12, color: c.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: picked ? c.brand : Colors.transparent,
                                      border: Border.all(
                                        color: picked ? c.brand : c.textMuted,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: picked
                                        ? Icon(Icons.check_rounded,
                                            size: 16,
                                            color: c.onPrimary)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final c = context.colors;
    final bool enabled;
    final String label;

    switch (_step) {
      case 0: // Welcome
        enabled = true;
        label = "Let's start →";
        break;
      case 1: // Genres
        enabled = _canContinueGenres;
        label = 'Continue';
        break;
      default: // First book (step 2)
        enabled = !_saving && !_addingBook;
        label = 'Start reading';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 1)
            Text(
              '${_selectedGenres.length} selected · $_minGenres minimum',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: _canContinueGenres ? c.brand : c.textMuted,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !enabled ? null : () async => await _finish(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brand,
                disabledBackgroundColor: c.surface,
                foregroundColor: c.onPrimary,
                disabledForegroundColor: c.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: (_saving || _addingBook)
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (_step == 2) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: (_saving || _addingBook) ? null : () async {
                _firstBookPicked = null;
                await _addFirstBookAndFinish();
              },
              child: Text(
                'Skip for now',
                style: GoogleFonts.outfit(color: c.textMuted, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: active ? c.brand : c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _GenrePalette {
  final Color accent;
  final Color glow;

  const _GenrePalette(this.accent, this.glow);

  static _GenrePalette forGenre(String id) {
    return switch (id) {
      'Motivation' =>
        const _GenrePalette(Color(0xFFE8A838), Color(0xFF3D2A0A)),
      'Programming' =>
        const _GenrePalette(Color(0xFF5B8DD9), Color(0xFF152030)),
      'Finance' =>
        const _GenrePalette(Color(0xFF4CAF7A), Color(0xFF0F2218)),
      'Psychology' =>
        const _GenrePalette(Color(0xFF9B7FD4), Color(0xFF221830)),
      'Productivity' =>
        const _GenrePalette(Color(0xFFE07C4C), Color(0xFF2E1810)),
      'Philosophy' =>
        const _GenrePalette(Color(0xFF8B9EB0), Color(0xFF1A2028)),
      'Fiction' =>
        const _GenrePalette(Color(0xFFD46B8C), Color(0xFF2A1420)),
      'Science' =>
        const _GenrePalette(Color(0xFF4ECDC4), Color(0xFF102220)),
      'History' =>
        const _GenrePalette(Color(0xFFC9A86C), Color(0xFF282010)),
      _ => const _GenrePalette(Color(0xFFD4A96A), Color(0xFF2A2218)),
    };
  }
}

class _GenreListTile extends StatelessWidget {
  const _GenreListTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PreferenceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final palette = _GenrePalette.forGenre(option.id);
    final accent = palette.accent;
    final glow = palette.glow;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? glow.withValues(alpha: 0.95) : c.surfaceAlt,
            border: Border.all(
              color: selected ? accent : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    color: selected ? accent : accent.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: selected ? 0.18 : 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: 0.9),
                              accent.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          option.emoji ?? '📚',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.label,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? accent
                              : Colors.transparent,
                          border: Border.all(
                            color: selected ? accent : c.textMuted.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: c.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeatureTile extends StatelessWidget {
  const _WelcomeFeatureTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: c.textMuted,
                    height: 1.45,
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

class _BookPlaceholder extends StatelessWidget {
  const _BookPlaceholder({required this.book});
  final dynamic book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: 46,
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.book_rounded, color: c.textMuted, size: 22),
    );
  }
}

