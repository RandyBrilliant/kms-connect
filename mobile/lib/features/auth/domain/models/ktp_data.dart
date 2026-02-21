class KtpData {
  final String? nik;
  final String? name;
  final String? birthPlace;
  final String? birthDate;
  final String? address;
  final String? gender;

  KtpData({
    this.nik,
    this.name,
    this.birthPlace,
    this.birthDate,
    this.address,
    this.gender,
  });

  factory KtpData.fromJson(Map<String, dynamic> json) {
    return KtpData(
      nik: json['nik'] as String?,
      name: json['name'] as String?,
      birthPlace: json['birth_place'] as String?,
      birthDate: json['birth_date'] as String?,
      address: json['address'] as String?,
      gender: json['gender'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'name': name,
      'birth_place': birthPlace,
      'birth_date': birthDate,
      'address': address,
      'gender': gender,
    };
  }

  KtpData copyWith({
    String? nik,
    String? name,
    String? birthPlace,
    String? birthDate,
    String? address,
    String? gender,
  }) {
    return KtpData(
      nik: nik ?? this.nik,
      name: name ?? this.name,
      birthPlace: birthPlace ?? this.birthPlace,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      gender: gender ?? this.gender,
    );
  }
}
