import 'package:booqly/models/book_model.dart';
import 'package:booqly/models/book_note_model.dart';
import 'package:booqly/services/notes_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BookNotesPage extends StatelessWidget {
  const BookNotesPage({super.key, required this.book});
  final BookModel book;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final service = NotesService();

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
              'Notes & Highlights',
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
            ),
            Text(
              book.title,
              style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // No AppBar action — FAB is the single entry point

      ),
      body: StreamBuilder<List<BookNoteModel>>(
        stream: service.notesStream(book.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.brand));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline_rounded, color: c.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load notes.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13, color: c.textMuted),
                  ),
                ]),
              ),
            );
          }
          final notes = snap.data ?? [];
          if (notes.isEmpty) {
            return _EmptyState(c: c, bookId: book.id);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _NoteCard(note: notes[i], bookId: book.id, c: c),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, book.id),
        backgroundColor: c.brand,
        icon: Icon(Icons.edit_note_rounded, color: c.onPrimary),
        label: Text('Add note',
            style: GoogleFonts.outfit(
                color: c.onPrimary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.bookId});
  final AppPalette c;
  final String bookId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.sticky_note_2_outlined,
                  color: c.brand, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes yet',
              style: GoogleFonts.figtree(
                  fontSize: 28, fontWeight: FontWeight.w600, color: c.text),
            ),
            const SizedBox(height: 12),
            Text(
              'Save quotes and thoughts as you read.\nTap the button below to add your first note.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: c.textMuted, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddSheet(context, bookId),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add first note',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brand,
                foregroundColor: c.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard(
      {required this.note, required this.bookId, required this.c});
  final BookNoteModel note;
  final String bookId;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    final isQuote = note.type == NoteType.quote;
    final accentColor = isQuote ? c.brand : c.quoteAccent;
    final dateLabel =
        DateFormat('MMM d, yyyy').format(note.createdAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type chip + page + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isQuote
                            ? Icons.format_quote_rounded
                            : Icons.sticky_note_2_rounded,
                        color: accentColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isQuote ? 'Quote' : 'Note',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (note.pageNumber != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'p. ${note.pageNumber}',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: c.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: c.textMuted, size: 20),
                  color: c.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'copy') {
                      Clipboard.setData(ClipboardData(text: note.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied to clipboard',
                              style: GoogleFonts.outfit()),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (val == 'edit') {
                      _showAddSheet(context, bookId, existing: note);
                    } else if (val == 'delete') {
                      _confirmDelete(context, note, bookId);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(children: [
                        Icon(Icons.copy_rounded,
                            color: c.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text('Copy',
                            style: GoogleFonts.outfit(color: c.text)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded,
                            color: c.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text('Edit',
                            style: GoogleFonts.outfit(color: c.text)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            color: c.error, size: 18),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: GoogleFonts.outfit(color: c.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: isQuote
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"',
                          style: GoogleFonts.figtree(
                            fontSize: 40,
                            color: c.brand.withValues(alpha: 0.4),
                            height: 0.8,
                          )),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.text,
                          style: GoogleFonts.figtree(
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            color: c.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    note.text,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: c.text,
                      height: 1.6,
                    ),
                  ),
          ),
          // Date
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              dateLabel,
              style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

void _confirmDelete(
    BuildContext context, BookNoteModel note, String bookId) {
  final c = AppColors.of(context);
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Delete note?',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: c.text)),
      content: Text('This cannot be undone.',
          style: GoogleFonts.outfit(color: c.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel',
              style: GoogleFonts.outfit(color: c.textMuted)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            NotesService().deleteNote(bookId: bookId, noteId: note.id);
          },
          child:
              Text('Delete', style: GoogleFonts.outfit(color: c.error)),
        ),
      ],
    ),
  );
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

void _showAddSheet(BuildContext context, String bookId,
    {BookNoteModel? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _AddNoteSheet(bookId: bookId, existing: existing),
  );
}

class _AddNoteSheet extends StatefulWidget {
  const _AddNoteSheet({required this.bookId, this.existing});
  final String bookId;
  final BookNoteModel? existing;

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _pageCtrl;
  late NoteType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.existing?.text ?? '');
    _pageCtrl = TextEditingController(
        text: widget.existing?.pageNumber?.toString() ?? '');
    _type = widget.existing?.type ?? NoteType.note;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final page = int.tryParse(_pageCtrl.text.trim());
    try {
      if (widget.existing != null) {
        await NotesService().updateNote(
          bookId: widget.bookId,
          noteId: widget.existing!.id,
          text: text,
          pageNumber: page,
          type: _type,
        );
      } else {
        await NotesService().addNote(
          bookId: widget.bookId,
          text: text,
          pageNumber: page,
          type: _type,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e',
                style: GoogleFonts.outfit()),
            backgroundColor: AppColors.of(context).error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(99))),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existing != null ? 'Edit note' : 'New note',
              style: GoogleFonts.figtree(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.text),
            ),
            const SizedBox(height: 16),

            // Type toggle
            Row(
              children: [
                _TypeChip(
                  label: 'Note',
                  icon: Icons.sticky_note_2_rounded,
                  selected: _type == NoteType.note,
                  color: c.quoteAccent,
                  onTap: () => setState(() => _type = NoteType.note),
                  c: c,
                ),
                const SizedBox(width: 10),
                _TypeChip(
                  label: 'Quote',
                  icon: Icons.format_quote_rounded,
                  selected: _type == NoteType.quote,
                  color: c.brand,
                  onTap: () => setState(() => _type = NoteType.quote),
                  c: c,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Text input
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              style: GoogleFonts.outfit(fontSize: 15, color: c.text),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _type == NoteType.quote
                    ? 'Paste or type the quote…'
                    : 'Write your thought…',
                hintStyle: GoogleFonts.outfit(color: c.textMuted),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: c.brand, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            // Page number
            TextField(
              controller: _pageCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.outfit(fontSize: 15, color: c.text),
              decoration: InputDecoration(
                hintText: 'Page number (optional)',
                hintStyle: GoogleFonts.outfit(color: c.textMuted),
                prefixIcon:
                    Icon(Icons.bookmark_outline_rounded, color: c.textMuted),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: c.brand, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_textCtrl.text.trim().isEmpty || _saving)
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  disabledBackgroundColor: c.border,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.onPrimary))
                    : Text('Save',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.onPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    required this.c,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : c.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : c.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? color : c.textMuted, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
