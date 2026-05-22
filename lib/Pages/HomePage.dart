import 'dart:io';

import 'package:booqly/Pages/BookChatPage.dart';
import 'package:booqly/Pages/LibraryPage.dart';
import 'package:booqly/Pages/SearchByTitlePage.dart';
import 'package:booqly/Pages/SettingsPage.dart';
import 'package:booqly/Pages/pdf_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/services/feedback_seed_service.dart';
import 'package:booqly/Pages/ManualEntryPage.dart';
import 'dart:async';

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
  final double width;
  final double height;

  const BookCover({
    super.key,
    required this.url,
    this.width = 100,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (url.trim().isEmpty) {
      child = Container(
        color: AppColors.surface,
        child: const Icon(Icons.menu_book_rounded),
      );
    } else if (url.startsWith('http')) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surface,
          child: const Icon(Icons.broken_image),
        ),
      );
    } else {
      child = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surface,
          child: const Icon(Icons.broken_image),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
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

List<WeekDay> streakWeek = [];

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
      title: 'Booqly',
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

  BookModel? continueBook;
  bool isLoadingContinue = true;

  // ── Add this at the top of _HomePageState ──
  StreamSubscription? _librarySubscription;

  @override
  void initState() {
    super.initState();
    _listenToContinueReading(); // ← stream instead of one-time fetch
    _listenToWantToRead(); // ← stream for want-to-read list as well
    _listenToStreak(); // ← load streak once on init (can be refreshed manually if needed)
    _seedDummyFeedbacks();
  }

  Future<void> _seedDummyFeedbacks() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await FeedbackSeedService().seedDummyFeedbacksIfNeeded();
    } catch (e, st) {
      debugPrint('FeedbackSeed failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _librarySubscription?.cancel();
    _wantToReadSub?.cancel();
    super.dispose();
    _streakSub?.cancel();
  }

  void _listenToContinueReading() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoadingContinue = false);
      return;
    }

    _librarySubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .where('status', isEqualTo: 'reading')
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isEmpty) {
            if (mounted) {
              setState(() {
                continueBook = null;
                isLoadingContinue = false;
              });
            }
            return;
          }

          // Sort by lastReadAt descending — most recent first
          final sorted = [...snapshot.docs]
            ..sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aTime =
                  (aData['lastReadAt'] as Timestamp?) ?? Timestamp(0, 0);
              final bTime =
                  (bData['lastReadAt'] as Timestamp?) ?? Timestamp(0, 0);
              return bTime.compareTo(aTime);
            });

          final doc = sorted.first;
          final bookId = doc.id;
          final libraryData = doc.data();

          try {
            final bookDoc = await FirebaseFirestore.instance
                .collection('books')
                .doc(bookId)
                .get();

            if (!bookDoc.exists) {
              if (mounted) {
                setState(() {
                  continueBook = null;
                  isLoadingContinue = false;
                });
              }
              return;
            }

            final bookData = bookDoc.data()!;

            if (mounted) {
              setState(() {
                continueBook = BookModel(
                  id: bookDoc.id,
                  title: bookData['title'] ?? '',
                  author: bookData['author'] ?? '',
                  description: bookData['description'] ?? '',
                  category: bookData['category'] ?? '',
                  coverUrl: bookData['coverUrl'] ?? '',
                  pdfUrl: bookData['pdfUrl'] ?? '',
                  totalPages: bookData['totalPages'] ?? 0,
                  progress: (libraryData['progress'] ?? 0).toDouble(),
                  currentPage: libraryData['currentPage'] ?? 0,
                );
                isLoadingContinue = false;
              });
            }
          } catch (e) {
            debugPrint('❌ stream book fetch error: $e');
            if (mounted) {
              setState(() {
                continueBook = null;
                isLoadingContinue = false;
              });
            }
          }
        });
  }

  List<WeekDay> _buildWeekDays(List<Timestamp> timestamps) {
    final now = DateTime.now();

    // start of week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // convert timestamps to readable days
    final readDays = timestamps.map((t) {
      final d = t.toDate();
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    List<WeekDay> result = [];

    final labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    for (int i = 0; i < 7; i++) {
      final dayDate = DateTime(monday.year, monday.month, monday.day + i);

      final normalized = DateTime(dayDate.year, dayDate.month, dayDate.day);

      DayStatus status;

      if (normalized.isAfter(DateTime(now.year, now.month, now.day))) {
        status = DayStatus.upcoming;
      } else if (readDays.contains(normalized)) {
        status = DayStatus.done;
      } else if (normalized.day == now.day &&
          normalized.month == now.month &&
          normalized.year == now.year) {
        status = DayStatus.today;
      } else {
        status = DayStatus.upcoming;
      }

      result.add(WeekDay(labels[i], status));
    }

    return result;
  }

  StreamSubscription? _streakSub;

  void _listenToStreak() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _streakSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots()
        .listen((snapshot) {
          List<Timestamp> timestamps = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['lastReadAt'] != null) {
              timestamps.add(data['lastReadAt']);
            }
          }

          if (!mounted) return;

          setState(() {
            streakWeek = _buildWeekDays(timestamps);
          });
        });
  }

  List<BookModel> wantToReadBooks = [];
  bool isLoadingWantToRead = true;
  StreamSubscription? _wantToReadSub;

  void _listenToWantToRead() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => isLoadingWantToRead = false);
      return;
    }

    _wantToReadSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .where('status', isEqualTo: 'want_to_read')
        .snapshots()
        .listen((snapshot) async {
          final futures = snapshot.docs.map((doc) async {
            final bookId = doc.id;
            final libraryData = doc.data();

            final bookDoc = await FirebaseFirestore.instance
                .collection('books')
                .doc(bookId)
                .get();

            if (!bookDoc.exists) return null;

            final bookData = bookDoc.data()!;

            return BookModel(
              id: bookDoc.id,
              title: bookData['title'] ?? '',
              author: bookData['author'] ?? '',
              description: bookData['description'] ?? '',
              category: bookData['category'] ?? '',
              coverUrl: bookData['coverUrl'] ?? '',
              pdfUrl: bookData['pdfUrl'] ?? '',
              totalPages: bookData['totalPages'] ?? 0,
              progress: (libraryData['progress'] ?? 0).toDouble().clamp(
                0.0,
                1.0,
              ),
              currentPage: libraryData['currentPage'] ?? 0,
            );
          });

          final results = await Future.wait(futures);
          final loaded = results.whereType<BookModel>().toList();

          if (mounted) {
            setState(() {
              wantToReadBooks = loaded;
              isLoadingWantToRead = false;
            });
          }
        });
  }

  // Keep _refresh for the card buttons (still useful for progress update after PdfReaderPage)
  Future<void> _refresh() async {} // stream handles updates automatically now

  // ── Fetch the most recently read "reading" book ──
  Future<void> fetchContinueReadingBook() async {
    // Reset loading so UI shows spinner on re-fetch
    if (mounted) setState(() => isLoadingContinue = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) setState(() => isLoadingContinue = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .where('status', isEqualTo: 'reading')
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            continueBook = null;
            isLoadingContinue = false;
          });
        }
        return;
      }

      // Sort manually — safe even when lastReadAt is missing
      snapshot.docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTime = (aData['lastReadAt'] as Timestamp?) ?? Timestamp(0, 0);
        final bTime = (bData['lastReadAt'] as Timestamp?) ?? Timestamp(0, 0);
        return bTime.compareTo(aTime);
      });

      final doc = snapshot.docs.first;
      final bookId = doc.id;
      final libraryData = doc.data();

      final bookDoc = await FirebaseFirestore.instance
          .collection('books')
          .doc(bookId)
          .get();

      if (!bookDoc.exists) {
        if (mounted) {
          setState(() {
            continueBook = null;
            isLoadingContinue = false;
          });
        }
        return;
      }

      final bookData = bookDoc.data()!;

      if (mounted) {
        setState(() {
          continueBook = BookModel(
            id: bookDoc.id,
            title: bookData['title'] ?? '',
            author: bookData['author'] ?? '',
            description: bookData['description'] ?? '',
            category: bookData['category'] ?? '',
            coverUrl: bookData['coverUrl'] ?? '',
            pdfUrl: bookData['pdfUrl'] ?? '',
            totalPages: bookData['totalPages'] ?? 0,
            progress: (libraryData['progress'] ?? 0).toDouble(),
            currentPage: libraryData['currentPage'] ?? 0,
          );
          isLoadingContinue = false;
        });
      }
    } catch (e) {
      debugPrint('❌ fetchContinueReadingBook error: $e');
      if (mounted) {
        setState(() {
          continueBook = null;
          isLoadingContinue = false;
        });
      }
    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   fetchContinueReadingBook();
  // }

  TextStyle get _outfit => GoogleFonts.outfit();
  TextStyle get _cormorant => GoogleFonts.cormorantGaramond();

  // ── Called after returning from any sub-page ──
  // Future<void> _refresh() => fetchContinueReadingBook();

  // ─── Page switcher ───────────────────────────────────────────────────────

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
              _ContinueReadingSection(
                cormorant: _cormorant,
                outfit: _outfit,
                book: continueBook,
                isLoading: isLoadingContinue,
                onRefresh: _refresh,
              ),
              _StreakSection(cormorant: _cormorant, outfit: _outfit),
              _WantToReadSection(
                books: wantToReadBooks,
                isLoading: isLoadingWantToRead,
                cormorant: _cormorant,
                outfit: _outfit,
              ),
              _MonthlyStatsSection(outfit: _outfit),
              const SizedBox(height: 12),
            ],
          ),
        );

      case 1:
        return const LibraryPage();
      case 2:
        return const BookChatPage();
      case 3:
        return const SettingsPage(embeddedInTab: true);
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

// ─── Add Book Bottom Sheet ────────────────────────────────────────────────────

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
          _addTile(
            context,
            icon: Icons.search_rounded,
            label: 'Search by title',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchByTitlePage()),
              );
            },
          ),
          _addTile(
            context,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan ISBN barcode',
            onTap: () => Navigator.pop(context),
          ),
          _addTile(
            context,
            icon: Icons.edit_rounded,
            label: 'Manual entry',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManualEntryPage()),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _addTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.goldMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.gold, size: 18),
    ),
    title: Text(
      label,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
    ),
    onTap: onTap,
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
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textMuted,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start),
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
    required this.book,
    required this.isLoading,
    required this.onRefresh, // ✅ callback to re-fetch after navigation
  });

  final TextStyle cormorant;
  final TextStyle outfit;
  final BookModel? book;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (book == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Continue reading'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.textMuted,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start reading a book to continue here',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Continue reading'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _ContinueReadingCard(
            cormorant: cormorant,
            outfit: outfit,
            book: book!,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.cormorant,
    required this.outfit,
    required this.book,
    required this.onRefresh,
  });

  final TextStyle cormorant;
  final TextStyle outfit;
  final BookModel book;
  final Future<void> Function() onRefresh;

  // ── Navigate to BookDetailPage and refresh on return ──
  Future<void> _openDetail(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
    );
    await onRefresh();
  }

  // ── Navigate straight to PDF reader and refresh on return ──
  Future<void> _resumeReading(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(book.id)
          .set({'lastReadAt': Timestamp.now()}, SetOptions(merge: true));
    }
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfReaderPage(book: book)),
    );
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (book.progress * 100).round();

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
                  // ✅ Tappable cover → BookDetailPage
                  GestureDetector(
                    onTap: () => _openDetail(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BookCover(
                        url: book.coverUrl,
                        width: 68,
                        height: 96,
                      ),
                    ),
                  ),

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

                        // ✅ Tappable title → BookDetailPage
                        GestureDetector(
                          onTap: () => _openDetail(context),
                          child: Text(
                            book.title,
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              color: const Color.fromARGB(173, 245, 240, 232),
                              height: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          book.author,
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
                              'p. ${book.currentPage} / ${book.totalPages}',
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
                            value: book.progress,
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

              // ✅ Resume reading → PdfReaderPage directly
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _resumeReading(context),
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
                  children: streakWeek.map((d) => _DayDot(day: d)).toList(),
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
  const _WantToReadSection({
    required this.books,
    required this.isLoading,
    required this.cormorant,
    required this.outfit,
  });

  final List<BookModel> books;
  final bool isLoading;
  final TextStyle cormorant;
  final TextStyle outfit;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (books.isEmpty) {
      return const _SectionLabel('Want to read');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Want to read'),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 22, right: 22, bottom: 4),
            itemCount: books.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final book = books[i];

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
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BookCover(
                          url: book.coverUrl,
                          width: 86,
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        book.author,
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
// ─── Data model for one week's stats ─────────────────────────────────────────

class _WeekStats {
  final String label; // W1, W2, W3, W4
  final int pages; // pages read that week
  final int sessions; // number of reading sessions
  final int booksRead; // books completed that week
  final DateTime weekStart;
  final DateTime weekEnd;

  const _WeekStats({
    required this.label,
    required this.pages,
    required this.sessions,
    required this.booksRead,
    required this.weekStart,
    required this.weekEnd,
  });
}

// ─── Monthly Stats Section ────────────────────────────────────────────────────

class _MonthlyStatsSection extends StatefulWidget {
  const _MonthlyStatsSection({required this.outfit});
  final TextStyle outfit;

  @override
  State<_MonthlyStatsSection> createState() => _MonthlyStatsSectionState();
}

class _MonthlyStatsSectionState extends State<_MonthlyStatsSection> {
  // ── State ──────────────────────────────────────────────────────────────
  bool _loading = true;
  int _totalBooks = 0;
  int _totalPages = 0;
  int _streak = 0;
  int _avgPerDay = 0;
  List<_WeekStats> _weeks = [];
  int _selectedWeek = -1; // -1 = none selected

  @override
  void initState() {
    super.initState();
    _fetchMonthlyStats();
  }

  // ── Build the 4 week buckets for the current month ──────────────────────

  List<_WeekStats> _buildWeekBuckets() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0); // last day of month

    List<_WeekStats> weeks = [];
    int weekNum = 1;
    DateTime cursor = start;

    while (cursor.isBefore(end) || cursor.isAtSameMomentAs(end)) {
      // Each bucket is 7 days, last bucket takes the rest
      final weekEnd = weekNum < 4 ? cursor.add(const Duration(days: 6)) : end;

      weeks.add(
        _WeekStats(
          label: 'W$weekNum',
          pages: 0,
          sessions: 0,
          booksRead: 0,
          weekStart: cursor,
          weekEnd: weekEnd,
        ),
      );

      cursor = weekEnd.add(const Duration(days: 1));
      weekNum++;
      if (weekNum > 4) break;
    }

    return weeks;
  }

  // ── Fetch real data from Firestore ──────────────────────────────────────

  Future<void> _fetchMonthlyStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    try {
      // Build empty week buckets
      final buckets = _buildWeekBuckets();

      // ── Reading sessions this month ──
      // Each time the user changes page, a session is logged in readingSessions
      // If you don't have that collection yet, we read from library lastReadAt
      // and currentPage changes — using the library docs as approximation

      final librarySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .get();

      int totalPages = 0;
      int totalBooks = 0;

      // ── Reading sessions (if you have this collection) ──
      QuerySnapshot? sessionSnap;
      try {
        sessionSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('readingSessions')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
            .get();
      } catch (_) {
        sessionSnap = null; // collection doesn't exist yet
      }

      // ── Count pages per week from sessions ──
      final weekPages = List<int>.filled(buckets.length, 0);
      final weekSessions = List<int>.filled(buckets.length, 0);

      if (sessionSnap != null && sessionSnap.docs.isNotEmpty) {
        for (final doc in sessionSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pages = (data['pagesRead'] ?? 0) as int;
          final date = (data['date'] as Timestamp).toDate();
          totalPages += pages;

          for (int i = 0; i < buckets.length; i++) {
            if (!date.isBefore(buckets[i].weekStart) &&
                !date.isAfter(buckets[i].weekEnd)) {
              weekPages[i] += pages;
              weekSessions[i] += 1;
              break;
            }
          }
        }
      } else {
        // Fallback: use currentPage from library docs as total pages
        for (final doc in librarySnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalPages += (data['currentPage'] ?? 0) as int;

          // Assign to the week based on lastReadAt
          final lastRead = data['lastReadAt'] as Timestamp?;
          if (lastRead != null) {
            final date = lastRead.toDate();
            if (!date.isBefore(monthStart) && !date.isAfter(monthEnd)) {
              for (int i = 0; i < buckets.length; i++) {
                if (!date.isBefore(buckets[i].weekStart) &&
                    !date.isAfter(buckets[i].weekEnd)) {
                  weekPages[i] += (data['currentPage'] ?? 0) as int;
                  weekSessions[i] += 1;
                  break;
                }
              }
            }
          }
        }
      }

      // ── Count completed books this month ──
      final weekBooks = List<int>.filled(buckets.length, 0);
      for (final doc in librarySnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'completed') {
          totalBooks++;
          final completedAt = data['completedAt'] as Timestamp?;
          if (completedAt != null) {
            final date = completedAt.toDate();
            if (!date.isBefore(monthStart) && !date.isAfter(monthEnd)) {
              for (int i = 0; i < buckets.length; i++) {
                if (!date.isBefore(buckets[i].weekStart) &&
                    !date.isAfter(buckets[i].weekEnd)) {
                  weekBooks[i] += 1;
                  break;
                }
              }
            }
          }
        }
      }

      // Calculate streak from library lastReadAt timestamps
      final Set<String> readDays = {};
      for (final doc in librarySnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lastRead = data['lastReadAt'] as Timestamp?;
        if (lastRead != null) {
          final d = lastRead.toDate();
          readDays.add('${d.year}-${d.month}-${d.day}');
        }
      }

      // Count consecutive days going backwards from today
      int streak = 0;
      final now = DateTime.now();
      for (int i = 0; i < 365; i++) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year}-${day.month}-${day.day}';
        if (readDays.contains(key)) {
          streak++;
        } else {
          break; // streak broken
        }
      }

      // ── Build final week list ──
      final finalWeeks = List.generate(
        buckets.length,
        (i) => _WeekStats(
          label: buckets[i].label,
          pages: weekPages[i],
          sessions: weekSessions[i],
          booksRead: weekBooks[i],
          weekStart: buckets[i].weekStart,
          weekEnd: buckets[i].weekEnd,
        ),
      );

      // ── Totals ──
      final daysInMonth = monthEnd.day;
      final avgPerDay = daysInMonth > 0 ? totalPages ~/ daysInMonth : 0;
      // Approx hours: ~40 pages per hour
      final totalHours = (totalPages / 40).round();

      if (mounted) {
        setState(() {
          _weeks = finalWeeks;
          _totalPages = totalPages;
          _totalBooks = totalBooks;
          _streak = streak;
          _avgPerDay = avgPerDay;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Monthly stats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) => '${d.day}/${d.month}';

  double _maxPages() {
    if (_weeks.isEmpty) return 1;
    final m = _weeks.map((w) => w.pages).reduce((a, b) => a > b ? a : b);
    return m == 0 ? 1 : m.toDouble();
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('This month'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top stat row ──
                      Row(
                        children: [
                          _StatTile(value: '$_totalBooks', label: 'Books'),
                          _vDivider(),
                          _StatTile(value: '$_totalPages', label: 'Pages'),
                          _vDivider(),
                          _StatTile(value: '${_streak}d', label: 'Streak'),
                          _vDivider(),
                          _StatTile(value: '$_avgPerDay p.', label: 'Avg/day'),
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

                      // ── Bar chart ──
                      SizedBox(
                        height: 96,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(_weeks.length, (i) {
                            final w = _weeks[i];
                            final maxP = _maxPages();
                            final frac = w.pages / maxP;
                            final isTop =
                                w.pages == maxP.round() && w.pages > 0;
                            final isSel = _selectedWeek == i;

                            return _Bar(
                              fraction: frac,
                              label: w.label,
                              highlight: isTop,
                              selected: isSel,
                              onTap: () => setState(() {
                                _selectedWeek = isSel ? -1 : i;
                              }),
                            );
                          }),
                        ),
                      ),

                      // ── Week detail popup ──
                      if (_selectedWeek >= 0 &&
                          _selectedWeek < _weeks.length) ...[
                        const SizedBox(height: 14),
                        _buildWeekDetail(_weeks[_selectedWeek]),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.border,
  );

  // ── Expanded week detail card ────────────────────────────────────────────

  Widget _buildWeekDetail(_WeekStats w) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${w.label}  ·  ${_formatDate(w.weekStart)} – ${_formatDate(w.weekEnd)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedWeek = -1),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats
          Row(
            children: [
              _detailStat('${w.pages}', 'Pages read'),
              const SizedBox(width: 16),
              _detailStat('${w.sessions}', 'Sessions'),
              const SizedBox(width: 16),
              _detailStat('${w.booksRead}', 'Books done'),
            ],
          ),
          // Empty hint
          if (w.pages == 0) ...[
            const SizedBox(height: 8),
            Text(
              'No reading recorded this week.',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ─── Stat tile ────────────────────────────────────────────────────────────────

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
              fontSize: 16,
              fontWeight: FontWeight.w500,
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

// ─── Bar ─────────────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.label,
    required this.highlight,
    required this.selected,
    required this.onTap,
  });

  final double fraction;
  final String label;
  final bool highlight;
  final bool selected;
  final VoidCallback onTap;

  static const _maxBarH = 52.0;

  @override
  Widget build(BuildContext context) {
    final barColor = selected
        ? AppColors.gold
        : highlight
        ? AppColors.gold
        : AppColors.goldMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Badge row
              SizedBox(
                height: 18,
                child: highlight
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
              // Bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: fraction == 0 ? 4 : _maxBarH * fraction,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                  border: highlight || selected
                      ? null
                      : Border.all(color: AppColors.goldDim),
                  // Selected glow
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              // Label
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: selected ? AppColors.gold : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
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
            icon: Icons.chat_rounded,
            label: 'Ask AI',
            index: 2,
            selected: selectedIndex,
            onTap: onTap,
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            index: 3,
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
                color: AppColors.gold.withValues(alpha: 0.3),
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
