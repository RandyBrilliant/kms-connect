class ApplicantProfile {
  final int id;
  final String? fullName;
  final String? birthPlace;
  final DateTime? birthDate;
  final String? address;
  final String? contactPhone;
  final int? siblingCount;
  final int? birthOrder;
  
  // Family data
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
  final String? familyContactPhone;
  
  // Identity
  final String? nik;
  final String? gender; // 'M' or 'F'
  final String? photo;
  final String? notes;
  
  // Verification
  final String verificationStatus; // DRAFT, SUBMITTED, ACCEPTED, REJECTED
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicantProfile({
    required this.id,
    this.fullName,
    this.birthPlace,
    this.birthDate,
    this.address,
    this.contactPhone,
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
    this.familyContactPhone,
    this.nik,
    this.gender,
    this.photo,
    this.notes,
    required this.verificationStatus,
    this.submittedAt,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApplicantProfile.fromJson(Map<String, dynamic> json) {
    return ApplicantProfile(
      id: json['id'] as int,
      fullName: json['full_name'] as String?,
      birthPlace: json['birth_place'] as String?,
      birthDate: json['birth_date'] != null 
          ? DateTime.parse(json['birth_date'] as String) 
          : null,
      address: json['address'] as String?,
      contactPhone: json['contact_phone'] as String?,
      siblingCount: json['sibling_count'] as int?,
      birthOrder: json['birth_order'] as int?,
      fatherName: json['father_name'] as String?,
      fatherAge: json['father_age'] as int?,
      fatherOccupation: json['father_occupation'] as String?,
      motherName: json['mother_name'] as String?,
      motherAge: json['mother_age'] as int?,
      motherOccupation: json['mother_occupation'] as String?,
      spouseName: json['spouse_name'] as String?,
      spouseAge: json['spouse_age'] as int?,
      spouseOccupation: json['spouse_occupation'] as String?,
      familyAddress: json['family_address'] as String?,
      familyContactPhone: json['family_contact_phone'] as String?,
      nik: json['nik'] as String?,
      gender: json['gender'] as String?,
      photo: json['photo'] as String?,
      notes: json['notes'] as String?,
      verificationStatus: json['verification_status'] as String,
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at'] as String) 
          : null,
      verifiedAt: json['verified_at'] != null 
          ? DateTime.parse(json['verified_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'birth_place': birthPlace,
      'birth_date': birthDate?.toIso8601String(),
      'address': address,
      'contact_phone': contactPhone,
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
      'family_contact_phone': familyContactPhone,
      'nik': nik,
      'gender': gender,
      'photo': photo,
      'notes': notes,
      'verification_status': verificationStatus,
    };
  }

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

  bool get canSubmit {
    return verificationStatus == 'DRAFT' &&
        nik != null &&
        nik!.isNotEmpty &&
        fullName != null &&
        fullName!.isNotEmpty &&
        address != null &&
        address!.isNotEmpty &&
        contactPhone != null &&
        contactPhone!.isNotEmpty;
  }
}
