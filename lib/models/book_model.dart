class BookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String category;
  final String coverUrl;
  final String pdfUrl;
  final int totalPages;

  double progress;
  int currentPage; 

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.category,
    required this.coverUrl,
    required this.pdfUrl,
    required this.totalPages,
    this.progress = 0.0,
    this.currentPage = 0,
  });

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

      progress: (map['progress'] ?? 0).toDouble(),
      currentPage: map['currentPage'] ?? 0, // ✅ ADD THIS
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'category': category,
      'coverUrl': coverUrl,
      'pdfUrl': pdfUrl,
      'totalPages': totalPages,
      'progress': progress,
      'currentPage': currentPage, // ✅ ADD THIS
    };
  }

  BookModel copyWith({
    double? progress,
    int? currentPage,
  }) {
    return BookModel(
      id: id,
      title: title,
      author: author,
      description: description,
      category: category,
      coverUrl: coverUrl,
      pdfUrl: pdfUrl,
      totalPages: totalPages,
      progress: progress ?? this.progress,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}