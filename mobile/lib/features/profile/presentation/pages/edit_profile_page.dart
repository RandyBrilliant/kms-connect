import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/applicant_profile.dart';

// 
// Page
// 

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _entranceCtrl;

  // Editable controllers
  final _addressCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _siblingCountCtrl = TextEditingController();
  final _birthOrderCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _fatherAgeCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherAgeCtrl = TextEditingController();
  final _motherOccupationCtrl = TextEditingController();
  final _spouseNameCtrl = TextEditingController();
  final _spouseAgeCtrl = TextEditingController();
  final _spouseOccupationCtrl = TextEditingController();
  final _familyAddressCtrl = TextEditingController();
  final _familyContactPhoneCtrl = TextEditingController();

  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _addressCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _siblingCountCtrl.dispose();
    _birthOrderCtrl.dispose();
    _fatherNameCtrl.dispose();
    _fatherAgeCtrl.dispose();
    _fatherOccupationCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherAgeCtrl.dispose();
    _motherOccupationCtrl.dispose();
    _spouseNameCtrl.dispose();
    _spouseAgeCtrl.dispose();
    _spouseOccupationCtrl.dispose();
    _familyAddressCtrl.dispose();
    _familyContactPhoneCtrl.dispose();
    super.dispose();
  }

  void _populate(ApplicantProfile p) {
    if (_populated) return;
    _populated = true;
    _addressCtrl.text = p.address ?? '';
    _contactPhoneCtrl.text = p.contactPhone ?? '';
    _siblingCountCtrl.text = p.siblingCount?.toString() ?? '';
    _birthOrderCtrl.text = p.birthOrder?.toString() ?? '';
    _fatherNameCtrl.text = p.fatherName ?? '';
    _fatherAgeCtrl.text = p.fatherAge?.toString() ?? '';
    _fatherOccupationCtrl.text = p.fatherOccupation ?? '';
    _motherNameCtrl.text = p.motherName ?? '';
    _motherAgeCtrl.text = p.motherAge?.toString() ?? '';
    _motherOccupationCtrl.text = p.motherOccupation ?? '';
    _spouseNameCtrl.text = p.spouseName ?? '';
    _spouseAgeCtrl.text = p.spouseAge?.toString() ?? '';
    _spouseOccupationCtrl.text = p.spouseOccupation ?? '';
    _familyAddressCtrl.text = p.familyAddress ?? '';
    _familyContactPhoneCtrl.text = p.familyContactPhone ?? '';
  }

  //  Save 

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      'contact_phone': _contactPhoneCtrl.text.trim().isEmpty
          ? null
          : _contactPhoneCtrl.text.trim(),
      'sibling_count': _siblingCountCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_siblingCountCtrl.text.trim()),
      'birth_order': _birthOrderCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_birthOrderCtrl.text.trim()),
      'father_name': _fatherNameCtrl.text.trim().isEmpty
          ? null
          : _fatherNameCtrl.text.trim(),
      'father_age': _fatherAgeCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_fatherAgeCtrl.text.trim()),
      'father_occupation': _fatherOccupationCtrl.text.trim().isEmpty
          ? null
          : _fatherOccupationCtrl.text.trim(),
      'mother_name': _motherNameCtrl.text.trim().isEmpty
          ? null
          : _motherNameCtrl.text.trim(),
      'mother_age': _motherAgeCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_motherAgeCtrl.text.trim()),
      'mother_occupation': _motherOccupationCtrl.text.trim().isEmpty
          ? null
          : _motherOccupationCtrl.text.trim(),
      'spouse_name': _spouseNameCtrl.text.trim().isEmpty
          ? null
          : _spouseNameCtrl.text.trim(),
      'spouse_age': _spouseAgeCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_spouseAgeCtrl.text.trim()),
      'spouse_occupation': _spouseOccupationCtrl.text.trim().isEmpty
          ? null
          : _spouseOccupationCtrl.text.trim(),
      'family_address': _familyAddressCtrl.text.trim().isEmpty
          ? null
          : _familyAddressCtrl.text.trim(),
      'family_contact_phone': _familyContactPhoneCtrl.text.trim().isEmpty
          ? null
          : _familyContactPhoneCtrl.text.trim(),
    };

    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.updateProfile(data);

    if (!mounted) return;

    if (success) {
      ref.invalidate(profileProvider);
      CustomToast.show(
        context,
        message: 'Profil berhasil diperbarui',
        type: ToastType.success,
      );
      context.pop();
    } else {
      final msg = ref.read(profileNotifierProvider).error ??
          'Gagal memperbarui profil';
      CustomToast.show(context, message: msg, type: ToastType.error);
    }
  }

  //  Animation helper 

  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  //  Build 

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final isLoading = ref.watch(profileNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            _animated(_buildTopBar(), 0.0, 0.35),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkGreen,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (e, _) => _buildError(e.toString()),
                data: (profile) {
                  _populate(profile);
                  return _buildScrollBody(profile);
                },
              ),
            ),
            if (profileAsync.hasValue)
              _animated(_buildSaveBar(isLoading), 0.65, 1.0),
          ],
        ),
      ),
    );
  }

  //  Top bar 

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppColors.backgroundOffWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 22, color: Color(0xFF0F172A)),
            ),
          ),
          Expanded(
            child: Text(
              'Data Diri',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  //  Scrollable body 

  Widget _buildScrollBody(ApplicantProfile profile) {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          _animated(_buildCompletionBanner(profile), 0.10, 0.45),
          const SizedBox(height: 12),
          _animated(_buildIdentitySection(profile), 0.18, 0.52),
          const SizedBox(height: 12),
          _animated(_buildContactSection(), 0.28, 0.62),
          const SizedBox(height: 12),
          _animated(_buildBirthOrderSection(), 0.35, 0.68),
          const SizedBox(height: 12),
          _animated(_buildParentsSection(), 0.42, 0.75),
          const SizedBox(height: 12),
          _animated(_buildSpouseSection(), 0.50, 0.82),
          const SizedBox(height: 12),
          _animated(_buildFamilyContactSection(), 0.56, 0.88),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  //  Completion banner 

  Widget _buildCompletionBanner(ApplicantProfile profile) {
    final int filled = _countFilled(profile);
    const int total = 12;
    final double pct = filled / total;
    final color = pct == 1.0
        ? AppColors.success
        : pct >= 0.6
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pct == 1.0
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pct == 1.0
                      ? 'Profil lengkap!'
                      : 'Kelengkapan profil ${(pct * 100).round()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pct == 1.0
                      ? 'Semua data sudah terisi. Siap untuk verifikasi.'
                      : 'Lengkapi data di bawah untuk meningkatkan peluang Anda.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countFilled(ApplicantProfile p) {
    int n = 0;
    if (p.fullName?.isNotEmpty == true) n++;
    if (p.nik?.isNotEmpty == true) n++;
    if (p.birthPlace?.isNotEmpty == true) n++;
    if (p.birthDate != null) n++;
    if (p.gender?.isNotEmpty == true) n++;
    if (_addressCtrl.text.isNotEmpty) n++;
    if (_contactPhoneCtrl.text.isNotEmpty) n++;
    if (_fatherNameCtrl.text.isNotEmpty) n++;
    if (_motherNameCtrl.text.isNotEmpty) n++;
    if (_familyAddressCtrl.text.isNotEmpty) n++;
    if (_familyContactPhoneCtrl.text.isNotEmpty) n++;
    if (_birthOrderCtrl.text.isNotEmpty) n++;
    return n;
  }

  //  Identitas section 

  Widget _buildIdentitySection(ApplicantProfile profile) {
    final genderLabel = profile.gender == 'M'
        ? 'Laki-laki'
        : profile.gender == 'F'
            ? 'Perempuan'
            : null;

    final birthDateLabel = profile.birthDate != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(profile.birthDate!)
        : null;

    return _SectionCard(
      title: 'Identitas KTP',
      subtitle: 'Data dari KTP tidak dapat diubah',
      icon: Icons.badge_outlined,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFDBEAFE),
      children: [
        _LockedField(
          label: 'Nama Lengkap',
          value: profile.fullName,
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _LockedField(
          label: 'NIK',
          value: profile.nik,
          icon: Icons.fingerprint_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LockedField(
                label: 'Tempat Lahir',
                value: profile.birthPlace,
                icon: Icons.location_city_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LockedField(
                label: 'Tanggal Lahir',
                value: birthDateLabel,
                icon: Icons.cake_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LockedField(
          label: 'Jenis Kelamin',
          value: genderLabel,
          icon: Icons.wc_rounded,
        ),
      ],
    );
  }

  //  Kontak & Alamat 

  Widget _buildContactSection() {
    return _SectionCard(
      title: 'Kontak & Alamat',
      subtitle: 'Informasi kontak dan alamat tinggal',
      icon: Icons.home_rounded,
      iconColor: AppColors.primaryDarkGreen,
      iconBg: AppColors.secondaryLightGreen,
      children: [
        _ProfileFormField(
          controller: _addressCtrl,
          label: 'Alamat Lengkap',
          hint: 'Masukkan alamat tempat tinggal',
          prefixIcon: Icons.home_outlined,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Alamat wajib diisi';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _ProfileFormField(
          controller: _contactPhoneCtrl,
          label: 'Nomor HP',
          hint: 'Contoh: 08123456789',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Nomor HP wajib diisi';
            if (v.trim().length < 9) return 'Nomor HP tidak valid';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  //  Urutan Kelahiran 

  Widget _buildBirthOrderSection() {
    return _SectionCard(
      title: 'Urutan Kelahiran',
      subtitle: 'Data posisi dalam keluarga',
      icon: Icons.family_restroom_rounded,
      iconColor: const Color(0xFF7C3AED),
      iconBg: const Color(0xFFF3E8FF),
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileFormField(
                controller: _birthOrderCtrl,
                label: 'Anak ke-',
                hint: 'Misal: 2',
                prefixIcon: Icons.looks_one_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return 'Tidak valid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileFormField(
                controller: _siblingCountCtrl,
                label: 'Jumlah Saudara',
                hint: 'Misal: 3',
                prefixIcon: Icons.group_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Tidak valid';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  //  Orang Tua 

  Widget _buildParentsSection() {
    return _SectionCard(
      title: 'Data Orang Tua',
      subtitle: 'Opsional  data ayah dan ibu',
      icon: Icons.people_outline_rounded,
      iconColor: const Color(0xFFD97706),
      iconBg: const Color(0xFFFEF3C7),
      children: [
        const _SubSectionLabel(label: 'Ayah'),
        const SizedBox(height: 10),
        _ProfileFormField(
          controller: _fatherNameCtrl,
          label: 'Nama Ayah',
          hint: 'Masukkan nama ayah',
          prefixIcon: Icons.person_outline_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileFormField(
                controller: _fatherAgeCtrl,
                label: 'Usia',
                hint: 'Thn',
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 120) return 'Tidak valid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _ProfileFormField(
                controller: _fatherOccupationCtrl,
                label: 'Pekerjaan',
                hint: 'Misal: Wirausaha',
                prefixIcon: Icons.work_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SubSectionLabel(label: 'Ibu'),
        const SizedBox(height: 10),
        _ProfileFormField(
          controller: _motherNameCtrl,
          label: 'Nama Ibu',
          hint: 'Masukkan nama ibu',
          prefixIcon: Icons.person_outline_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileFormField(
                controller: _motherAgeCtrl,
                label: 'Usia',
                hint: 'Thn',
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 120) return 'Tidak valid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _ProfileFormField(
                controller: _motherOccupationCtrl,
                label: 'Pekerjaan',
                hint: 'Misal: Ibu Rumah Tangga',
                prefixIcon: Icons.work_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  //  Pasangan 

  Widget _buildSpouseSection() {
    return _SectionCard(
      title: 'Data Pasangan',
      subtitle: 'Opsional  isi bila sudah menikah',
      icon: Icons.favorite_border_rounded,
      iconColor: const Color(0xFFE11D48),
      iconBg: const Color(0xFFFFE4E6),
      children: [
        _ProfileFormField(
          controller: _spouseNameCtrl,
          label: 'Nama Suami / Istri',
          hint: 'Masukkan nama pasangan',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileFormField(
                controller: _spouseAgeCtrl,
                label: 'Usia',
                hint: 'Thn',
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 120) return 'Tidak valid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _ProfileFormField(
                controller: _spouseOccupationCtrl,
                label: 'Pekerjaan',
                hint: 'Misal: Karyawan Swasta',
                prefixIcon: Icons.work_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  //  Kontak Keluarga 

  Widget _buildFamilyContactSection() {
    return _SectionCard(
      title: 'Kontak Keluarga',
      subtitle: 'Alamat dan nomor darurat keluarga',
      icon: Icons.contact_phone_outlined,
      iconColor: const Color(0xFF0284C7),
      iconBg: const Color(0xFFE0F2FE),
      children: [
        _ProfileFormField(
          controller: _familyAddressCtrl,
          label: 'Alamat Keluarga',
          hint: 'Alamat orang tua / keluarga',
          prefixIcon: Icons.home_outlined,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _ProfileFormField(
          controller: _familyContactPhoneCtrl,
          label: 'Nomor HP Keluarga',
          hint: 'Nomor darurat yang bisa dihubungi',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  //  Save bar 

  Widget _buildSaveBar(bool isLoading) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkGreen,
              disabledBackgroundColor:
                  AppColors.primaryDarkGreen.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'Simpan Perubahan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  //  Error state 

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data profil',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Periksa koneksi internet, lalu coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(profileProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// 
// _SectionCard
// 

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          )),
                      Text(subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.textMedium,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// 
// _ProfileFormField
// 

class _ProfileFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _ProfileFormField({
    required this.controller,
    required this.label,
    this.hint,
    required this.prefixIcon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType:
              maxLines > 1 ? TextInputType.multiline : keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textLight),
            prefixIcon:
                Icon(prefixIcon, size: 18, color: AppColors.textMedium),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.backgroundOffWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primaryDarkGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// 
// _LockedField
// 

class _LockedField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const _LockedField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.lock_outline_rounded,
                size: 11, color: AppColors.textLight),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEmpty ? 'Belum terisi' : value!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight:
                        isEmpty ? FontWeight.w400 : FontWeight.w500,
                    color: isEmpty
                        ? AppColors.textLight
                        : const Color(0xFF334155),
                    fontStyle:
                        isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 
// _SubSectionLabel
// 

class _SubSectionLabel extends StatelessWidget {
  final String label;

  const _SubSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primaryDarkGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}