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
  final String uid;
  final String userName;
  final String bookTitle;
  final String? bookCover;
  final String activityType; // 'reading' | 'completed' | 'added'
  final DateTime timestamp;

  const FriendActivity({
    required this.uid,
    required this.userName,
    required this.bookTitle,
    this.bookCover,
    required this.activityType,
    required this.timestamp,
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

      // Get following list for isFollowing check
      final followingSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final followingSet =
          followingSnap.docs.map((d) => d.id).toSet();

      // Search by firstName (case-insensitive prefix via range query)
      final snap = await _db
          .collection('users')
          .orderBy('firstName')
          .startAt([q[0].toUpperCase() + q.substring(1)])
          .endAt([q[0].toUpperCase() + q.substring(1) + ''])
          .limit(20)
          .get();

      final results = <PublicUserProfile>[];
      for (final doc in snap.docs) {
        if (doc.id == uid) continue; // exclude self
        final data = doc.data();
        final first = (data['firstName'] as String? ?? '').toLowerCase();
        final last = (data['lastName'] as String? ?? '').toLowerCase();
        final email = (data['email'] as String? ?? '').toLowerCase();
        if (!first.contains(q) && !last.contains(q) && !email.contains(q)) {
          continue;
        }
        results.add(await _buildProfile(doc.id, data, followingSet));
      }

      // Also try email exact match
      if (query.contains('@')) {
        final emailSnap = await _db
            .collection('users')
            .where('email', isEqualTo: query.trim().toLowerCase())
            .limit(5)
            .get();
        for (final doc in emailSnap.docs) {
          if (doc.id == uid) continue;
          if (results.any((r) => r.uid == doc.id)) continue;
          results.add(
              await _buildProfile(doc.id, doc.data(), followingSet));
        }
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
    // Get their current reading book
    String? currentBookTitle;
    String? currentBookCover;
    int booksCompleted = 0;
    int streak = 0;

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
        // We need the book title — stored in library or we skip
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
        final doc =
            await _db.collection('users').doc(targetUid).get();
        if (!doc.exists) continue;
        profiles.add(
            await _buildProfile(targetUid, doc.data()!, followingSet));
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
      final since = DateTime.now().subtract(const Duration(days: 7));

      for (final targetUid in uids.take(10)) {
        final userDoc =
            await _db.collection('users').doc(targetUid).get();
        if (!userDoc.exists) continue;
        final uData = userDoc.data()!;
        final name =
            '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'
                .trim();

        // Recent reading sessions
        final sessionSnap = await _db
            .collection('users')
            .doc(targetUid)
            .collection('readingSessions')
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .orderBy('date', descending: true)
            .limit(3)
            .get();

        for (final s in sessionSnap.docs) {
          final sd = s.data();
          activities.add(FriendActivity(
            uid: targetUid,
            userName: name,
            bookTitle: sd['bookTitle'] as String? ?? 'a book',
            activityType: 'reading',
            timestamp:
                (sd['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }
      }

      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(30).toList();
    } catch (e) {
      debugPrint('SocialService.getActivityFeed: $e');
      return [];
    }
  }

  // ── Reading Wrapped data ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWrappedData(int year) async {
    final uid = _uid;
    if (uid == null) return {};

    final yearStart = Timestamp.fromDate(DateTime(year));
    final yearEnd = Timestamp.fromDate(DateTime(year + 1));

    try {
      // Books completed this year — query by status only, filter dates client-side
      // (avoids composite index requirement)
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

      // Reading sessions stats
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

      // Most read book
      String? topBookId;
      int topCount = 0;
      bookReadCount.forEach((bid, count) {
        if (count > topCount) {
          topCount = count;
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

      // User name
      final userDoc = await _db.collection('users').doc(uid).get();
      final firstName =
          userDoc.data()?['firstName'] as String? ?? 'Reader';

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
