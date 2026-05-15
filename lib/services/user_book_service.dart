import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBookService {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ─────────────────────────────────────────
  // ADD BOOK TO USER LIBRARY
  // ─────────────────────────────────────────

  Future<void> addBookToLibrary({
    required String bookId,
    required String title,
    required String author,
    required String coverUrl,
    required int totalPages,
  }) async {

    // Current logged-in user
    final user = _auth.currentUser;

    if (user == null) return;

    // Save inside:
    // users/{uid}/userBooks/{bookId}

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('userBooks')
        .doc(bookId)
        .set({

      // Basic book info
      'title': title,
      'author': author,
      'coverUrl': coverUrl,

      // Reading state
      'status': 'want_to_read',

      // Progress
      'currentPage': 0,
      'totalPages': totalPages,
      'progress': 0,

      // Dates
      'addedAt': Timestamp.now(),
    });
  }

  // ─────────────────────────────────────────
  // UPDATE READING PROGRESS
  // ─────────────────────────────────────────

  Future<void> updateProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) async {

    final user = _auth.currentUser;

    if (user == null) return;

    // Calculate percentage
    final progress =
        ((currentPage / totalPages) * 100).toInt();

    // Determine status
    String status = 'reading';

    if (progress >= 100) {
      status = 'completed';
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('userBooks')
        .doc(bookId)
        .update({

      'currentPage': currentPage,
      'progress': progress,
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }
}