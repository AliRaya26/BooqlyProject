/// Normalizes cover URLs from Firestore maps and external APIs.
String resolveBookCoverUrl(dynamic raw) {
  if (raw == null) return '';
  var url = raw.toString().trim();
  if (url.isEmpty) return '';

  // Firebase Storage gs:// → HTTPS download URL.
  if (url.startsWith('gs://')) {
    final withoutScheme = url.substring(5);
    final slash = withoutScheme.indexOf('/');
    if (slash > 0) {
      final bucket = withoutScheme.substring(0, slash);
      final path = Uri.encodeComponent(withoutScheme.substring(slash + 1));
      return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media';
    }
  }

  // Protocol-relative URLs (common in Google Books API responses).
  if (url.startsWith('//')) {
    url = 'https:$url';
  }

  // Prefer HTTPS on web to avoid mixed-content blocks.
  if (url.startsWith('http://')) {
    url = url.replaceFirst('http://', 'https://');
  }

  // Google Books thumbnails: remove edge=curl and force https.
  if (url.contains('books.google.com')) {
    url = url.replaceAll(RegExp(r'&edge=curl'), '');
    url = url.replaceAll(RegExp(r'\?edge=curl&'), '?');
    url = url.replaceAll(RegExp(r'\?edge=curl$'), '');
  }

  return url;
}

/// Reads a cover URL from common Firestore field names.
String coverUrlFromMap(Map<String, dynamic> map) {
  final raw = map['coverUrl'] ??
      map['coverURL'] ??
      map['cover'] ??
      map['imageUrl'] ??
      map['thumbnail'];
  return resolveBookCoverUrl(raw);
}

/// Open Library cover by book title (free, works on web).
String openLibraryCoverForTitle(String title) {
  final t = title.trim();
  if (t.isEmpty) return '';
  return 'https://covers.openlibrary.org/b/title/${Uri.encodeComponent(t)}-M.jpg';
}

/// Open Library cover by ISBN.
String openLibraryCoverForIsbn(String isbn) {
  final id = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
  if (id.isEmpty) return '';
  return 'https://covers.openlibrary.org/b/isbn/$id-M.jpg';
}

/// Best URL to display: stored cover, then Open Library fallback from title/ISBN.
String effectiveCoverUrl({
  required String coverUrl,
  required String title,
  String? isbn,
}) {
  final resolved = resolveBookCoverUrl(coverUrl);
  if (resolved.isNotEmpty) return resolved;

  if (isbn != null && isbn.trim().isNotEmpty) {
    return openLibraryCoverForIsbn(isbn);
  }

  return openLibraryCoverForTitle(title);
}
