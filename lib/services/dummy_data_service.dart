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
      {'bookTitle': 'Atomic Habits', 'bookId': 'dummy_book_ah1', 'pagesRead': 22, 'durationMinutes': 35, 'hoursAgo': 1},
      {'bookTitle': 'Atomic Habits', 'bookId': 'dummy_book_ah1', 'pagesRead': 18, 'durationMinutes': 28, 'hoursAgo': 25},
      {'bookTitle': 'Deep Work', 'bookId': 'dummy_book_ah2', 'pagesRead': 30, 'durationMinutes': 50, 'hoursAgo': 50},
    ],
    'dummy_user_sarah': [
      {'bookTitle': 'The Power of Now', 'bookId': 'dummy_book_sa1', 'pagesRead': 40, 'durationMinutes': 60, 'hoursAgo': 3},
      {'bookTitle': 'Sapiens', 'bookId': 'dummy_book_sa2', 'pagesRead': 55, 'durationMinutes': 75, 'hoursAgo': 48},
    ],
    'dummy_user_omar': [
      {'bookTitle': 'The Alchemist', 'bookId': 'dummy_book_om1', 'pagesRead': 60, 'durationMinutes': 90, 'hoursAgo': 2},
      {'bookTitle': 'The Alchemist', 'bookId': 'dummy_book_om1', 'pagesRead': 45, 'durationMinutes': 65, 'hoursAgo': 26},
    ],
    'dummy_user_lena': [
      {'bookTitle': 'Dune', 'bookId': 'dummy_book_ln1', 'pagesRead': 35, 'durationMinutes': 55, 'hoursAgo': 5},
      {'bookTitle': 'Dune', 'bookId': 'dummy_book_ln1', 'pagesRead': 28, 'durationMinutes': 42, 'hoursAgo': 30},
      {'bookTitle': '1984', 'bookId': 'dummy_book_ln2', 'pagesRead': 50, 'durationMinutes': 70, 'hoursAgo': 96},
    ],
  };

  static final _notes = {
    'dummy_user_ahmed': [
      {
        'bookId': 'dummy_book_ah1', 'bookTitle': 'Atomic Habits',
        'type': 'quote',
        'text': '"You do not rise to the level of your goals. You fall to the level of your systems."',
        'hoursAgo': 2,
      },
      {
        'bookId': 'dummy_book_ah1', 'bookTitle': 'Atomic Habits',
        'type': 'note',
        'text': 'The 1% improvement concept is powerful — small daily gains compound into massive results over time.',
        'hoursAgo': 10,
      },
      {
        'bookId': 'dummy_book_ah2', 'bookTitle': 'Deep Work',
        'type': 'quote',
        'text': '"Clarity about what matters provides clarity about what does not."',
        'hoursAgo': 52,
      },
    ],
    'dummy_user_sarah': [
      {
        'bookId': 'dummy_book_sa1', 'bookTitle': 'The Power of Now',
        'type': 'quote',
        'text': '"Realize deeply that the present moment is all you ever have."',
        'hoursAgo': 4,
      },
      {
        'bookId': 'dummy_book_sa2', 'bookTitle': 'Sapiens',
        'type': 'note',
        'text': 'Fascinating how the Cognitive Revolution ~70,000 years ago changed everything about human society.',
        'hoursAgo': 50,
      },
    ],
    'dummy_user_omar': [
      {
        'bookId': 'dummy_book_om1', 'bookTitle': 'The Alchemist',
        'type': 'quote',
        'text': '"And, when you want something, all the universe conspires in helping you to achieve it."',
        'hoursAgo': 3,
      },
      {
        'bookId': 'dummy_book_om1', 'bookTitle': 'The Alchemist',
        'type': 'note',
        'text': "Santiago's journey is a metaphor for following your Personal Legend — don't let fear stop you.",
        'hoursAgo': 28,
      },
    ],
    'dummy_user_lena': [
      {
        'bookId': 'dummy_book_ln1', 'bookTitle': 'Dune',
        'type': 'quote',
        'text': '"I must not fear. Fear is the mind-killer."',
        'hoursAgo': 6,
      },
      {
        'bookId': 'dummy_book_ln1', 'bookTitle': 'Dune',
        'type': 'note',
        'text': 'The ecological world-building in Dune is unmatched. Herbert clearly did deep research on desert ecosystems.',
        'hoursAgo': 32,
      },
    ],
  };

  static final _reviews = {
    'dummy_user_ahmed': [
      {
        'bookId': 'dummy_book_ah2', 'bookTitle': 'Deep Work',
        'rating': 5,
        'comment': 'Life-changing book. Changed how I structure my work day completely. Must-read for anyone in knowledge work.',
        'hoursAgo': 72,
      },
    ],
    'dummy_user_sarah': [
      {
        'bookId': 'dummy_book_sa2', 'bookTitle': 'Sapiens',
        'rating': 5,
        'comment': 'Brilliant and thought-provoking. Made me rethink everything I thought I knew about human history.',
        'hoursAgo': 96,
      },
      {
        'bookId': 'dummy_book_sa1', 'bookTitle': 'The Power of Now',
        'rating': 4,
        'comment': 'Deeply insightful. Some parts feel repetitive but the core message is profound.',
        'hoursAgo': 15,
      },
    ],
    'dummy_user_omar': [
      {
        'bookId': 'dummy_book_om1', 'bookTitle': 'The Alchemist',
        'rating': 5,
        'comment': 'A timeless fable about following your dreams. Short, beautiful, and deeply motivating.',
        'hoursAgo': 48,
      },
    ],
    'dummy_user_lena': [
      {
        'bookId': 'dummy_book_ln2', 'bookTitle': '1984',
        'rating': 5,
        'comment': 'Haunting and more relevant today than ever. Orwell was a true visionary.',
        'hoursAgo': 100,
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
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      }, SetOptions(merge: true));

      // ── Library entry for current book ─────────────────────────────────────
      final bookId = user['currentBookId'] as String?;
      if (bookId != null && user['currentBook'] != null) {
        batch.set(userRef.collection('library').doc(bookId), {
          'title': user['currentBook'],
          'status': user['status'],
          'lastReadAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        }, SetOptions(merge: true));
      }

      // ── Completed books ────────────────────────────────────────────────────
      batch.set(
        userRef.collection('library').doc('${uid}_completed_1'),
        {
          'title': 'Thinking, Fast and Slow',
          'status': 'completed',
          'lastReadAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'completedAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
        },
        SetOptions(merge: true),
      );
      batch.set(
        userRef.collection('library').doc('${uid}_completed_2'),
        {
          'title': 'The Subtle Art of Not Giving a F*ck',
          'status': 'completed',
          'lastReadAt': Timestamp.fromDate(now.subtract(const Duration(days: 60))),
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

    // ── Reading sessions ───────────────────────────────────────────────────
    for (final entry in _sessions.entries) {
      final uid = entry.key;
      final sessions = entry.value;
      final sessRef = _db.collection('users').doc(uid).collection('readingSessions');
      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        await sessRef.doc('${uid}_session_$i').set({
          'bookTitle': s['bookTitle'],
          'bookId': s['bookId'],
          'pagesRead': s['pagesRead'],
          'durationMinutes': s['durationMinutes'],
          'date': Timestamp.fromDate(now.subtract(Duration(hours: s['hoursAgo'] as int))),
        }, SetOptions(merge: true));
      }
    }

    // ── Notes & quotes ────────────────────────────────────────────────────
    for (final entry in _notes.entries) {
      final uid = entry.key;
      final notesList = entry.value;
      for (int i = 0; i < notesList.length; i++) {
        final n = notesList[i];
        final noteDate = now.subtract(Duration(hours: n['hoursAgo'] as int));
        final bookId = n['bookId'] as String;

        // Ensure library parent doc exists so subcollection writes succeed
        await _db.collection('users').doc(uid).collection('library').doc(bookId).set({
          'title': n['bookTitle'],
          'lastReadAt': Timestamp.fromDate(noteDate),
        }, SetOptions(merge: true));

        await _db
            .collection('users').doc(uid)
            .collection('library').doc(bookId)
            .collection('notes').doc('${uid}_note_$i')
            .set({
          'bookId': bookId,
          'text': n['text'],
          'type': n['type'],
          'createdAt': Timestamp.fromDate(noteDate),
        }, SetOptions(merge: true));
      }
    }

    // ── Reviews ────────────────────────────────────────────────────────────
    for (final entry in _reviews.entries) {
      final uid = entry.key;
      final reviewsList = entry.value;
      for (final r in reviewsList) {
        await _db
            .collection('users').doc(uid)
            .collection('reviews').doc(r['bookId'] as String)
            .set({
          'bookId': r['bookId'],
          'bookTitle': r['bookTitle'],
          'rating': r['rating'],
          'comment': r['comment'],
          'createdAt': Timestamp.fromDate(now.subtract(Duration(hours: r['hoursAgo'] as int))),
        }, SetOptions(merge: true));
      }
    }

    debugPrint('DummyDataService: seeded ${_dummyUsers.length} users + sessions + notes + reviews');
  }

  /// Remove dummy following entries from the current user (cleanup).
  Future<void> unseed() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;
    final batch = _db.batch();
    for (final user in _dummyUsers) {
      batch.delete(
        _db.collection('users').doc(currentUid).collection('following').doc(user['uid'] as String),
      );
    }
    await batch.commit();
    debugPrint('DummyDataService: removed dummy follows');
  }
}
