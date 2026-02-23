/// Represents an Indonesian administrative region (Province or Regency/City).
///
/// Used for cascading dropdowns in registration and profile forms.
class Region {
  final int id;
  final String code;
  final String name;

  const Region({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Region && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
