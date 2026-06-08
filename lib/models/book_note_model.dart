import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { note, quote }

class BookNoteModel {
  final String id;
  final String bookId;
  final String text;
  final int? pageNumber;
  final NoteType type;
  final DateTime createdAt;

  const BookNoteModel({
    required this.id,
    required this.bookId,
    required this.text,
    this.pageNumber,
    required this.type,
    required this.createdAt,
  });

  factory BookNoteModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookNoteModel(
      id: doc.id,
      bookId: d['bookId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      pageNumber: (d['pageNumber'] as num?)?.toInt(),
      type: d['type'] == 'quote' ? NoteType.quote : NoteType.note,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'text': text,
        if (pageNumber != null) 'pageNumber': pageNumber,
        'type': type == NoteType.quote ? 'quote' : 'note',
        'createdAt': FieldValue.serverTimestamp(),
      };
}
