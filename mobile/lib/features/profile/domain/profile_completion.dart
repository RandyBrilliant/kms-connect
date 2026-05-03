import 'models/applicant_profile.dart';

/// Sections shown on the profile completion checklist (aligned with edit profile UI).
enum ProfileSetupSection {
  personal,
  educationPhysical,
  addressKtp,
  documents,
  passport,
  family,
  spouse,
  heir,
}

/// Result of [evaluateProfileCompletion].
class ProfileCompletionReport {
  final Map<ProfileSetupSection, bool> sections;

  const ProfileCompletionReport(this.sections);

  bool get isFullyComplete =>
      sections.values.every((complete) => complete);

  int get completedCount => sections.values.where((v) => v).length;

  int get totalCount => sections.length;

  double get fraction =>
      totalCount == 0 ? 1.0 : completedCount / totalCount;

  List<ProfileSetupSection> get incompleteSections =>
      sections.entries.where((e) => !e.value).map((e) => e.key).toList();
}

bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

bool _nikOk(String? nik) =>
    nik != null && nik.trim().length == 16;

/// Evaluates biodata completeness section-by-section for applicant onboarding.
///
/// Rules mirror the main blocks on [EditProfilePage]: every field the client
/// expects to be filled is included so the checklist matches “lengkapi profil”.
ProfileCompletionReport evaluateProfileCompletion(ApplicantProfile p) {
  // ── Data pribadi
  final personal = _nonEmpty(p.fullName) &&
      _nikOk(p.nik) &&
      _nonEmpty(p.birthPlaceText) &&
      p.birthDate != null &&
      _nonEmpty(p.gender) &&
      _nonEmpty(p.religion) &&
      _nonEmpty(p.maritalStatus) &&
      _nonEmpty(p.contactPhone);

  // ── Pendidikan & fisik
  final educationPhysical = _nonEmpty(p.educationLevel) &&
      _nonEmpty(p.educationMajor) &&
      p.heightCm != null &&
      p.heightCm! > 0 &&
      p.weightKg != null &&
      p.weightKg! > 0 &&
      p.wearsGlasses != null &&
      _nonEmpty(p.writingHand) &&
      p.shoeSize != null &&
      p.shoeSize! > 0 &&
      _nonEmpty(p.shirtSize);

  // ── Alamat KTP
  final addressKtp = _nonEmpty(p.address) &&
      _nonEmpty(p.postalCode) &&
      p.provinceId != null &&
      p.districtId != null &&
      p.villageId != null;

  // ── Data dokumen
  final documents = _nonEmpty(p.familyCardNumber) &&
      _nonEmpty(p.diplomaNumber) &&
      _nonEmpty(p.bpjsNumber);

  // ── Paspor
  final passport = p.hasPassport != null &&
      (p.hasPassport == false ||
          (_nonEmpty(p.passportNumber) &&
              _nonEmpty(p.passportIssuePlace) &&
              p.passportIssueDate != null &&
              p.passportExpiryDate != null));

  // ── Data keluarga
  final family = p.siblingCount != null &&
      p.birthOrder != null &&
      _nonEmpty(p.familyAddress) &&
      _nonEmpty(p.familyPostalCode) &&
      p.familyProvinceId != null &&
      p.familyDistrictId != null &&
      p.familyVillageId != null &&
      _fatherBlockComplete(p) &&
      _motherBlockComplete(p);

  // ── Data pasangan (hanya jika menikah)
  final spouse = _spouseSectionComplete(p);

  // ── Ahli waris
  final heir = _nonEmpty(p.heirName) &&
      _nonEmpty(p.heirRelationship) &&
      _nonEmpty(p.heirContactPhone);

  return ProfileCompletionReport({
    ProfileSetupSection.personal: personal,
    ProfileSetupSection.educationPhysical: educationPhysical,
    ProfileSetupSection.addressKtp: addressKtp,
    ProfileSetupSection.documents: documents,
    ProfileSetupSection.passport: passport,
    ProfileSetupSection.family: family,
    ProfileSetupSection.spouse: spouse,
    ProfileSetupSection.heir: heir,
  });
}

bool _fatherBlockComplete(ApplicantProfile p) {
  if (p.fatherAlmarhum) return true;
  return _nonEmpty(p.fatherName) &&
      p.fatherAge != null &&
      p.fatherAge! > 0 &&
      _nonEmpty(p.fatherOccupation);
}

bool _motherBlockComplete(ApplicantProfile p) {
  if (p.motherAlmarhum) return true;
  return _nonEmpty(p.motherName) &&
      p.motherAge != null &&
      p.motherAge! > 0 &&
      _nonEmpty(p.motherOccupation);
}

bool _spouseSectionComplete(ApplicantProfile p) {
  final m = (p.maritalStatus ?? '').toUpperCase();
  if (m != 'MENIKAH') return true;
  if (p.spouseAlmarhum) return true;
  return _nonEmpty(p.spouseName) &&
      p.spouseAge != null &&
      p.spouseAge! > 0 &&
      _nonEmpty(p.spouseOccupation);
}

/// When true, the app should show the profile completion flow (draft only).
bool shouldBlockForIncompleteProfile(ApplicantProfile? p) {
  if (p == null) return false;
  if (p.verificationStatus != 'DRAFT') return false;
  return !evaluateProfileCompletion(p).isFullyComplete;
}
