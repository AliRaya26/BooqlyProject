import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booqly/models/reading_goal_model.dart';

class GoalsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GoalsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    return user.uid;
  }

  int get _currentYear => DateTime.now().year;

  DocumentReference<Map<String, dynamic>> _goalDoc(int year) =>
      _firestore.collection('users').doc(_uid).collection('goals').doc('$year');

  /// Reads the goal for the current year from Firestore.
  Future<ReadingGoalModel> getGoal() async {
    final snap = await _goalDoc(_currentYear).get();
    if (!snap.exists || snap.data() == null) {
      return const ReadingGoalModel();
    }
    return ReadingGoalModel.fromMap(snap.data()!);
  }

  /// Writes/merges the goal for the current year to Firestore.
  Future<void> saveGoal(ReadingGoalModel goal) async {
    await _goalDoc(_currentYear).set(goal.toMap(), SetOptions(merge: true));
  }

  /// Returns progress for the current year + today.
  Future<GoalProgress> getProgress() async {
    final year = _currentYear;
    final now = DateTime.now();

    // ── Fetch goal ────────────────────────────────────────────────────────────
    final goal = await getGoal();

    // ── Count books completed this year ──────────────────────────────────────
    final yearStart = Timestamp.fromDate(DateTime(year, 1, 1));
    final yearEnd = Timestamp.fromDate(DateTime(year + 1, 1, 1));

    // Query by status only (avoids composite index requirement),
    // then filter completedAt client-side.
    final librarySnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .where('status', isEqualTo: 'completed')
        .get();

    final booksCompletedThisYear = librarySnap.docs.where((doc) {
      final data = doc.data();
      final ts = data['completedAt'];
      if (ts == null || ts is! Timestamp) return false;
      return ts.compareTo(yearStart) >= 0 && ts.compareTo(yearEnd) < 0;
    }).length;

    // ── Sum pages read today ──────────────────────────────────────────────────
    final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final tomorrowStart = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day + 1));

    final sessionsSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('readingSessions')
        .where('date', isGreaterThanOrEqualTo: todayStart)
        .where('date', isLessThan: tomorrowStart)
        .get();

    int pagesReadToday = 0;
    for (final doc in sessionsSnap.docs) {
      final data = doc.data();
      pagesReadToday += (data['pagesRead'] as num?)?.toInt() ?? 0;
    }

    return GoalProgress(
      goal: goal,
      booksCompletedThisYear: booksCompletedThisYear,
      pagesReadToday: pagesReadToday,
      year: year,
    );
  }

  /// Returns a stream of GoalProgress. For simplicity, wraps a single fetch.
  Stream<GoalProgress> progressStream() {
    return Stream.fromFuture(getProgress());
  }
}
