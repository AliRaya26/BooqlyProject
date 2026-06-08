import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/social_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only view of a followed user's notes & quotes for a specific book.
class FriendNotesPage extends StatefulWidget {
  const FriendNotesPage({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.bookId,
    required this.bookTitle,
  });

  final String friendUid;
  final String friendName;
  final String bookId;
  final String bookTitle;

  @override
  State<FriendNotesPage> createState() => _FriendNotesPageState();
}

class _FriendNotesPageState extends State<FriendNotesPage> {
  final _social = SocialService();

  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notes = await _social.getFriendNotesForBook(
      friendUid: widget.friendUid,
      bookId: widget.bookId,
    );
    if (mounted) setState(() { _notes = notes; _loading = false; });
  }

  Future<void> _goToBook() async {
    setState(() => _navigating = true);
    try {
      // Try to fetch from the real books catalog
      final data = await _social.getBookData(widget.bookId);
      if (!mounted) return;
      if (data != null) {
        final book = BookModel.fromMap(data, data['id'] as String);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => BookDetailPage(book: book),
        ));
      } else {
        // Book is not in the Booqly catalog (dummy/external)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '"${widget.bookTitle}" is not in the Booqly catalog yet.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.of(context).brand,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final quotes = _notes.where((n) => n['type'] == 'quote').toList();
    final regularNotes = _notes.where((n) => n['type'] != 'quote').toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.friendName.split(' ').first}\'s Notes',
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
            ),
            Text(
              widget.bookTitle,
              style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _navigating ? null : _goToBook,
            icon: _navigating
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.brand))
                : Icon(Icons.menu_book_rounded, size: 16, color: c.brand),
            label: Text('View Book',
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w600, color: c.brand)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.brand))
          : _notes.isEmpty
              ? _empty(c)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: c.brand,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (quotes.isNotEmpty) ...[
                        _sectionLabel('Saved Quotes', c),
                        ...quotes.map((n) => _NoteCard(note: n, c: c)),
                        const SizedBox(height: 8),
                      ],
                      if (regularNotes.isNotEmpty) ...[
                        _sectionLabel('Notes', c),
                        ...regularNotes.map((n) => _NoteCard(note: n, c: c)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _sectionLabel(String label, AppPalette c) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
    child: Text(label.toUpperCase(),
        style: GoogleFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: c.textMuted, letterSpacing: 1.2)),
  );

  Widget _empty(AppPalette c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sticky_note_2_outlined, color: c.textMuted, size: 48),
        const SizedBox(height: 16),
        Text('No notes yet',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 8),
        Text('${widget.friendName.split(' ').first} hasn\'t added any notes\nfor this book yet.',
            style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.c});
  final Map<String, dynamic> note;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    final isQuote = note['type'] == 'quote';
    final text = note['text'] as String? ?? '';
    final ts = note['createdAt'];
    DateTime? date;
    if (ts is Timestamp) date = ts.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isQuote ? c.brandSoft : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isQuote ? c.brand.withValues(alpha: 0.3) : c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            isQuote ? Icons.format_quote_rounded : Icons.sticky_note_2_outlined,
            size: 15,
            color: isQuote ? c.brand : c.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            isQuote ? 'Quote' : 'Note',
            style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: isQuote ? c.brand : c.textMuted,
                letterSpacing: 0.5),
          ),
          const Spacer(),
          if (date != null)
            Text(
              DateFormat('MMM d').format(date),
              style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: c.text,
            height: 1.55,
            fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ]),
    );
  }
}
