import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:booqly/models/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _feedbacksRef(String bookId) {
    return _firestore
        .collection('books')
        .doc(bookId)
        .collection('feedbacks');
  }

  Stream<List<FeedbackModel>> feedbacksStream(String bookId) {
    return _feedbacksRef(bookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FeedbackModel.fromMap(
                  doc.data(),
                  doc.id,
                  bookId: bookId,
                ),
              )
              .toList(),
        );
  }

  Future<List<FeedbackModel>> getFeedbacksForBook(String bookId) async {
    final snapshot = await _feedbacksRef(bookId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => FeedbackModel.fromMap(
            doc.data(),
            doc.id,
            bookId: bookId,
          ),
        )
        .toList();
  }

  Future<BookFeedbackSummary> getSummaryForBook(String bookId) async {
    final reviews = await getFeedbacksForBook(bookId);
    return _summaryFromReviews(bookId, reviews);
  }

  Future<Map<String, BookFeedbackSummary>> getSummariesForBooks(
    List<String> bookIds,
  ) async {
    if (bookIds.isEmpty) return {};

    final results = await Future.wait(
      bookIds.map((id) async {
        final summary = await getSummaryForBook(id);
        return MapEntry(id, summary);
      }),
    );

    return Map.fromEntries(results);
  }

  BookFeedbackSummary _summaryFromReviews(
    String bookId,
    List<FeedbackModel> reviews,
  ) {
    if (reviews.isEmpty) {
      return BookFeedbackSummary(
        bookId: bookId,
        averageRating: 0,
        count: 0,
      );
    }

    final total = reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return BookFeedbackSummary(
      bookId: bookId,
      averageRating: total / reviews.length,
      count: reviews.length,
      recent: reviews.take(5).toList(),
    );
  }
}
