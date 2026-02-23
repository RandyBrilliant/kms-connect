import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/work_experience.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class WorkExperiencesPage extends ConsumerStatefulWidget {
  const WorkExperiencesPage({super.key});

  @override
  ConsumerState<WorkExperiencesPage> createState() =>
      _WorkExperiencesPageState();
}

class _WorkExperiencesPageState extends ConsumerState<WorkExperiencesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }

  // ── Open add/edit bottom sheet ─────────────────────────────────────────────

  Future<void> _openForm({WorkExperience? experience}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkExperienceForm(existing: experience),
    );
  }

  // ── Confirm delete ─────────────────────────────────────────────────────────

  Future<void> _handleDelete(WorkExperience exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Pengalaman Kerja',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Hapus "${exp.companyName} — ${exp.position}"?',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(workExperienceNotifierProvider.notifier);
    final ok = await notifier.delete(exp.id);

    if (!mounted) return;
    if (ok) {
      CustomToast.show(context,
          message: 'Pengalaman kerja dihapus', type: ToastType.success);
    } else {
      final err = ref.read(workExperienceNotifierProvider).error ??
          'Gagal menghapus';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workExperienceNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            _animated(_buildTopBar(), 0.0, 0.35),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDarkGreen,
                        strokeWidth: 2.5,
                      ),
                    )
                  : state.items.isEmpty
                      ? _animated(_buildEmpty(), 0.2, 0.8)
                      : _buildList(state.items),
            ),
          ],
        ),
      ),
      floatingActionButton: _animated(
        FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primaryDarkGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Tambah',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        0.55,
        0.9,
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

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
              'Pengalaman Kerja',
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

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.secondaryLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.work_outline_rounded,
                  size: 44, color: AppColors.primaryDarkGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada pengalaman kerja',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan riwayat pekerjaan Anda\nuntuk melengkapi profil.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(
                'Tambah Pengalaman',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── List of experiences ────────────────────────────────────────────────────

  Widget _buildList(List<WorkExperience> items) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(workExperienceNotifierProvider.notifier).reload(),
      color: AppColors.primaryDarkGreen,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, i) {
          return _animated(
            _ExperienceCard(
              experience: items[i],
              onEdit: () => _openForm(experience: items[i]),
              onDelete: () => _handleDelete(items[i]),
            ),
            (0.15 + i * 0.08).clamp(0.0, 0.85),
            (0.45 + i * 0.08).clamp(0.2, 1.0),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExperienceCard
// ─────────────────────────────────────────────────────────────────────────────

class _ExperienceCard extends StatelessWidget {
  final WorkExperience experience;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExperienceCard({
    required this.experience,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM yyyy', 'id_ID');
    final start =
        experience.startDate != null ? fmt.format(experience.startDate!) : '-';
    final end = experience.stillEmployed
        ? 'Sekarang'
        : experience.endDate != null
            ? fmt.format(experience.endDate!)
            : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.primaryDarkGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              experience.companyName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (experience.stillEmployed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDarkGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Aktif',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDarkGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        experience.position,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 5),
                          Text(
                            '$start — $end',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                          if (experience.country != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              experience.country!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.primaryDarkGreen),
                          const SizedBox(width: 10),
                          Text('Edit',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 10),
                          Text('Hapus',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
          ),
          if (experience.description != null &&
              experience.description!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Text(
                experience.description!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkExperienceForm — bottom sheet for add / edit
// ─────────────────────────────────────────────────────────────────────────────

class _WorkExperienceForm extends ConsumerStatefulWidget {
  final WorkExperience? existing;

  const _WorkExperienceForm({this.existing});

  @override
  ConsumerState<_WorkExperienceForm> createState() =>
      _WorkExperienceFormState();
}

class _WorkExperienceFormState extends ConsumerState<_WorkExperienceForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _companyCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _descCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _stillEmployed = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _companyCtrl = TextEditingController(text: e?.companyName ?? '');
    _positionCtrl = TextEditingController(text: e?.position ?? '');
    _countryCtrl = TextEditingController(text: e?.country ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
    _stillEmployed = e?.stillEmployed ?? false;
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _positionCtrl.dispose();
    _countryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime(DateTime.now().year - 1))
        : (_endDate ?? DateTime.now());
    final first = isStart ? DateTime(1970) : (_startDate ?? DateTime(1970));
    final last = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      helpText: isStart ? 'Tanggal Mulai' : 'Tanggal Selesai',
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDarkGreen,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'company_name': _companyCtrl.text.trim(),
      'position': _positionCtrl.text.trim(),
      'country':
          _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'start_date': _startDate?.toIso8601String().substring(0, 10),
      'end_date': _stillEmployed
          ? null
          : _endDate?.toIso8601String().substring(0, 10),
      'still_employed': _stillEmployed,
    };

    final notifier = ref.read(workExperienceNotifierProvider.notifier);
    final bool ok;
    if (_isEdit) {
      ok = await notifier.update(widget.existing!.id, data);
    } else {
      ok = await notifier.create(data);
    }

    if (!mounted) return;

    if (ok) {
      CustomToast.show(
        context,
        message: _isEdit
            ? 'Pengalaman kerja diperbarui'
            : 'Pengalaman kerja ditambahkan',
        type: ToastType.success,
      );
      Navigator.pop(context);
    } else {
      final err = ref.read(workExperienceNotifierProvider).error ??
          'Terjadi kesalahan';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(workExperienceNotifierProvider).isLoading;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                _isEdit ? 'Edit Pengalaman Kerja' : 'Tambah Pengalaman Kerja',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),

              _FormField(
                controller: _companyCtrl,
                label: 'Nama Perusahaan',
                hint: 'Contoh: PT. Maju Mundur',
                icon: Icons.business_rounded,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nama perusahaan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),

              _FormField(
                controller: _positionCtrl,
                label: 'Jabatan / Posisi',
                hint: 'Contoh: Staff Marketing',
                icon: Icons.badge_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Jabatan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),

              _FormField(
                controller: _countryCtrl,
                label: 'Negara',
                hint: 'Contoh: Indonesia',
                icon: Icons.flag_outlined,
              ),
              const SizedBox(height: 14),

              // Dates row
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Tanggal Mulai',
                      value: _startDate != null ? fmt.format(_startDate!) : null,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _stillEmployed
                        ? _DatePickerField(
                            label: 'Tanggal Selesai',
                            value: 'Sekarang',
                            onTap: null,
                            disabled: true,
                          )
                        : _DatePickerField(
                            label: 'Tanggal Selesai',
                            value: _endDate != null
                                ? fmt.format(_endDate!)
                                : null,
                            onTap: () => _pickDate(isStart: false),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Still employed checkbox
              GestureDetector(
                onTap: () => setState(() => _stillEmployed = !_stillEmployed),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _stillEmployed
                            ? AppColors.primaryDarkGreen
                            : Colors.white,
                        border: Border.all(
                          color: _stillEmployed
                              ? AppColors.primaryDarkGreen
                              : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: _stillEmployed
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Masih bekerja di sini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _FormField(
                controller: _descCtrl,
                label: 'Deskripsi Pekerjaan',
                hint: 'Uraikan tugas dan tanggung jawab (opsional)',
                icon: Icons.description_outlined,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkGreen,
                    disabledBackgroundColor:
                        AppColors.primaryDarkGreen.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEdit ? 'Simpan Perubahan' : 'Tambah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// _FormField — reusable text field for the bottom sheet form
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textLight),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMedium),
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

// ─────────────────────────────────────────────────────────────────────────────
// _DatePickerField
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool disabled;

  const _DatePickerField({
    required this.label,
    this.value,
    this.onTap,
    this.disabled = false,
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: disabled
                  ? const Color(0xFFF8FAFC)
                  : AppColors.backgroundOffWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: disabled
                    ? const Color(0xFFE2E8F0)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: disabled
                      ? AppColors.textLight
                      : AppColors.textMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? 'Pilih tanggal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: value == null
                          ? AppColors.textLight
                          : const Color(0xFF0F172A),
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
