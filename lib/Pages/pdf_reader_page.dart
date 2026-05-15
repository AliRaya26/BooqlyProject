import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.book.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),

      // THIS loads the REAL PDF from Firebase/URL
      body: SfPdfViewer.network(
        widget.book.pdfUrl,
      ),
    );
  }
}