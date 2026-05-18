import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:booqly/models/book_model.dart';

class PdfReaderPage extends StatefulWidget {
  final BookModel book;

  const PdfReaderPage({
    super.key,
    required this.book,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  int _currentPage = 1;
  int _totalPages = 0;

  // SAVE READING PROGRESS
  Future<void> _saveReadingProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final progress =
        _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(widget.book.id)
        .set({
          "status": "reading",
          "progress": progress,
          "currentPage": _currentPage,
          "lastReadAt": Timestamp.now(),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),

            Text(
              'Page $_currentPage / $_totalPages',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),

      body: SfPdfViewer.network(
        widget.book.pdfUrl,

        controller: _pdfController,

        // TOTAL PAGES
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },

        // PAGE CHANGED
        onPageChanged: (details) async {
          setState(() {
            _currentPage = details.newPageNumber;
          });

          await _saveReadingProgress();
        },
      ),
    );
  }
}