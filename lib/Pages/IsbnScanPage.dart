import 'package:booqly/services/gemini_isbn_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class IsbnScanPage extends StatefulWidget {
  const IsbnScanPage({super.key});

  @override
  State<IsbnScanPage> createState() => _IsbnScanPageState();
}

class _IsbnScanPageState extends State<IsbnScanPage> {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  final _isbnService = GeminiIsbnService();

  bool _scanning = true;
  bool _torchOn = false;
  bool _looking = false;
  String? _scannedIsbn;
  IsbnBookResult? _result;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '');

    // Accept ISBN-13 (EAN-13 starting 978 or 979) or ISBN-10
    final isIsbn13 = cleaned.length == 13 &&
        (cleaned.startsWith('978') || cleaned.startsWith('979'));
    final isIsbn10 = cleaned.length == 10 &&
        RegExp(r'^\d{9}[\dXx]$').hasMatch(cleaned);
    if (!isIsbn13 && !isIsbn10) { return; }

    setState(() {
      _scanning = false;
      _looking = true;
      _scannedIsbn = cleaned;
      _result = null;
      _error = null;
    });
    await _scanner.stop();

    try {
      final result = await _isbnService.lookupIsbn(cleaned);
      if (mounted) { setState(() { _result = result; _looking = false; }); }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not look up this ISBN. Check your connection and try again.';
        _looking = false;
      });
    }
  }

  void _rescan() {
    setState(() {
      _scanning = true;
      _looking = false;
      _scannedIsbn = null;
      _result = null;
      _error = null;
      _saved = false;
    });
    _scanner.start();
  }

  Future<void> _addToLibrary(String status) async {
    final result = _result;
    if (result == null || !result.found) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saved = true);

    try {
      final docId = 'isbn_${result.isbn}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('library')
          .doc(docId)
          .set({
        'title': result.title,
        'author': result.author,
        'description': result.description,
        'category': result.category,
        'totalPages': result.totalPages,
        'coverUrl': result.coverUrl ?? '',
        'pdfUrl': '',
        'status': status,
        'progress': 0.0,
        'currentPage': 0,
        'isbn': result.isbn,
        'addedAt': FieldValue.serverTimestamp(),
        if (status == 'reading')
          'lastReadAt': FieldValue.serverTimestamp(),
        if (status == 'completed')
          'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '"${result.title}" added to your library.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.of(context).brand,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saved = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.of(context).error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan ISBN Barcode',
          style: GoogleFonts.outfit(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (_scanning)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn ? c.warning : Colors.white,
              ),
              onPressed: () async {
                await _scanner.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
              tooltip: 'Toggle torch',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _scanning || _looking
          ? _buildScannerView(c)
          : _buildResultView(c),
    );
  }

  // ── Scanner view ────────────────────────────────────────────────────────────

  Widget _buildScannerView(AppPalette c) {
    return Stack(
      children: [
        // Camera feed
        MobileScanner(
          controller: _scanner,
          onDetect: _onBarcodeDetected,
        ),

        // Overlay with cutout
        CustomPaint(
          painter: _ScanOverlayPainter(brandColor: c.brand),
          child: const SizedBox.expand(),
        ),

        // Hint text
        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _looking
                    ? 'Found ISBN $_scannedIsbn — looking up book…'
                    : 'Point the camera at the barcode\non the back of the book',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Loading spinner while looking up
        if (_looking)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: c.brand),
                  const SizedBox(height: 16),
                  Text(
                    'Looking up ISBN $_scannedIsbn…',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Result view ─────────────────────────────────────────────────────────────

  Widget _buildResultView(AppPalette c) {
    if (_error != null) {
      return _ErrorResult(
        isbn: _scannedIsbn ?? '',
        message: _error!,
        onRetry: _rescan,
        c: c,
      );
    }

    final result = _result;
    if (result == null) return const SizedBox.shrink();

    if (!result.found) {
      return _NotFoundResult(
        isbn: _scannedIsbn ?? '',
        onRescan: _rescan,
        c: c,
      );
    }

    return _FoundResult(
      result: result,
      saved: _saved,
      onRescan: _rescan,
      onAdd: _addToLibrary,
      c: c,
    );
  }
}

// ── Scan overlay ──────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({required this.brandColor});
  final Color brandColor;

  @override
  void paint(Canvas canvas, Size size) {
    const cutW = 280.0;
    const cutH = 120.0;
    final left = (size.width - cutW) / 2;
    final top = (size.height - cutH) / 2 - 40;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutW, cutH),
      const Radius.circular(12),
    );

    // Dark overlay
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addRRect(rect);
    canvas.drawPath(
        Path.combine(PathOperation.difference, full, cutout), overlay);

    // Border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rect, border);

    // Corner accents
    const accentRadius = 12.0;
    final accent = Paint()
      ..color = brandColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final corners = [
      [Offset(left, top + accentRadius), Offset(left, top), Offset(left + accentRadius, top)],
      [Offset(left + cutW - accentRadius, top), Offset(left + cutW, top), Offset(left + cutW, top + accentRadius)],
      [Offset(left, top + cutH - accentRadius), Offset(left, top + cutH), Offset(left + accentRadius, top + cutH)],
      [Offset(left + cutW - accentRadius, top + cutH), Offset(left + cutW, top + cutH), Offset(left + cutW, top + cutH - accentRadius)],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, accent);
    }

    // Scan line
    final linePaint = Paint()
      ..color = brandColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(left + 8, top + cutH / 2),
      Offset(left + cutW - 8, top + cutH / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.brandColor != brandColor;
}

// ── Found result ──────────────────────────────────────────────────────────────

class _FoundResult extends StatelessWidget {
  const _FoundResult({
    required this.result,
    required this.saved,
    required this.onRescan,
    required this.onAdd,
    required this.c,
  });

  final IsbnBookResult result;
  final bool saved;
  final VoidCallback onRescan;
  final void Function(String status) onAdd;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ISBN chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ISBN ${result.isbn}',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: c.brand,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              // Book card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: result.coverUrl != null &&
                            result.coverUrl!.isNotEmpty
                        ? Image.network(result.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx2, err, stack) =>
                                _coverPlaceholder(c))
                        : _coverPlaceholder(c),
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: GoogleFonts.figtree(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.author,
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: c.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          _chip(result.category, c),
                          if (result.totalPages > 0)
                            _chip('${result.totalPages} pages', c),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Description
              if (result.description.isNotEmpty) ...[
                Text(
                  'About this book',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  result.description,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: c.text, height: 1.6),
                ),
                const SizedBox(height: 28),
              ],

              // Add buttons
              if (!saved) ...[
                Text(
                  'Add to library as…',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted),
                ),
                const SizedBox(height: 12),
                _AddButton(
                  icon: Icons.bookmark_add_rounded,
                  label: 'Want to Read',
                  color: c.brand,
                  onTap: () => onAdd('want_to_read'),
                ),
                const SizedBox(height: 10),
                _AddButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Currently Reading',
                  color: c.brand,
                  onTap: () => onAdd('reading'),
                ),
                const SizedBox(height: 10),
                _AddButton(
                  icon: Icons.check_circle_rounded,
                  label: 'Already Read',
                  color: c.success,
                  onTap: () => onAdd('completed'),
                ),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: c.success, size: 20),
                        const SizedBox(width: 8),
                        Text('Added to library',
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.success)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: onRescan,
                  icon: Icon(Icons.qr_code_scanner_rounded,
                      color: c.textMuted, size: 18),
                  label: Text('Scan another book',
                      style: GoogleFonts.outfit(
                          color: c.textMuted, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(AppPalette c) => Center(
        child: Icon(Icons.menu_book_rounded, color: c.textMuted, size: 32),
      );

  Widget _chip(String label, AppPalette c) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        child: Text(label,
            style:
                GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: c.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Not found ─────────────────────────────────────────────────────────────────

class _NotFoundResult extends StatelessWidget {
  const _NotFoundResult(
      {required this.isbn, required this.onRescan, required this.c});
  final String isbn;
  final VoidCallback onRescan;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.search_off_rounded,
                      color: c.textMuted, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Book not found',
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 8),
                Text(
                  'ISBN $isbn was not recognised.\nTry scanning again or add manually.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: c.textMuted, height: 1.6),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: onRescan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text('Scan again',
                      style:
                          GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorResult extends StatelessWidget {
  const _ErrorResult({
    required this.isbn,
    required this.message,
    required this.onRetry,
    required this.c,
  });
  final String isbn;
  final String message;
  final VoidCallback onRetry;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: c.error, size: 48),
                const SizedBox(height: 16),
                Text('Lookup failed',
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: c.textMuted, height: 1.5)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Try again',
                      style:
                          GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
