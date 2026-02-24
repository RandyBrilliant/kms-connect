import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/region.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';
import '../../../auth/data/providers/regions_provider.dart';
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
  final _familyPhone = TextEditingController();
  final _spouseName = TextEditingController();
  final _spouseAge = TextEditingController();
  final _spouseOccupation = TextEditingController();

  // Date-of-birth pickers for family members
  final _fatherBirthDateCtrl = TextEditingController();
  final _motherBirthDateCtrl = TextEditingController();
  final _spouseBirthDateCtrl = TextEditingController();

  // ── Region state – KTP address (cascading) ────────────────────────────────
  Region? _province;
  Region? _kabupaten;   // Kabupaten/Kota (regency)
  Region? _kecamatan;   // Kecamatan (district)
  Region? _kelurahan;   // Kelurahan/Desa (village)

  // ── Region state – Tempat Lahir ──────────────────────────────────────────
  Region? _birthPlace;  // Regency

  String? _gender;
  DateTime? _pickedDate;
  DateTime? _pickedFatherBirthDate;
  DateTime? _pickedMotherBirthDate;
  DateTime? _pickedSpouseBirthDate;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    // Populate form once profile is available — outside build() to avoid
    // triggering rebuilds inside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileNotifierProvider).profile;
      if (profile != null) _populate(profile);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _fullName, _nik, _birthDate, _address, _phone,
      _siblingCount, _birthOrder, _fatherName, _fatherAge, _fatherOccupation,
      _motherName, _motherAge, _motherOccupation, _familyAddress, _familyPhone,
      _spouseName, _spouseAge, _spouseOccupation,
      _fatherBirthDateCtrl, _motherBirthDateCtrl, _spouseBirthDateCtrl,
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
    _fullName.text = p.fullName ?? '';
    _nik.text = p.nik ?? '';
    if (p.birthDate != null) {
      _pickedDate = p.birthDate;
      _birthDate.text = DateFormat('dd MMMM yyyy', 'id').format(p.birthDate!);
    }
    _gender = p.gender;
    _address.text = p.address ?? '';
    _phone.text = p.contactPhone ?? '';
    _siblingCount.text = p.siblingCount?.toString() ?? '';
    _birthOrder.text = p.birthOrder?.toString() ?? '';
    _fatherName.text = p.fatherName ?? '';
    _fatherAge.text = p.fatherAge?.toString() ?? '';
    if (p.fatherAge != null) {
      _pickedFatherBirthDate = DateTime(DateTime.now().year - p.fatherAge!);
      _fatherBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedFatherBirthDate!);
    }
    _fatherOccupation.text = p.fatherOccupation ?? '';
    _motherName.text = p.motherName ?? '';
    _motherAge.text = p.motherAge?.toString() ?? '';
    if (p.motherAge != null) {
      _pickedMotherBirthDate = DateTime(DateTime.now().year - p.motherAge!);
      _motherBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedMotherBirthDate!);
    }
    _motherOccupation.text = p.motherOccupation ?? '';
    _familyAddress.text = p.familyAddress ?? '';
    _familyPhone.text = p.familyContactPhone ?? '';
    _spouseName.text = p.spouseName ?? '';
    _spouseAge.text = p.spouseAge?.toString() ?? '';
    if (p.spouseAge != null) {
      _pickedSpouseBirthDate = DateTime(DateTime.now().year - p.spouseAge!);
      _spouseBirthDateCtrl.text =
          DateFormat('dd MMMM yyyy', 'id').format(_pickedSpouseBirthDate!);
    }
    _spouseOccupation.text = p.spouseOccupation ?? '';

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
      if (_familyPhone.text.trim().isNotEmpty)
        'family_contact_phone': _familyPhone.text.trim(),
      if (_spouseName.text.trim().isNotEmpty)
        'spouse_name': _spouseName.text.trim(),
      if (_pickedSpouseBirthDate != null)
        'spouse_age': _computeAge(_pickedSpouseBirthDate!),
      if (_spouseOccupation.text.trim().isNotEmpty)
        'spouse_occupation': _spouseOccupation.text.trim(),
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
                          textCapitalization:
                              TextCapitalization.words,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Nama lengkap wajib diisi'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _nik,
                          label: 'NIK',
                          hint: '16 digit NIK',
                          prefixIcon: Icons.credit_card_outlined,
                          readOnly: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(16),
                          ],
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
                        M3TextField(
                          controller: _phone,
                          label: 'Nomor Telepon',
                          hint: 'Contoh: 0812xxxxxxxx',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
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
                          textCapitalization: TextCapitalization.words,
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
                          textCapitalization:
                              TextCapitalization.words,
                        ),
                        const SizedBox(height: 18),
                        _SubLabel('Ibu'),
                        const SizedBox(height: 8),
                        M3TextField(
                          controller: _motherName,
                          label: 'Nama Ibu',
                          hint: 'Nama lengkap',
                          prefixIcon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
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
                          textCapitalization:
                              TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _familyAddress,
                          label: 'Alamat Keluarga',
                          hint: 'Jika berbeda dengan alamat KTP',
                          prefixIcon: Icons.home_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        M3TextField(
                          controller: _familyPhone,
                          label: 'No. Telepon Keluarga',
                          hint: 'Contoh: 0812xxxxxxxx',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
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
                          textCapitalization: TextCapitalization.words,
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
                          textCapitalization:
                              TextCapitalization.words,
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
