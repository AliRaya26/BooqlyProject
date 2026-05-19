import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/gemini_chat_service.dart';

enum BookMatchLocation {
  inLibrary,
  inCatalogOnly,
  notFound,
}

class BookLookupMatch {
  final BookModel book;
  final BookMatchLocation location;
  final String? libraryStatus;

  const BookLookupMatch({
    required this.book,
    required this.location,
    this.libraryStatus,
  });
}

class BookLookupService {
  BookLookupMatch? findBestMatch({
    required String query,
    required BookChatContext context,
  }) {
    final normalized = _normalize(query);
    if (normalized.length < 2) return null;

    BookLookupMatch? best;
    var bestScore = 0;

    for (final entry in context.libraryBooks) {
      final score = _scoreBook(normalized, entry.book);
      if (score > bestScore && score >= 40) {
        bestScore = score;
        best = BookLookupMatch(
          book: entry.book,
          location: BookMatchLocation.inLibrary,
          libraryStatus: entry.status,
        );
      }
    }

    for (final book in context.catalogBooks) {
      final score = _scoreBook(normalized, book);
      if (score > bestScore && score >= 40) {
        bestScore = score;
        final inLib = context.libraryBooks.any((e) => e.book.id == book.id);
        best = BookLookupMatch(
          book: book,
          location: inLib
              ? BookMatchLocation.inLibrary
              : BookMatchLocation.inCatalogOnly,
          libraryStatus: inLib
              ? context.libraryBooks
                  .firstWhere((e) => e.book.id == book.id)
                  .status
              : null,
        );
      }
    }

    return best;
  }

  String formatLookupSummary(BookLookupMatch? match, {String? queryLabel}) {
    if (match == null) {
      final label = queryLabel != null ? ' "$queryLabel"' : '';
      return 'Not found$label in your library or the Booqly catalog.';
    }

    final b = match.book;
    switch (match.location) {
      case BookMatchLocation.inLibrary:
        final status = _statusLabel(match.libraryStatus ?? '');
        return '✓ "${b.title}" by ${b.author} is in your library ($status).';
      case BookMatchLocation.inCatalogOnly:
        return '"${b.title}" by ${b.author} is in the Booqly catalog but not in your library yet. '
            'You can add it from Search.';
      case BookMatchLocation.notFound:
        return 'Not found in your library or catalog.';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return 'currently reading';
      case 'completed':
        return 'completed';
      case 'want_to_read':
        return 'want to read';
      default:
        return status;
    }
  }

  int _scoreBook(String query, BookModel book) {
    final title = _normalize(book.title);
    final author = _normalize(book.author);
    var score = 0;

    if (title == query || author == query) score += 100;
    if (title.contains(query) || query.contains(title)) score += 70;
    if (author.contains(query) || query.contains(author)) score += 50;

    final words = query.split(' ').where((w) => w.length > 2);
    for (final word in words) {
      if (title.contains(word)) score += 15;
      if (author.contains(word)) score += 10;
    }

    return score;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
}
