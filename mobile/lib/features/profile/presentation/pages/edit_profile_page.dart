import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';
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
  final _birthPlace = TextEditingController();
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

  String? _gender;
  DateTime? _pickedDate;
  bool _populated = false;

  @override
  void dispose() {
    for (final c in [
      _fullName, _nik, _birthPlace, _birthDate, _address, _phone,
      _siblingCount, _birthOrder, _fatherName, _fatherAge, _fatherOccupation,
      _motherName, _motherAge, _motherOccupation, _familyAddress, _familyPhone,
      _spouseName, _spouseAge, _spouseOccupation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(ApplicantProfile p) {
    if (_populated) return;
    _populated = true;
    _fullName.text = p.fullName ?? '';
    _nik.text = p.nik ?? '';
    _birthPlace.text = p.birthPlace ?? '';
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
    _fatherOccupation.text = p.fatherOccupation ?? '';
    _motherName.text = p.motherName ?? '';
    _motherAge.text = p.motherAge?.toString() ?? '';
    _motherOccupation.text = p.motherOccupation ?? '';
    _familyAddress.text = p.familyAddress ?? '';
    _familyPhone.text = p.familyContactPhone ?? '';
    _spouseName.text = p.spouseName ?? '';
    _spouseAge.text = p.spouseAge?.toString() ?? '';
    _spouseOccupation.text = p.spouseOccupation ?? '';
    setState(() {});
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
      if (_birthPlace.text.trim().isNotEmpty)
        'birth_place': _birthPlace.text.trim(),
      if (_pickedDate != null)
        'birth_date': DateFormat('yyyy-MM-dd').format(_pickedDate!),
      if (_gender != null) 'gender': _gender,
      if (_address.text.trim().isNotEmpty)
        'address': _address.text.trim(),
      if (_phone.text.trim().isNotEmpty)
        'contact_phone': _phone.text.trim(),
      if (_siblingCount.text.trim().isNotEmpty)
        'sibling_count': int.tryParse(_siblingCount.text.trim()),
      if (_birthOrder.text.trim().isNotEmpty)
        'birth_order': int.tryParse(_birthOrder.text.trim()),
      if (_fatherName.text.trim().isNotEmpty)
        'father_name': _fatherName.text.trim(),
      if (_fatherAge.text.trim().isNotEmpty)
        'father_age': int.tryParse(_fatherAge.text.trim()),
      if (_fatherOccupation.text.trim().isNotEmpty)
        'father_occupation': _fatherOccupation.text.trim(),
      if (_motherName.text.trim().isNotEmpty)
        'mother_name': _motherName.text.trim(),
      if (_motherAge.text.trim().isNotEmpty)
        'mother_age': int.tryParse(_motherAge.text.trim()),
      if (_motherOccupation.text.trim().isNotEmpty)
        'mother_occupation': _motherOccupation.text.trim(),
      if (_familyAddress.text.trim().isNotEmpty)
        'family_address': _familyAddress.text.trim(),
      if (_familyPhone.text.trim().isNotEmpty)
        'family_contact_phone': _familyPhone.text.trim(),
      if (_spouseName.text.trim().isNotEmpty)
        'spouse_name': _spouseName.text.trim(),
      if (_spouseAge.text.trim().isNotEmpty)
        'spouse_age': int.tryParse(_spouseAge.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.profile;
    if (profile != null) _populate(profile);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AuthWaveHeader(height: headerH + topPad),
                ),
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.white.withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Data Diri',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        label: 'Data Pribadi'),
                    const SizedBox(height: 12),
                    M3TextField(
                      controller: _fullName,
                      label: 'Nama Lengkap',
                      hint: 'Masukkan nama lengkap',
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama lengkap wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _nik,
                      label: 'NIK',
                      hint: '16 digit NIK',
                      prefixIcon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: M3TextField(
                            controller: _birthPlace,
                            label: 'Tempat Lahir',
                            hint: 'Kota',
                            prefixIcon: Icons.location_city_outlined,
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3TextField(
                            controller: _birthDate,
                            label: 'Tanggal Lahir',
                            hint: 'Pilih tanggal',
                            prefixIcon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: _pickDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GenderSelector(
                      selected: _gender,
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _address,
                      label: 'Alamat',
                      hint: 'Alamat lengkap sesuai KTP',
                      prefixIcon: Icons.home_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _phone,
                      label: 'Nomor Telepon',
                      hint: 'Contoh: 0812xxxxxxxx',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(
                      icon: Icons.family_restroom_outlined,
                      label: 'Data Keluarga',
                    ),
                    const SizedBox(height: 12),
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
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3TextField(
                            controller: _birthOrder,
                            label: 'Anak ke-',
                            hint: '1',
                            prefixIcon: Icons.format_list_numbered,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SubSectionLabel(label: 'Ayah'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: M3TextField(
                            controller: _fatherName,
                            label: 'Nama Ayah',
                            hint: 'Nama lengkap',
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3TextField(
                            controller: _fatherAge,
                            label: 'Usia',
                            hint: '45',
                            prefixIcon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _fatherOccupation,
                      label: 'Pekerjaan Ayah',
                      hint: 'Contoh: Wiraswasta',
                      prefixIcon: Icons.work_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    _SubSectionLabel(label: 'Ibu'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: M3TextField(
                            controller: _motherName,
                            label: 'Nama Ibu',
                            hint: 'Nama lengkap',
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3TextField(
                            controller: _motherAge,
                            label: 'Usia',
                            hint: '45',
                            prefixIcon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _motherOccupation,
                      label: 'Pekerjaan Ibu',
                      hint: 'Contoh: Ibu Rumah Tangga',
                      prefixIcon: Icons.work_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _familyAddress,
                      label: 'Alamat Keluarga',
                      hint: 'Jika berbeda dengan alamat di atas',
                      prefixIcon: Icons.home_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _familyPhone,
                      label: 'No. Telepon Keluarga',
                      hint: 'Contoh: 0812xxxxxxxx',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Data Pasangan',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Isi jika sudah menikah',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: M3TextField(
                            controller: _spouseName,
                            label: 'Nama Pasangan',
                            hint: 'Nama lengkap',
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3TextField(
                            controller: _spouseAge,
                            label: 'Usia',
                            hint: '30',
                            prefixIcon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _spouseOccupation,
                      label: 'Pekerjaan Pasangan',
                      hint: 'Contoh: Karyawan Swasta',
                      prefixIcon: Icons.work_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: 28),
                    // ── Save button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: profileState.isLoading
                            ? null
                            : _handleSave,
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: profileState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                'Simpan Perubahan',
                                style:
                                    tt.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.secondaryLightGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryDarkGreen),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  const _SubSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const options = [('Laki-laki', Icons.male_rounded), ('Perempuan', Icons.female_rounded)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            'Jenis Kelamin',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Row(
          children: [
            for (final (label, icon) in options) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected == label
                          ? AppColors.secondaryLightGreen
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected == label
                            ? AppColors.primaryDarkGreen
                            : cs.outlineVariant,
                        width: selected == label ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: selected == label
                              ? AppColors.primaryDarkGreen
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected == label
                                ? AppColors.primaryDarkGreen
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (label != options.last.$1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}
