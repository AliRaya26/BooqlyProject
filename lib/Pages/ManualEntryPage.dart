import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:booqly/theme/app_colors.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class ManualEntryPage extends StatefulWidget {
  const ManualEntryPage({super.key});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {

  // ── Controllers ──────────────────────────────────────────────────────────
  final _titleCtrl       = TextEditingController();
  final _totalPagesCtrl  = TextEditingController();
  final _authorCtrl      = TextEditingController();
  final _translatorCtrl  = TextEditingController();
  final _narratorCtrl    = TextEditingController();
  final _publisherCtrl   = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // ── Dropdowns ────────────────────────────────────────────────────────────
  String _language = 'English';
  String _category = 'Fiction';
  int    _pubYear  = DateTime.now().year;
  int    _pubMonth = 1;
  int    _pubDay   = 1;

  // ── Cover image ──────────────────────────────────────────────────────────
  File? _coverImage;
  bool  _savingCover = false;

  // ── PDF ──────────────────────────────────────────────────────────────────
  File?   _pdfFile;
  String? _pdfFileName;
  bool    _copyingPdf = false;

  // ── Save ─────────────────────────────────────────────────────────────────
  bool _saving = false;

  // ── Static lists ─────────────────────────────────────────────────────────
  static const _languages = [
    'English','Arabic','French','Spanish','German',
    'Italian','Portuguese','Chinese','Japanese','Other',
  ];

  static const _categories = [
    'Fiction','Non-Fiction','Economics','Health','Culture',
    'Science','Philosophy','Psychology','Productivity','Motivation',
    'Programming','History','Biography','Other',
  ];

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalPagesCtrl.dispose();
    _authorCtrl.dispose();
    _translatorCtrl.dispose();
    _narratorCtrl.dispose();
    _publisherCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ─── Cover ───────────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;
    setState(() => _coverImage = File(picked.path));
  }

  Future<String> _saveCoverLocally(String bookId) async {
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/covers/$bookId.jpg');
    await dest.parent.create(recursive: true);
    await _coverImage!.copy(dest.path);
    return dest.path;
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pdfFile     = File(result.files.single.path!);
      _pdfFileName = result.files.single.name;
    });
  }

  void _removePdf() => setState(() { _pdfFile = null; _pdfFileName = null; });

  Future<String> _savePdfLocally(String bookId) async {
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/pdfs/$bookId.pdf');
    await dest.parent.create(recursive: true);
    await _pdfFile!.copy(dest.path);
    return dest.path;
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { _snack('Please enter a title'); return; }

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in');
      setState(() => _saving = false);
      return;
    }

    try {
      // Generate a unique ID from the user's library subcollection
      // (manual books are private — never written to the global /books catalog)
      final libraryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc();
      final bookId = libraryRef.id;

      // ── Save cover locally ──
      String localCoverPath = '';
      if (_coverImage != null) {
        setState(() => _savingCover = true);
        localCoverPath = await _saveCoverLocally(bookId);
        if (mounted) setState(() => _savingCover = false);
      }

      // ── Copy PDF locally ──
      String localPdfPath = '';
      if (_pdfFile != null) {
        setState(() => _copyingPdf = true);
        localPdfPath = await _savePdfLocally(bookId);
        if (mounted) setState(() => _copyingPdf = false);
      }

      final totalPages  = int.tryParse(_totalPagesCtrl.text.trim()) ?? 0;
      final author      = _authorCtrl.text.trim();
      final description = _descriptionCtrl.text.trim();
      final publishedAt = '$_pubDay ${_months[_pubMonth - 1]} $_pubYear';

      // ── Add to user library (all metadata stored here — no global catalog write) ──
      await libraryRef.set({
            // reading progress
            'status':      'want_to_read',
            'currentPage': 0,
            'totalPages':  totalPages,
            'progress':    0.0,
            'lastReadAt':  Timestamp.now(),
            'addedAt':     Timestamp.now(),
            // metadata mirror — used as fallback when catalog lookup fails
            'title':       title,
            'author':      author,
            'coverUrl':    localCoverPath,
            'category':    _category,
            'description': description,
            'language':    _language,
            'publishedAt': publishedAt,
            'pdfUrl':      localPdfPath,
            'isLocal':     true,
            'source':      'manual',
          });

      if (!mounted) return;
      _snack('Book added to your library ✓');
      Navigator.pop(context);

    } catch (e, stack) {
      debugPrint('❌ ManualEntry save error: $e\n$stack');
      if (mounted) _snack('Error: ${e.toString()}');
    }

    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg) {
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: c.text)),
      backgroundColor: c.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c   = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: c.surface,
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_left_rounded,
                        color: c.textSub, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a book',
                      style: GoogleFonts.figtree(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: c.text, height: 1.1)),
                    Text('Manual entry',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),

          // ── Scrollable body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _section(c, 'Book Info'),
                  _buildCoverPicker(c),
                  _field(c, _titleCtrl,      'Title',       Icons.title_rounded),
                  _field(c, _totalPagesCtrl, 'Total pages', Icons.menu_book_rounded,
                      keyboardType: TextInputType.number),
                  Row(children: [
                    Expanded(child: _dropdown(c, 'Language', _languages, _language,
                        (v) => setState(() => _language = v!))),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown(c, 'Category', _categories, _category,
                        (v) => setState(() => _category = v!))),
                  ]),

                  _section(c, 'Creators'),
                  _field(c, _authorCtrl,     'Author(s)',  Icons.person_rounded),
                  _field(c, _translatorCtrl, 'Translator', Icons.translate_rounded),
                  _field(c, _narratorCtrl,   'Narrator',   Icons.record_voice_over_rounded),

                  _section(c, 'Publication'),
                  _field(c, _publisherCtrl, 'Publisher', Icons.business_rounded),
                  _buildDatePicker(c),
                  _field(c, _descriptionCtrl, 'Description', Icons.notes_rounded,
                      maxLines: 4, hint: 'A short summary of the book…'),

                  _section(c, 'PDF File'),
                  _buildPdfSection(c),

                  const SizedBox(height: 32),
                  _buildSaveButton(c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section label ────────────────────────────────────────────────────────

  Widget _section(AppPalette c, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Text(text.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10, letterSpacing: 0.14,
              color: c.brand, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );
  }

  // ─── Cover picker ─────────────────────────────────────────────────────────

  Widget _buildCoverPicker(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _coverImage == null ? _pickCover : null,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _coverImage != null ? c.brand : c.border,
              width: _coverImage != null ? 1.5 : 1,
            ),
            image: _coverImage != null
                ? DecorationImage(
                    image: FileImage(_coverImage!), fit: BoxFit.cover)
                : null,
          ),
          child: _coverImage != null
              ? Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: c.scrim,
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Row(
                        children: [
                          _overlayBtn(c, Icons.edit_rounded, _pickCover),
                          const SizedBox(width: 8),
                          _overlayBtn(c, Icons.close_rounded,
                              () => setState(() => _coverImage = null)),
                        ],
                      ),
                    ),
                    Center(
                      child: Icon(Icons.check_circle_rounded,
                          color: c.onPrimary.withValues(alpha: 0.7), size: 32),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: c.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_photo_alternate_rounded,
                          color: c.brand, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text('Add cover image',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w500,
                            color: c.text)),
                    const SizedBox(height: 4),
                    Text('Tap to choose from gallery',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: c.textMuted)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _overlayBtn(AppPalette c, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: c.overlay,
            shape: BoxShape.circle),
        child: Icon(icon, color: c.onPrimary, size: 16),
      ),
    );
  }

  // ─── Text field ───────────────────────────────────────────────────────────

  Widget _field(
    AppPalette c,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller:   ctrl,
        keyboardType: keyboardType,
        maxLines:     maxLines,
        style: GoogleFonts.outfit(fontSize: 14, color: c.text),
        decoration: InputDecoration(
          hintText:  hint ?? label,
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: c.textMuted),
          prefixIcon: Icon(icon, size: 18, color: c.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          filled:    true,
          fillColor: c.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.brand, width: 1.2),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical:   maxLines > 1 ? 14 : 0,
            horizontal: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  // ─── Dropdown ─────────────────────────────────────────────────────────────

  Widget _dropdown(AppPalette c, String label, List<String> items,
      String value, ValueChanged<String?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:         value,
          isExpanded:    true,
          dropdownColor: c.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: c.textMuted, size: 18),
          style: GoogleFonts.outfit(fontSize: 13, color: c.text),
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s, style: GoogleFonts.outfit(fontSize: 13, color: c.text)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Date picker ──────────────────────────────────────────────────────────

  Widget _buildDatePicker(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: _dateDrop<int>(c,
            items: List.generate(31, (i) => i + 1), value: _pubDay,
            label: (v) => '$v',
            onChanged: (v) => setState(() => _pubDay = v!),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _dateDrop<int>(c,
            items: List.generate(12, (i) => i + 1), value: _pubMonth,
            label: (v) => _months[v - 1],
            onChanged: (v) => setState(() => _pubMonth = v!),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _dateDrop<int>(c,
            items: List.generate(124, (i) => DateTime.now().year - i),
            value: _pubYear, label: (v) => '$v',
            onChanged: (v) => setState(() => _pubYear = v!),
          )),
        ],
      ),
    );
  }

  Widget _dateDrop<T>(AppPalette c, {
    required List<T> items,
    required T value,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:         value,
          isExpanded:    true,
          dropdownColor: c.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: c.textMuted, size: 16),
          style: GoogleFonts.outfit(fontSize: 13, color: c.text),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(label(item),
                style: GoogleFonts.outfit(fontSize: 13, color: c.text)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── PDF section ──────────────────────────────────────────────────────────

  Widget _buildPdfSection(AppPalette c) {
    if (_pdfFile == null) {
      return GestureDetector(
        onTap: _pickPdf,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.brand.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: c.brandSoft, shape: BoxShape.circle,
                    border: Border.all(color: c.brand.withValues(alpha: 0.4))),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: c.brand, size: 24),
              ),
              const SizedBox(height: 10),
              Text('Attach a PDF',
                  style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
              const SizedBox(height: 4),
              Text('Saved on your device — read anytime offline',
                  style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                decoration: BoxDecoration(
                    color: c.brand, borderRadius: BorderRadius.circular(20)),
                child: Text('Choose PDF',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: c.onPrimary)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: c.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pdfFileName ?? 'file.pdf',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: c.text)),
                    Text('Will be saved on your device',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _removePdf,
                child: Icon(Icons.close_rounded,
                    color: c.textMuted, size: 18),
              ),
            ],
          ),
          if (_copyingPdf) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(c.brand),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text('Saving PDF to device…',
                style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
          ],
        ],
      ),
    );
  }

  // ─── Save button ──────────────────────────────────────────────────────────

  Widget _buildSaveButton(AppPalette c) {
    String label = 'Add to Library';
    if (_savingCover) label = 'Saving cover…';
    if (_copyingPdf)  label = 'Saving PDF…';
    if (_saving && !_savingCover && !_copyingPdf) label = 'Adding…';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _saving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: c.onPrimary)),
                ],
              )
            : Text('Add to Library',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: c.onPrimary)),
      ),
    );
  }
}
