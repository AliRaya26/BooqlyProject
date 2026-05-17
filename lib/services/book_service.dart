import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:booqly/models/book_model.dart';

class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // GET BOOKS ONCE
  // ─────────────────────────────────────────────
  Future<List<BookModel>> getBooks() async {
    final snapshot = await _firestore.collection('books').get();

    return snapshot.docs.map((doc) {
      return BookModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  // ─────────────────────────────────────────────
  // REALTIME STREAM
  // Updates automatically when Firestore changes
  // ─────────────────────────────────────────────
  Stream<List<BookModel>> booksStream() {
    return _firestore.collection('books').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BookModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  List<BookModel> suggestBooks({
    required List<BookModel> catalog,
    required List<String> preferredGenres,
    required Set<String> excludeBookIds,
    int limit = 12,
  }) {
    if (preferredGenres.isEmpty) return [];

    final genreSet = preferredGenres.toSet();
    final matches = catalog
        .where(
          (book) =>
              genreSet.contains(book.category) && !excludeBookIds.contains(book.id),
        )
        .toList();

    matches.sort((a, b) {
      final aIdx = preferredGenres.indexOf(a.category);
      final bIdx = preferredGenres.indexOf(b.category);
      return aIdx.compareTo(bIdx);
    });

    return matches.take(limit).toList();
  }
}