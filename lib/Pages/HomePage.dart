import 'package:booqly/Pages/LibraryPage.dart';
import 'package:booqly/Pages/SearchByTitlePage.dart';
import 'package:booqly/Pages/SignupPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Theme ───────────────────────────────────────────────────────────────────

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
  Book(
    title: 'Deep Work',
    author: 'Cal Newport',
    coverBg: AppColors.coverAmber,
    spineColor: AppColors.spineAmber,
  ),
  Book(
    title: 'Thinking, Fast & Slow',
    author: 'Kahneman',
    coverBg: AppColors.coverBlue,
    spineColor: AppColors.spineBlue,
  ),
  Book(
    title: 'Sapiens',
    author: 'Yuval Noah Harari',
    coverBg: AppColors.coverPurple,
    spineColor: AppColors.spinePurple,
  ),
  Book(
    title: 'The Power of Now',
    author: 'Eckhart Tolle',
    coverBg: AppColors.coverGreen,
    spineColor: AppColors.spineGreen,
  ),
  Book(
    title: 'Sapiens',
    author: 'Yuval Noah Harari',
    coverBg: AppColors.coverPurple,
    spineColor: AppColors.spinePurple,
  ),
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
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

  Widget _buildPageContent() {
    switch (_navIndex) {
      case 0:
        return SingleChildScrollView(
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
              _MonthlyStatsSection(outfit: _outfit),
              // _AddBookSection(outfit: _outfit),
              const SizedBox(height: 12),
            ],
          ),
        );
      case 1:
        return const LibraryPage();
      case 2:
        return Center(
          child: Text(
            'Explore',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),
        );
      case 3:
        return Center(
          child: Text(
            'Profile',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          _buildPageContent(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomNav(
              selectedIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
              outfit: _outfit,
              onAddTap: () => _showAddBottomSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}


// note: The function to show the bottom sheet when the user click on the add book section, it will show the options to add a book, the user can choose to search by title, scan ISBN or manual entry
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add a book',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search_rounded, color: AppColors.gold, size: 18),
              ),
              title: Text(
                'Search by title',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchByTitlePage()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.gold, size: 18),
              ),
              title: Text(
                'Scan ISBN barcode',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to scan ISBN page
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_rounded, color: AppColors.gold, size: 18),
              ),
              title: Text(
                'Manual entry',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to manual entry page
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 12,
        22,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Booqly',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
              letterSpacing: 0.05,
            ),
          ),
          Container(
            width: 34,
            height: 34,
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
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // children: [
        //   Text(
        //     'YOUR READING SPACE',
        //     style: GoogleFonts.outfit(
        //       fontSize: 11,
        //       letterSpacing: 0.15,
        //       color: AppColors.gold,
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        //   const SizedBox(height: 6),
        //   RichText(
        //     text: TextSpan(
        //       style: GoogleFonts.cormorantGaramond(
        //         fontSize: 34,
        //         fontWeight: FontWeight.w600,
        //         color: AppColors.textPrimary,
        //         height: 1.1,
        //       ),
        //       children: const [
        //         TextSpan(text: 'Good\u00a0morning,\n'),
        //         TextSpan(
        //           text: 'Lara.',
        //           style: TextStyle(
        //             fontStyle: FontStyle.italic,
        //             color: AppColors.gold,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ],
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
  const _ContinueReadingSection({
    required this.cormorant,
    required this.outfit,
  });
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
            top: -40,
            right: -40,
            child: Container(
              width: 130,
              height: 130,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
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
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            // fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(173, 245, 240, 232),
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
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.gold,
                            ),
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

// note: will be replaced by the image of the book entered by the user when they add the book or fetched it from the
// database

class _BookSpine extends StatelessWidget {
  const _BookSpine({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 96,
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
                        color: const Color.fromARGB(173, 245, 240, 232),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '7 days',
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
        inner = Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
        );
        break;
      case DayStatus.upcoming:
        bg = const Color(0x0DFFFFFF);
        border = null;
        inner = Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0x26FFFFFF),
            shape: BoxShape.circle,
          ),
        );
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
          width: 32,
          height: 32,
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
                onTap: () {
                  // note: do not forget to change to InfoPage, when the user click on the book, it will navigate to the book details page where they can see more information about the book and add it to their library if they want to read it later
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupPage()),
                  );
                },
                child: SizedBox(
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 86,
                        height: 120,
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

// ─── Monthly Statistics ───────────────────────────────────────────────────────

class _MonthlyStatsSection extends StatelessWidget {
  const _MonthlyStatsSection({required this.outfit});
  final TextStyle outfit;

  static const _weekBars   = [0.55, 0.80, 0.45, 0.95];
  static const _weekLabels = ['W1', 'W2', 'W3', 'W4'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // same padding as every other _SectionLabel in the file
        const _SectionLabel('This month'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            // extra bottom padding so the "Best" badge never clips
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Stat row ──
                Row(
                  children: [
                    _StatTile(value: '4',     label: 'Books'),
                    _vDivider(),
                    _StatTile(value: '1240',  label: 'Pages'),
                    _vDivider(),
                    _StatTile(value: '18h',   label: 'Hours'),
                    _vDivider(),
                    _StatTile(value: '42 p.', label: 'Avg/day'),
                  ],
                ),

                const SizedBox(height: 20),

                Text(
                  'Pages per week',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 0.05,
                  ),
                ),

                const SizedBox(height: 12),

                // Fixed height that fits badge (18) + gap (6) + bar + gap (6) + label (14)
                SizedBox(
                  height: 96,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_weekBars.length, (i) {
                      final isTop = _weekBars[i] ==
                          _weekBars.reduce((a, b) => a > b ? a : b);
                      return _Bar(
                        fraction: _weekBars[i],
                        label: _weekLabels[i],
                        highlight: isTop,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.border,
  );
}

// ── Single stat tile ──
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppColors.gold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Single bar ──
class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.label,
    required this.highlight,
  });
  final double fraction;
  final String label;
  final bool highlight;

  // max bar height = 96 total - 18 badge - 6 gap - 6 gap - 14 label = 52
  static const _maxBarH = 52.0;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Badge row: always 18px tall so columns stay aligned
            SizedBox(
              height: 18,
              child: highlight
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Best',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bg,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 6),
            Container(
              height: _maxBarH * fraction,
              decoration: BoxDecoration(
                color: highlight ? AppColors.gold : AppColors.goldMuted,
                borderRadius: BorderRadius.circular(6),
                border: highlight ? null : Border.all(color: AppColors.goldDim),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Bottom Navigation ────────────────────────────────────────────────────────
// Replace your existing _BottomNav widget with this one

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.outfit,
    required this.onAddTap,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final TextStyle outfit;
  final VoidCallback onAddTap;

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
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            index: 0,
            selected: selectedIndex,
            onTap: onTap,
          ),

          _NavItem(
            icon: Icons.menu_book_rounded,
            label: 'Library',
            index: 1,
            selected: selectedIndex,
            onTap: onTap,
          ),

          _NavFab(onTap: onAddTap),

          _NavItem(
            icon: Icons.explore_rounded,
            label: 'Explore',
            index: 3,
            selected: selectedIndex,
            onTap: onTap,
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            index: 4,
            selected: selectedIndex,
            onTap: onTap,
          ),
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
              width: 4,
              height: 4,
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
        offset: const Offset(0, -8),
        child: Container(
          width: 50,
          height: 50,
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
