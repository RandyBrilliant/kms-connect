/// Data extracted from KTP via OCR.
///
/// Only the four fields that can be reliably read from a KTP photo are
/// included: NIK, nama, tempat lahir, and tanggal lahir.
///
/// Optionally includes [birthPlaceRegency] if the backend successfully
/// matched the OCR birth_place to a regency in the database.
class KtpData {
  final String? nik;
  final String? name;
  final String? birthPlace;
  final String? birthDate;

  /// Matched regency info from backend (optional).
  /// Contains: id, code, name, province
  final BirthPlaceRegency? birthPlaceRegency;

  const KtpData({
    this.nik,
    this.name,
    this.birthPlace,
    this.birthDate,
    this.birthPlaceRegency,
  });

  factory KtpData.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(dynamic v) {
      final s = v as String?;
      return (s == null || s.trim().isEmpty) ? null : s.trim();
    }

    BirthPlaceRegency? regency;
    if (json['birth_place_regency'] != null) {
      regency = BirthPlaceRegency.fromJson(
        json['birth_place_regency'] as Map<String, dynamic>,
      );
    }

    return KtpData(
      nik: nonEmpty(json['nik']),
      name: nonEmpty(json['name']),
      birthPlace: nonEmpty(json['birth_place']),
      birthDate: nonEmpty(json['birth_date']),
      birthPlaceRegency: regency,
    );
  }

  Map<String, dynamic> toJson() => {
        'nik': nik,
        'name': name,
        'birth_place': birthPlace,
        'birth_date': birthDate,
        if (birthPlaceRegency != null)
          'birth_place_regency': birthPlaceRegency!.toJson(),
      };

  KtpData copyWith({
    String? nik,
    String? name,
    String? birthPlace,
    String? birthDate,
    BirthPlaceRegency? birthPlaceRegency,
  }) {
    return KtpData(
      nik: nik ?? this.nik,
      name: name ?? this.name,
      birthPlace: birthPlace ?? this.birthPlace,
      birthDate: birthDate ?? this.birthDate,
      birthPlaceRegency: birthPlaceRegency ?? this.birthPlaceRegency,
    );
  }

  /// Whether any OCR field was successfully extracted.
  bool get hasData =>
      nik != null || name != null || birthPlace != null || birthDate != null;
}

/// Matched regency info returned from backend OCR.
class BirthPlaceRegency {
  final int id;
  final String code;
  final String name;
  final String province;

  const BirthPlaceRegency({
    required this.id,
    required this.code,
    required this.name,
    required this.province,
  });

  factory BirthPlaceRegency.fromJson(Map<String, dynamic> json) {
    return BirthPlaceRegency(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      province: json['province'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'province': province,
      };
}
