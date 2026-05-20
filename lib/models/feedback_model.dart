import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String bookId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const FeedbackModel({
    required this.id,
    required this.bookId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory FeedbackModel.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    required String bookId,
  }) {
    final created = map['createdAt'];
    return FeedbackModel(
      id: documentId,
      bookId: bookId,
      userName: map['userName'] as String? ?? 'Reader',
      rating: (map['rating'] as num?)?.round().clamp(1, 5) ?? 5,
      comment: map['comment'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class BookFeedbackSummary {
  final String bookId;
  final double averageRating;
  final int count;
  final List<FeedbackModel> recent;

  const BookFeedbackSummary({
    required this.bookId,
    required this.averageRating,
    required this.count,
    this.recent = const [],
  });

  static const empty = BookFeedbackSummary(
    bookId: '',
    averageRating: 0,
    count: 0,
  );

  bool get hasReviews => count > 0;

  String get averageRatingLabel =>
      hasReviews ? averageRating.toStringAsFixed(1) : '—';

  String formatForChat({String? title, String? author}) {
    if (!hasReviews) {
      final label = title != null ? '"$title"' : 'This book';
      return '$label has no reader feedback in Booqly yet.';
    }

    final bookLabel = title != null
        ? '"$title"${author != null ? ' by $author' : ''}'
        : 'This book';

    final buffer = StringBuffer()
      ..writeln(
        '$bookLabel: ${averageRating.toStringAsFixed(1)}/5 average '
        'from $count reader review${count == 1 ? '' : 's'}.',
      );

    for (final review in recent.take(4)) {
      buffer.writeln(
        '- ${review.userName} (${review.rating}/5): ${review.comment}',
      );
    }

    return buffer.toString().trim();
  }
}
