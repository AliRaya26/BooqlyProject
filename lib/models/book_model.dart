class BookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String category;
  final String coverUrl;
  final String pdfUrl;
  final int totalPages;

  // NEW
  double progress;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.category,
    required this.coverUrl,
    required this.pdfUrl,
    required this.totalPages,

    // NEW
    this.progress = 0.0,
  });

  // ─────────────────────────────
  // FIRESTORE → MODEL
  // ─────────────────────────────

  factory BookModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return BookModel(
      id: documentId,
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      pdfUrl: map['pdfUrl'] ?? '',
      totalPages: map['totalPages'] ?? 0,

      // NEW
      progress: (map['progress'] ?? 0).toDouble(),
    );
  }

  // ─────────────────────────────
  // MODEL → FIRESTORE
  // ─────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'category': category,
      'coverUrl': coverUrl,
      'pdfUrl': pdfUrl,
      'totalPages': totalPages,

      // NEW
      'progress': progress,
    };
  }

  BookModel copyWith({
  double? progress,
}) {
  return BookModel(
    id: id,
    title: title,
    author: author,
    category: category,
    description: description,
    coverUrl: coverUrl,
    pdfUrl: pdfUrl,
    totalPages: totalPages,
    progress: progress ?? this.progress,
  );
}
}

