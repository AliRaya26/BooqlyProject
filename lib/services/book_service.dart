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
}