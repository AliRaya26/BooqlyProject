import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:booqly/services/reading_session_service.dart';
import 'package:booqly/Pages/BookChatPage.dart';
import 'package:booqly/Pages/DiscoverPage.dart';
import 'package:booqly/Pages/FriendsPage.dart';
import 'package:booqly/Pages/GoalsPage.dart';
import 'package:booqly/Pages/LibraryPage.dart';
import 'package:booqly/services/goals_service.dart';
import 'package:booqly/models/reading_goal_model.dart';
import 'package:booqly/Pages/SearchByTitlePage.dart' hide AppColors;
import 'package:booqly/Pages/SettingsPage.dart';
import 'package:booqly/Pages/pdf_reader_page.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/services/feedback_seed_service.dart';
import 'package:booqly/Pages/ManualEntryPage.dart';
import 'dart:async';

// ─── Book cover widget ────────────────────────────────────────────────────────

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

    final c = AppColors.of(context);
    if (url.trim().isEmpty) {
      child = Container(
        color: c.surfaceAlt,
        child: Icon(Icons.menu_book_rounded, color: c.textMuted),
      );
    } else if (url.startsWith('http')) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: c.surfaceAlt,
          child: Icon(Icons.broken_image, color: c.textMuted),
        ),
      );
    } else if (kIsWeb) {
      child = Container(
        color: c.surfaceAlt,
        child: Center(
          child: Icon(Icons.image_not_supported_rounded, color: c.textMuted),
        ),
      );
    } else {
      child = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
          color: c.surfaceAlt,
          child: Icon(Icons.broken_image, color: c.textMuted),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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

  StreamSubscription? _librarySubscription;

  @override
  void initState() {
    super.initState();
    _listenToContinueReading();
    _listenToWantToRead();
    _listenToStreak();
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
    _streakSub?.cancel();
    super.dispose();
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
            debugPrint('stream book fetch error: $e');
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
    final monday = now.subtract(Duration(days: now.weekday - 1));
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
  int _streakCount = 0;

  void _listenToStreak() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _streakSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots()
        .listen((snapshot) {
          final List<Timestamp> timestamps = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['lastReadAt'] != null) {
              timestamps.add(data['lastReadAt'] as Timestamp);
            }
          }

          final readDays = timestamps.map((t) {
            final d = t.toDate();
            return DateTime(d.year, d.month, d.day);
          }).toSet();

          final today = DateTime.now();
          int streak = 0;
          for (int i = 0; i < 365; i++) {
            final day = today.subtract(Duration(days: i));
            if (readDays.contains(DateTime(day.year, day.month, day.day))) {
              streak++;
            } else {
              break;
            }
          }

          if (!mounted) return;

          setState(() {
            streakWeek = _buildWeekDays(timestamps);
            _streakCount = streak;
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
              progress: (libraryData['progress'] ?? 0).toDouble().clamp(0.0, 1.0),
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

  Future<void> _refresh() async {}

  Widget _buildPageContent() {
    switch (_navIndex) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(),
              const SizedBox(height: 12),
              ActiveSessionBanner(),
              const SizedBox(height: 8),
              _ContinueReadingSection(
                book: continueBook,
                isLoading: isLoadingContinue,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 28),
              _StreakSection(streakCount: _streakCount),
              const SizedBox(height: 28),
              _GoalProgressSection(),
              const SizedBox(height: 28),
              _WantToReadSection(
                books: wantToReadBooks,
                isLoading: isLoadingWantToRead,
              ),
              const SizedBox(height: 28),
              _MonthlyStatsSection(),
              const SizedBox(height: 12),
            ],
          ),
        );

      case 1:
        return const DiscoverPage();
      case 2:
        return const LibraryPage();
      case 3:
        return const FriendsPage();
      case 4:
        return const SettingsPage(embeddedInTab: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      // FAB only on the Library tab (index 2)
      floatingActionButton: _navIndex == 2
          ? FloatingActionButton(
              onPressed: () => _showAddBottomSheet(context),
              backgroundColor: c.brand,
              elevation: 3,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
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
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Book Bottom Sheet ────────────────────────────────────────────────────

void _showAddBottomSheet(BuildContext context) {
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final cc = AppColors.of(ctx);
      return Padding(
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
                  color: cc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add a book',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: cc.text)),
            const SizedBox(height: 16),
            _addTile(ctx, icon: Icons.search_rounded, label: 'Search by title',
                onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchByTitlePage()));
            }),
            _addTile(ctx,
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan ISBN barcode', onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: cc.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                content: Text('ISBN scanning coming soon',
                    style: GoogleFonts.outfit(color: cc.text)),
                duration: const Duration(seconds: 2),
              ));
            }),
            _addTile(ctx, icon: Icons.edit_rounded, label: 'Manual entry',
                onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManualEntryPage()));
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Widget _addTile(BuildContext context,
    {required IconData icon,
    required String label,
    required VoidCallback onTap}) {
  final c = AppColors.of(context);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 40,
      height: 40,
      decoration:
          BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: c.brand, size: 18),
    ),
    title: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: c.text)),
    onTap: onTap,
  );
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting,
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w600, color: c.text)),
            Text('Keep reading',
                style: GoogleFonts.outfit(fontSize: 13, color: c.textSub)),
          ]),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  boxShadow: cardShadow(context)),
              child: Icon(Icons.settings_outlined, color: c.textSub, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
            fontSize: 11,
            letterSpacing: 0.08,
            color: c.textMuted,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Continue Reading ─────────────────────────────────────────────────────────

class _ContinueReadingSection extends StatelessWidget {
  const _ContinueReadingSection({
    required this.book,
    required this.isLoading,
    required this.onRefresh,
  });

  final BookModel? book;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (isLoading) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(30),
              child: CircularProgressIndicator(color: c.brand)));
    }

    if (book == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel('Continue reading'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: cardShadow(context)),
            child: Center(
              child: Column(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                  child: Icon(Icons.menu_book_rounded, color: c.brand, size: 24),
                ),
                const SizedBox(height: 12),
                Text('Pick a book to start',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: c.textSub, fontSize: 14)),
              ]),
            ),
          ),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Continue reading'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ContinueReadingCard(book: book!, onRefresh: onRefresh),
        ),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.book,
    required this.onRefresh,
  });

  final BookModel book;
  final Future<void> Function() onRefresh;

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
    );
    await onRefresh();
  }

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
    final c = AppColors.of(context);
    final pct = (book.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
              onTap: () => _openDetail(context),
              child: BookCover(url: book.coverUrl, width: 64, height: 92)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: c.brandSoft, borderRadius: BorderRadius.circular(100)),
                child: Text('IN PROGRESS',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        letterSpacing: 0.10,
                        color: c.brand,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openDetail(context),
                child: Text(book.title,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2)),
              ),
              const SizedBox(height: 3),
              Text(book.author,
                  style: GoogleFonts.outfit(fontSize: 12, color: c.textSub)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: book.progress,
                  minHeight: 4,
                  backgroundColor: c.brandMid,
                  valueColor: AlwaysStoppedAnimation(c.brand),
                ),
              ),
              const SizedBox(height: 6),
              Text('p.${book.currentPage} / ${book.totalPages} · $pct%',
                  style: GoogleFonts.outfit(fontSize: 11, color: c.textSub)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        ValueListenableBuilder<ActiveSession?>(
          valueListenable: ReadingSessionService.instance.active,
          builder: (context, session, _) {
            final isActive = session?.bookId == book.id;
            return SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (isActive) {
                    showStopSessionSheet(context);
                  } else {
                    ReadingSessionService.instance.start(
                      bookId: book.id,
                      bookTitle: book.title,
                      coverUrl: book.coverUrl,
                      currentPage: book.currentPage,
                      totalPages: book.totalPages,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? c.red : c.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive
                          ? 'Stop  ·  ${session!.elapsedLabel}'
                          : 'Start Reading',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: isActive
                              ? const [FontFeature.tabularFigures()]
                              : null),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// ─── Reading Streak ───────────────────────────────────────────────────────────

// ─── Goal progress section ────────────────────────────────────────────────────

class _GoalProgressSection extends StatelessWidget {
  const _GoalProgressSection();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<GoalProgress>(
      future: GoalsService().getProgress(),
      builder: (context, snap) {
        final progress = snap.data;
        if (progress == null || !progress.goal.hasAnyGoal) {
          // Show a subtle "Set a goal" prompt
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GoalsPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(children: [
                  Icon(Icons.flag_rounded, color: c.brand, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Set a reading goal for ${DateTime.now().year}',
                      style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted))),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
                ]),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GoalsPage())),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.flag_rounded, color: c.brand, size: 18),
                  const SizedBox(width: 8),
                  Text('Reading Goals', style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w700, color: c.text,
                      letterSpacing: 0.3)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  if (progress.goal.hasYearlyGoal)
                    Expanded(child: _GoalRing(
                      progress: progress.yearlyProgress,
                      current: progress.booksCompletedThisYear,
                      goal: progress.goal.yearlyBookGoal,
                      label: 'books this year',
                      c: c,
                    )),
                  if (progress.goal.hasYearlyGoal && progress.goal.hasDailyGoal)
                    const SizedBox(width: 16),
                  if (progress.goal.hasDailyGoal)
                    Expanded(child: _GoalRing(
                      progress: progress.dailyProgress,
                      current: progress.pagesReadToday,
                      goal: progress.goal.dailyPageGoal,
                      label: 'pages today',
                      c: c,
                    )),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.progress,
    required this.current,
    required this.goal,
    required this.label,
    required this.c,
  });
  final double progress;
  final int current, goal;
  final String label;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 52, height: 52,
        child: CustomPaint(
          painter: _RingPainter(progress: progress, color: c.brand,
              trackColor: c.brandSoft),
          child: Center(child: Text(
            '${(progress * 100).round()}%',
            style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700, color: c.brand),
          )),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$current / $goal',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
      ])),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.trackColor});
  final double progress;
  final Color color, trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - 7) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    const startAngle = -1.5708; // -π/2
    canvas.drawCircle(Offset(cx, cy), r, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        6.2832 * progress.clamp(0, 1),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Streak section ───────────────────────────────────────────────────────────

class _StreakSection extends StatelessWidget {
  const _StreakSection({required this.streakCount});
  final int streakCount;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final streakLabel = streakCount == 0
        ? 'Start reading!'
        : '$streakCount day${streakCount == 1 ? '' : 's'} 🔥';
    final badgeColor = streakCount == 0 ? c.surfaceAlt : c.brandSoft;
    final badgeTextColor = streakCount == 0 ? c.textMuted : c.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('This week'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardShadow(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: streakWeek.map((d) => _DayDot(day: d)).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    streakLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor,
                    ),
                  ),
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
    final c = AppColors.of(context);
    Widget inner;
    Color bg;
    Border? border;

    switch (day.status) {
      case DayStatus.done:
        bg = c.brand;
        border = null;
        inner = const Icon(Icons.check, size: 14, color: Colors.white);
      case DayStatus.today:
        bg = Colors.transparent;
        border = Border.all(color: c.brand, width: 2);
        inner = Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle));
      case DayStatus.upcoming:
        bg = c.surfaceAlt;
        border = null;
        inner = Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: c.textMuted, shape: BoxShape.circle));
    }

    return Column(children: [
      Text(day.label,
          style: GoogleFonts.outfit(fontSize: 10, color: c.textMuted)),
      const SizedBox(height: 6),
      Container(
        width: 32,
        height: 32,
        decoration:
            BoxDecoration(color: bg, shape: BoxShape.circle, border: border),
        alignment: Alignment.center,
        child: inner,
      ),
    ]);
  }
}

// ─── Want to Read ─────────────────────────────────────────────────────────────

class _WantToReadSection extends StatelessWidget {
  const _WantToReadSection({
    required this.books,
    required this.isLoading,
  });

  final List<BookModel> books;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (isLoading) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: c.brand)));
    }

    if (books.isEmpty) return const _SectionLabel('Want to read');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('Want to read'),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final book = books[i];
            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
              child: SizedBox(
                width: 86,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BookCover(url: book.coverUrl, width: 86, height: 120),
                  const SizedBox(height: 8),
                  Text(book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: c.text, fontWeight: FontWeight.w500)),
                  Text(book.author,
                      style: GoogleFonts.outfit(fontSize: 10, color: c.textSub)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─── Monthly Statistics ───────────────────────────────────────────────────────

class _WeekStats {
  final String label;
  final int pages;
  final int sessions;
  final int booksRead;
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

class _MonthlyStatsSection extends StatefulWidget {
  const _MonthlyStatsSection();

  @override
  State<_MonthlyStatsSection> createState() => _MonthlyStatsSectionState();
}

class _MonthlyStatsSectionState extends State<_MonthlyStatsSection> {
  bool _loading = true;
  int _totalBooks = 0;
  int _totalPages = 0;
  int _streak = 0;
  int _avgPerDay = 0;
  List<_WeekStats> _weeks = [];
  int _selectedWeek = -1;

  StreamSubscription? _librarySub;
  StreamSubscription? _sessionsSub;

  QuerySnapshot? _latestLibrarySnap;
  QuerySnapshot? _latestSessionSnap;

  DateTime? _monthStart;
  DateTime? _monthEnd;

  @override
  void initState() {
    super.initState();
    _listenToMonthlyStats();
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    _sessionsSub?.cancel();
    super.dispose();
  }

  List<_WeekStats> _buildWeekBuckets() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    List<_WeekStats> weeks = [];
    int weekNum = 1;
    DateTime cursor = start;

    while (cursor.isBefore(end) || cursor.isAtSameMomentAs(end)) {
      final weekEnd = weekNum < 4 ? cursor.add(const Duration(days: 6)) : end;

      weeks.add(_WeekStats(
        label: 'W$weekNum',
        pages: 0,
        sessions: 0,
        booksRead: 0,
        weekStart: cursor,
        weekEnd: weekEnd,
      ));

      cursor = weekEnd.add(const Duration(days: 1));
      weekNum++;
      if (weekNum > 4) break;
    }

    return weeks;
  }

  void _listenToMonthlyStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    _monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    _librarySub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots()
        .listen(
          (snap) {
            _latestLibrarySnap = snap;
            _recompute();
          },
          onError: (e) {
            debugPrint('Monthly library stream error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );

    _sessionsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readingSessions')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_monthStart!),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_monthEnd!))
        .snapshots()
        .listen(
          (snap) {
            _latestSessionSnap = snap;
            _recompute();
          },
          onError: (_) {
            _latestSessionSnap = null;
            _recompute();
          },
        );
  }

  void _recompute() {
    final librarySnap = _latestLibrarySnap;
    final monthStart = _monthStart;
    final monthEnd = _monthEnd;
    if (librarySnap == null || monthStart == null || monthEnd == null) return;

    final sessionSnap = _latestSessionSnap;
    final buckets = _buildWeekBuckets();

    int totalPages = 0;
    int totalBooks = 0;

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
      for (final doc in librarySnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalPages += (data['currentPage'] ?? 0) as int;

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

    final Set<String> readDays = {};
    for (final doc in librarySnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastRead = data['lastReadAt'] as Timestamp?;
      if (lastRead != null) {
        final d = lastRead.toDate();
        readDays.add('${d.year}-${d.month}-${d.day}');
      }
    }

    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      if (readDays.contains(key)) {
        streak++;
      } else {
        break;
      }
    }

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

    final daysInMonth = monthEnd.day;
    final avgPerDay = daysInMonth > 0 ? totalPages ~/ daysInMonth : 0;

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
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}';

  double _maxPages() {
    if (_weeks.isEmpty) return 1;
    final m = _weeks.map((w) => w.pages).reduce((a, b) => a > b ? a : b);
    return m == 0 ? 1 : m.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('This month'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Builder(builder: (context) {
            final c = AppColors.of(context);
            return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardShadow(context),
            ),
            child: _loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: c.brand),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatTile(value: '$_totalBooks', label: 'Books'),
                          _vDivider(c),
                          _StatTile(value: '$_totalPages', label: 'Pages'),
                          _vDivider(c),
                          _StatTile(value: '${_streak}d', label: 'Streak'),
                          _vDivider(c),
                          _StatTile(value: '$_avgPerDay p.', label: 'Avg/day'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Pages per week',
                        style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 96,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(_weeks.length, (i) {
                            final w = _weeks[i];
                            final maxP = _maxPages();
                            final frac = w.pages / maxP;
                            final isTop = w.pages == maxP.round() && w.pages > 0;
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
                      if (_selectedWeek >= 0 && _selectedWeek < _weeks.length) ...[
                        const SizedBox(height: 14),
                        _buildWeekDetail(_weeks[_selectedWeek], c),
                      ],
                    ],
                  ),
          );
          }),
        ),
      ],
    );
  }

  Widget _vDivider(AppPalette c) => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: c.border,
  );

  Widget _buildWeekDetail(_WeekStats w, AppPalette c) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.brandSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.brandMid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${w.label}  ·  ${_formatDate(w.weekStart)} – ${_formatDate(w.weekEnd)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.brand,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedWeek = -1),
                child: Icon(Icons.close_rounded, size: 14, color: c.brand),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _detailStat('${w.pages}', 'Pages read', c),
              const SizedBox(width: 16),
              _detailStat('${w.sessions}', 'Sessions', c),
              const SizedBox(width: 16),
              _detailStat('${w.booksRead}', 'Books done', c),
            ],
          ),
          if (w.pages == 0) ...[
            const SizedBox(height: 8),
            Text(
              'No reading recorded this week.',
              style: GoogleFonts.outfit(fontSize: 11, color: c.textSub),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailStat(String value, String label, AppPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: c.brand,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: c.textSub),
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
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.brand,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10, color: c.textMuted),
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
    final c = AppColors.of(context);
    final barColor = (selected || highlight) ? c.brand : c.brandSoft;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 18,
                child: highlight
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.brand,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Best',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: fraction == 0 ? 4 : _maxBarH * fraction,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: c.brand.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: selected ? c.brand : c.textMuted,
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
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded,         label: 'Home',     index: 0, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.explore_rounded,      label: 'Discover', index: 1, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.library_books_rounded,label: 'Library',  index: 2, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.people_alt_rounded,   label: 'Friends',  index: 3, selected: selectedIndex, onTap: onTap),
          _NavItem(icon: Icons.person_rounded,       label: 'Profile',  index: 4, selected: selectedIndex, onTap: onTap),
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
    final c = AppColors.of(context);
    final color = isActive ? c.brand : c.textMuted;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              letterSpacing: 0.05,
              color: color,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

