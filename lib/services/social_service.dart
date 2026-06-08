import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PublicUserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String? currentBookTitle;
  final String? currentBookCover;
  final int booksCompleted;
  final int readingStreak;
  final bool isFollowing;

  const PublicUserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.currentBookTitle,
    this.currentBookCover,
    required this.booksCompleted,
    required this.readingStreak,
    required this.isFollowing,
  });

  String get displayName =>
      '$firstName ${lastName.isNotEmpty ? lastName : ''}'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }
}

class FriendActivity {
  final String ownerUid;
  final String userName;
  final String bookTitle;
  final String bookId;       // for navigation
  final String? bookCover;
  final String activityType; // 'reading' | 'completed' | 'note' | 'quote' | 'review'
  final DateTime timestamp;
  final String? noteText;    // note/quote text
  final int? rating;         // review star rating
  final String? reviewText;  // review comment

  const FriendActivity({
    required this.ownerUid,
    required this.userName,
    required this.bookTitle,
    required this.bookId,
    this.bookCover,
    required this.activityType,
    required this.timestamp,
    this.noteText,
    this.rating,
    this.reviewText,
  });
}

class SocialService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Following ──────────────────────────────────────────────────────────────

  Future<void> follow(String targetUid) async {
    final uid = _uid;
    if (uid == null || uid == targetUid) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid)
        .set({'followedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unfollow(String targetUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid)
        .delete();
  }

  Future<bool> isFollowing(String targetUid) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  Stream<List<String>> followingUidsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<PublicUserProfile>> searchUsers(String query) async {
    final uid = _uid;
    if (uid == null || query.trim().length < 2) return [];

    try {
      final q = query.trim().toLowerCase();

      final followingSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final followingSet = followingSnap.docs.map((d) => d.id).toSet();

      // Client-side filtering — the old startAt/endAt range query had a bug
      // (endAt == startAt), so we fetch up to 200 users and filter locally.
      final snap = await _db.collection('users').limit(200).get();

      final results = <PublicUserProfile>[];
      for (final doc in snap.docs) {
        if (doc.id == uid) continue;
        final data = doc.data();
        final first = (data['firstName'] as String? ?? '').toLowerCase();
        final last  = (data['lastName']  as String? ?? '').toLowerCase();
        final email = (data['email']     as String? ?? '').toLowerCase();
        if (!'$first $last'.contains(q) && !email.contains(q)) continue;
        results.add(await _buildProfile(doc.id, data, followingSet));
        if (results.length >= 20) break;
      }

      return results;
    } catch (e) {
      debugPrint('SocialService.searchUsers: $e');
      return [];
    }
  }

  Future<PublicUserProfile> _buildProfile(
    String targetUid,
    Map<String, dynamic> data,
    Set<String> followingSet,
  ) async {
    String? currentBookTitle;
    String? currentBookCover;
    int booksCompleted = 0;
    const int streak = 0;

    try {
      final librarySnap = await _db
          .collection('users')
          .doc(targetUid)
          .collection('library')
          .where('status', isEqualTo: 'reading')
          .orderBy('lastReadAt', descending: true)
          .limit(1)
          .get();
      if (librarySnap.docs.isNotEmpty) {
        final ld = librarySnap.docs.first.data();
        currentBookTitle = ld['title'] as String?;
        currentBookCover = ld['coverUrl'] as String?;
      }

      final completedSnap = await _db
          .collection('users')
          .doc(targetUid)
          .collection('library')
          .where('status', isEqualTo: 'completed')
          .count()
          .get();
      booksCompleted = completedSnap.count ?? 0;
    } catch (_) {}

    return PublicUserProfile(
      uid: targetUid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      currentBookTitle: currentBookTitle,
      currentBookCover: currentBookCover,
      booksCompleted: booksCompleted,
      readingStreak: streak,
      isFollowing: followingSet.contains(targetUid),
    );
  }

  // ── Following profiles ─────────────────────────────────────────────────────

  Future<List<PublicUserProfile>> getFollowingProfiles() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final followingSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .get();
      final uids = followingSnap.docs.map((d) => d.id).toList();
      final followingSet = uids.toSet();

      final profiles = <PublicUserProfile>[];
      for (final targetUid in uids) {
        final doc = await _db.collection('users').doc(targetUid).get();
        if (!doc.exists) continue;
        profiles.add(await _buildProfile(targetUid, doc.data()!, followingSet));
      }
      return profiles;
    } catch (e) {
      debugPrint('SocialService.getFollowingProfiles: $e');
      return [];
    }
  }

  // ── Activity feed ──────────────────────────────────────────────────────────

  Future<List<FriendActivity>> getActivityFeed() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final followingSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final uids = followingSnap.docs.map((d) => d.id).toList();
      if (uids.isEmpty) return [];

      final activities = <FriendActivity>[];
      final since = DateTime.now().subtract(const Duration(days: 30));
      final sinceTs = Timestamp.fromDate(since);

      for (final targetUid in uids.take(10)) {
        final userDoc = await _db.collection('users').doc(targetUid).get();
        if (!userDoc.exists) continue;
        final uData = userDoc.data()!;
        final name =
            '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'.trim();

        // ── Reading sessions ───────────────────────────────────────────────
        try {
          final sessionSnap = await _db
              .collection('users')
              .doc(targetUid)
              .collection('readingSessions')
              .where('date', isGreaterThanOrEqualTo: sinceTs)
              .orderBy('date', descending: true)
              .limit(3)
              .get();

          for (final s in sessionSnap.docs) {
            final sd = s.data();
            activities.add(FriendActivity(
              ownerUid: targetUid,
              userName: name,
              bookTitle: sd['bookTitle'] as String? ?? 'a book',
              bookId: sd['bookId'] as String? ?? '',
              activityType: 'reading',
              timestamp: (sd['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ));
          }
        } catch (_) {}

        // ── Notes & quotes ─────────────────────────────────────────────────
        try {
          // Get their recently active library books (limit 5)
          final librarySnap = await _db
              .collection('users')
              .doc(targetUid)
              .collection('library')
              .orderBy('lastReadAt', descending: true)
              .limit(5)
              .get();

          for (final libDoc in librarySnap.docs) {
            final ld = libDoc.data();
            final bookId = libDoc.id;
            final bookTitle = ld['title'] as String? ?? 'a book';

            final notesSnap = await _db
                .collection('users')
                .doc(targetUid)
                .collection('library')
                .doc(bookId)
                .collection('notes')
                .orderBy('createdAt', descending: true)
                .limit(2)
                .get();

            for (final n in notesSnap.docs) {
              final nd = n.data();
              final noteTs = (nd['createdAt'] as Timestamp?)?.toDate();
              if (noteTs == null || noteTs.isBefore(since)) continue;
              activities.add(FriendActivity(
                ownerUid: targetUid,
                userName: name,
                bookTitle: bookTitle,
                bookId: bookId,
                activityType: nd['type'] == 'quote' ? 'quote' : 'note',
                timestamp: noteTs,
                noteText: nd['text'] as String?,
              ));
            }
          }
        } catch (_) {}

        // ── Reviews ────────────────────────────────────────────────────────
        try {
          final reviewSnap = await _db
              .collection('users')
              .doc(targetUid)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();

          for (final r in reviewSnap.docs) {
            final rd = r.data();
            final reviewTs = (rd['createdAt'] as Timestamp?)?.toDate();
            if (reviewTs == null || reviewTs.isBefore(since)) continue;
            activities.add(FriendActivity(
              ownerUid: targetUid,
              userName: name,
              bookTitle: rd['bookTitle'] as String? ?? 'a book',
              bookId: rd['bookId'] as String? ?? r.id,
              activityType: 'review',
              timestamp: reviewTs,
              rating: (rd['rating'] as num?)?.toInt(),
              reviewText: rd['comment'] as String?,
            ));
          }
        } catch (_) {}
      }

      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(50).toList();
    } catch (e) {
      debugPrint('SocialService.getActivityFeed: $e');
      return [];
    }
  }

  // ── Fetch a friend's notes for a specific book ─────────────────────────────

  Future<List<Map<String, dynamic>>> getFriendNotesForBook({
    required String friendUid,
    required String bookId,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(friendUid)
          .collection('library')
          .doc(bookId)
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('SocialService.getFriendNotesForBook: $e');
      return [];
    }
  }

  // ── Fetch a book from the catalog ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getBookData(String bookId) async {
    try {
      final doc = await _db.collection('books').doc(bookId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (_) {
      return null;
    }
  }

  // ── Reading Wrapped data ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWrappedData(int year) async {
    final uid = _uid;
    if (uid == null) return {};

    final yearStart = Timestamp.fromDate(DateTime(year));
    final yearEnd = Timestamp.fromDate(DateTime(year + 1));

    try {
      final completedSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('library')
          .where('status', isEqualTo: 'completed')
          .get();
      final booksCompleted = completedSnap.docs.where((doc) {
        final ts = doc.data()['completedAt'];
        if (ts == null || ts is! Timestamp) return false;
        return ts.compareTo(yearStart) >= 0 && ts.compareTo(yearEnd) < 0;
      }).length;

      final sessionsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('readingSessions')
          .where('date', isGreaterThanOrEqualTo: yearStart)
          .where('date', isLessThan: yearEnd)
          .get();

      int totalPages = 0;
      int totalMinutes = 0;
      final bookReadCount = <String, int>{};

      for (final s in sessionsSnap.docs) {
        final d = s.data();
        totalPages += (d['pagesRead'] as num?)?.toInt() ?? 0;
        totalMinutes += (d['durationMinutes'] as num?)?.toInt() ?? 0;
        final bId = d['bookId'] as String? ?? '';
        if (bId.isNotEmpty) {
          bookReadCount[bId] = (bookReadCount[bId] ?? 0) + 1;
        }
      }

      String? topBookId;
      int topCount = 0;
      bookReadCount.forEach((bid, n) {
        if (n > topCount) {
          topCount = n;
          topBookId = bid;
        }
      });

      String? topBookTitle;
      String? topBookCover;
      if (topBookId != null) {
        final bookDoc = await _db
            .collection('users')
            .doc(uid)
            .collection('library')
            .doc(topBookId)
            .get();
        if (bookDoc.exists) {
          topBookTitle = bookDoc.data()?['title'] as String?;
          topBookCover = bookDoc.data()?['coverUrl'] as String?;
        }
      }

      final userDoc = await _db.collection('users').doc(uid).get();
      final firstName = userDoc.data()?['firstName'] as String? ?? 'Reader';

      return {
        'year': year,
        'firstName': firstName,
        'booksCompleted': booksCompleted,
        'totalPages': totalPages,
        'totalHours': (totalMinutes / 60).round(),
        'totalSessions': sessionsSnap.docs.length,
        'topBookTitle': topBookTitle,
        'topBookCover': topBookCover,
      };
    } catch (e) {
      debugPrint('SocialService.getWrappedData: $e');
      return {};
    }
  }
}
