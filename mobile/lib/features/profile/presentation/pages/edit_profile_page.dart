import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/utils/safe_navigation.dart';
import '../../../../core/models/region.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../../../core/widgets/professional_phone_field.dart';
import '../../../../core/widgets/professional_dropdown_field.dart';
import '../../../auth/data/providers/regions_provider.dart';
import '../../../auth/data/providers/staff_referrers_provider.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/applicant_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────────────────
  final _fullName = TextEditingController();
  final _nik = TextEditingController();
  final _birthDate = TextEditingController();
  final _birthPlaceText = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _phone = TextEditingController();
  final _siblingCount = TextEditingController();
  final _birthOrder = TextEditingController();
  final _fatherName = TextEditingController();
  final _fatherAge = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _motherName = TextEditingController();
  final _motherAge = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _familyAddress = TextEditingController();
  final _familyPostalCode = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherPhone = TextEditingController();
  bool _fatherAlmarhum = false;
  bool _motherAlmarhum = false;
  bool _spouseAlmarhum = false;
  final _spouseName = TextEditingController();
  final _spouseAge = TextEditingController();
  final _spouseOccupation = TextEditingController();

  // Ahli Waris (Next of Kin)
  final _heirName = TextEditingController();
  final _heirContactPhone = TextEditingController();

  // Date-of-birth pickers for family members
  final _fatherBirthDateCtrl = TextEditingController();
  final _motherBirthDateCtrl = TextEditingController();
  final _spouseBirthDateCtrl = TextEditingController();

  // ── New: Data Fisik / Pendidikan / Dokumen ─────────────────────────────
  final _educationMajor = TextEditingController();
  final _heightCm = TextEditingController();
  final _weightKg = TextEditingController();
  final _shoeSize = TextEditingController();

  // ── New: Data Paspor ──────────────────────────────────────────────────
  final _passportNumber = TextEditingController();
  final _passportIssuePlace = TextEditingController();
  final _passportIssueDateCtrl = TextEditingController();
  final _passportExpiryDateCtrl = TextEditingController();

  // ── New: Data Dokumen ─────────────────────────────────────────────────
  final _familyCardNumber = TextEditingController();
  final _diplomaNumber = TextEditingController();
  final _bpjsNumber = TextEditingController();

  // ── Region state – KTP address (cascading) ────────────────────────────────
  Region? _province;
  Region? _kabupaten; // Kabupaten/Kota (regency)
  Region? _kecamatan; // Kecamatan (district)
  Region? _kelurahan; // Kelurahan/Desa (village)

  // ── Region state – Alamat Keluarga (cascading) ────────────────────────
  Region? _familyProvince;
  Region? _familyKabupaten;
  Region? _familyKecamatan;
  Region? _familyKelurahan;

  String? _gender;
  String? _heirRelationship;
  StaffReferrer? _selectedStaff;
  DateTime? _pickedDate;
  DateTime? _pickedFatherBirthDate;
  DateTime? _pickedMotherBirthDate;
  DateTime? _pickedSpouseBirthDate;
  bool _populated = false;

  // ── New: dropdown state ───────────────────────────────────────────────
  String? _religion;
  String? _educationLevel;
  String? _writingHand;
  String? _maritalStatus;
  String? _shirtSize;
  bool? _wearsGlasses;
  bool? _hasPassport;
  DateTime? _pickedPassportIssueDate;
  DateTime? _pickedPassportExpiryDate;
  final Set<String> _missingRequiredFields = <String>{};

  @override
  void initState() {
    super.initState();
    // Populate form once profile is available — outside build() to avoid
    // triggering rebuilds inside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileNotifierProvider).profile;
      if (profile != null) {
        _populate(profile);
        // Warm-up: pre-fetch staff list
        ref.read(staffReferrersProvider).whenData((list) {
          if (!mounted) return;
          if (profile.referrerId != null) {
            final match = list
                .where((s) => s.id == profile.referrerId)
                .firstOrNull;
            if (match != null) setState(() => _selectedStaff = match);
          }
        });
        // Kecamatan is not persisted in the profile model; derive it from
        // the saved village via the detail endpoint.
        if (profile.villageId != null) {
          _loadKecamatan(profile.villageId!, isFamily: false);
        }
        if (profile.familyVillageId != null) {
          _loadKecamatan(profile.familyVillageId!, isFamily: true);
        }
      }
    });
  }

  /// Async-fetches the parent kecamatan (district) for [villageId] and
  /// sets [_kecamatan] (or [_familyKecamatan]) so the cascading kelurahan
  /// picker is pre-filled.
  Future<void> _loadKecamatan(int villageId, {bool isFamily = false}) async {
    try {
      final kecamatan = await ref.read(
        kecamatanFromVillageProvider(villageId).future,
      );
      if (mounted) {
        setState(() {
          if (isFamily) {
            _familyKecamatan = kecamatan;
          } else {
            _kecamatan = kecamatan;
          }
        });
      }
    } catch (_) {
      // Silently fail — user can manually pick kecamatan to enable kelurahan.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _nik,
      _birthDate,
      _birthPlaceText,
      _address,
      _postalCode,
      _phone,
      _siblingCount,
      _birthOrder,
      _fatherName,
      _fatherAge,
      _fatherOccupation,
      _motherName,
      _motherAge,
      _motherOccupation,
      _familyAddress,
      _familyPostalCode,
      _fatherPhone,
      _motherPhone,
      _spouseName,
      _spouseAge,
      _spouseOccupation,
      _heirName,
      _heirContactPhone,
      _fatherBirthDateCtrl,
      _motherBirthDateCtrl,
      _spouseBirthDateCtrl,
      _educationMajor,
      _heightCm,
      _weightKg,
      _shoeSize,
      _passportNumber,
      _passportIssuePlace,
      _passportIssueDateCtrl,
      _passportExpiryDateCtrl,
      _familyCardNumber,
      _diplomaNumber,
      _bpjsNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Maps backend strings to dropdown keys (case/spacing tolerant).
  static String? _normalizeDropdownKey(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.toUpperCase();
  }

  /// Normalizes gender to `M` / `F` for segmented control (only two options).
  static String? _normalizeGender(String? raw) {
    if (raw == null) return null;
    final u = raw.trim().toUpperCase();
    if (u == 'O') return null;
    if (u == 'M' || u == 'L' || u == 'LAKI' || u.startsWith('LAKI')) {
      return 'M';
    }
    if (u == 'F' || u == 'P' || u.startsWith('PEREM')) return 'F';
    return null;
  }

  /// Populates controllers exactly once from the loaded profile.
  /// Does NOT call setState — the controllers themselves notify their
  /// respective TextFormField widgets via ChangeNotifier.
  void _populate(ApplicantProfile p) {
    if (_populated) return;
    _populated = true;
    _fullName.text = (p.fullName ?? '').toUpperCase();
    _nik.text = p.nik ?? '';
    if (p.birthDate != null) {
      _pickedDate = p.birthDate;
      _birthDate.text = DateFormat('dd MMMM yyyy', 'id').format(p.birthDate!);
    }
    _birthPlaceText.text = (p.birthPlaceText ?? '').toUpperCase();
    _gender = _normalizeGender(p.gender);
    _address.text = (p.address ?? '').toUpperCase();
    _postalCode.text = p.postalCode ?? '';
    _phone.text = p.contactPhone ?? '';
    _siblingCount.text = p.siblingCount?.toString() ?? '';
    _birthOrder.text = p.birthOrder?.toString() ?? '';

    // ── New: Data Pribadi dropdowns (normalize to API keys / item keys) ─
    _religion = _normalizeDropdownKey(p.religion);
    _educationLevel = _normalizeDropdownKey(p.educationLevel);
    _educationMajor.text = (p.educationMajor ?? '').toUpperCase();
    _maritalStatus = _normalizeDropdownKey(p.maritalStatus);

    // ── New: Data Fisik ──────────────────────────────────────────────────
    _heightCm.text = p.heightCm?.toString() ?? '';
    _weightKg.text = p.weightKg?.toString() ?? '';
    _wearsGlasses = p.wearsGlasses;
    _writingHand = _normalizeDropdownKey(p.writingHand);
    _shoeSize.text = p.shoeSize?.toString() ?? '';
    _shirtSize = _normalizeDropdownKey(p.shirtSize);

    // ── New: Data Paspor ────────────────────────────────────────────────
    _hasPassport = p.hasPassport;
    _passportNumber.text = (p.passportNumber ?? '').toUpperCase();
    _passportIssuePlace.text = (p.passportIssuePlace ?? '').toUpperCase();
    if (p.passportIssueDate != null) {
      _pickedPassportIssueDate = p.passportIssueDate;
      _passportIssueDateCtrl.text = DateFormat(
        'dd MMMM yyyy',
        'id',
      ).format(p.passportIssueDate!);
    }
    if (p.passportExpiryDate != null) {
      _pickedPassportExpiryDate = p.passportExpiryDate;
      _passportExpiryDateCtrl.text = DateFormat(
        'dd MMMM yyyy',
        'id',
      ).format(p.passportExpiryDate!);
    }

    // ── New: Data Dokumen ───────────────────────────────────────────────
    _familyCardNumber.text = p.familyCardNumber ?? '';
    _diplomaNumber.text = (p.diplomaNumber ?? '').toUpperCase();
    _bpjsNumber.text = p.bpjsNumber ?? '';

    // ── Keluarga ────────────────────────────────────────────────────────
    _fatherName.text = (p.fatherName ?? '').toUpperCase();
    _fatherAge.text = p.fatherAge?.toString() ?? '';
    if (p.fatherAge != null) {
      _pickedFatherBirthDate = DateTime(DateTime.now().year - p.fatherAge!);
      _fatherBirthDateCtrl.text = DateFormat(
        'dd MMMM yyyy',
        'id',
      ).format(_pickedFatherBirthDate!);
    }
    _fatherOccupation.text = (p.fatherOccupation ?? '').toUpperCase();
    _motherName.text = (p.motherName ?? '').toUpperCase();
    _motherAge.text = p.motherAge?.toString() ?? '';
    if (p.motherAge != null) {
      _pickedMotherBirthDate = DateTime(DateTime.now().year - p.motherAge!);
      _motherBirthDateCtrl.text = DateFormat(
        'dd MMMM yyyy',
        'id',
      ).format(_pickedMotherBirthDate!);
    }
    _motherOccupation.text = (p.motherOccupation ?? '').toUpperCase();
    _familyAddress.text = (p.familyAddress ?? '').toUpperCase();
    _familyPostalCode.text = p.familyPostalCode ?? '';
    _fatherPhone.text = p.fatherPhone ?? '';
    _motherPhone.text = p.motherPhone ?? '';
    _fatherAlmarhum = p.fatherAlmarhum;
    _motherAlmarhum = p.motherAlmarhum;
    _spouseAlmarhum = p.spouseAlmarhum;
    _spouseName.text = (p.spouseName ?? '').toUpperCase();
    _spouseAge.text = p.spouseAge?.toString() ?? '';
    if (p.spouseAge != null) {
      _pickedSpouseBirthDate = DateTime(DateTime.now().year - p.spouseAge!);
      _spouseBirthDateCtrl.text = DateFormat(
        'dd MMMM yyyy',
        'id',
      ).format(_pickedSpouseBirthDate!);
    }
    _spouseOccupation.text = (p.spouseOccupation ?? '').toUpperCase();

    // Ahli Waris
    _heirName.text = (p.heirName ?? '').toUpperCase();
    _heirRelationship = _normalizeDropdownKey(p.heirRelationship);
    _heirContactPhone.text = p.heirContactPhone ?? '';

    // Pre-seed region objects from names stored in profile
    if (p.provinceId != null && p.provinceName != null) {
      _province = Region(id: p.provinceId!, code: '', name: p.provinceName!);
    }
    if (p.districtId != null && p.districtName != null) {
      _kabupaten = Region(id: p.districtId!, code: '', name: p.districtName!);
    }
    if (p.villageId != null && p.villageName != null) {
      _kelurahan = Region(id: p.villageId!, code: '', name: p.villageName!);
    }

    // Family address regions
    if (p.familyProvinceId != null && p.familyProvinceName != null) {
      _familyProvince = Region(
        id: p.familyProvinceId!,
        code: '',
        name: p.familyProvinceName!,
      );
    }
    if (p.familyDistrictId != null && p.familyDistrictName != null) {
      _familyKabupaten = Region(
        id: p.familyDistrictId!,
        code: '',
        name: p.familyDistrictName!,
      );
    }
    if (p.familyVillageId != null && p.familyVillageName != null) {
      _familyKelurahan = Region(
        id: p.familyVillageId!,
        code: '',
        name: p.familyVillageName!,
      );
    }

    // Trigger a single rebuild for the non-controller state (_gender, regions).
    if (mounted) setState(() {});
  }

  int _computeAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }

  Future<void> _pickFamilyMemberDate({
    required TextEditingController controller,
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final initial = current ?? DateTime(now.year - 40);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 1),
    );
    if (picked != null && mounted) {
      setState(() {
        controller.text = DateFormat('dd MMMM yyyy', 'id').format(picked);
        onPicked(picked);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _pickedDate ?? DateTime(now.year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 15),
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedDate = picked;
        _birthDate.text = DateFormat('dd MMMM yyyy', 'id').format(picked);
      });
    }
  }

  /// Generic date picker for passport and other date fields.
  Future<void> _pickGenericDate({
    required DateTime? current,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final initial = current ?? DateTime.now();
    final clamped = initial.isBefore(firstDate)
        ? firstDate
        : initial.isAfter(lastDate)
        ? lastDate
        : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) onPicked(picked);
  }

  List<String> _collectMissingRequiredFields() {
    final missing = <String>[];

    void requireText(TextEditingController c, String label) {
      if (c.text.trim().isEmpty) missing.add(label);
    }

    void requireValue(Object? v, String label) {
      if (v == null) missing.add(label);
    }

    // Data pribadi
    requireText(_fullName, 'Nama Lengkap');
    requireText(_nik, 'NIK');
    requireText(_birthPlaceText, 'Tempat Lahir');
    requireValue(_pickedDate, 'Tanggal Lahir');
    requireValue(_gender, 'Jenis Kelamin');
    requireText(_phone, 'Nomor Telepon');
    requireValue(_religion, 'Agama');
    requireValue(_maritalStatus, 'Status Perkawinan');

    // Pendidikan & fisik
    requireValue(_educationLevel, 'Pendidikan Terakhir');
    requireText(_educationMajor, 'Jurusan');
    requireText(_heightCm, 'Tinggi (cm)');
    requireText(_weightKg, 'Berat (kg)');
    requireValue(_wearsGlasses, 'Memakai Kacamata');
    requireValue(_writingHand, 'Menulis dengan Tangan');
    requireText(_shoeSize, 'Ukuran Sepatu');
    requireValue(_shirtSize, 'Ukuran Baju');

    // Alamat KTP
    requireText(_address, 'Alamat Lengkap');
    requireText(_postalCode, 'Kode Pos');
    requireValue(_province, 'Provinsi');
    requireValue(_kabupaten, 'Kabupaten / Kota');
    requireValue(_kecamatan, 'Kecamatan');
    requireValue(_kelurahan, 'Kelurahan / Desa');

    // Data dokumen
    requireText(_familyCardNumber, 'Nomor Kartu Keluarga');
    requireText(_diplomaNumber, 'Nomor Ijazah');
    requireText(_bpjsNumber, 'Nomor BPJS / KIS');

    // Data paspor
    requireValue(_hasPassport, 'Memiliki Paspor');
    if (_hasPassport == true) {
      requireText(_passportNumber, 'Nomor Paspor');
      requireText(_passportIssuePlace, 'Tempat Terbit Paspor');
      requireValue(_pickedPassportIssueDate, 'Tanggal Terbit Paspor');
      requireValue(_pickedPassportExpiryDate, 'Tanggal Berakhir Paspor');
    }

    // Data keluarga
    requireText(_siblingCount, 'Jumlah Saudara');
    requireText(_birthOrder, 'Anak ke-');
    if (!_fatherAlmarhum) {
      requireText(_fatherName, 'Nama Ayah');
      requireValue(_pickedFatherBirthDate, 'Tanggal Lahir Ayah');
      requireText(_fatherOccupation, 'Pekerjaan Ayah');
      requireText(_fatherPhone, 'No. Telepon Ayah');
    }
    if (!_motherAlmarhum) {
      requireText(_motherName, 'Nama Ibu');
      requireValue(_pickedMotherBirthDate, 'Tanggal Lahir Ibu');
      requireText(_motherOccupation, 'Pekerjaan Ibu');
      requireText(_motherPhone, 'No. Telepon Ibu');
    }
    requireText(_familyAddress, 'Alamat Orang Tua / Keluarga');
    requireText(_familyPostalCode, 'Kode Pos Orang Tua / Keluarga');
    requireValue(_familyProvince, 'Provinsi Orang Tua / Keluarga');
    requireValue(_familyKabupaten, 'Kab/Kota Orang Tua / Keluarga');
    requireValue(_familyKecamatan, 'Kecamatan Orang Tua / Keluarga');
    requireValue(_familyKelurahan, 'Kelurahan Orang Tua / Keluarga');

    // Data pasangan: optional (client request).

    // Ahli waris
    requireText(_heirName, 'Nama Ahli Waris');
    requireValue(_heirRelationship, 'Hubungan Ahli Waris');
    requireText(_heirContactPhone, 'No. Telepon Ahli Waris');

    return missing;
  }

  String? _requiredErrorText(String fieldLabel) {
    return _missingRequiredFields.contains(fieldLabel) ? 'Wajib diisi' : null;
  }

  /// Earliest selectable passport expiry (must be after issue date when known).
  DateTime get _passportExpiryFirstDate {
    final issue = _pickedPassportIssueDate;
    if (issue != null) {
      return issue.add(const Duration(days: 1));
    }
    return DateTime(2000);
  }

  DateTime get _passportExpiryLastDate =>
      DateTime(DateTime.now().year + 20);

  String? _passportDateValidationMessage() {
    if (_hasPassport != true) return null;
    final issue = _pickedPassportIssueDate;
    final expiry = _pickedPassportExpiryDate;
    if (issue == null || expiry == null) return null;
    if (!expiry.isAfter(issue)) {
      return 'Tanggal berakhir paspor harus setelah tanggal terbit paspor.';
    }
    return null;
  }

  String? _passportExpiryValidator(String? _) {
    final passportErr = _passportDateValidationMessage();
    if (passportErr != null) return passportErr;
    if (_missingRequiredFields.contains('Tanggal Berakhir Paspor') &&
        _pickedPassportExpiryDate == null) {
      return 'Wajib diisi';
    }
    return null;
  }

  Future<void> _handleSave() async {
    // Collect all missing fields first so every control can show an error,
    // then run Form.validate() (phones, formats). Previously validate() ran
    // first and stopped at the first phone error, so other fields never highlighted.
    final missing = _collectMissingRequiredFields();
    setState(() {
      _missingRequiredFields
        ..clear()
        ..addAll(missing);
    });

    final passportDateError = _passportDateValidationMessage();
    if (passportDateError != null) {
      setState(() {
        _missingRequiredFields.add('Tanggal Berakhir Paspor');
      });
    }

    final formValid = _formKey.currentState?.validate() ?? false;

    if (passportDateError != null) {
      CustomToast.show(context, message: passportDateError, type: ToastType.error);
      return;
    }

    if (missing.isNotEmpty || !formValid) {
      if (missing.isNotEmpty) {
        CustomToast.show(
          context,
          message: 'Lengkapi field wajib: ${missing.first}',
          type: ToastType.error,
        );
      }
      return;
    }

    if (_missingRequiredFields.isNotEmpty) {
      setState(_missingRequiredFields.clear);
    }
    final data = <String, dynamic>{
      if (_fullName.text.trim().isNotEmpty) 'full_name': _fullName.text.trim(),
      if (_nik.text.trim().isNotEmpty) 'nik': _nik.text.trim(),
      if (_birthPlaceText.text.trim().isNotEmpty)
        'birth_place_text': _birthPlaceText.text.trim(),
      if (_pickedDate != null)
        'birth_date': DateFormat('yyyy-MM-dd').format(_pickedDate!),
      if (_gender != null) 'gender': _gender,
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_postalCode.text.trim().isNotEmpty)
        'postal_code': _postalCode.text.trim(),
      if (_province != null) 'province': _province!.id,
      if (_kabupaten != null) 'district': _kabupaten!.id,
      if (_kelurahan != null) 'village': _kelurahan!.id,
      if (_phone.text.trim().isNotEmpty)
        'contact_phone': ProfessionalPhoneField.toIndonesiaE164(_phone.text),

      // ── New: Data Pribadi dropdowns ──────────────────────────────────
      if (_religion != null) 'religion': _religion,
      if (_educationLevel != null) 'education_level': _educationLevel,
      if (_educationMajor.text.trim().isNotEmpty)
        'education_major': _educationMajor.text.trim(),
      if (_maritalStatus != null) 'marital_status': _maritalStatus,

      // ── New: Data Fisik ──────────────────────────────────────────────
      // Backend: height_cm/weight_kg are integers; shoe_size is CharField (string).
      // Only send parsed ints when tryParse succeeds — never send null.
      'height_cm': ?int.tryParse(_heightCm.text.trim()),
      'weight_kg': ?int.tryParse(_weightKg.text.trim()),
      if (_wearsGlasses != null) 'wears_glasses': _wearsGlasses,
      if (_writingHand != null) 'writing_hand': _writingHand,
      if (_shoeSize.text.trim().isNotEmpty) 'shoe_size': _shoeSize.text.trim(),
      if (_shirtSize != null) 'shirt_size': _shirtSize,

      // ── New: Data Paspor ─────────────────────────────────────────────
      if (_hasPassport != null) 'has_passport': _hasPassport,
      if (_passportNumber.text.trim().isNotEmpty)
        'passport_number': _passportNumber.text.trim(),
      if (_pickedPassportIssueDate != null)
        'passport_issue_date': DateFormat(
          'yyyy-MM-dd',
        ).format(_pickedPassportIssueDate!),
      if (_passportIssuePlace.text.trim().isNotEmpty)
        'passport_issue_place': _passportIssuePlace.text.trim(),
      if (_pickedPassportExpiryDate != null)
        'passport_expiry_date': DateFormat(
          'yyyy-MM-dd',
        ).format(_pickedPassportExpiryDate!),

      // ── New: Data Dokumen ────────────────────────────────────────────
      if (_familyCardNumber.text.trim().isNotEmpty)
        'family_card_number': _familyCardNumber.text.trim(),
      if (_diplomaNumber.text.trim().isNotEmpty)
        'diploma_number': _diplomaNumber.text.trim(),
      if (_bpjsNumber.text.trim().isNotEmpty)
        'bpjs_number': _bpjsNumber.text.trim(),

      // ── Keluarga ────────────────────────────────────────────────────
      'sibling_count': ?int.tryParse(_siblingCount.text.trim()),
      'birth_order': ?int.tryParse(_birthOrder.text.trim()),
      'father_almarhum': _fatherAlmarhum,
      'mother_almarhum': _motherAlmarhum,
      'spouse_almarhum': _spouseAlmarhum,
      if (_fatherName.text.trim().isNotEmpty)
        'father_name': _fatherName.text.trim(),
      if (_pickedFatherBirthDate != null)
        'father_age': _computeAge(_pickedFatherBirthDate!),
      if (_fatherOccupation.text.trim().isNotEmpty)
        'father_occupation': _fatherOccupation.text.trim(),
      if (_motherName.text.trim().isNotEmpty)
        'mother_name': _motherName.text.trim(),
      if (_pickedMotherBirthDate != null)
        'mother_age': _computeAge(_pickedMotherBirthDate!),
      if (_motherOccupation.text.trim().isNotEmpty)
        'mother_occupation': _motherOccupation.text.trim(),
      if (_familyAddress.text.trim().isNotEmpty)
        'family_address': _familyAddress.text.trim(),
      if (_familyPostalCode.text.trim().isNotEmpty)
        'family_postal_code': _familyPostalCode.text.trim(),
      if (_familyProvince != null) 'family_province': _familyProvince!.id,
      if (_familyKabupaten != null) 'family_district': _familyKabupaten!.id,
      if (_familyKelurahan != null) 'family_village': _familyKelurahan!.id,
      if (_fatherPhone.text.trim().isNotEmpty)
        'father_phone': ProfessionalPhoneField.toIndonesiaE164(_fatherPhone.text),
      if (_motherPhone.text.trim().isNotEmpty)
        'mother_phone': ProfessionalPhoneField.toIndonesiaE164(_motherPhone.text),
      if (_spouseName.text.trim().isNotEmpty)
        'spouse_name': _spouseName.text.trim(),
      if (_pickedSpouseBirthDate != null)
        'spouse_age': _computeAge(_pickedSpouseBirthDate!),
      if (_spouseOccupation.text.trim().isNotEmpty)
        'spouse_occupation': _spouseOccupation.text.trim(),
      if (_heirName.text.trim().isNotEmpty) 'heir_name': _heirName.text.trim(),
      if (_heirRelationship != null) 'heir_relationship': _heirRelationship,
      if (_heirContactPhone.text.trim().isNotEmpty)
        'heir_contact_phone': ProfessionalPhoneField.toIndonesiaE164(_heirContactPhone.text),
    };

    final success = await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile(data);
    if (!mounted) return;
    if (success) {
      // Capture container before pop — [ref] is unsafe after [dispose].
      // Sync [ref.invalidate] + toast overlay could rebuild go_router's
      // [Navigator] while it is locked.
      final container = ProviderScope.containerOf(context);
      CustomToast.showGlobal(
        message: 'Profil berhasil diperbarui',
        type: ToastType.success,
      );
      runWhenNavigatorUnlocked(() {
        if (!mounted) return;
        Navigator.pop(context);
        runWhenNavigatorUnlocked(() {
          container.invalidate(profileProvider);
        });
      });
    } else {
      final err = ref.read(profileNotifierProvider).error ?? 'Gagal menyimpan';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
  }

  // ── Region bottom-sheet picker (matches registration KTP city sheet) ─────
  Future<Region?> _showRegionPicker({
    required String title,
    required List<Region> items,
    Region? selected,
  }) async {
    return showModalBottomSheet<Region>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _RegionPickerSheet(title: title, items: items, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.profile;
    // Populate once when data arrives (safe: _populated flag prevents re-entry).
    // This handles the async case where profile loads AFTER build runs.
    if (profile != null && !_populated) {
      // Schedule outside the build phase to avoid setState-during-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _populate(profile);
        // Kecamatan is not stored on profile; derive from village (same as initState path).
        if (profile.villageId != null) {
          _loadKecamatan(profile.villageId!, isFamily: false);
        }
        if (profile.familyVillageId != null) {
          _loadKecamatan(profile.familyVillageId!, isFamily: true);
        }
      });
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bool isAccepted =
        profile?.verificationStatus.toUpperCase() == 'ACCEPTED';

    // Loading skeleton
    if (profileState.isLoading && profile == null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: ProfessionalGradientBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfessionalHeader(context),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Error state
    if (profileState.error != null && profile == null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: ProfessionalGradientBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfessionalHeader(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ProfessionalCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: cs.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Gagal memuat data',
                                style: tt.titleMedium?.copyWith(
                                  color: cs.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                profileState.error!,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(profileNotifierProvider.notifier)
                                    .loadProfile(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfessionalHeader(context),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      24 + bottomInset + bottomPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAccepted) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 22,
                                  color: Color(0xFF0A7A43),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Profil Anda sudah diterima oleh admin. '
                                    'Data diri tidak dapat diubah lagi dari aplikasi.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                      color: const Color(0xFF1B4332),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        IgnorePointer(
                          ignoring: isAccepted,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ─── Data Pribadi ──────────────────────────────────
                              _SectionCard(
                                icon: Icons.person_outline_rounded,
                                label: 'Data Pribadi',
                                children: [
                                  M3TextField(
                                    controller: _fullName,
                                    label: 'Nama Lengkap',
                                    hint: 'Sesuai KTP',
                                    prefixIcon: Icons.badge_outlined,
                                    upperCase: true,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Nama wajib diisi';
                                      if (s.length < 2) {
                                        return 'Nama terlalu pendek';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _nik,
                                    label: 'NIK',
                                    hint: '16 digit NIK',
                                    prefixIcon: Icons.credit_card_outlined,
                                    readOnly: true,
                                    keyboardType: TextInputType.number,
                                    suffixWidget: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _birthPlaceText,
                                    label: 'Tempat Lahir',
                                    hint: 'Sesuai KTP',
                                    prefixIcon: Icons.location_city_outlined,
                                    upperCase: true,
                                    requiredLabel: 'Tempat Lahir',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _birthDate,
                                    label: 'Tanggal Lahir',
                                    hint: 'Pilih tanggal',
                                    prefixIcon: Icons.calendar_today_outlined,
                                    readOnly: true,
                                    onTap: _pickDate,
                                    requiredLabel: 'Tanggal Lahir',
                                    requiredDate: _pickedDate,
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  _GenderSelector(
                                    selected: _gender,
                                    onChanged: (g) =>
                                        setState(() => _gender = g),
                                    errorText: _requiredErrorText(
                                      'Jenis Kelamin',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  PhoneInputField(
                                    controller: _phone,
                                    label: 'Nomor Telepon',
                                    hint: '812xxxxxxxx',
                                    requiredLabel: 'Nomor Telepon',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  _DropdownField<String>(
                                    label: 'Agama',
                                    prefixIcon: Icons.mosque_outlined,
                                    value: _religion,
                                    hint: 'Pilih agama',
                                    items: const [
                                      ('ISLAM', 'Islam'),
                                      ('KRISTEN', 'Kristen'),
                                      ('KATHOLIK', 'Katholik'),
                                      ('HINDU', 'Hindu'),
                                      ('BUDHA', 'Budha'),
                                      ('LAINNYA', 'Lainnya'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _religion = v),
                                    errorText: _requiredErrorText('Agama'),
                                  ),
                                  const SizedBox(height: 14),
                                  _DropdownField<String>(
                                    label: 'Status Perkawinan',
                                    prefixIcon: Icons.family_restroom_outlined,
                                    value: _maritalStatus,
                                    hint: 'Pilih status',
                                    items: const [
                                      ('BELUM MENIKAH', 'Belum Menikah'),
                                      ('MENIKAH', 'Menikah'),
                                      ('CERAI HIDUP', 'Cerai Hidup'),
                                      ('CERAI MATI', 'Cerai Mati'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _maritalStatus = v),
                                    errorText: _requiredErrorText(
                                      'Status Perkawinan',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Data Pendidikan & Fisik ───────────────────────
                              _SectionCard(
                                icon: Icons.school_outlined,
                                label: 'Pendidikan & Fisik',
                                children: [
                                  _DropdownField<String>(
                                    label: 'Pendidikan Terakhir',
                                    prefixIcon: Icons.school_outlined,
                                    value: _educationLevel,
                                    hint: 'Pilih pendidikan',
                                    items: const [
                                      ('SMP', 'SMP'),
                                      ('SMA', 'SMA'),
                                      ('SMK', 'SMK'),
                                      ('MA', 'MA'),
                                      ('D3', 'D3'),
                                      ('S1', 'S1'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _educationLevel = v),
                                    errorText: _requiredErrorText(
                                      'Pendidikan Terakhir',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _educationMajor,
                                    label: 'Jurusan',
                                    hint: 'Contoh: Teknik Mesin',
                                    prefixIcon: Icons.menu_book_outlined,
                                    upperCase: true,
                                    requiredLabel: 'Jurusan',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: M3TextField(
                                          controller: _heightCm,
                                          label: 'Tinggi (cm)',
                                          hint: '165',
                                          prefixIcon: Icons.height_rounded,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          requiredLabel: 'Tinggi (cm)',
                                          missingRequiredFields:
                                              _missingRequiredFields,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: M3TextField(
                                          controller: _weightKg,
                                          label: 'Berat (kg)',
                                          hint: '60',
                                          prefixIcon:
                                              Icons.monitor_weight_outlined,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          requiredLabel: 'Berat (kg)',
                                          missingRequiredFields:
                                              _missingRequiredFields,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _DropdownField<bool>(
                                    label: 'Memakai Kacamata?',
                                    prefixIcon: Icons.visibility_outlined,
                                    value: _wearsGlasses,
                                    hint: 'Pilih',
                                    items: const [
                                      (true, 'Ya'),
                                      (false, 'Tidak'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _wearsGlasses = v),
                                    errorText: _requiredErrorText(
                                      'Memakai Kacamata',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _DropdownField<String>(
                                    label: 'Menulis dengan Tangan',
                                    prefixIcon: Icons.draw_outlined,
                                    value: _writingHand,
                                    hint: 'Pilih tangan',
                                    items: const [
                                      ('KANAN', 'Kanan'),
                                      ('KIRI', 'Kiri'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _writingHand = v),
                                    errorText: _requiredErrorText(
                                      'Menulis dengan Tangan',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: M3TextField(
                                          controller: _shoeSize,
                                          label: 'Ukuran Sepatu',
                                          hint: '42',
                                          prefixIcon:
                                              Icons.ice_skating_outlined,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          requiredLabel: 'Ukuran Sepatu',
                                          missingRequiredFields:
                                              _missingRequiredFields,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _DropdownField<String>(
                                          label: 'Ukuran Baju',
                                          prefixIcon: Icons.checkroom_outlined,
                                          value: _shirtSize,
                                          hint: 'Pilih',
                                          items: const [
                                            ('S', 'S'),
                                            ('M', 'M'),
                                            ('L', 'L'),
                                            ('XL', 'XL'),
                                            ('XXL', 'XXL'),
                                          ],
                                          onChanged: (v) =>
                                              setState(() => _shirtSize = v),
                                          errorText: _requiredErrorText(
                                            'Ukuran Baju',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Alamat KTP ────────────────────────────────────
                              _SectionCard(
                                icon: Icons.home_outlined,
                                label: 'Alamat KTP',
                                children: [
                                  M3TextField(
                                    controller: _address,
                                    label: 'Alamat Lengkap',
                                    hint: 'Jalan, RT/RW',
                                    prefixIcon: Icons.edit_road_outlined,
                                    maxLines: 2,
                                    upperCase: true,
                                    requiredLabel: 'Alamat Lengkap',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _postalCode,
                                    label: 'Kode Pos',
                                    hint: 'Contoh: 40123',
                                    prefixIcon:
                                        Icons.markunread_mailbox_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    requiredLabel: 'Kode Pos',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  // Province
                                  _RegionPickerField(
                                    label: 'Provinsi',
                                    hint: 'Pilih provinsi',
                                    prefixIcon: Icons.map_outlined,
                                    selected: _province,
                                    errorText: _requiredErrorText('Provinsi'),
                                    onTap: () async {
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              provincesProvider.future,
                                            ),
                                            () => ref.invalidate(
                                              provincesProvider,
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Provinsi',
                                        items: items,
                                        selected: _province,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _province = picked;
                                          _kabupaten = null;
                                          _kecamatan = null;
                                          _kelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  // Kabupaten/Kota
                                  _RegionPickerField(
                                    label: 'Kabupaten / Kota',
                                    hint: _province == null
                                        ? 'Pilih provinsi dahulu'
                                        : 'Pilih kab/kota',
                                    prefixIcon: Icons.location_city_outlined,
                                    selected: _kabupaten,
                                    enabled: _province != null,
                                    errorText: _requiredErrorText(
                                      'Kabupaten / Kota',
                                    ),
                                    onTap: () async {
                                      if (_province == null) return;
                                      final pid = _province!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              regenciesByProvinceProvider(
                                                pid,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              regenciesByProvinceProvider(pid),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kab/Kota',
                                        items: items,
                                        selected: _kabupaten,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _kabupaten = picked;
                                          _kecamatan = null;
                                          _kelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  // Kecamatan
                                  _RegionPickerField(
                                    label: 'Kecamatan',
                                    hint: _kabupaten == null
                                        ? 'Pilih kab/kota dahulu'
                                        : 'Pilih kecamatan',
                                    prefixIcon: Icons.place_outlined,
                                    selected: _kecamatan,
                                    enabled: _kabupaten != null,
                                    errorText: _requiredErrorText('Kecamatan'),
                                    onTap: () async {
                                      if (_kabupaten == null) return;
                                      final rid = _kabupaten!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              districtsByRegencyProvider(
                                                rid,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              districtsByRegencyProvider(rid),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kecamatan',
                                        items: items,
                                        selected: _kecamatan,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _kecamatan = picked;
                                          _kelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  // Kelurahan/Desa
                                  _RegionPickerField(
                                    label: 'Kelurahan / Desa',
                                    hint: _kecamatan == null
                                        ? 'Pilih kecamatan dahulu'
                                        : 'Pilih kelurahan',
                                    prefixIcon: Icons.villa_outlined,
                                    selected: _kelurahan,
                                    enabled: _kecamatan != null,
                                    errorText: _requiredErrorText(
                                      'Kelurahan / Desa',
                                    ),
                                    onTap: () async {
                                      if (_kecamatan == null) return;
                                      final did = _kecamatan!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              villagesByDistrictProvider(
                                                did,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              villagesByDistrictProvider(did),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kelurahan/Desa',
                                        items: items,
                                        selected: _kelurahan,
                                      );
                                      if (picked != null) {
                                        setState(() => _kelurahan = picked);
                                      }
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Data Dokumen ──────────────────────────────────
                              _SectionCard(
                                icon: Icons.folder_outlined,
                                label: 'Data Dokumen',
                                children: [
                                  M3TextField(
                                    controller: _familyCardNumber,
                                    label: 'Nomor Kartu Keluarga',
                                    hint: 'Nomor KK',
                                    prefixIcon: Icons.credit_card_outlined,
                                    keyboardType: TextInputType.number,
                                    requiredLabel: 'Nomor Kartu Keluarga',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _diplomaNumber,
                                    label: 'Nomor Ijazah',
                                    hint: 'Nomor ijazah terakhir',
                                    prefixIcon: Icons.school_outlined,
                                    upperCase: true,
                                    requiredLabel: 'Nomor Ijazah',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _bpjsNumber,
                                    label: 'Nomor BPJS / KIS',
                                    hint: 'Nomor BPJS kesehatan',
                                    prefixIcon:
                                        Icons.health_and_safety_outlined,
                                    keyboardType: TextInputType.number,
                                    requiredLabel: 'Nomor BPJS / KIS',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Data Paspor ───────────────────────────────────
                              _SectionCard(
                                icon: Icons.flight_outlined,
                                label: 'Data Paspor',
                                children: [
                                  _DropdownField<bool>(
                                    label: 'Memiliki Paspor?',
                                    prefixIcon: Icons.article_outlined,
                                    value: _hasPassport,
                                    hint: 'Pilih',
                                    items: const [
                                      (true, 'Ya'),
                                      (false, 'Tidak'),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _hasPassport = v),
                                    errorText: _requiredErrorText(
                                      'Memiliki Paspor',
                                    ),
                                  ),
                                  if (_hasPassport == true) ...[
                                    const SizedBox(height: 14),
                                    M3TextField(
                                      controller: _passportNumber,
                                      label: 'Nomor Paspor',
                                      hint: 'A12345678',
                                      prefixIcon:
                                          Icons.confirmation_number_outlined,
                                      upperCase: true,
                                      requiredLabel: 'Nomor Paspor',
                                      missingRequiredFields:
                                          _missingRequiredFields,
                                    ),
                                    const SizedBox(height: 14),
                                    M3TextField(
                                      controller: _passportIssuePlace,
                                      label: 'Tempat Terbit Paspor',
                                      hint: 'Contoh: Jakarta',
                                      prefixIcon: Icons.location_on_outlined,
                                      upperCase: true,
                                      requiredLabel: 'Tempat Terbit Paspor',
                                      missingRequiredFields:
                                          _missingRequiredFields,
                                    ),
                                    const SizedBox(height: 14),
                                    M3TextField(
                                      controller: _passportIssueDateCtrl,
                                      label: 'Tanggal Terbit',
                                      hint: 'Pilih tanggal',
                                      prefixIcon: Icons.calendar_today_outlined,
                                      readOnly: true,
                                      requiredLabel: 'Tanggal Terbit Paspor',
                                      requiredDate: _pickedPassportIssueDate,
                                      missingRequiredFields:
                                          _missingRequiredFields,
                                      onTap: () => _pickGenericDate(
                                        current: _pickedPassportIssueDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                        onPicked: (d) => setState(() {
                                          _pickedPassportIssueDate = d;
                                          _passportIssueDateCtrl.text =
                                              DateFormat(
                                                'dd MMMM yyyy',
                                                'id',
                                              ).format(d);
                                        }),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    M3TextField(
                                      controller: _passportExpiryDateCtrl,
                                      label: 'Tanggal Berakhir',
                                      hint: 'Pilih tanggal',
                                      prefixIcon: Icons.event_outlined,
                                      readOnly: true,
                                      requiredLabel: 'Tanggal Berakhir Paspor',
                                      requiredDate: _pickedPassportExpiryDate,
                                      missingRequiredFields:
                                          _missingRequiredFields,
                                      validator: _passportExpiryValidator,
                                      onTap: () => _pickGenericDate(
                                        current: _pickedPassportExpiryDate,
                                        firstDate: _passportExpiryFirstDate,
                                        lastDate: _passportExpiryLastDate,
                                        onPicked: (d) => setState(() {
                                          _pickedPassportExpiryDate = d;
                                          _passportExpiryDateCtrl.text =
                                              DateFormat(
                                                'dd MMMM yyyy',
                                                'id',
                                              ).format(d);
                                        }),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Data Keluarga ─────────────────────────────────
                              _SectionCard(
                                icon: Icons.family_restroom_outlined,
                                label: 'Data Keluarga',
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: M3TextField(
                                          controller: _siblingCount,
                                          label: 'Jumlah Saudara',
                                          hint: '0',
                                          prefixIcon: Icons.people_outline,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          requiredLabel: 'Jumlah Saudara',
                                          missingRequiredFields:
                                              _missingRequiredFields,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: M3TextField(
                                          controller: _birthOrder,
                                          label: 'Anak ke-',
                                          hint: '1',
                                          prefixIcon:
                                              Icons.format_list_numbered,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          requiredLabel: 'Anak ke-',
                                          missingRequiredFields:
                                              _missingRequiredFields,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _SubLabel('Ayah'),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    value: _fatherAlmarhum,
                                    onChanged: (v) => setState(
                                      () => _fatherAlmarhum = v ?? false,
                                    ),
                                    title: Text(
                                      'Ayah Almarhum',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                  M3TextField(
                                    controller: _fatherName,
                                    label: 'Nama Ayah',
                                    hint: 'Nama lengkap',
                                    prefixIcon: Icons.person_outline_rounded,
                                    upperCase: true,
                                    requiredLabel: 'Nama Ayah',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _fatherBirthDateCtrl,
                                    label: 'Tanggal Lahir Ayah',
                                    hint: 'Pilih tanggal',
                                    prefixIcon: Icons.calendar_today_outlined,
                                    readOnly: true,
                                    requiredLabel: 'Tanggal Lahir Ayah',
                                    requiredDate: _pickedFatherBirthDate,
                                    missingRequiredFields: _missingRequiredFields,
                                    onTap: () => _pickFamilyMemberDate(
                                      controller: _fatherBirthDateCtrl,
                                      current: _pickedFatherBirthDate,
                                      onPicked: (d) => setState(
                                        () => _pickedFatherBirthDate = d,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _fatherOccupation,
                                    label: 'Pekerjaan Ayah',
                                    hint: 'Contoh: Wiraswasta',
                                    prefixIcon: Icons.work_outline_rounded,
                                    upperCase: true,
                                    requiredLabel: 'Pekerjaan Ayah',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  PhoneInputField(
                                    controller: _fatherPhone,
                                    label: 'No. Telepon Ayah',
                                    hint: '812xxxxxxxx',
                                    requiredLabel: 'No. Telepon Ayah',
                                    missingRequiredFields: _missingRequiredFields,
                                    skipRequired: _fatherAlmarhum,
                                  ),
                                  const SizedBox(height: 18),
                                  _SubLabel('Ibu'),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    value: _motherAlmarhum,
                                    onChanged: (v) => setState(
                                      () => _motherAlmarhum = v ?? false,
                                    ),
                                    title: Text(
                                      'Ibu Almarhumah',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                  M3TextField(
                                    controller: _motherName,
                                    label: 'Nama Ibu',
                                    hint: 'Nama lengkap',
                                    prefixIcon: Icons.person_outline_rounded,
                                    upperCase: true,
                                    requiredLabel: 'Nama Ibu',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _motherBirthDateCtrl,
                                    label: 'Tanggal Lahir Ibu',
                                    hint: 'Pilih tanggal',
                                    prefixIcon: Icons.calendar_today_outlined,
                                    readOnly: true,
                                    requiredLabel: 'Tanggal Lahir Ibu',
                                    requiredDate: _pickedMotherBirthDate,
                                    missingRequiredFields: _missingRequiredFields,
                                    onTap: () => _pickFamilyMemberDate(
                                      controller: _motherBirthDateCtrl,
                                      current: _pickedMotherBirthDate,
                                      onPicked: (d) => setState(
                                        () => _pickedMotherBirthDate = d,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _motherOccupation,
                                    label: 'Pekerjaan Ibu',
                                    hint: 'Contoh: Ibu Rumah Tangga',
                                    prefixIcon: Icons.work_outline_rounded,
                                    upperCase: true,
                                    requiredLabel: 'Pekerjaan Ibu',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  PhoneInputField(
                                    controller: _motherPhone,
                                    label: 'No. Telepon Ibu',
                                    hint: '812xxxxxxxx',
                                    requiredLabel: 'No. Telepon Ibu',
                                    missingRequiredFields: _missingRequiredFields,
                                    skipRequired: _motherAlmarhum,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _familyAddress,
                                    label: 'Alamat Orang Tua / Keluarga',
                                    hint: 'Jika berbeda dengan alamat KTP',
                                    prefixIcon: Icons.home_outlined,
                                    maxLines: 2,
                                    upperCase: true,
                                    requiredLabel: 'Alamat Orang Tua / Keluarga',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _familyPostalCode,
                                    label: 'Kode Pos Orang Tua / Keluarga',
                                    hint: 'Contoh: 40211',
                                    prefixIcon:
                                        Icons.local_post_office_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    requiredLabel: 'Kode Pos Orang Tua / Keluarga',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  // ── Family address region pickers ──
                                  _RegionPickerField(
                                    label: 'Provinsi Orang Tua / Keluarga',
                                    hint: 'Pilih provinsi',
                                    prefixIcon: Icons.map_outlined,
                                    selected: _familyProvince,
                                    errorText: _requiredErrorText(
                                      'Provinsi Orang Tua / Keluarga',
                                    ),
                                    onTap: () async {
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              provincesProvider.future,
                                            ),
                                            () => ref.invalidate(
                                              provincesProvider,
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Provinsi',
                                        items: items,
                                        selected: _familyProvince,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _familyProvince = picked;
                                          _familyKabupaten = null;
                                          _familyKecamatan = null;
                                          _familyKelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _RegionPickerField(
                                    label: 'Kab/Kota (Orang Tua / Keluarga)',
                                    hint: _familyProvince == null
                                        ? 'Pilih provinsi dahulu'
                                        : 'Pilih kab/kota',
                                    prefixIcon: Icons.location_city_outlined,
                                    selected: _familyKabupaten,
                                    enabled: _familyProvince != null,
                                    errorText: _requiredErrorText(
                                      'Kab/Kota Orang Tua / Keluarga',
                                    ),
                                    onTap: () async {
                                      if (_familyProvince == null) return;
                                      final pid = _familyProvince!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              regenciesByProvinceProvider(
                                                pid,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              regenciesByProvinceProvider(pid),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kab/Kota',
                                        items: items,
                                        selected: _familyKabupaten,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _familyKabupaten = picked;
                                          _familyKecamatan = null;
                                          _familyKelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _RegionPickerField(
                                    label: 'Kecamatan (Orang Tua / Keluarga)',
                                    hint: _familyKabupaten == null
                                        ? 'Pilih kab/kota dahulu'
                                        : 'Pilih kecamatan',
                                    prefixIcon: Icons.place_outlined,
                                    selected: _familyKecamatan,
                                    enabled: _familyKabupaten != null,
                                    errorText: _requiredErrorText(
                                      'Kecamatan Orang Tua / Keluarga',
                                    ),
                                    onTap: () async {
                                      if (_familyKabupaten == null) return;
                                      final rid = _familyKabupaten!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              districtsByRegencyProvider(
                                                rid,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              districtsByRegencyProvider(rid),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kecamatan',
                                        items: items,
                                        selected: _familyKecamatan,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _familyKecamatan = picked;
                                          _familyKelurahan = null;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _RegionPickerField(
                                    label: 'Kelurahan (Orang Tua / Keluarga)',
                                    hint: _familyKecamatan == null
                                        ? 'Pilih kecamatan dahulu'
                                        : 'Pilih kelurahan',
                                    prefixIcon: Icons.villa_outlined,
                                    selected: _familyKelurahan,
                                    enabled: _familyKecamatan != null,
                                    errorText: _requiredErrorText(
                                      'Kelurahan Orang Tua / Keluarga',
                                    ),
                                    onTap: () async {
                                      if (_familyKecamatan == null) return;
                                      final did = _familyKecamatan!.id;
                                      final items =
                                          await readRegionListWithRetry(
                                            ref,
                                            () => ref.read(
                                              villagesByDistrictProvider(
                                                did,
                                              ).future,
                                            ),
                                            () => ref.invalidate(
                                              villagesByDistrictProvider(did),
                                            ),
                                          );
                                      if (!mounted) return;
                                      final picked = await _showRegionPicker(
                                        title: 'Pilih Kelurahan/Desa',
                                        items: items,
                                        selected: _familyKelurahan,
                                      );
                                      if (picked != null) {
                                        setState(
                                          () => _familyKelurahan = picked,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Data Pasangan ─────────────────────────────────
                              _SectionCard(
                                icon: Icons.favorite_outline_rounded,
                                label: 'Data Pasangan',
                                subtitle: 'Isi jika sudah menikah',
                                children: [
                                  CheckboxListTile(
                                    value: _spouseAlmarhum,
                                    onChanged: (v) => setState(
                                      () => _spouseAlmarhum = v ?? false,
                                    ),
                                    title: Text(
                                      'Suami/Istri Almarhum / Almarhumah',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                  M3TextField(
                                    controller: _spouseName,
                                    label: 'Nama Pasangan',
                                    hint: 'Nama lengkap',
                                    prefixIcon: Icons.person_outline_rounded,
                                    upperCase: true,
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _spouseBirthDateCtrl,
                                    label: 'Tanggal Lahir Pasangan',
                                    hint: 'Pilih tanggal',
                                    prefixIcon: Icons.calendar_today_outlined,
                                    readOnly: true,
                                    onTap: () => _pickFamilyMemberDate(
                                      controller: _spouseBirthDateCtrl,
                                      current: _pickedSpouseBirthDate,
                                      onPicked: (d) => setState(
                                        () => _pickedSpouseBirthDate = d,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  M3TextField(
                                    controller: _spouseOccupation,
                                    label: 'Pekerjaan Pasangan',
                                    hint: 'Contoh: Karyawan Swasta',
                                    prefixIcon: Icons.work_outline_rounded,
                                    upperCase: true,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ─── Ahli Waris ────────────────────────────────────
                              _SectionCard(
                                icon: Icons.people_alt_outlined,
                                label: 'Ahli Waris',
                                subtitle: 'Kontak darurat terdekat',
                                children: [
                                  M3TextField(
                                    controller: _heirName,
                                    label: 'Nama Ahli Waris',
                                    hint: 'Nama lengkap',
                                    prefixIcon: Icons.person_outline_rounded,
                                    upperCase: true,
                                    requiredLabel: 'Nama Ahli Waris',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                  const SizedBox(height: 14),
                                  _HeirRelationshipSelector(
                                    selected: _heirRelationship,
                                    onChanged: (v) =>
                                        setState(() => _heirRelationship = v),
                                    errorText: _requiredErrorText(
                                      'Hubungan Ahli Waris',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  PhoneInputField(
                                    controller: _heirContactPhone,
                                    label: 'No. Telepon Ahli Waris',
                                    hint: '812xxxxxxxx',
                                    requiredLabel: 'No. Telepon Ahli Waris',
                                    missingRequiredFields: _missingRequiredFields,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // ─── Informasi Staff Rujukan ───────────────────────
                              _SectionCard(
                                icon: Icons.person_pin_outlined,
                                label: 'Staff Rujukan',
                                subtitle:
                                    'Informasi petugas rujukan Anda (hanya dapat diubah oleh petugas/admin).',
                                children: [
                                  _StaffReferrerInfoField(
                                    selected: _selectedStaff,
                                    profileReferrerName: profile?.referrerName,
                                    profileReferrerCode: profile?.referrerCode,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ─── Save button ───────────────────────────────────
                        ProfessionalButton(
                          label: 'Simpan Perubahan',
                          icon: Icons.save_rounded,
                          isLoading: profileState.isLoading,
                          onPressed: (profileState.isLoading || isAccepted)
                              ? null
                              : _handleSave,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Kembali',
          ),
          Expanded(
            child: Text(
              'Data Diri',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Private reusable widgets
// =============================================================================

/// Backward-compatible wrapper that renders the new professional text field.
class M3TextField extends StatelessWidget {
  const M3TextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.readOnly = false,
    this.upperCase = true,
    this.suffixWidget,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onTap,
    this.maxLines = 1,
    this.inputFormatters,
    this.validator,
    this.requiredLabel,
    this.missingRequiredFields = const {},
    this.requiredDate,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool readOnly;
  final bool upperCase;
  final Widget? suffixWidget;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onTap;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  /// Label key from [_collectMissingRequiredFields] for inline required errors.
  final String? requiredLabel;
  final Set<String> missingRequiredFields;
  /// When set, empty check uses this instead of controller text (date pickers).
  final DateTime? requiredDate;

  String? Function(String?)? get _effectiveValidator {
    if (validator != null) return validator;
    if (requiredLabel == null) return null;
    return (value) {
      if (!missingRequiredFields.contains(requiredLabel)) return null;
      if (requiredDate != null) {
        return requiredDate == null ? 'Wajib diisi' : null;
      }
      if ((value ?? '').trim().isEmpty) return 'Wajib diisi';
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalTextField(
      controller: controller,
      label: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      readOnly: readOnly,
      onTap: onTap,
      upperCase: upperCase,
      suffixIcon: suffixWidget,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: _effectiveValidator,
    );
  }
}

/// Backward-compatible wrapper that renders the new professional phone field.
class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.requiredLabel,
    this.missingRequiredFields = const {},
    this.skipRequired = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final String? requiredLabel;
  final Set<String> missingRequiredFields;
  final bool skipRequired;

  String? Function(String?)? get _effectiveValidator {
    if (skipRequired) return validator;
    final requiredKey = requiredLabel ?? label;
    return (value) {
      if (!skipRequired &&
          missingRequiredFields.contains(requiredKey) &&
          ProfessionalPhoneField.normalizeIndonesiaNumber(value ?? '').isEmpty) {
        return 'Wajib diisi';
      }
      if (validator != null) return validator!(value);
      if ((value ?? '').trim().isNotEmpty) return validatePhoneNumber(value);
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalPhoneField(
      controller: controller,
      label: label,
      hintText: hint,
      textInputAction: TextInputAction.next,
      validator: _effectiveValidator,
    );
  }
}

String? validatePhoneNumber(String? value) {
  final normalized = ProfessionalPhoneField.normalizeIndonesiaNumber(
    value ?? '',
  );
  if (normalized.isEmpty) return 'Nomor telepon wajib diisi';
  if (normalized.length < 8 || normalized.length > 13) {
    return 'Nomor telepon harus 8-13 digit';
  }
  return null;
}

/// M3 card wrapping a section with icon header and children.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final List<Widget> children;

  static const Color _accent = Color(0xFF0A7A43);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B4332),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: tt.bodySmall?.copyWith(
                            color: const Color(0xFF52796F),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Tappable region picker that looks like a filled text field.
class _RegionPickerField extends StatelessWidget {
  const _RegionPickerField({
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.onTap,
    this.selected,
    this.enabled = true,
    this.errorText,
  });

  final String label;
  final String hint;
  final IconData prefixIcon;
  final Region? selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.6,
          child: IgnorePointer(
            ignoring: !enabled,
            child: ProfessionalDropdownField(
              valueText: selected?.name ?? '',
              label: label,
              hint: hint,
              prefixIcon: prefixIcon,
              onTap: onTap,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ],
    );
  }
}

/// Region list sheet styled like registration tempat lahir picker.
class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({
    required this.title,
    required this.items,
    this.selected,
  });

  final String title;
  final List<Region> items;
  final Region? selected;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<Region> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = List.of(widget.items);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        if (q.isEmpty) {
          _filtered = List.of(widget.items);
        } else {
          _filtered = widget.items
              .where((r) => r.name.toLowerCase().contains(q))
              .toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari wilayah...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textMedium,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textMedium,
                              size: 18,
                            ),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundOffWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryDarkGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} hasil',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ditemukan',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final r = _filtered[i];
                          final isSelected = widget.selected?.id == r.id;
                          return ListTile(
                            onTap: () => Navigator.pop(context, r),
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryDarkGreen
                                .withValues(alpha: 0.1),
                            tileColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            title: Text(
                              r.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primaryDarkGreen
                                    : AppColors.textDark,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryDarkGreen,
                                    size: 20,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Divider with centred label (Ayah / Ibu).
class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

/// Non-null wrapper so a bottom sheet can return "clear" vs user dismissing (null).
class _OptionPick<T> {
  const _OptionPick(this.value);
  final T? value;
}

String? _dropdownLabelForValue<T>(T? value, List<(T, String)> items) {
  if (value == null) return null;
  for (final i in items) {
    if (i.$1 == value) return i.$2;
  }
  if (value is String) {
    final vu = value.toUpperCase();
    for (final i in items) {
      if (i.$1 is String && (i.$1 as String).toUpperCase() == vu) {
        return i.$2;
      }
    }
  }
  return null;
}

/// Generic dropdown field matching professional white style + registration sheets.
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.prefixIcon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String label;
  final IconData prefixIcon;
  final T? value;
  final String hint;

  /// Each item is `(value, displayLabel)`.
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedLabel = _dropdownLabelForValue(value, items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfessionalDropdownField(
          valueText: selectedLabel ?? '',
          label: label,
          hint: hint,
          prefixIcon: prefixIcon,
          onTap: () async {
            final result = await showModalBottomSheet<_OptionPick<T>?>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _SimpleOptionSheet<T>(
                title: label,
                hint: hint,
                value: value,
                items: items,
              ),
            );
            if (result == null) return;
            onChanged(result.value);
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _SimpleOptionSheet<T> extends StatefulWidget {
  const _SimpleOptionSheet({
    required this.title,
    required this.hint,
    required this.value,
    required this.items,
  });

  final String title;
  final String hint;
  final T? value;
  final List<(T, String)> items;

  @override
  State<_SimpleOptionSheet<T>> createState() => _SimpleOptionSheetState<T>();
}

class _SimpleOptionSheetState<T> extends State<_SimpleOptionSheet<T>> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _selected(T? a, T? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a == b) return true;
    if (a is String && b is String) {
      return (a as String).toUpperCase() == (b as String).toUpperCase();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.items
        .where((i) => i.$2.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textMedium,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textMedium,
                              size: 18,
                            ),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundOffWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryDarkGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        title: Text(
                          'Kosongkan pilihan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                        onTap: () =>
                            Navigator.pop(context, _OptionPick<T>(null)),
                      );
                    }
                    final item = filtered[index - 1];
                    final selected = _selected(item.$1, widget.value);
                    return ListTile(
                      onTap: () =>
                          Navigator.pop(context, _OptionPick<T>(item.$1)),
                      selected: selected,
                      selectedTileColor: AppColors.primaryDarkGreen.withValues(
                        alpha: 0.1,
                      ),
                      tileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      title: Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryDarkGreen
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryDarkGreen,
                              size: 20,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// M3 SegmentedButton gender picker.
class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.selected,
    required this.onChanged,
    this.errorText,
  });
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Jenis Kelamin',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'M',
              label: Text('Laki-laki'),
              icon: Icon(Icons.male_rounded),
            ),
            ButtonSegment(
              value: 'F',
              label: Text('Perempuan'),
              icon: Icon(Icons.female_rounded),
            ),
          ],
          selected: selected != null ? {selected!} : {},
          emptySelectionAllowed: true,
          multiSelectionEnabled: false,
          onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
          style: SegmentedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dropdown selector for heir (ahli waris) relationship type.
class _HeirRelationshipSelector extends StatelessWidget {
  const _HeirRelationshipSelector({
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  static const _options = <(String, String)>[
    ('SUAMI', 'Suami'),
    ('ISTRI', 'Istri'),
    ('AYAH', 'Ayah'),
    ('IBU', 'Ibu'),
    ('KAKAK', 'Kakak'),
    ('ADIK', 'Adik'),
    ('ANAK', 'Anak'),
    ('PAMAN', 'Paman'),
    ('BIBI', 'Bibi'),
    ('LAINNYA', 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context) {
    return _DropdownField<String>(
      label: 'Hubungan',
      prefixIcon: Icons.family_restroom_outlined,
      value: selected,
      hint: 'Pilih hubungan',
      items: _options,
      onChanged: onChanged,
      errorText: errorText,
    );
  }
}

// =============================================================================
// Staff referrer picker widgets
// =============================================================================

class _StaffReferrerInfoField extends StatelessWidget {
  const _StaffReferrerInfoField({
    required this.selected,
    this.profileReferrerName,
    this.profileReferrerCode,
  });

  final StaffReferrer? selected;
  final String? profileReferrerName;
  final String? profileReferrerCode;

  @override
  Widget build(BuildContext context) {
    final name = selected?.fullName ?? profileReferrerName;
    final code = selected?.referralCode ?? profileReferrerCode;
    final hasName = name != null && name.trim().isNotEmpty;
    final hasCode = code != null && code.trim().isNotEmpty;
    final safeName = name?.trim() ?? '';
    final safeCode = code?.trim() ?? '';

    final displayValue = hasName
        ? (hasCode ? '$safeName • $safeCode' : safeName)
        : (hasCode ? safeCode : 'Belum ada staff rujukan');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Staff Penerima Rujukan',
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayValue,
          style: tt.bodyMedium?.copyWith(
            color: hasName || hasCode ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StaffPickerSheet extends ConsumerStatefulWidget {
  final AsyncValue<List<StaffReferrer>> staffAsync;

  const _StaffPickerSheet({required this.staffAsync});

  @override
  ConsumerState<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends ConsumerState<_StaffPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<StaffReferrer> _filtered = [];
  List<StaffReferrer> _all = [];

  @override
  void initState() {
    super.initState();
    widget.staffAsync.whenData((list) {
      _all = list;
      _filtered = list;
    });
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where(
                  (s) =>
                      s.fullName.toLowerCase().contains(q) ||
                      s.referralCode.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final staffAsync = ref.watch(staffReferrersProvider);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Pilih Staff Rujukan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau kode...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: staffAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gagal memuat data',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(staffReferrersProvider),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  if (_all.isEmpty && list.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _all = list;
                        _filtered = list;
                      });
                    });
                  }
                  if (_filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada staff ditemukan',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final staff = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            staff.fullName.isNotEmpty
                                ? staff.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          staff.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Kode: ${staff.referralCode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(staff),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }
}
