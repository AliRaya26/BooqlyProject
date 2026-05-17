import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/models/reading_preferences_model.dart';
import 'package:booqly/services/preferences_service.dart';
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
  static const _bg = Color(0xFF0E0C0A);
  static const _gold = Color(0xFFD4A96A);
  static const _ink = Color(0xFFF5F0E8);
  static const _muted = Color(0xFF888580);
  static const _surf = Color(0xFF1A1713);
  static const _minGenres = 3;

  final PreferencesService _preferencesService = PreferencesService();
  final PageController _pageController = PageController();

  PreferenceCatalog? _catalog;
  bool _loadingCatalog = true;
  bool _saving = false;
  int _step = 0;

  final Set<String> _selectedGenres = {};
  String _readingTheme = 'cozy_dark';
  String _readingPace = 'steady';

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

  bool get _canContinueStep0 => _selectedGenres.length >= _minGenres;

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
        builder: (ctx) => AlertDialog(
          backgroundColor: _surf,
          title: Text(
            'Not signed in',
            style: GoogleFonts.outfit(color: _ink, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Sign up or sign in first. Your choices are saved to Firestore '
            'under preferences/your-user-id.',
            style: GoogleFonts.outfit(color: _muted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.outfit(color: _gold)),
            ),
          ],
        ),
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
          builder: (ctx) => AlertDialog(
            backgroundColor: _surf,
            title: Text(
              'Could not save',
              style: GoogleFonts.outfit(color: _ink, fontWeight: FontWeight.w600),
            ),
            content: Text(
              result.error ??
                  'Firestore rejected the save. In Firebase Console → Firestore → Rules, '
                  'publish the rules from firestore.rules in your project folder.',
              style: GoogleFonts.outfit(color: _muted, height: 1.5, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.outfit(color: _gold)),
              ),
            ],
          ),
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

  Future<void> _finish() async {
    await _saveAndGoHome(_buildPreferences());
  }

  Future<void> _skip() async {
    await _saveAndGoHome(
      const ReadingPreferencesModel(preferencesCompleted: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loadingCatalog
            ? const Center(
                child: CircularProgressIndicator(color: _gold),
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
                        _buildGenresStep(),
                        _buildStyleStep(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  onPressed: () => _goToStep(0),
                  icon: const Icon(Icons.arrow_back_rounded, color: _muted),
                ),
              const Spacer(),
              Text(
                'Step ${_step + 1} of 2',
                style: GoogleFonts.outfit(color: _muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _step == 0 ? 'What do you love to read?' : 'How do you like to read?',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: _gold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _step == 0
                ? 'Pick at least $_minGenres genres — we\'ll tailor discovery for you.'
                : 'Choose your reading vibe and pace. You can change these later.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _StepIndicator(current: _step),
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

  Widget _buildStyleStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        Text(
          'Reading theme',
          style: GoogleFonts.outfit(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._catalog!.readingThemes.map(
          (theme) => _OptionCard(
            option: theme,
            selected: _readingTheme == theme.id,
            onTap: () => setState(() => _readingTheme = theme.id),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Reading pace',
          style: GoogleFonts.outfit(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._catalog!.readingPaces.map(
          (pace) => _OptionCard(
            option: pace,
            selected: _readingPace == pace.id,
            onTap: () => setState(() => _readingPace = pace.id),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final onStep0 = _step == 0;
    final enabled = onStep0 ? _canContinueStep0 : !_saving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onStep0)
            Text(
              '${_selectedGenres.length} selected · $_minGenres minimum',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: _canContinueStep0 ? _gold : _muted,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !enabled
                  ? null
                  : () async {
                      if (onStep0) {
                        _goToStep(1);
                      } else {
                        await _finish();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: _surf,
                foregroundColor: _bg,
                disabledForegroundColor: _muted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _bg,
                      ),
                    )
                  : Text(
                      onStep0 ? 'Continue' : 'Start reading',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (!onStep0) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : _skip,
              child: Text(
                'Skip for now',
                style: GoogleFonts.outfit(color: _muted, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final active = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFD4A96A)
                  : const Color(0xFF2A2520),
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

  static const _ink = Color(0xFFF5F0E8);
  static const _muted = Color(0xFF888580);

  @override
  Widget build(BuildContext context) {
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
            color: selected ? glow.withValues(alpha: 0.95) : const Color(0xFF161310),
            border: Border.all(
              color: selected ? accent : const Color(0xFF2A2520),
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
                            color: _ink,
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
                            color: selected ? accent : _muted.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Color(0xFF0E0C0A),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PreferenceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF221C12)
                  : const Color(0xFF161310),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFD4A96A)
                    : const Color(0xFF2A2520),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1A16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.emoji ?? '•',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF5F0E8),
                        ),
                      ),
                      if (option.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          option.subtitle!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF888580),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0xFFD4A96A)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFD4A96A)
                          : const Color(0xFF888580),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF0E0C0A),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
