/// A light reference to a region (id + name), returned embedded in profile JSON.
class RegionRef {
  final int id;
  final String name;

  const RegionRef({required this.id, required this.name});

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RegionRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ApplicantProfile {
  final int id;
  final String? fullName;

  // Birth
  final int? birthPlaceId;   // FK → regions.Regency
  final String? birthPlaceName;
  final DateTime? birthDate;
  final String? gender;       // 'M' or 'F'

  // KTP address – cascading hierarchy
  final String? address;
  final int? provinceId;
  final String? provinceName;
  final int? districtId;      // = Kabupaten/Kota (Regency FK named 'district' on backend)
  final String? districtName;
  final int? villageId;
  final String? villageName;

  // Contact
  final String? contactPhone;

  // Identity
  final String? nik;
  final String? religion;
  final String? educationLevel;
  final String? educationMajor;
  final int? heightCm;
  final int? weightKg;
  final bool? wearsGlasses;
  final String? writingHand;
  final String? maritalStatus;
  final bool? hasPassport;
  final String? passportNumber;
  final DateTime? passportIssueDate;
  final String? passportIssuePlace;
  final DateTime? passportExpiryDate;
  final String? familyCardNumber;
  final String? diplomaNumber;
  final String? bpjsNumber;
  final int? shoeSize;
  final String? shirtSize;

  // Family
  final int? siblingCount;
  final int? birthOrder;
  final String? fatherName;
  final int? fatherAge;
  final String? fatherOccupation;
  final String? motherName;
  final int? motherAge;
  final String? motherOccupation;
  final String? spouseName;
  final int? spouseAge;
  final String? spouseOccupation;
  final String? familyAddress;
  final int? familyProvinceId;
  final String? familyProvinceName;
  final int? familyDistrictId;
  final String? familyDistrictName;
  final int? familyVillageId;
  final String? familyVillageName;
  final String? fatherPhone;
  final String? motherPhone;

  // Referral (who referred this applicant)
  final int? referrerId;

  // Ahli Waris (Next of Kin)
  final String? heirName;
  final String? heirRelationship;
  final String? heirContactPhone;

  // Photo & notes
  final String? photo;
  final String? notes;

  // Verification
  final String verificationStatus;
  final double? score;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ApplicantProfile({
    required this.id,
    this.fullName,
    this.birthPlaceId,
    this.birthPlaceName,
    this.birthDate,
    this.gender,
    this.address,
    this.provinceId,
    this.provinceName,
    this.districtId,
    this.districtName,
    this.villageId,
    this.villageName,
    this.contactPhone,
    this.nik,
    this.religion,
    this.educationLevel,
    this.educationMajor,
    this.heightCm,
    this.weightKg,
    this.wearsGlasses,
    this.writingHand,
    this.maritalStatus,
    this.hasPassport,
    this.passportNumber,
    this.passportIssueDate,
    this.passportIssuePlace,
    this.passportExpiryDate,
    this.familyCardNumber,
    this.diplomaNumber,
    this.bpjsNumber,
    this.shoeSize,
    this.shirtSize,
    this.siblingCount,
    this.birthOrder,
    this.fatherName,
    this.fatherAge,
    this.fatherOccupation,
    this.motherName,
    this.motherAge,
    this.motherOccupation,
    this.spouseName,
    this.spouseAge,
    this.spouseOccupation,
    this.familyAddress,
    this.familyProvinceId,
    this.familyProvinceName,
    this.familyDistrictId,
    this.familyDistrictName,
    this.familyVillageId,
    this.familyVillageName,
    this.fatherPhone,
    this.motherPhone,
    this.referrerId,
    this.heirName,
    this.heirRelationship,
    this.heirContactPhone,
    this.photo,
    this.notes,
    required this.verificationStatus,
    this.score,
    this.submittedAt,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String? _nameFromField(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['name'] as String?;
    return null;
  }

  static int? _idFromField(dynamic v) {
    if (v == null) return null;
    if (v is Map) return _parseId(v['id']);
    return _parseId(v);
  }

  static String? _str(dynamic v) => v?.toString();

  factory ApplicantProfile.fromJson(Map<String, dynamic> json) {
    // Backend returns region FK fields as plain integer PKs.
    // Region *names* are embedded in the display helper dicts.
    final vd = json['village_display'] as Map<String, dynamic>?;
    final fvd = json['family_village_display'] as Map<String, dynamic>?;

    return ApplicantProfile(
      id: _parseId(json['id'])!,
      fullName: _str(json['full_name']),
      birthPlaceId: _idFromField(json['birth_place']),
      birthPlaceName: _str(json['birth_place_display']) ?? _nameFromField(json['birth_place']),
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      gender: _str(json['gender']),
      address: _str(json['address']),
      provinceId: _idFromField(json['province']),
      provinceName: _str(vd?['province']) ?? _nameFromField(json['province']),
      districtId: _idFromField(json['district']),
      districtName: _str(vd?['regency']) ?? _nameFromField(json['district']),
      villageId: _idFromField(json['village']),
      villageName: _str(vd?['village']) ?? _nameFromField(json['village']),
      contactPhone: _str(json['contact_phone']),
      nik: _str(json['nik']),
      religion: _str(json['religion']),
      educationLevel: _str(json['education_level']),
      educationMajor: _str(json['education_major']),
      heightCm: _parseId(json['height_cm']),
      weightKg: _parseId(json['weight_kg']),
      wearsGlasses: json['wears_glasses'] as bool?,
      writingHand: _str(json['writing_hand']),
      maritalStatus: _str(json['marital_status']),
      hasPassport: json['has_passport'] as bool?,
      passportNumber: _str(json['passport_number']),
      passportIssueDate: json['passport_issue_date'] != null
          ? DateTime.tryParse(json['passport_issue_date'].toString())
          : null,
      passportIssuePlace: _str(json['passport_issue_place']),
      passportExpiryDate: json['passport_expiry_date'] != null
          ? DateTime.tryParse(json['passport_expiry_date'].toString())
          : null,
      familyCardNumber: _str(json['family_card_number']),
      diplomaNumber: _str(json['diploma_number']),
      bpjsNumber: _str(json['bpjs_number']),
      shoeSize: _parseId(json['shoe_size']),
      shirtSize: _str(json['shirt_size']),
      siblingCount: _parseId(json['sibling_count']),
      birthOrder: _parseId(json['birth_order']),
      fatherName: _str(json['father_name']),
      fatherAge: _parseId(json['father_age']),
      fatherOccupation: _str(json['father_occupation']),
      motherName: _str(json['mother_name']),
      motherAge: _parseId(json['mother_age']),
      motherOccupation: _str(json['mother_occupation']),
      spouseName: _str(json['spouse_name']),
      spouseAge: _parseId(json['spouse_age']),
      spouseOccupation: _str(json['spouse_occupation']),
      familyAddress: _str(json['family_address']),
      familyProvinceId: _idFromField(json['family_province']),
      familyProvinceName: _str(fvd?['province']) ?? _nameFromField(json['family_province']),
      familyDistrictId: _idFromField(json['family_district']),
      familyDistrictName: _str(fvd?['regency']) ?? _nameFromField(json['family_district']),
      familyVillageId: _idFromField(json['family_village']),
      familyVillageName: _str(fvd?['village']) ?? _nameFromField(json['family_village']),
      fatherPhone: _str(json['father_phone']),
      motherPhone: _str(json['mother_phone']),
      referrerId: _parseId(json['referrer']),
      heirName: _str(json['heir_name']),
      heirRelationship: _str(json['heir_relationship']),
      heirContactPhone: _str(json['heir_contact_phone']),
      photo: _str(json['photo']),
      notes: _str(json['notes']),
      verificationStatus: _str(json['verification_status']) ?? 'DRAFT',
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'birth_place': birthPlaceId,
        'birth_date': birthDate?.toIso8601String(),
        'gender': gender,
        'address': address,
        'province': provinceId,
        'district': districtId,
        'village': villageId,
        'contact_phone': contactPhone,
        'nik': nik,
        'sibling_count': siblingCount,
        'birth_order': birthOrder,
        'father_name': fatherName,
        'father_age': fatherAge,
        'father_occupation': fatherOccupation,
        'mother_name': motherName,
        'mother_age': motherAge,
        'mother_occupation': motherOccupation,
        'spouse_name': spouseName,
        'spouse_age': spouseAge,
        'spouse_occupation': spouseOccupation,
        'family_address': familyAddress,
        'family_province': familyProvinceId,
        'family_district': familyDistrictId,
        'family_village': familyVillageId,
        'father_phone': fatherPhone,
        'mother_phone': motherPhone,
        'heir_name': heirName,
        'heir_relationship': heirRelationship,
        'heir_contact_phone': heirContactPhone,
        'verification_status': verificationStatus,
        'score': score,
      };

  String get verificationStatusDisplay {
    switch (verificationStatus) {
      case 'DRAFT':
        return 'Draf';
      case 'SUBMITTED':
        return 'Menunggu Verifikasi';
      case 'ACCEPTED':
        return 'Diterima';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return verificationStatus;
    }
  }

  bool get canSubmit =>
      verificationStatus == 'DRAFT' &&
      nik != null &&
      nik!.isNotEmpty &&
      fullName != null &&
      fullName!.isNotEmpty &&
      address != null &&
      address!.isNotEmpty &&
      contactPhone != null &&
      contactPhone!.isNotEmpty;
}
