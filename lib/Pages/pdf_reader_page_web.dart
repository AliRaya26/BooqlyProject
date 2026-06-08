import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:booqly/models/book_model.dart';

Widget buildPdfViewer({
  required BookModel book,
  required PdfViewerController controller,
  required void Function(PdfDocumentLoadedDetails) onDocumentLoaded,
  required void Function(PdfPageChangedDetails) onPageChanged,
  required void Function(PdfDocumentLoadFailedDetails) onDocumentLoadFailed,
}) {
  // On web, only network URLs are supported (no local File access).
  return SfPdfViewer.network(
    book.pdfUrl,
    controller: controller,
    onDocumentLoaded: onDocumentLoaded,
    onPageChanged: onPageChanged,
    onDocumentLoadFailed: onDocumentLoadFailed,
  );
}
