import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────

class _C {
  static const bg      = Color(0xFF0E0C0A);
  static const surface = Color(0xFF1A1713);
  static const border  = Color(0xFF2A2520);
  static const gold    = Color(0xFFD4A96A);
  static const goldMut = Color(0x1FD4A96A);
  static const goldDim = Color(0x4DD4A96A);
  static const ink     = Color(0xFFF5F0E8);
  static const muted   = Color(0xFF888580);
}

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
  File?   _coverImage;
  bool    _savingCover = false;

  // ── PDF ──────────────────────────────────────────────────────────────────
  File?   _pdfFile;
  String? _pdfFileName;
  bool    _copyingPdf  = false;

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

  // Save cover to app documents folder, return local path
  Future<String> _saveCoverLocally(String bookId) async {
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/covers/$bookId.jpg');
    await dest.parent.create(recursive: true);
    await _coverImage!.copy(dest.path);
    debugPrint('✅ Cover saved: ${dest.path}');
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

  // Copy PDF into app documents — returns local path
  Future<String> _savePdfLocally(String bookId) async {
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/pdfs/$bookId.pdf');
    await dest.parent.create(recursive: true);
    await _pdfFile!.copy(dest.path);
    debugPrint('✅ PDF saved locally: ${dest.path}');
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
      // Generate a book ID
      final bookRef = FirebaseFirestore.instance.collection('books').doc();
      final bookId  = bookRef.id;

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

      // ── Write book metadata to Firestore ──
      // pdfUrl and coverUrl store the LOCAL file path
      // PdfReaderPage will use File(book.pdfUrl) to open it
      await bookRef.set({
        'title':          title,
        'author':         _authorCtrl.text.trim(),
        'translator':     _translatorCtrl.text.trim(),
        'narrator':       _narratorCtrl.text.trim(),
        'publisher':      _publisherCtrl.text.trim(),
        'description':    _descriptionCtrl.text.trim(),
        'language':       _language,
        'category':       _category,
        'totalPages':     int.tryParse(_totalPagesCtrl.text.trim()) ?? 0,
        'coverUrl':       localCoverPath,   // local path
        'pdfUrl':         localPdfPath,     // local path
        'isLocal':        true,             // flag so UI knows it's a local file
        'publishedAt':    '$_pubDay ${_months[_pubMonth - 1]} $_pubYear',
        'addedBy':        user.uid,
        'source':         'manual',
        'createdAt':      Timestamp.now(),
      });

      debugPrint('✅ Book saved: $bookId');

      // ── Add to user library ──
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(bookId)
          .set({
            'status':      'want_to_read',
            'currentPage': 0,
            'totalPages':  int.tryParse(_totalPagesCtrl.text.trim()) ?? 0,
            'progress':    0.0,
            'lastReadAt':  Timestamp.now(),
            'addedAt':     Timestamp.now(),
          });

      debugPrint('✅ Library entry added');

      if (!mounted) return;
      _snack('Book added to your library ✓');
      Navigator.pop(context);

    } catch (e, stack) {
      debugPrint('❌ Save error: $e');
      debugPrint('❌ Stack: $stack');
      if (mounted) _snack('Error: ${e.toString()}');
    }

    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: _C.ink)),
      backgroundColor: _C.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _sectionTitle('Book Info'),
                    _buildCoverPicker(),
                    _field(_titleCtrl,      'Title',       Icons.title_rounded),
                    _field(_totalPagesCtrl, 'Total pages', Icons.menu_book_rounded,
                        keyboardType: TextInputType.number),
                    _row([
                      _dropdown('Language', _languages, _language,
                          (v) => setState(() => _language = v!)),
                      const SizedBox(width: 12),
                      _dropdown('Category', _categories, _category,
                          (v) => setState(() => _category = v!)),
                    ]),

                    _sectionTitle('Creators'),
                    _field(_authorCtrl,     'Author(s)',  Icons.person_rounded),
                    _field(_translatorCtrl, 'Translator', Icons.translate_rounded),
                    _field(_narratorCtrl,   'Narrator',   Icons.record_voice_over_rounded),

                    _sectionTitle('Publication'),
                    _field(_publisherCtrl, 'Publisher', Icons.business_rounded),
                    _buildDatePicker(),
                    _field(_descriptionCtrl, 'Description', Icons.notes_rounded,
                        maxLines: 4, hint: 'A short summary of the book…'),

                    _sectionTitle('PDF File'),
                    _buildPdfSection(),

                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _C.surface, shape: BoxShape.circle,
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.chevron_left_rounded, color: _C.muted, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Text('Add a book',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26, fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic, color: _C.gold)),
        ],
      ),
    );
  }

  // ─── Section title ────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Text(text.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10, letterSpacing: 0.14,
              color: _C.gold, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _C.border)),
        ],
      ),
    );
  }

  // ─── Cover picker ─────────────────────────────────────────────────────────

  Widget _buildCoverPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: _coverImage == null ? _pickCover : null,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _coverImage != null ? _C.gold : _C.border,
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
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Row(
                        children: [
                          _iconOverlayBtn(Icons.edit_rounded, _pickCover),
                          const SizedBox(width: 8),
                          _iconOverlayBtn(Icons.close_rounded,
                              () => setState(() => _coverImage = null)),
                        ],
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.check_circle_rounded,
                          color: Colors.white70, size: 32),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _C.goldMut, shape: BoxShape.circle,
                        border: Border.all(color: _C.goldDim)),
                      child: const Icon(Icons.add_photo_alternate_rounded,
                          color: _C.gold, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text('Add cover image',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w500, color: _C.ink)),
                    const SizedBox(height: 4),
                    Text('Tap to choose from gallery',
                        style: GoogleFonts.outfit(fontSize: 12, color: _C.muted)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _iconOverlayBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ─── Text field ───────────────────────────────────────────────────────────

  Widget _field(
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
        style: GoogleFonts.outfit(fontSize: 14, color: _C.ink),
        decoration: InputDecoration(
          hintText:   hint ?? label,
          hintStyle:  GoogleFonts.outfit(fontSize: 14, color: _C.muted),
          prefixIcon: Icon(icon, size: 18, color: _C.muted),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          filled:     true,
          fillColor:  _C.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: _C.gold, width: 1.2),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical:   maxLines > 1 ? 14 : 0,
            horizontal: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  // ─── Row helper ───────────────────────────────────────────────────────────

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: children
            .map((w) => w is SizedBox ? w : Expanded(child: w))
            .toList(),
      ),
    );
  }

  // ─── Dropdown ─────────────────────────────────────────────────────────────

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:         value,
          isExpanded:    true,
          dropdownColor: _C.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _C.muted, size: 18),
          style: GoogleFonts.outfit(fontSize: 13, color: _C.ink),
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s, style: GoogleFonts.outfit(fontSize: 13, color: _C.ink)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Date picker ──────────────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: _dateDropdown<int>(
            items: List.generate(31, (i) => i + 1), value: _pubDay,
            label: (v) => '$v',
            onChanged: (v) => setState(() => _pubDay = v!),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _dateDropdown<int>(
            items: List.generate(12, (i) => i + 1), value: _pubMonth,
            label: (v) => _months[v - 1],
            onChanged: (v) => setState(() => _pubMonth = v!),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _dateDropdown<int>(
            items: List.generate(124, (i) => DateTime.now().year - i),
            value: _pubYear, label: (v) => '$v',
            onChanged: (v) => setState(() => _pubYear = v!),
          )),
        ],
      ),
    );
  }

  Widget _dateDropdown<T>({
    required List<T> items,
    required T value,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:         value,
          isExpanded:    true,
          dropdownColor: _C.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _C.muted, size: 16),
          style: GoogleFonts.outfit(fontSize: 13, color: _C.ink),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(label(item),
                style: GoogleFonts.outfit(fontSize: 13, color: _C.ink)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── PDF section ──────────────────────────────────────────────────────────

  Widget _buildPdfSection() {
    if (_pdfFile == null) {
      return GestureDetector(
        onTap: _pickPdf,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: _C.goldMut,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.goldDim),
          ),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _C.goldMut, shape: BoxShape.circle,
                  border: Border.all(color: _C.goldDim)),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: _C.gold, size: 24),
              ),
              const SizedBox(height: 10),
              Text('Attach a PDF',
                  style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _C.ink)),
              const SizedBox(height: 4),
              Text('Saved on your device — read anytime offline',
                  style: GoogleFonts.outfit(fontSize: 12, color: _C.muted)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                    color: _C.gold, borderRadius: BorderRadius.circular(20)),
                child: Text('Choose PDF',
                    style: GoogleFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _C.bg)),
              ),
            ],
          ),
        ),
      );
    }

    // PDF selected
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: _C.goldMut,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: _C.gold, size: 20),
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
                            color: _C.ink)),
                    Text('Will be saved on your device',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: _C.muted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _removePdf,
                child: const Icon(Icons.close_rounded, color: _C.muted, size: 18),
              ),
            ],
          ),

          // Copying indicator
          if (_copyingPdf) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              backgroundColor: Color(0x14FFFFFF),
              valueColor: AlwaysStoppedAnimation(_C.gold),
            ),
            const SizedBox(height: 6),
            Text('Saving PDF to device…',
                style: GoogleFonts.outfit(fontSize: 11, color: _C.muted)),
          ],
        ],
      ),
    );
  }

  // ─── Save button ──────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    // Show what's currently happening
    String label = 'Add to Library';
    if (_savingCover) label = 'Saving cover…';
    if (_copyingPdf)  label = 'Saving PDF…';
    if (_saving && !_savingCover && !_copyingPdf) label = 'Adding…';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.gold,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _saving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF0E0C0A)),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _C.bg)),
                ],
              )
            : Text('Add to Library',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _C.bg)),
      ),
    );
  }
}