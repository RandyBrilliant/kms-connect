class DocumentType {
  final int id;
  final String code;
  final String name;
  final bool isRequired;
  final int sortOrder;

  DocumentType({
    required this.id,
    required this.code,
    required this.name,
    required this.isRequired,
    required this.sortOrder,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      isRequired: json['is_required'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}
