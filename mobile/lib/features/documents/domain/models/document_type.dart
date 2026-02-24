class DocumentType {
  final int id;
  final String code;
  final String name;
  final bool isRequired;
  final int sortOrder;
  final String description;

  const DocumentType({
    required this.id,
    required this.code,
    required this.name,
    required this.isRequired,
    required this.sortOrder,
    this.description = '',
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      code: (json['code'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      description: (json['description'] ?? '') as String,
    );
  }
}
