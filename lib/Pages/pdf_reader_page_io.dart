import 'dart:io';
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
  if (book.pdfUrl.startsWith('/')) {
    return SfPdfViewer.file(
      File(book.pdfUrl),
      controller: controller,
      onDocumentLoaded: onDocumentLoaded,
      onPageChanged: onPageChanged,
      onDocumentLoadFailed: onDocumentLoadFailed,
    );
  }
  return SfPdfViewer.network(
    book.pdfUrl,
    controller: controller,
    onDocumentLoaded: onDocumentLoaded,
    onPageChanged: onPageChanged,
    onDocumentLoadFailed: onDocumentLoadFailed,
  );
}
