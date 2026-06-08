import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One-shot helper to write dummy social data so the Friends UI can be previewed.
/// Safe to call multiple times (uses set with merge).
class DummyDataService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const _dummyUsers = [
    {
      'uid': 'dummy_user_ahmed',
      'firstName': 'Ahmed',
      'lastName': 'Al-Rashid',
      'email': 'ahmed@example.com',
      'currentBook': 'Atomic Habits',
      'currentBookId': 'dummy_book_ah1',
      'status': 'reading',
    },
    {
      'uid': 'dummy_user_sarah',
      'firstName': 'Sarah',
      'lastName': 'Mitchell',
      'email': 'sarah@example.com',
      'currentBook': null,
      'currentBookId': null,
      'status': null,
    },
    {
      'uid': 'dummy_user_omar',
      'firstName': 'Omar',
      'lastName': 'Hassan',
      'email': 'omar@example.com',
      'currentBook': 'The Alchemist',
      'currentBookId': 'dummy_book_om1',
      'status': 'reading',
    },
    {
      'uid': 'dummy_user_lena',
      'firstName': 'Lena',
      'lastName': 'Kovač',
      'email': 'lena@example.com',
      'currentBook': 'Dune',
      'currentBookId': 'dummy_book_ln1',
      'status': 'reading',
    },
  ];

  static final _sessions = {
    'dummy_user_ahmed': [
      {
        'bookTitle': 'Atomic Habits',
        'bookId': 'dummy_book_ah1',
        'pagesRead': 22,
        'durationMinutes': 35,
        'hoursAgo': 1,
      },
      {
        'bookTitle': 'Atomic Habits',
        'bookId': 'dummy_book_ah1',
        'pagesRead': 18,
        'durationMinutes': 28,
        'hoursAgo': 25,
      },
      {
        'bookTitle': 'Deep Work',
        'bookId': 'dummy_book_ah2',
        'pagesRead': 30,
        'durationMinutes': 50,
        'hoursAgo': 50,
      },
    ],
    'dummy_user_sarah': [
      {
        'bookTitle': 'The Power of Now',
        'bookId': 'dummy_book_sa1',
        'pagesRead': 40,
        'durationMinutes': 60,
        'hoursAgo': 3,
      },
      {
        'bookTitle': 'Sapiens',
        'bookId': 'dummy_book_sa2',
        'pagesRead': 55,
        'durationMinutes': 75,
        'hoursAgo': 48,
      },
    ],
    'dummy_user_omar': [
      {
        'bookTitle': 'The Alchemist',
        'bookId': 'dummy_book_om1',
        'pagesRead': 60,
        'durationMinutes': 90,
        'hoursAgo': 2,
      },
      {
        'bookTitle': 'The Alchemist',
        'bookId': 'dummy_book_om1',
        'pagesRead': 45,
        'durationMinutes': 65,
        'hoursAgo': 26,
      },
    ],
    'dummy_user_lena': [
      {
        'bookTitle': 'Dune',
        'bookId': 'dummy_book_ln1',
        'pagesRead': 35,
        'durationMinutes': 55,
        'hoursAgo': 5,
      },
      {
        'bookTitle': 'Dune',
        'bookId': 'dummy_book_ln1',
        'pagesRead': 28,
        'durationMinutes': 42,
        'hoursAgo': 30,
      },
      {
        'bookTitle': '1984',
        'bookId': 'dummy_book_ln2',
        'pagesRead': 50,
        'durationMinutes': 70,
        'hoursAgo': 96,
      },
    ],
  };

  Future<void> seed() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final batch = _db.batch();
    final now = DateTime.now();

    for (final user in _dummyUsers) {
      final uid = user['uid'] as String;
      final userRef = _db.collection('users').doc(uid);

      // ── User document ──────────────────────────────────────────────────────
      batch.set(userRef, {
        'firstName': user['firstName'],
        'lastName': user['lastName'],
        'email': user['email'],
        'createdAt': Timestamp.fromDate(
            DateTime(2024, 1, 1)), // fixed so it doesn't spam
      }, SetOptions(merge: true));

      // ── Library entry for current book ─────────────────────────────────────
      final bookId = user['currentBookId'] as String?;
      if (bookId != null && user['currentBook'] != null) {
        final libRef = userRef.collection('library').doc(bookId);
        batch.set(libRef, {
          'title': user['currentBook'],
          'status': user['status'],
          'lastReadAt': Timestamp.fromDate(
              now.subtract(Duration(hours: 1))),
        }, SetOptions(merge: true));
      }

      // ── Completed books (so booksCompleted count shows) ────────────────────
      batch.set(
        userRef.collection('library').doc('${uid}_completed_1'),
        {
          'title': 'Thinking, Fast and Slow',
          'status': 'completed',
          'completedAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
        },
        SetOptions(merge: true),
      );
      batch.set(
        userRef.collection('library').doc('${uid}_completed_2'),
        {
          'title': 'The Subtle Art of Not Giving a F*ck',
          'status': 'completed',
          'completedAt': Timestamp.fromDate(now.subtract(const Duration(days: 60))),
        },
        SetOptions(merge: true),
      );

      // ── Current user follows this dummy user ───────────────────────────────
      batch.set(
        _db.collection('users').doc(currentUid).collection('following').doc(uid),
        {'followedAt': Timestamp.fromDate(now.subtract(const Duration(days: 1)))},
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // ── Reading sessions (separate batches per user) ───────────────────────
    for (final entry in _sessions.entries) {
      final uid = entry.key;
      final sessions = entry.value;
      final sessRef = _db.collection('users').doc(uid).collection('readingSessions');

      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        final sessionDate = now.subtract(Duration(hours: s['hoursAgo'] as int));
        await sessRef.doc('${uid}_session_$i').set({
          'bookTitle': s['bookTitle'],
          'bookId': s['bookId'],
          'pagesRead': s['pagesRead'],
          'durationMinutes': s['durationMinutes'],
          'date': Timestamp.fromDate(sessionDate),
        }, SetOptions(merge: true));
      }
    }

    debugPrint('DummyDataService: seeded ${_dummyUsers.length} users + sessions');
  }

  /// Remove dummy following entries from the current user (cleanup).
  Future<void> unseed() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;
    final batch = _db.batch();
    for (final user in _dummyUsers) {
      batch.delete(
        _db
            .collection('users')
            .doc(currentUid)
            .collection('following')
            .doc(user['uid'] as String),
      );
    }
    await batch.commit();
    debugPrint('DummyDataService: removed dummy follows');
  }
}
