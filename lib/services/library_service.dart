import 'package:booqly/utils/book_cover_url.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibraryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Metadata copied onto library entries so covers/titles render reliably.
  static Map<String, dynamic> bookMetadata({
    String? title,
    String? author,
    String? coverUrl,
    String? category,
  }) {
    final data = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      data['title'] = title.trim();
    }
    if (author != null && author.trim().isNotEmpty) {
      data['author'] = author.trim();
    }
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      data['coverUrl'] = resolveBookCoverUrl(coverUrl);
    }
    if (category != null && category.trim().isNotEmpty) {
      data['category'] = category.trim();
    }
    return data;
  }

  // ─────────────────────────────────────────────
  // ADD BOOK TO USER LIBRARY
  // ─────────────────────────────────────────────
  Future<void> addBook({
    required String bookId,
    required String status,
    required int totalPages,
    String? title,
    String? author,
    String? coverUrl,
    String? category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final payload = <String, dynamic>{
      'status': status,
      'currentPage': 0,
      'totalPages': totalPages,
      'progress': 0.0,
      'lastReadAt': Timestamp.now(),
      'addedAt': Timestamp.now(),
      ...bookMetadata(
        title: title,
        author: author,
        coverUrl: coverUrl,
        category: category,
      ),
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(bookId)
        .set(payload, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────
  // GET USER LIBRARY
  // ─────────────────────────────────────────────
  Future<List<QueryDocumentSnapshot>> getLibraryBooks() async {

    final user = _auth.currentUser;

    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .get();

    return snapshot.docs;
  }
}