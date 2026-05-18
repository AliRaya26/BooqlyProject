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

  final user = _auth.currentUser;
  if (user == null) return;

  await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('library')
      .doc(bookId)
      .set({

    'status': status,

    'currentPage': 0,
    'totalPages': totalPages,

    // ✅ ADD THIS
    'progress': 0.0,

    // ✅ VERY IMPORTANT FOR HOME PAGE
    'lastReadAt': Timestamp.now(),

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