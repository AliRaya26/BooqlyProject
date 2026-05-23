import 'dart:io';

import 'package:booqly/Pages/pdf_reader_page.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/feedback_model.dart';
import 'package:booqly/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:booqly/services/email_service.dart';
import 'package:booqly/services/library_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
// BOOK DETAIL PAGE
// ─────────────────────────────────────────────────────────────

class BookDetailPage extends StatefulWidget {
  final BookModel book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

final LibraryService _libraryService = LibraryService();
final FeedbackService _feedbackService = FeedbackService();
final EmailService _emailService = EmailService();

bool _statusLoading = true;

class _BookDetailPageState extends State<BookDetailPage> {
  // CURRENT BOOK STATUS
  String? _bookStatus;
  bool _isFavorite = false;

  // LOADING STATUS

  bool _loadingProgress = true;

  // Current page reached
  int _currentPage = 0;

  Future<void> loadBookStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .get();

    if (doc.exists) {
      final data = doc.data();

      _bookStatus = data?['status'];

      _currentPage = data?['currentPage'] ?? 0;
    } else {
      _bookStatus = null;
    }

    if (!mounted) return;

    setState(() {
      _statusLoading = false;
    });
  }

  // ───────────────────────────────────────────────────────────
  // INIT STATE
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    loadBookStatus();
    loadProgress();
    loadFavoriteStatus();
  }

  // ───────────────────────────────────────────────────────────
  // REMOVE BOOK FROM LIBRARY
  // ───────────────────────────────────────────────────────────

  Future<void> removeBookFromLibrary() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .delete();

    setState(() {
      _bookStatus = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Book removed from library")));
  }

  // ───────────────────────────────────────────────────────────
  // LOAD READING PROGRESS
  // ───────────────────────────────────────────────────────────

  Future<void> loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .get();

    if (doc.exists) {
      final data = doc.data();

      setState(() {
        _currentPage = data?['currentPage'] ?? 0;
        _loadingProgress = false;
      });
    } else {
      setState(() {
        _loadingProgress = false;
      });
    }
  }

  // ───────────────────────────────────────────────────────────
  // SAVE PROGRESS
  // ───────────────────────────────────────────────────────────

  Future<void> saveProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .set({
          "status": "reading",
          "progress": _currentPage / widget.book.totalPages,
          "currentPage": _currentPage,
          "totalPages": widget.book.totalPages,
          "addedAt": Timestamp.now(),
        }, SetOptions(merge: true));
  }

  // ───────────────────────────────────────────────────────────
  // LOAD FAVORITE STATUS
  // ───────────────────────────────────────────────────────────

  Future<void> loadFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.book.id)
        .get();

    if (!mounted) return;

    setState(() {
      _isFavorite = doc.exists;
    });
  }

  // ───────────────────────────────────────────────────────────
  // MARK BOOK AS COMPLETED
  // ───────────────────────────────────────────────────────────

  Future<String> _readerFirstName(String uid, User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final fromDoc = doc.data()?['firstName'] as String?;
      if (fromDoc != null && fromDoc.trim().isNotEmpty) {
        return fromDoc.trim();
      }
    } catch (e) {
      debugPrint('BookDetailPage._readerFirstName: $e');
    }

    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display.split(RegExp(r'\s+')).first;
    }
    return 'Reader';
  }

  /// Sends the "you finished a book" email and returns a structured result the
  /// caller can render in the UI. We deliberately do NOT show a snackbar from
  /// here — earlier versions did, and the snackbar was rendered behind the
  /// trophy dialog and then destroyed when the page was popped, so the user
  /// never saw success or failure. The completion dialog now shows this
  /// result inline instead.
  Future<_CompletionEmailOutcome> _sendBookCompletedEmail(User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      debugPrint(
        'BookDetailPage._sendBookCompletedEmail: signed-in user has no email '
        '(uid=${user.uid}, providers=${user.providerData.map((p) => p.providerId).toList()}). '
        'Skipping completion email.',
      );
      return const _CompletionEmailOutcome(
        success: false,
        message: 'No email on this account, so no congratulations email was sent.',
      );
    }

    try {
      final firstName = await _readerFirstName(user.uid, user);
      debugPrint(
        'BookDetailPage._sendBookCompletedEmail: sending to "$email" '
        '(firstName="$firstName", book="${widget.book.title}")',
      );

      final result = await _emailService.sendBookCompletedEmail(
        toEmail: email,
        firstName: firstName,
        bookTitle: widget.book.title,
        author: widget.book.author,
        totalPages: widget.book.totalPages,
        coverUrl: widget.book.coverUrl,
        completedAt: DateTime.now(),
      );

      if (result.success) {
        debugPrint(
          'BookDetailPage._sendBookCompletedEmail: SENT to "$email" '
          '(delivered=${result.delivered}, '
          'queuedInFirestore=${result.queuedInFirestore})',
        );
        return _CompletionEmailOutcome(
          success: true,
          message: 'Congratulations email sent to $email.',
        );
      }

      debugPrint(
        'BookDetailPage._sendBookCompletedEmail: FAILED for "$email": '
        '${result.errorMessage} (code=${result.functionsErrorCode})',
      );
      return _CompletionEmailOutcome(
        success: false,
        message: result.errorMessage ??
            'Could not send congratulations email. Check the debug log.',
      );
    } catch (e, stack) {
      debugPrint(
        'BookDetailPage._sendBookCompletedEmail: unexpected error: $e\n$stack',
      );
      return _CompletionEmailOutcome(
        success: false,
        message: 'Could not send congratulations email: $e',
      );
    }
  }

  Future<void> completeBook() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Save completed state
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .set({
          "status": "completed",
          "progress": 1.0,
          "currentPage": widget.book.totalPages,
          "totalPages": widget.book.totalPages,
          "completedAt": Timestamp.now(),
        }, SetOptions(merge: true));

    // Kick off the email send before showing the dialog so the dialog can
    // surface its result inline (success or failure) instead of relying on a
    // snackbar that gets hidden behind the dialog and lost on navigation.
    final emailFuture = _sendBookCompletedEmail(user);

    if (!mounted) return;

    // Update local UI
    setState(() {
      _currentPage = widget.book.totalPages;
    });

    // Beautiful popup
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),

      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,

          child: Container(
            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // Trophy icon
                Container(
                  width: 90,
                  height: 90,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                  ),

                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: AppColors.gold,
                  ),
                ),

                const SizedBox(height: 24),

                // Congratulations text
                Text(
                  "Congratulations!",

                  textAlign: TextAlign.center,

                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  "You completed\n${widget.book.title}",

                  textAlign: TextAlign.center,

                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 26),

                // Stats box
                Container(
                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,

                    children: [
                      Column(
                        children: [
                          Text(
                            "${widget.book.totalPages}",

                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "Pages",

                            style: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      Container(width: 1, height: 40, color: AppColors.border),

                      Column(
                        children: [
                          Text(
                            "100%",

                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "Finished",

                            style: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Email status (sending / sent / failed). Lives inside the
                // dialog so the user actually sees it instead of a snackbar
                // hidden behind the dialog and then thrown away on pop.
                _CompletionEmailStatus(emailFuture: emailFuture),

                const SizedBox(height: 22),

                // Close button
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),

                    child: Text(
                      "Awesome!",

                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // LOADING
    if (_statusLoading || _loadingProgress) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final progressPercent = ((_currentPage / widget.book.totalPages) * 100)
        .round();

    return Scaffold(
      backgroundColor: AppColors.bg,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ─────────────────────────────────────────────
              // TOP IMAGE SECTION
              // ─────────────────────────────────────────────
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 420,

                    child: widget.book.coverUrl.startsWith('http')
                        ? Image.network(
                            widget.book.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.gold,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : Image.file(
                            File(widget.book.coverUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.gold,
                                  size: 50,
                                ),
                              );
                            },
                          ),
                  ),

                  Container(
                    width: double.infinity,
                    height: 420,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),

                  Positioned(
                    top: 18,
                    left: 18,

                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),

                      child: Container(
                        width: 38,
                        height: 38,

                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ─────────────────────────────────────────────
              // CONTENT
              // ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // Category
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),

                      child: Text(
                        widget.book.category,

                        style: GoogleFonts.outfit(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      widget.book.title,

                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 40,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Author
                    Text(
                      'by ${widget.book.author}',

                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: AppColors.textMuted,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // INFO CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            title: 'Pages',
                            value: '${widget.book.totalPages}',
                            icon: Icons.menu_book_rounded,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _InfoCard(
                            title: 'Category',
                            value: widget.book.category,
                            icon: Icons.category_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // About title
                    Text(
                      'About this book',

                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Description
                    Text(
                      widget.book.description,

                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        height: 1.8,
                        color: AppColors.textMuted,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ─────────────────────────────────────
                    // READING PROGRESS SECTION
                    // ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_stories_rounded,
                                color: AppColors.gold,
                                size: 22,
                              ),

                              const SizedBox(width: 10),

                              Text(
                                "Reading Progress",

                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Current page
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "$_currentPage",

                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 58,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),

                                Text(
                                  "Current Page",

                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Percentage
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Text(
                                "0",

                                style: GoogleFonts.outfit(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),

                              Text(
                                "$progressPercent% completed",

                                style: GoogleFonts.outfit(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),

                              Text(
                                "${widget.book.totalPages}",

                                style: GoogleFonts.outfit(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.gold,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: AppColors.gold,
                              overlayColor: AppColors.gold.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),

                            child: Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: widget.book.totalPages.toDouble(),

                              onChanged: (value) async {
                                setState(() {
                                  _currentPage = value.round();
                                });

                                await saveProgress();
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Buttons
                          Row(
                            children: [
                              // Minus
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (_currentPage > 0) {
                                      setState(() {
                                        _currentPage--;
                                      });

                                      await saveProgress();
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),

                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),

                                    child: const Icon(
                                      Icons.remove_rounded,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Read next page
                              Expanded(
                                flex: 2,

                                child: GestureDetector(
                                  onTap: () async {
                                    if (_currentPage < widget.book.totalPages) {
                                      setState(() {
                                        _currentPage++;
                                      });

                                      await saveProgress();
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),

                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(16),
                                    ),

                                    child: Center(
                                      child: Text(
                                        "Read Next Page",

                                        style: GoogleFonts.outfit(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Plus
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (_currentPage < widget.book.totalPages) {
                                      setState(() {
                                        _currentPage++;
                                      });

                                      await saveProgress();
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),

                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),

                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // START READING BUTTON
                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;

                          if (user == null) return;

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('library')
                              .doc(widget.book.id)
                              .set({
                                "status": "reading",
                                "progress":
                                    _currentPage / widget.book.totalPages,
                                "currentPage": _currentPage,
                                "totalPages": widget.book.totalPages,
                                "addedAt": Timestamp.now(),
                              }, SetOptions(merge: true));

                          if (!context.mounted) return;

                          setState(() {
                            _bookStatus = "reading";
                          });

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfReaderPage(book: widget.book),
                            ),
                          );

                          // Refresh after returning
                          await loadBookStatus();
                          await loadProgress();

                          if (mounted) {
                            setState(() {});
                          }
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),

                        child: Text(
                          _bookStatus == "reading"
                              ? 'Continue Reading'
                              : 'Start Reading',

                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // SECONDARY BUTTONS
                    Row(
                      children: [
                        // Want to read
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // REMOVE BOOK
                              if (_bookStatus == "want_to_read") {
                                await removeBookFromLibrary();

                                return;
                              }

                              // ADD TO WANT TO READ
                              await _libraryService.addBook(
                                bookId: widget.book.id,
                                status: "want_to_read",
                                totalPages: widget.book.totalPages,
                              );

                              if (!context.mounted) return;

                              setState(() {
                                _bookStatus = "want_to_read";
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Added to Want To Read"),
                                ),
                              );
                            },

                            icon: const Icon(
                              Icons.bookmark_border_rounded,
                              color: AppColors.gold,
                            ),

                            label: Text(
                              _bookStatus == "want_to_read"
                                  ? 'Remove from List'
                                  : 'Want to Read',

                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),

                              side: const BorderSide(color: AppColors.border),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Favorite
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;

                              if (user == null) return;

                              // REMOVE FAVORITE
                              if (_isFavorite) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('favorites')
                                    .doc(widget.book.id)
                                    .delete();

                                if (!context.mounted) return;

                                setState(() {
                                  _isFavorite = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surface,
                                    behavior: SnackBarBehavior.floating,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),

                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.heart_broken_rounded,
                                          color: Colors.red,
                                        ),

                                        const SizedBox(width: 12),

                                        Expanded(
                                          child: Text(
                                            "Removed from favorites",
                                            style: GoogleFonts.outfit(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    duration: const Duration(seconds: 2),
                                  ),
                                );

                                return;
                              }

                              // ADD FAVORITE
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('favorites')
                                  .doc(widget.book.id)
                                  .set({
                                    "bookId": widget.book.id,
                                    "addedAt": Timestamp.now(),
                                  });

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),

                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Colors.red,
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Text(
                                          "Added to your favorites ❤️",
                                          style: GoogleFonts.outfit(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              setState(() {
                                _isFavorite = true;
                              });
                            },

                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: AppColors.gold,
                            ),

                            label: Text(
                              _isFavorite ? 'Remove Favorite' : 'Favorite',

                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),

                              side: const BorderSide(color: AppColors.border),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // MARK AS COMPLETED BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // MARK INCOMPLETE
                          if (_bookStatus == "completed") {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser!.uid)
                                .collection('library')
                                .doc(widget.book.id)
                                .set({
                                  "status": "reading",
                                  "progress": 0,
                                  "currentPage": 0,
                                }, SetOptions(merge: true));

                            setState(() {
                              _bookStatus = "reading";
                              _currentPage = 0;
                            });

                            return;
                          }

                          // COMPLETE BOOK
                          await completeBook();

                          setState(() {
                            _bookStatus = "completed";
                            _currentPage = widget.book.totalPages;
                          });
                        },

                        icon: Icon(
                          _bookStatus == "completed"
                              ? Icons.refresh_rounded
                              : Icons.check_circle_rounded,
                          color: AppColors.gold,
                        ),

                        label: Text(
                          _bookStatus == "completed"
                              ? "Mark Incomplete"
                              : "Mark as Completed",

                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(
                            color: _bookStatus == "completed"
                                ? AppColors.border
                                : AppColors.gold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    _BookFeedbacksSection(
                      bookId: widget.book.id,
                      feedbackService: _feedbackService,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────

class _BookFeedbacksSection extends StatelessWidget {
  const _BookFeedbacksSection({
    required this.bookId,
    required this.feedbackService,
  });

  final String bookId;
  final FeedbackService feedbackService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FeedbackModel>>(
      stream: feedbackService.feedbacksStream(bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return const SizedBox.shrink();
        }

        final total = reviews.fold<int>(0, (acc, r) => acc + r.rating);
        final average = total / reviews.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reader feedback',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _StarRating(value: average, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${average.toStringAsFixed(1)} (${reviews.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeedbackCard(review: review),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.review});

  final FeedbackModel review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StarRating(value: review.rating.toDouble(), size: 14),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, this.size = 16});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = value >= index + 1;
        final half = !filled && value > index && value < index + 1;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: AppColors.gold,
        );
      }),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),

      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 24),

          const SizedBox(height: 10),

          Text(
            value,

            textAlign: TextAlign.center,

            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,

            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Result of attempting to send the "you finished this book" email. Lives at
/// the file level so it can be passed between `_BookDetailPageState` and the
/// dialog widget that displays its result.
class _CompletionEmailOutcome {
  final bool success;
  final String message;
  const _CompletionEmailOutcome({required this.success, required this.message});
}

/// Inline email-status block shown inside the trophy dialog. While the email
/// is in flight it shows a small spinner; once the future resolves it shows a
/// success or failure line so the user knows whether the congratulations
/// email actually went out.
class _CompletionEmailStatus extends StatelessWidget {
  final Future<_CompletionEmailOutcome> emailFuture;
  const _CompletionEmailStatus({required this.emailFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CompletionEmailOutcome>(
      future: emailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _row(
            icon: Icons.mail_outline_rounded,
            color: AppColors.textMuted,
            text: 'Sending congratulations email…',
            showSpinner: true,
          );
        }

        final outcome = snapshot.data;
        if (outcome == null) {
          return _row(
            icon: Icons.error_outline_rounded,
            color: Colors.redAccent,
            text: 'Could not send congratulations email.',
          );
        }

        return _row(
          icon: outcome.success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: outcome.success ? AppColors.gold : Colors.redAccent,
          text: outcome.message,
        );
      },
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String text,
    bool showSpinner = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showSpinner)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
