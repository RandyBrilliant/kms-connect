import '../../../../core/utils/api_datetime.dart';

class News {
  final int id;
  final String title;
  final String slug;
  final String? summary;
  final String content;
  final String? heroImage;
  final bool isPinned;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  News({
    required this.id,
    required this.title,
    required this.slug,
    this.summary,
    required this.content,
    this.heroImage,
    required this.isPinned,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: _safeInt(json['id']),
      title: (json['title'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
      summary: json['summary']?.toString(),
      content: (json['content'] ?? '') as String,
      heroImage: json['hero_image']?.toString(),
      isPinned: json['is_pinned'] as bool? ?? false,
      publishedAt: ApiDateTime.parse(json['published_at']),
      createdAt:
          ApiDateTime.parseRequired(json['created_at'], fieldName: 'created_at'),
      updatedAt:
          ApiDateTime.parseRequired(json['updated_at'], fieldName: 'updated_at'),
    );
  }
}
