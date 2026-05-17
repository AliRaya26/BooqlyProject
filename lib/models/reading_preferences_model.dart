import 'package:cloud_firestore/cloud_firestore.dart';

/// User reading preferences stored in Firestore collection `preferences/{userId}`.
class ReadingPreferencesModel {
  final List<String> preferredGenres;
  final String readingTheme;
  final String readingPace;
  final bool preferencesCompleted;
  final DateTime? updatedAt;

  const ReadingPreferencesModel({
    this.preferredGenres = const [],
    this.readingTheme = 'cozy_dark',
    this.readingPace = 'steady',
    this.preferencesCompleted = false,
    this.updatedAt,
  });

  factory ReadingPreferencesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ReadingPreferencesModel();

    final genres = map['preferredGenres'];
    return ReadingPreferencesModel(
      preferredGenres: genres is List
          ? genres.map((e) => e.toString()).toList()
          : const [],
      readingTheme: map['readingTheme']?.toString() ?? 'cozy_dark',
      readingPace: map['readingPace']?.toString() ?? 'steady',
      preferencesCompleted: map['preferencesCompleted'] == true,
      updatedAt: (map['preferencesUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredGenres': preferredGenres,
      'readingTheme': readingTheme,
      'readingPace': readingPace,
      'preferencesCompleted': preferencesCompleted,
      if (updatedAt != null)
        'preferencesUpdatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  ReadingPreferencesModel copyWith({
    List<String>? preferredGenres,
    String? readingTheme,
    String? readingPace,
    bool? preferencesCompleted,
    DateTime? updatedAt,
  }) {
    return ReadingPreferencesModel(
      preferredGenres: preferredGenres ?? this.preferredGenres,
      readingTheme: readingTheme ?? this.readingTheme,
      readingPace: readingPace ?? this.readingPace,
      preferencesCompleted:
          preferencesCompleted ?? this.preferencesCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Catalog option loaded from `app_config/reading_preferences`.
class PreferenceOption {
  final String id;
  final String label;
  final String? subtitle;
  final String? emoji;

  const PreferenceOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.emoji,
  });

  factory PreferenceOption.fromMap(Map<String, dynamic> map) {
    return PreferenceOption(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      emoji: map['emoji']?.toString(),
    );
  }
}

class PreferenceCatalog {
  final List<PreferenceOption> genres;
  final List<PreferenceOption> readingThemes;
  final List<PreferenceOption> readingPaces;

  const PreferenceCatalog({
    required this.genres,
    required this.readingThemes,
    required this.readingPaces,
  });
}
