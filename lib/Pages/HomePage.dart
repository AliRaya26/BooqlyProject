import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Theme ───────────────────────────────────────────────────────────────────

class AppColors {
  static const bg         = Color(0xFF0E0C0A);
  static const surface    = Color(0xFF1A1713);
  static const navBar     = Color(0xFF141210);
  static const gold       = Color(0xFFD4A96A);
  static const goldMuted  = Color(0x1FD4A96A);
  static const goldDim    = Color(0x4DD4A96A);
  static const textPrimary   = Color(0xFFF5F0E8);
  static const textSecondary = Color(0x80FFFFFF);
  static const textMuted     = Color(0x4DFFFFFF);
  static const border     = Color(0x0FFFFFFF);
  static const borderDash = Color(0x4DD4A96A);
  static const dayDone    = gold;
  static const chipBorder = Color(0x1FFFFFFF);

  // Book cover accents
  static const coverAmber  = Color(0xFF2C1F0E);
  static const coverBlue   = Color(0xFF151C24);
  static const coverPurple = Color(0xFF1A1424);
  static const coverGreen  = Color(0xFF0F1F18);

  static const spineAmber  = Color(0xFFD4A96A);
  static const spineBlue   = Color(0xFF5B8DD9);
  static const spinePurple = Color(0xFF9B7FD4);
  static const spineGreen  = Color(0xFF4A9E7A);
}

// ─── Models ──────────────────────────────────────────────────────────────────

class Book {
  final String title;
  final String author;
  final Color coverBg;
  final Color spineColor;
  final int currentPage;
  final int totalPages;

  const Book({
    required this.title,
    required this.author,
    required this.coverBg,
    required this.spineColor,
    this.currentPage = 0,
    this.totalPages = 300,
  });

  double get progress => totalPages > 0 ? currentPage / totalPages : 0;
}

enum DayStatus { done, today, upcoming }

class WeekDay {
  final String label;
  final DayStatus status;
  const WeekDay(this.label, this.status);
}

// ─── Sample Data ─────────────────────────────────────────────────────────────

const currentBook = Book(
  title: 'Atomic Habits',
  author: 'James Clear',
  coverBg: AppColors.coverAmber,
  spineColor: AppColors.spineAmber,
  currentPage: 214,
  totalPages: 319,
);

const wantToRead = [
  Book(title: 'Deep Work',           author: 'Cal Newport',      coverBg: AppColors.coverAmber,  spineColor: AppColors.spineAmber),
  Book(title: 'Thinking, Fast & Slow', author: 'Kahneman',       coverBg: AppColors.coverBlue,   spineColor: AppColors.spineBlue),
  Book(title: 'Sapiens',             author: 'Yuval Noah Harari', coverBg: AppColors.coverPurple, spineColor: AppColors.spinePurple),
  Book(title: 'The Power of Now',    author: 'Eckhart Tolle',    coverBg: AppColors.coverGreen,  spineColor: AppColors.spineGreen),
];

const weekDays = [
  WeekDay('Mo', DayStatus.done),
  WeekDay('Tu', DayStatus.done),
  WeekDay('We', DayStatus.done),
  WeekDay('Th', DayStatus.done),
  WeekDay('Fr', DayStatus.today),
  WeekDay('Sa', DayStatus.upcoming),
  WeekDay('Su', DayStatus.upcoming),
];

// ─── App Root ─────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ReadlyApp());
}

class ReadlyApp extends StatelessWidget {
  const ReadlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Readly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(primary: AppColors.gold),
      ),
      home: const HomePage(),
    );
  }
}

// ─── Home Page ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;

  TextStyle get _outfit => GoogleFonts.outfit();
  TextStyle get _cormorant => GoogleFonts.cormorantGaramond();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(),
                _HeroGreeting(cormorant: _cormorant, outfit: _outfit),
                const _Divider(),
                _ContinueReadingSection(cormorant: _cormorant, outfit: _outfit),
                _StreakSection(cormorant: _cormorant, outfit: _outfit),
                _WantToReadSection(cormorant: _cormorant, outfit: _outfit),
                _AddBookSection(outfit: _outfit),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomNav(
              selectedIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
              outfit: _outfit,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 12, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
              letterSpacing: 0.05,
            ),
          ),
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'L',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.bg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Greeting ────────────────────────────────────────────────────────────

class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.cormorant, required this.outfit});
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR READING SPACE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              letterSpacing: 0.15,
              color: AppColors.gold,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.cormorantGaramond(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
              children: const [
                TextSpan(text: 'Good\u00a0morning,\n'),
                TextSpan(
                  text: 'Lara.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
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

// ─── Divider ─────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.fromLTRB(22, 22, 22, 0),
    color: AppColors.border,
  );
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10,
        letterSpacing: 0.14,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// ─── Continue Reading ─────────────────────────────────────────────────────────

class _ContinueReadingSection extends StatelessWidget {
  const _ContinueReadingSection({required this.cormorant, required this.outfit});
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Continue reading'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _ContinueReadingCard(cormorant: cormorant, outfit: outfit),
        ),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.cormorant, required this.outfit});
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    final pct = (currentBook.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Decorative orb
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 130, height: 130,
              decoration: const BoxDecoration(
                color: AppColors.goldMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BookSpine(book: currentBook),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.goldMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'In progress',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              letterSpacing: 0.10,
                              color: AppColors.gold,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentBook.title,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentBook.author,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'p. ${currentBook.currentPage} / ${currentBook.totalPages}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.gold,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: currentBook.progress,
                            minHeight: 3,
                            backgroundColor: const Color(0x14FFFFFF),
                            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Resume reading',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bg,
                        letterSpacing: 0.02,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookSpine extends StatelessWidget {
  const _BookSpine({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68, height: 96,
      decoration: BoxDecoration(
        color: book.coverBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Container(
            width: 7,
            decoration: BoxDecoration(
              color: book.spineColor.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: book.spineColor.withOpacity(0.8),
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reading Streak ───────────────────────────────────────────────────────────

class _StreakSection extends StatelessWidget {
  const _StreakSection({required this.cormorant, required this.outfit});
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Reading streak'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'This week',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔥 7 days',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekDays.map((d) => _DayDot(day: d)).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});
  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    Color bg;
    Border? border;

    switch (day.status) {
      case DayStatus.done:
        bg = AppColors.gold;
        border = null;
        inner = const Icon(Icons.check, size: 14, color: AppColors.bg);
        break;
      case DayStatus.today:
        bg = Colors.transparent;
        border = Border.all(color: AppColors.gold, width: 2);
        inner = Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle));
        break;
      case DayStatus.upcoming:
        bg = const Color(0x0DFFFFFF);
        border = null;
        inner = Container(width: 5, height: 5,
          decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle));
        break;
    }

    return Column(
      children: [
        Text(
          day.label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppColors.textMuted,
            letterSpacing: 0.05,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: inner,
        ),
      ],
    );
  }
}

// ─── Want to Read ─────────────────────────────────────────────────────────────

class _WantToReadSection extends StatelessWidget {
  const _WantToReadSection({required this.cormorant, required this.outfit});
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Want to read'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 22, right: 22, bottom: 4),
            itemCount: wantToRead.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final book = wantToRead[i];
              return GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 86, height: 120,
                        decoration: BoxDecoration(
                          color: book.coverBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: book.spineColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  book.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
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
            },
          ),
        ),
      ],
    );
  }
}

// ─── Add a Book ───────────────────────────────────────────────────────────────

class _AddBookSection extends StatelessWidget {
  const _AddBookSection({required this.outfit});
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: GestureDetector(
        onTap: () => _showAddBottomSheet(context),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.goldMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.goldDim, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldDim),
                ),
                child: const Icon(Icons.add, color: AppColors.gold, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                'Add a book',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search online or add manually',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: ['Search by title', 'Scan ISBN', 'Manual entry']
                    .map((label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.chipBorder),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add a book',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...[
              ('Search by title', Icons.search_rounded),
              ('Scan ISBN barcode', Icons.qr_code_scanner_rounded),
              ('Manual entry', Icons.edit_rounded),
            ].map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.$2, color: AppColors.gold, size: 18),
              ),
              title: Text(
                item.$1,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.pop(context),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.outfit,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.menu_book_rounded, label: 'Library', index: 1, selected: selectedIndex, onTap: onTap),
          _NavFab(onTap: () {}),
          _NavItem(icon: Icons.explore_rounded, label: 'Explore', index: 3, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 4, selected: selectedIndex, onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onTap;

  bool get isActive => index == selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isActive ? AppColors.gold : AppColors.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              letterSpacing: 0.05,
              color: isActive ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 3),
            Container(
              width: 4, height: 4,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavFab extends StatelessWidget {
  const _NavFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: AppColors.bg, size: 26),
        ),
      ),
    );
  }
}