import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:booqly/Pages/pdf_reader_page.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/feedback_model.dart';
import 'package:booqly/services/feedback_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:booqly/services/email_service.dart';
import 'package:booqly/services/library_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final LibraryService _libraryService = LibraryService();
  final FeedbackService _feedbackService = FeedbackService();
  final EmailService _emailService = EmailService();

  String? _bookStatus;
  bool _isFavorite = false;

  bool _statusLoading = true;
  bool _loadingProgress = true;

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
    setState(() => _statusLoading = false);
  }

  @override
  void initState() {
    super.initState();
    loadBookStatus();
    loadProgress();
    loadFavoriteStatus();
  }

  Future<void> removeBookFromLibrary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .delete();

    setState(() => _bookStatus = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Book removed from library")),
    );
  }

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
      setState(() => _loadingProgress = false);
    }
  }

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
    setState(() => _isFavorite = doc.exists);
  }

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

  Future<_CompletionEmailOutcome> _sendBookCompletedEmail(User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      return const _CompletionEmailOutcome(
        success: false,
        message: 'No email on this account, so no congratulations email was sent.',
      );
    }

    try {
      final firstName = await _readerFirstName(user.uid, user);
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
        return _CompletionEmailOutcome(
          success: true,
          message: 'Congratulations email sent to $email.',
        );
      }

      return _CompletionEmailOutcome(
        success: false,
        message: result.errorMessage ??
            'Could not send congratulations email. Check the debug log.',
      );
    } catch (e, stack) {
      debugPrint('BookDetailPage._sendBookCompletedEmail: unexpected error: $e\n$stack');
      return _CompletionEmailOutcome(
        success: false,
        message: 'Could not send congratulations email: $e',
      );
    }
  }

  Future<void> completeBook() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

    final emailFuture = _sendBookCompletedEmail(user);

    if (!mounted) return;

    setState(() => _currentPage = widget.book.totalPages);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: kCardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandSoft,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Congratulations!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
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
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
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
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Pages",
                            style: GoogleFonts.outfit(
                              color: AppColors.textSub,
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
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Finished",
                            style: GoogleFonts.outfit(
                              color: AppColors.textSub,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _CompletionEmailStatus(emailFuture: emailFuture),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Awesome!",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
    if (_statusLoading || _loadingProgress) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }

    final progressPercent = ((_currentPage / widget.book.totalPages) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero cover
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: widget.book.coverUrl.startsWith('http')
                      ? Image.network(
                          widget.book.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceAlt,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.brand,
                              size: 50,
                            ),
                          ),
                        )
                      : kIsWeb
                          ? Container(
                              color: AppColors.surfaceAlt,
                              child: const Center(
                                child: Icon(Icons.menu_book_rounded,
                                    color: AppColors.brand, size: 64),
                              ),
                            )
                          : Image.file(
                              File(widget.book.coverUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                color: AppColors.surfaceAlt,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.brand,
                                  size: 50,
                                ),
                              ),
                            ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: kCardShadow,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.text,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // White content area
            Container(
              color: AppColors.bg,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          widget.book.category,
                          style: GoogleFonts.outfit(
                            color: AppColors.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title — Cormorant Garamond
                      Text(
                        widget.book.title,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'by ${widget.book.author}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppColors.textSub,
                        ),
                      ),

                      const SizedBox(height: 24),

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

                      const SizedBox(height: 28),

                      Text(
                        'About this book',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        widget.book.description,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          height: 1.7,
                          color: AppColors.textSub,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Progress section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: kCardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Reading Progress",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "$_currentPage",
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                  Text(
                                    "Current Page",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
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
                                    color: AppColors.brand,
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
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.brand,
                                inactiveTrackColor: AppColors.brandMid,
                                thumbColor: AppColors.brand,
                                overlayColor: AppColors.brand.withValues(alpha: 0.15),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _currentPage.toDouble(),
                                min: 0,
                                max: widget.book.totalPages.toDouble(),
                                onChanged: (value) async {
                                  setState(() => _currentPage = value.round());
                                  await saveProgress();
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_currentPage > 0) {
                                        setState(() => _currentPage--);
                                        await saveProgress();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Icon(
                                        Icons.remove_rounded,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_currentPage < widget.book.totalPages) {
                                        setState(() => _currentPage++);
                                        await saveProgress();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "Read Next Page",
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_currentPage < widget.book.totalPages) {
                                        setState(() => _currentPage++);
                                        await saveProgress();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Start / Continue Reading
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
                                  "progress": _currentPage / widget.book.totalPages,
                                  "currentPage": _currentPage,
                                  "totalPages": widget.book.totalPages,
                                  "addedAt": Timestamp.now(),
                                }, SetOptions(merge: true));

                            if (!context.mounted) return;
                            setState(() => _bookStatus = "reading");

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfReaderPage(book: widget.book),
                              ),
                            );

                            await loadBookStatus();
                            await loadProgress();
                            if (mounted) setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _bookStatus == "reading" ? 'Continue Reading' : 'Start Reading',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (_bookStatus == "want_to_read") {
                                  await removeBookFromLibrary();
                                  return;
                                }
                                await _libraryService.addBook(
                                  bookId: widget.book.id,
                                  status: "want_to_read",
                                  totalPages: widget.book.totalPages,
                                );
                                if (!context.mounted) return;
                                setState(() => _bookStatus = "want_to_read");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Added to Want To Read")),
                                );
                              },
                              icon: Icon(
                                Icons.bookmark_border_rounded,
                                color: AppColors.brand,
                              ),
                              label: Text(
                                _bookStatus == "want_to_read"
                                    ? 'Remove from List'
                                    : 'Want to Read',
                                style: GoogleFonts.outfit(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;

                                if (_isFavorite) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('favorites')
                                      .doc(widget.book.id)
                                      .delete();
                                  if (!context.mounted) return;
                                  setState(() => _isFavorite = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.surface,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      content: Row(
                                        children: [
                                          const Icon(Icons.heart_broken_rounded, color: Colors.red),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Removed from favorites",
                                              style: GoogleFonts.outfit(color: AppColors.text),
                                            ),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }

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
                                        const Icon(Icons.favorite_rounded, color: Colors.red),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Added to your favorites ❤️",
                                            style: GoogleFonts.outfit(color: AppColors.text),
                                          ),
                                        ),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                setState(() => _isFavorite = true);
                              },
                              icon: Icon(
                                _isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: AppColors.brand,
                              ),
                              label: Text(
                                _isFavorite ? 'Remove Favorite' : 'Favorite',
                                style: GoogleFonts.outfit(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
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
                            color: AppColors.brand,
                          ),
                          label: Text(
                            _bookStatus == "completed"
                                ? "Mark Incomplete"
                                : "Mark as Completed",
                            style: GoogleFonts.outfit(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: _bookStatus == "completed"
                                  ? AppColors.border
                                  : AppColors.brand,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                color: AppColors.brand,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) return const SizedBox.shrink();

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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
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
                    color: AppColors.brand,
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
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
                    color: AppColors.text,
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
              color: AppColors.textSub,
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
          color: AppColors.amber,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.brand, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

class _CompletionEmailOutcome {
  final bool success;
  final String message;
  const _CompletionEmailOutcome({required this.success, required this.message});
}

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
            color: AppColors.red,
            text: 'Could not send congratulations email.',
          );
        }

        return _row(
          icon: outcome.success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: outcome.success ? AppColors.green : AppColors.red,
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
        color: AppColors.surfaceAlt,
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
                color: AppColors.textSub,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
