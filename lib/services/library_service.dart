import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibraryService {

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────
  // ADD BOOK TO USER LIBRARY
  // ─────────────────────────────────────────────
  Future<void> addBook({

    required String bookId,
    required String status,
    required int totalPages,

  }) async {

    // Current logged user
    final user = _auth.currentUser;

    // Stop if user not logged in
    if (user == null) return;

    // Save inside:
    // users -> uid -> library -> bookId
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc(bookId)
        .set({

      // reading / want_to_read / completed
      'status': status,

      // Reading progress
      'currentPage': 0,
      'totalPages': totalPages,

      // Save time
      'addedAt': Timestamp.now(),
    });
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