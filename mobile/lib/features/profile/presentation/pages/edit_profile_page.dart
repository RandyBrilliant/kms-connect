import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/region.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';
import '../../../../core/widgets/phone_input_field.dart';
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
  final _address = TextEditingController();
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
  final _fatherPhone = TextEditingController();
  final _motherPhone = TextEditingController();
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
  Region? _kabupaten;   // Kabupaten/Kota (regency)
  Region? _kecamatan;   // Kecamatan (district)
  Region? _kelurahan;   // Kelurahan/Desa (village)

  // ── Region state – Tempat Lahir ──────────────────────────────────────────
  Region? _birthPlace;  // Regency

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
            final match = list.where((s) => s.id == profile.referrerId).firstOrNull;
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
      _fullName, _nik, _birthDate, _address, _phone,
      _siblingCount, _birthOrder, _fatherName, _fatherAge, _fatherOccupation,
      _motherName, _motherAge, _motherOccupation, _familyAddress, _fatherPhone,
      _motherPhone,
      _spouseName, _spouseAge, _spouseOccupation,
      _heirName, _heirContactPhone,
      _fatherBirthDateCtrl, _motherBirthDateCtrl, _spouseBirthDateCtrl,
      _educationMajor, _heightCm, _weightKg, _shoeSize,
      _passportNumber, _passportIssuePlace, _passportIssueDateCtrl,
      _passportExpiryDateCtrl,
      _familyCardNumber, _diplomaNumber, _bpjsNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
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
    _gender = p.gender;
    _address.text = (p.address ?? '').toUpperCase();
    _phone.text = p.contactPhone ?? '';
    _siblingCount.text = p.siblingCount?.toString() ?? '';
    _birthOrder.text = p.birthOrder?.toString() ?? '';

    // ── New: Data Pribadi dropdowns ──────────────────────────────────────
    _religion = (p.religion?.isNotEmpty == true) ? p.religion : null;
    _educationLevel = (p.educationLevel?.isNotEmpty == true) ? p.educationLevel : null;
    _educationMajor.text = (p.educationMajor ?? '').toUpperCase();
    _maritalStatus = (p.maritalStatus?.isNotEmpty == true) ? p.maritalStatus : null;

    // ── New: Data Fisik ──────────────────────────────────────────────────
    _heightCm.text = p.heightCm?.toString() ?? '';
    _weightKg.text = p.weightKg?.toString() ?? '';
    _wearsGlasses = p.wearsGlasses;
    _writingHand = (p.writingHand?.isNotEmpty == true) ? p.writingHand : null;
    _shoeSize.text = p.shoeSize?.toString() ?? '';
    _shirtSize = (p.shirtSize?.isNotEmpty == true) ? p.shirtSize : null;

    // ── New: Data Paspor ────────────────────────────────────────────────
    _hasPassport = p.hasPassport;
    _passportNumber.text = p.passportNumber ?? '';
    _passportIssuePlace.text = (p.passportIssuePlace ?? '').toUpperCase();
    if (p.passportIssueDate != null) {
      _pickedPassportIssueDate = p.passportIssueDate;
      _passportIssueDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(p.passportIssueDate!);
    }
    if (p.passportExpiryDate != null) {
      _pickedPassportExpiryDate = p.passportExpiryDate;
      _passportExpiryDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(p.passportExpiryDate!);
    }

    // ── New: Data Dokumen ───────────────────────────────────────────────
    _familyCardNumber.text = p.familyCardNumber ?? '';
    _diplomaNumber.text = p.diplomaNumber ?? '';
    _bpjsNumber.text = p.bpjsNumber ?? '';

    // ── Keluarga ────────────────────────────────────────────────────────
    _fatherName.text = (p.fatherName ?? '').toUpperCase();
    _fatherAge.text = p.fatherAge?.toString() ?? '';
    if (p.fatherAge != null) {
      _pickedFatherBirthDate = DateTime(DateTime.now().year - p.fatherAge!);
      _fatherBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedFatherBirthDate!);
    }
    _fatherOccupation.text = (p.fatherOccupation ?? '').toUpperCase();
    _motherName.text = (p.motherName ?? '').toUpperCase();
    _motherAge.text = p.motherAge?.toString() ?? '';
    if (p.motherAge != null) {
      _pickedMotherBirthDate = DateTime(DateTime.now().year - p.motherAge!);
      _motherBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedMotherBirthDate!);
    }
    _motherOccupation.text = (p.motherOccupation ?? '').toUpperCase();
    _familyAddress.text = (p.familyAddress ?? '').toUpperCase();
    _fatherPhone.text = p.fatherPhone ?? '';
    _motherPhone.text = p.motherPhone ?? '';
    _spouseName.text = (p.spouseName ?? '').toUpperCase();
    _spouseAge.text = p.spouseAge?.toString() ?? '';
    if (p.spouseAge != null) {
      _pickedSpouseBirthDate = DateTime(DateTime.now().year - p.spouseAge!);
      _spouseBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedSpouseBirthDate!);
    }
    _spouseOccupation.text = (p.spouseOccupation ?? '').toUpperCase();

    // Ahli Waris
    _heirName.text = (p.heirName ?? '').toUpperCase();
    _heirRelationship = (p.heirRelationship?.isNotEmpty == true) ? p.heirRelationship : null;
    _heirContactPhone.text = p.heirContactPhone ?? '';

    // Pre-seed region objects from names stored in profile
    if (p.birthPlaceId != null && p.birthPlaceName != null) {
      _birthPlace = Region(id: p.birthPlaceId!, code: '', name: p.birthPlaceName!);
    }
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
      _familyProvince = Region(id: p.familyProvinceId!, code: '', name: p.familyProvinceName!);
    }
    if (p.familyDistrictId != null && p.familyDistrictName != null) {
      _familyKabupaten = Region(id: p.familyDistrictId!, code: '', name: p.familyDistrictName!);
    }
    if (p.familyVillageId != null && p.familyVillageName != null) {
      _familyKelurahan = Region(id: p.familyVillageId!, code: '', name: p.familyVillageName!);
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
        controller.text =
            DateFormat('dd MMMM yyyy', 'id').format(picked);
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
        _birthDate.text =
            DateFormat('dd MMMM yyyy', 'id').format(picked);
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

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = <String, dynamic>{
      if (_fullName.text.trim().isNotEmpty)
        'full_name': _fullName.text.trim(),
      if (_nik.text.trim().isNotEmpty) 'nik': _nik.text.trim(),
      if (_birthPlace != null) 'birth_place': _birthPlace!.id,
      if (_pickedDate != null)
        'birth_date': DateFormat('yyyy-MM-dd').format(_pickedDate!),
      if (_gender != null) 'gender': _gender,
      if (_address.text.trim().isNotEmpty)
        'address': _address.text.trim(),
      if (_province != null) 'province': _province!.id,
      if (_kabupaten != null) 'district': _kabupaten!.id,
      if (_kecamatan != null) 'kecamatan': _kecamatan!.id,
      if (_kelurahan != null) 'village': _kelurahan!.id,
      if (_phone.text.trim().isNotEmpty)
        'contact_phone': _phone.text.trim(),

      // ── New: Data Pribadi dropdowns ──────────────────────────────────
      if (_religion != null) 'religion': _religion,
      if (_educationLevel != null) 'education_level': _educationLevel,
      if (_educationMajor.text.trim().isNotEmpty)
        'education_major': _educationMajor.text.trim(),
      if (_maritalStatus != null) 'marital_status': _maritalStatus,

      // ── New: Data Fisik ──────────────────────────────────────────────
      if (_heightCm.text.trim().isNotEmpty)
        'height_cm': int.tryParse(_heightCm.text.trim()),
      if (_weightKg.text.trim().isNotEmpty)
        'weight_kg': int.tryParse(_weightKg.text.trim()),
      if (_wearsGlasses != null) 'wears_glasses': _wearsGlasses,
      if (_writingHand != null) 'writing_hand': _writingHand,
      if (_shoeSize.text.trim().isNotEmpty)
        'shoe_size': _shoeSize.text.trim(),
      if (_shirtSize != null) 'shirt_size': _shirtSize,

      // ── New: Data Paspor ─────────────────────────────────────────────
      if (_hasPassport != null) 'has_passport': _hasPassport,
      if (_passportNumber.text.trim().isNotEmpty)
        'passport_number': _passportNumber.text.trim(),
      if (_pickedPassportIssueDate != null)
        'passport_issue_date': DateFormat('yyyy-MM-dd').format(_pickedPassportIssueDate!),
      if (_passportIssuePlace.text.trim().isNotEmpty)
        'passport_issue_place': _passportIssuePlace.text.trim(),
      if (_pickedPassportExpiryDate != null)
        'passport_expiry_date': DateFormat('yyyy-MM-dd').format(_pickedPassportExpiryDate!),

      // ── New: Data Dokumen ────────────────────────────────────────────
      if (_familyCardNumber.text.trim().isNotEmpty)
        'family_card_number': _familyCardNumber.text.trim(),
      if (_diplomaNumber.text.trim().isNotEmpty)
        'diploma_number': _diplomaNumber.text.trim(),
      if (_bpjsNumber.text.trim().isNotEmpty)
        'bpjs_number': _bpjsNumber.text.trim(),

      // ── Keluarga ────────────────────────────────────────────────────
      if (_siblingCount.text.trim().isNotEmpty)
        'sibling_count': int.tryParse(_siblingCount.text.trim()),
      if (_birthOrder.text.trim().isNotEmpty)
        'birth_order': int.tryParse(_birthOrder.text.trim()),
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
      if (_familyProvince != null) 'family_province': _familyProvince!.id,
      if (_familyKabupaten != null) 'family_district': _familyKabupaten!.id,
      if (_familyKelurahan != null) 'family_village': _familyKelurahan!.id,
      if (_fatherPhone.text.trim().isNotEmpty)
        'father_phone': _fatherPhone.text.trim(),
      if (_motherPhone.text.trim().isNotEmpty)
        'mother_phone': _motherPhone.text.trim(),
      if (_selectedStaff != null)
        'referral_code_input': _selectedStaff!.referralCode,
      if (_spouseName.text.trim().isNotEmpty)
        'spouse_name': _spouseName.text.trim(),
      if (_pickedSpouseBirthDate != null)
        'spouse_age': _computeAge(_pickedSpouseBirthDate!),
      if (_spouseOccupation.text.trim().isNotEmpty)
        'spouse_occupation': _spouseOccupation.text.trim(),
      if (_heirName.text.trim().isNotEmpty)
        'heir_name': _heirName.text.trim(),
      if (_heirRelationship != null)
        'heir_relationship': _heirRelationship,
      if (_heirContactPhone.text.trim().isNotEmpty)
        'heir_contact_phone': _heirContactPhone.text.trim(),
    };

    final success =
        await ref.read(profileNotifierProvider.notifier).updateProfile(data);
    if (!mounted) return;
    if (success) {
      ref.invalidate(profileProvider);
      CustomToast.show(context,
          message: 'Profil berhasil diperbarui',
          type: ToastType.success);
      Navigator.pop(context);
    } else {
      final err =
          ref.read(profileNotifierProvider).error ?? 'Gagal menyimpan';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
  }

  // ── Region bottom-sheet picker ─────────────────────────────────────────────
  Future<Region?> _showRegionPicker({
    required String title,
    required List<Region> items,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final searchCtrl = TextEditingController();
    List<Region> filtered = List.of(items);

    return showModalBottomSheet<Region>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(title,
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  controller: searchCtrl,
                  hintText: 'Cari...',
                  leading: const Icon(Icons.search_rounded, size: 20),
                  onChanged: (q) {
                    final lower = q.toLowerCase();
                    setModal(() {
                      filtered = items
                          .where((r) =>
                              r.name.toLowerCase().contains(lower))
                          .toList();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('Tidak ditemukan',
                            style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          return ListTile(
                            title: Text(r.name,
                                style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500)),
                            onTap: () => Navigator.pop(ctx, r),
                          );
                        },
                      ),
              ),
              SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 8),
            ],
          ),
        ),
      ),
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
        if (mounted) _populate(profile);
      });
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Loading skeleton
    if (profileState.isLoading && profile == null) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              const Expanded(
                  child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    // Error state
    if (profileState.error != null && profile == null) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text('Gagal memuat data',
                            style: tt.titleMedium
                                ?.copyWith(color: cs.error)),
                        const SizedBox(height: 8),
                        Text(profileState.error!,
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(profileNotifierProvider.notifier)
                              .loadProfile(),
                          icon:
                              const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
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
                          readOnly: true,
                          upperCase: true,
                          suffixWidget: const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                          ),
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
                        // Tempat lahir – regency picker
                        _RegionPickerField(
                          label: 'Tempat Lahir',
                          hint: 'Pilih kabupaten/kota',
                          prefixIcon: Icons.location_city_outlined,
                          selected: _birthPlace,
                          onTap: () async {
                            final items = await ref
                                .read(regenciesProvider.future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kota/Kabupaten',
                                items: items);
                            if (picked != null) {
                              setState(
                                  () => _birthPlace = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _birthDate,
                          label: 'Tanggal Lahir',
                          hint: 'Pilih tanggal',
                          prefixIcon:
                              Icons.calendar_today_outlined,
                          readOnly: true,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 14),
                        _GenderSelector(
                          selected: _gender,
                          onChanged: (g) =>
                              setState(() => _gender = g),
                        ),
                        const SizedBox(height: 14),
                        PhoneInputField(
                          controller: _phone,
                          label: 'Nomor Telepon',
                          hint: '812xxxxxxxx',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return validatePhoneNumber(v);
                          },
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
                          onChanged: (v) => setState(() => _religion = v),
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
                          onChanged: (v) => setState(() => _maritalStatus = v),
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
                          onChanged: (v) => setState(() => _educationLevel = v),
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _educationMajor,
                          label: 'Jurusan',
                          hint: 'Contoh: Teknik Mesin',
                          prefixIcon: Icons.menu_book_outlined,
                          upperCase: true,
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
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: M3TextField(
                                controller: _weightKg,
                                label: 'Berat (kg)',
                                hint: '60',
                                prefixIcon: Icons.monitor_weight_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
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
                          onChanged: (v) => setState(() => _wearsGlasses = v),
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
                          onChanged: (v) => setState(() => _writingHand = v),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: M3TextField(
                                controller: _shoeSize,
                                label: 'Ukuran Sepatu',
                                hint: '42',
                                prefixIcon: Icons.ice_skating_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
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
                                onChanged: (v) => setState(() => _shirtSize = v),
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
                        ),
                        const SizedBox(height: 14),
                        // Province
                        _RegionPickerField(
                          label: 'Provinsi',
                          hint: 'Pilih provinsi',
                          prefixIcon: Icons.map_outlined,
                          selected: _province,
                          onTap: () async {
                            final items = await ref
                                .read(provincesProvider.future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Provinsi',
                                items: items);
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
                          prefixIcon:
                              Icons.location_city_outlined,
                          selected: _kabupaten,
                          enabled: _province != null,
                          onTap: () async {
                            if (_province == null) return;
                            final items = await ref.read(
                                regenciesByProvinceProvider(
                                        _province!.id)
                                    .future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kab/Kota',
                                items: items);
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
                          onTap: () async {
                            if (_kabupaten == null) return;
                            final items = await ref.read(
                                districtsByRegencyProvider(
                                        _kabupaten!.id)
                                    .future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kecamatan',
                                items: items);
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
                          onTap: () async {
                            if (_kecamatan == null) return;
                            final items = await ref.read(
                                villagesByDistrictProvider(
                                        _kecamatan!.id)
                                    .future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kelurahan/Desa',
                                items: items);
                            if (picked != null) {
                              setState(
                                  () => _kelurahan = picked);
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
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _diplomaNumber,
                          label: 'Nomor Ijazah',
                          hint: 'Nomor ijazah terakhir',
                          prefixIcon: Icons.school_outlined,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _bpjsNumber,
                          label: 'Nomor BPJS / KIS',
                          hint: 'Nomor BPJS kesehatan',
                          prefixIcon: Icons.health_and_safety_outlined,
                          keyboardType: TextInputType.number,
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
                          onChanged: (v) => setState(() => _hasPassport = v),
                        ),
                        if (_hasPassport == true) ...[
                          const SizedBox(height: 14),
                          M3TextField(
                            controller: _passportNumber,
                            label: 'Nomor Paspor',
                            hint: 'A12345678',
                            prefixIcon: Icons.confirmation_number_outlined,
                          ),
                          const SizedBox(height: 14),
                          M3TextField(
                            controller: _passportIssuePlace,
                            label: 'Tempat Terbit Paspor',
                            hint: 'Contoh: Jakarta',
                            prefixIcon: Icons.location_on_outlined,
                            upperCase: true,
                          ),
                          const SizedBox(height: 14),
                          M3TextField(
                            controller: _passportIssueDateCtrl,
                            label: 'Tanggal Terbit',
                            hint: 'Pilih tanggal',
                            prefixIcon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: () => _pickGenericDate(
                              current: _pickedPassportIssueDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              onPicked: (d) => setState(() {
                                _pickedPassportIssueDate = d;
                                _passportIssueDateCtrl.text =
                                    DateFormat('dd MMMM yyyy', 'id').format(d);
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
                            onTap: () => _pickGenericDate(
                              current: _pickedPassportExpiryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(DateTime.now().year + 20),
                              onPicked: (d) => setState(() {
                                _pickedPassportExpiryDate = d;
                                _passportExpiryDateCtrl.text =
                                    DateFormat('dd MMMM yyyy', 'id').format(d);
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
                                prefixIcon:
                                    Icons.people_outline,
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly
                                ],
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
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SubLabel('Ayah'),
                        const SizedBox(height: 8),
                        M3TextField(
                          controller: _fatherName,
                          label: 'Nama Ayah',
                          hint: 'Nama lengkap',
                          prefixIcon: Icons.person_outline_rounded,
                          upperCase: true,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _fatherBirthDateCtrl,
                          label: 'Tanggal Lahir Ayah',
                          hint: 'Pilih tanggal',
                          prefixIcon: Icons.calendar_today_outlined,
                          readOnly: true,
                          onTap: () => _pickFamilyMemberDate(
                            controller: _fatherBirthDateCtrl,
                            current: _pickedFatherBirthDate,
                            onPicked: (d) =>
                                setState(() => _pickedFatherBirthDate = d),
                          ),
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _fatherOccupation,
                          label: 'Pekerjaan Ayah',
                          hint: 'Contoh: Wiraswasta',
                          prefixIcon: Icons.work_outline_rounded,
                          upperCase: true,
                        ),
                        const SizedBox(height: 14),
                        PhoneInputField(
                          controller: _fatherPhone,
                          label: 'No. Telepon Ayah',
                          hint: '812xxxxxxxx',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return validatePhoneNumber(v);
                          },
                        ),
                        const SizedBox(height: 18),
                        _SubLabel('Ibu'),
                        const SizedBox(height: 8),
                        M3TextField(
                          controller: _motherName,
                          label: 'Nama Ibu',
                          hint: 'Nama lengkap',
                          prefixIcon: Icons.person_outline_rounded,
                          upperCase: true,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _motherBirthDateCtrl,
                          label: 'Tanggal Lahir Ibu',
                          hint: 'Pilih tanggal',
                          prefixIcon: Icons.calendar_today_outlined,
                          readOnly: true,
                          onTap: () => _pickFamilyMemberDate(
                            controller: _motherBirthDateCtrl,
                            current: _pickedMotherBirthDate,
                            onPicked: (d) =>
                                setState(() => _pickedMotherBirthDate = d),
                          ),
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _motherOccupation,
                          label: 'Pekerjaan Ibu',
                          hint: 'Contoh: Ibu Rumah Tangga',
                          prefixIcon: Icons.work_outline_rounded,
                          upperCase: true,
                        ),
                        const SizedBox(height: 14),
                        PhoneInputField(
                          controller: _motherPhone,
                          label: 'No. Telepon Ibu',
                          hint: '812xxxxxxxx',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return validatePhoneNumber(v);
                          },
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _familyAddress,
                          label: 'Alamat Keluarga',
                          hint: 'Jika berbeda dengan alamat KTP',
                          prefixIcon: Icons.home_outlined,
                          maxLines: 2,
                          upperCase: true,
                        ),
                        const SizedBox(height: 14),
                        // ── Family address region pickers ──
                        _RegionPickerField(
                          label: 'Provinsi (Keluarga)',
                          hint: 'Pilih provinsi',
                          prefixIcon: Icons.map_outlined,
                          selected: _familyProvince,
                          onTap: () async {
                            final items = await ref.read(provincesProvider.future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Provinsi', items: items);
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
                          label: 'Kab/Kota (Keluarga)',
                          hint: _familyProvince == null
                              ? 'Pilih provinsi dahulu'
                              : 'Pilih kab/kota',
                          prefixIcon: Icons.location_city_outlined,
                          selected: _familyKabupaten,
                          enabled: _familyProvince != null,
                          onTap: () async {
                            if (_familyProvince == null) return;
                            final items = await ref.read(
                                regenciesByProvinceProvider(_familyProvince!.id).future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kab/Kota', items: items);
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
                          label: 'Kecamatan (Keluarga)',
                          hint: _familyKabupaten == null
                              ? 'Pilih kab/kota dahulu'
                              : 'Pilih kecamatan',
                          prefixIcon: Icons.place_outlined,
                          selected: _familyKecamatan,
                          enabled: _familyKabupaten != null,
                          onTap: () async {
                            if (_familyKabupaten == null) return;
                            final items = await ref.read(
                                districtsByRegencyProvider(_familyKabupaten!.id).future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kecamatan', items: items);
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
                          label: 'Kelurahan (Keluarga)',
                          hint: _familyKecamatan == null
                              ? 'Pilih kecamatan dahulu'
                              : 'Pilih kelurahan',
                          prefixIcon: Icons.villa_outlined,
                          selected: _familyKelurahan,
                          enabled: _familyKecamatan != null,
                          onTap: () async {
                            if (_familyKecamatan == null) return;
                            final items = await ref.read(
                                villagesByDistrictProvider(_familyKecamatan!.id).future);
                            if (!mounted) return;
                            final picked = await _showRegionPicker(
                                title: 'Pilih Kelurahan/Desa', items: items);
                            if (picked != null) {
                              setState(() => _familyKelurahan = picked);
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
                            onPicked: (d) =>
                                setState(() => _pickedSpouseBirthDate = d),
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
                        ),
                        const SizedBox(height: 14),
                        _HeirRelationshipSelector(
                          selected: _heirRelationship,
                          onChanged: (v) =>
                              setState(() => _heirRelationship = v),
                        ),
                        const SizedBox(height: 14),
                        PhoneInputField(
                          controller: _heirContactPhone,
                          label: 'No. Telepon Ahli Waris',
                          hint: '812xxxxxxxx',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return validatePhoneNumber(v);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ─── Informasi Staff Rujukan ───────────────────────
                    _SectionCard(
                      icon: Icons.person_pin_outlined,
                      label: 'Staff Rujukan',
                      subtitle: 'Petugas yang merujuk Anda',
                      children: [
                        _StaffReferrerPickerField(
                          selected: _selectedStaff,
                          onTap: () async {
                            final staffAsync =
                                ref.read(staffReferrersProvider);
                            final picked =
                                await showModalBottomSheet<StaffReferrer>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _StaffPickerSheet(
                                staffAsync: staffAsync,
                                initialSelected: _selectedStaff,
                              ),
                            );
                            if (picked != null && mounted) {
                              setState(() => _selectedStaff = picked);
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ─── Save button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            profileState.isLoading ? null : _handleSave,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: profileState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      color: cs.primaryContainer,
      padding: EdgeInsets.fromLTRB(8, topPad + 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 4),
          Text(
            'Data Diri',
            style: tt.titleLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      color: cs.surfaceContainerLow,
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
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18,
                      color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        )),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: cs.outlineVariant),
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
  });

  final String label;
  final String hint;
  final IconData prefixIcon;
  final Region? selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final activeColor =
        enabled ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.38);
    final fillColor = enabled
        ? cs.surfaceContainerHighest
        : cs.onSurface.withValues(alpha: 0.04);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(prefixIcon, size: 20, color: activeColor),
          suffixIcon:
              Icon(Icons.arrow_drop_down_rounded, color: activeColor),
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
        isEmpty: selected == null,
        child: selected != null
            ? Text(
                selected!.name,
                style: tt.bodyLarge?.copyWith(
                  color: enabled
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.38),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(hint,
                style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.38))),
      ),
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
          child: Text(text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  )),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

/// Generic dropdown field matching the M3 filled style.
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.prefixIcon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final IconData prefixIcon;
  final T? value;
  final String hint;
  /// Each item is `(value, displayLabel)`.
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(prefixIcon, size: 20, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: hint,
      ),
      items: [
        DropdownMenuItem<T>(value: null, child: Text(hint)),
        ...items.map(
          (i) => DropdownMenuItem<T>(value: i.$1, child: Text(i.$2)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// M3 SegmentedButton gender picker.
class _GenderSelector extends StatelessWidget {
  const _GenderSelector(
      {required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Jenis Kelamin',
              style: tt.labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
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
          onSelectionChanged: (s) =>
              onChanged(s.isEmpty ? null : s.first),
          style: SegmentedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown selector for heir (ahli waris) relationship type.
class _HeirRelationshipSelector extends StatelessWidget {
  const _HeirRelationshipSelector({
      required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Hubungan',
              style: tt.labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
        DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.family_restroom_outlined, size: 20),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            hintText: 'Pilih hubungan',
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Pilih hubungan'),
            ),
            ..._options.map(
              (o) => DropdownMenuItem<String>(
                value: o.$1,
                child: Text(o.$2),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// =============================================================================
// Staff referrer picker widgets
// =============================================================================

class _StaffReferrerPickerField extends StatelessWidget {
  const _StaffReferrerPickerField({
    required this.selected,
    required this.onTap,
  });

  final StaffReferrer? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasValue = selected != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Staff Penerima Rujukan',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon:
              Icon(Icons.person_outline_rounded, size: 20, color: cs.onSurfaceVariant),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: cs.onSurfaceVariant),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        isEmpty: !hasValue,
        child: hasValue
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected!.fullName,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
                  Text(
                    'Kode: ${selected!.referralCode}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              )
            : Text('Pilih staff...',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ),
    );
  }
}

class _StaffPickerSheet extends ConsumerStatefulWidget {
  final AsyncValue<List<StaffReferrer>> staffAsync;
  final StaffReferrer? initialSelected;

  const _StaffPickerSheet({
    required this.staffAsync,
    this.initialSelected,
  });

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
              .where((s) =>
                  s.fullName.toLowerCase().contains(q) ||
                  s.referralCode.toLowerCase().contains(q))
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
              child: Text('Pilih Staff Rujukan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
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
                      horizontal: 16, vertical: 12),
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
                      Icon(Icons.wifi_off_rounded,
                          size: 40, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('Gagal memuat data',
                          style: TextStyle(color: cs.onSurfaceVariant)),
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
                      child: Text('Tidak ada staff ditemukan',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final staff = _filtered[i];
                      final isSelected =
                          widget.initialSelected?.id == staff.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? cs.primary
                              : cs.primaryContainer,
                          child: Text(
                            staff.fullName.isNotEmpty
                                ? staff.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isSelected
                                  ? cs.onPrimary
                                  : cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(staff.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('Kode: ${staff.referralCode}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: cs.primary)
                            : null,
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
