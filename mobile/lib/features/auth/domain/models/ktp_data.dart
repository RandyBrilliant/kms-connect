/// Data extracted from KTP via OCR.
///
/// Only the four fields that can be reliably read from a KTP photo are
/// included: NIK, nama, tempat lahir, and tanggal lahir.
class KtpData {
  final String? nik;
  final String? name;
  final String? birthPlace;
  final String? birthDate;

  const KtpData({
    this.nik,
    this.name,
    this.birthPlace,
    this.birthDate,
  });

  factory KtpData.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(dynamic v) {
      final s = v as String?;
      return (s == null || s.trim().isEmpty) ? null : s.trim();
    }

    return KtpData(
      nik: nonEmpty(json['nik']),
      name: nonEmpty(json['name']),
      birthPlace: nonEmpty(json['birth_place']),
      birthDate: nonEmpty(json['birth_date']),
    );
  }

  Map<String, dynamic> toJson() => {
        'nik': nik,
        'name': name,
        'birth_place': birthPlace,
        'birth_date': birthDate,
      };

  KtpData copyWith({
    String? nik,
    String? name,
    String? birthPlace,
    String? birthDate,
  }) {
    return KtpData(
      nik: nik ?? this.nik,
      name: name ?? this.name,
      birthPlace: birthPlace ?? this.birthPlace,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  /// Whether any OCR field was successfully extracted.
  bool get hasData => nik != null || name != null || birthPlace != null || birthDate != null;
}
