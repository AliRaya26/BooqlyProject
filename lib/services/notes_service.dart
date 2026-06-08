import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:booqly/models/book_note_model.dart';

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _notesRef(String bookId) {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    return _db
        .collection('users')
        .doc(uid)
        .collection('library')
        .doc(bookId)
        .collection('notes');
  }

  Stream<List<BookNoteModel>> notesStream(String bookId) {
    if (_uid == null) return Stream.error('Not signed in');
    return _notesRef(bookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookNoteModel.fromDoc(d)).toList());
  }

  Future<void> addNote({
    required String bookId,
    required String text,
    int? pageNumber,
    NoteType type = NoteType.note,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Ensure the library parent document exists so subcollection writes succeed
    // even if the book hasn't been formally added to the library yet.
    final libRef = _db
        .collection('users')
        .doc(uid)
        .collection('library')
        .doc(bookId);
    final libSnap = await libRef.get();
    if (!libSnap.exists) {
      await libRef.set({'bookId': bookId}, SetOptions(merge: true));
    }

    await _notesRef(bookId).add(
      BookNoteModel(
        id: '',
        bookId: bookId,
        text: text,
        pageNumber: pageNumber,
        type: type,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> deleteNote({required String bookId, required String noteId}) async {
    await _notesRef(bookId).doc(noteId).delete();
  }

  Future<void> updateNote({
    required String bookId,
    required String noteId,
    required String text,
    int? pageNumber,
    NoteType? type,
  }) async {
    await _notesRef(bookId).doc(noteId).update({
      'text': text,
      if (pageNumber != null) 'pageNumber': pageNumber,
      if (type != null) 'type': type == NoteType.quote ? 'quote' : 'note',
    });
  }

  Future<int> getNotesCount(String bookId) async {
    try {
      final snap = await _notesRef(bookId).count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
