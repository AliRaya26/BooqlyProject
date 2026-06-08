import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:booqly/models/book_model.dart';

// Platform-conditional: uses File on native, network-only on web.
// ignore: uri_does_not_exist
import 'pdf_reader_page_io.dart' if (dart.library.html) 'pdf_reader_page_web.dart';

class PdfReaderPage extends StatefulWidget {
  final BookModel book;

  const PdfReaderPage({super.key, required this.book});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  int _currentPage = 1;
  int _totalPages = 0;
  String? _loadError;

  Future<void> _saveReadingProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .set({
          'status': 'reading',
          'progress': progress,
          'currentPage': _currentPage,
          'lastReadAt': Timestamp.now(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              _totalPages > 0
                  ? 'Page $_currentPage / $_totalPages'
                  : 'Loading…',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load PDF.\n$_loadError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          : buildPdfViewer(
              book: widget.book,
              controller: _pdfController,
              onDocumentLoaded: (details) {
                setState(() => _totalPages = details.document.pages.count);
              },
              onPageChanged: (details) {
                setState(() => _currentPage = details.newPageNumber);
                // Fire-and-forget; log errors rather than crashing the viewer.
                _saveReadingProgress().catchError(
                  (e) => debugPrint('PdfReaderPage: save progress failed: $e'),
                );
              },
              onDocumentLoadFailed: (details) {
                setState(() => _loadError = details.description);
              },
            ),
    );
  }
}
