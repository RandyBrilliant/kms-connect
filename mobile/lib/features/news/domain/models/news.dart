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

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] as int,
      title: json['title'] as String,
      slug: json['slug'] as String,
      summary: json['summary'] as String?,
      content: json['content'] as String,
      heroImage: json['hero_image'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
