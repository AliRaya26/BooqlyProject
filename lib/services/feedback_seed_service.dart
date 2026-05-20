import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:flutter/foundation.dart';

/// Writes demo reader feedback into `books/{id}/feedbacks` when empty.
class FeedbackSeedService {
  FeedbackSeedService({
    BookService? bookService,
    FirebaseFirestore? firestore,
  })  : _bookService = bookService ?? BookService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final BookService _bookService;
  final FirebaseFirestore _firestore;

  static const _reviewers = [
    'Alex K.',
    'Jordan P.',
    'Morgan L.',
    'Riley S.',
    'Casey T.',
    'Sam D.',
    'Taylor N.',
    'Jamie W.',
  ];

  static const _commentTemplates = [
    '{title} is exactly what I needed — clear, engaging, and worth every page.',
    'I finished {title} faster than expected. {author} explains ideas in a way that sticks.',
    'Solid read. Some sections of {title} are dense, but the payoff is real.',
    '{title} changed how I think about {category}. Highly recommend for curious readers.',
    'Good book overall. {title} has a few slow chapters, but the core message lands well.',
    'One of the better {category} picks on Booqly. {title} deserves a spot on your shelf.',
  ];

  /// Seeds 5 reviews per catalog book that has none yet.
  Future<int> seedDummyFeedbacksIfNeeded() async {
    final books = await _bookService.getBooks();
    if (books.isEmpty) return 0;

    var written = 0;
    for (final book in books) {
      written += await _seedBookIfEmpty(book);
    }

    if (written > 0) {
      debugPrint('FeedbackSeed: wrote $written dummy review(s).');
    }
    return written;
  }

  Future<int> _seedBookIfEmpty(BookModel book) async {
    final col = _firestore
        .collection('books')
        .doc(book.id)
        .collection('feedbacks');

    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return 0;

    final seed = _hashString(book.id);
    final batch = _firestore.batch();

    for (var i = 0; i < 5; i++) {
      final reviewer = _reviewers[(seed + i) % _reviewers.length];
      final rating = 3 + ((seed + i * 7) % 3);
      final template = _commentTemplates[(seed + i) % _commentTemplates.length];
      final comment = template
          .replaceAll('{title}', book.title)
          .replaceAll('{author}', book.author)
          .replaceAll('{category}', book.category.isNotEmpty ? book.category : 'this genre');

      final daysAgo = 5 + i * 11 + (seed % 20);
      final createdAt = DateTime.now().subtract(Duration(days: daysAgo));

      final docId = 'fb_${i + 1}';
      batch.set(col.doc(docId), {
        'bookId': book.id,
        'userName': reviewer,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      });
    }

    await batch.commit();
    return 5;
  }

  int _hashString(String value) {
    var hash = 0;
    for (var i = 0; i < value.length; i++) {
      hash = ((hash << 5) - hash + value.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }
}
