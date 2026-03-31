import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/utils/safe_navigation.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/work_experience.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class WorkExperiencesPage extends ConsumerWidget {
  const WorkExperiencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workExperienceNotifierProvider);

    void openForm({WorkExperience? existing}) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _WorkExperienceFormSheet(existing: existing),
      );
    }

    Future<void> handleDelete(WorkExperience exp) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Hapus Pengalaman',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          content: Text(
            'Hapus "${exp.companyName}" dari riwayat pekerjaan?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Hapus',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final ok = await ref
          .read(workExperienceNotifierProvider.notifier)
          .delete(exp.id);
      if (context.mounted) {
        if (ok) {
          CustomToast.showGlobal(
            message: 'Pengalaman berhasil dihapus',
            type: ToastType.success,
          );
        } else {
          final err =
              ref.read(workExperienceNotifierProvider).error ??
              'Gagal menghapus';
          CustomToast.show(context, message: err, type: ToastType.error);
        }
      }
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Tambah',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
      ),
      body: ProfessionalGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Kembali',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengalaman Kerja',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.items.length} riwayat',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(workExperienceNotifierProvider.notifier)
                          .reload(),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Segarkan',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.isLoading && state.items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : state.error != null &&
                          state.items.isEmpty &&
                          !state.isLoading
                    ? _WorkExpErrorState(
                        message: state.error!,
                        onRetry: () => ref
                            .read(workExperienceNotifierProvider.notifier)
                            .reload(),
                      )
                    : state.items.isEmpty
                    ? _EmptyState(onAdd: () => openForm())
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          100 + bottomInset + bottomPad,
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: state.items.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final exp = state.items[i];
                          return _WorkExpCard(
                            exp: exp,
                            onEdit: () => openForm(existing: exp),
                            onDelete: () => handleDelete(exp),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state (load failed)
// ---------------------------------------------------------------------------

class _WorkExpErrorState extends StatelessWidget {
  const _WorkExpErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ProfessionalCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 44,
                  color: AppColors.primaryDarkGreen.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat data',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      'Coba Lagi',
                      style: GoogleFonts.plusJakartaSans(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkExpCard
// ─────────────────────────────────────────────────────────────────────────────

class _WorkExpCard extends StatelessWidget {
  const _WorkExpCard({
    required this.exp,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkExperience exp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMM yyyy', 'id').format(dt);
  }

  /// Build a readable "City, 🇮🇩 Indonesia" style label.
  String _buildLocationLabel(WorkExperience exp) {
    final parts = <String>[];
    if (exp.location != null && exp.location!.isNotEmpty) {
      parts.add(exp.location!);
    }
    if (exp.country != null && exp.country!.isNotEmpty) {
      final item = _kCountries.where((c) => c.code == exp.country).firstOrNull;
      if (item != null) {
        parts.add('${item.flag} ${item.name}');
      } else {
        parts.add(exp.country!);
      }
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final start = _formatDate(exp.startDate);
    final end = exp.stillEmployed ? 'Sekarang' : _formatDate(exp.endDate);
    final duration = start.isEmpty ? '' : '$start - $end';

    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: AppColors.primaryDarkGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.position,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        exp.companyName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDarkGreen,
                        ),
                      ),
                      if (exp.industryType != null &&
                          exp.industryType!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _kIndustryTypes
                                  .where((i) => i.value == exp.industryType)
                                  .map((i) => i.label)
                                  .firstOrNull ??
                              exp.industryType!,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if ((exp.location ?? exp.country) != null &&
                          (exp.location ?? exp.country)!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _buildLocationLabel(exp),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Hapus',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (duration.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (exp.description != null && exp.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exp.description!,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Belum ada riwayat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan pengalaman kerja untuk memperkuat profil Anda.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ProfessionalCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.work_history_outlined,
                        size: 40,
                        color: AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mulai dari sini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tekan tombol di bawah atau ikon + di pojok kanan.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          'Tambah Pengalaman',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDarkGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkExperienceFormSheet
// ─────────────────────────────────────────────────────────────────────────────

class _WorkExperienceFormSheet extends ConsumerStatefulWidget {
  const _WorkExperienceFormSheet({this.existing});
  final WorkExperience? existing;

  @override
  ConsumerState<_WorkExperienceFormSheet> createState() =>
      _WorkExperienceFormSheetState();
}

class _WorkExperienceFormSheetState
    extends ConsumerState<_WorkExperienceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _location = TextEditingController(); // free-text city
  final _description = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();

  String? _selectedCountryCode; // ISO 3166-1 alpha-2
  String? _selectedCountryName;
  String? _selectedIndustryType;
  DateTime? _startPicked;
  DateTime? _endPicked;
  bool _stillEmployed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _company.text = e.companyName.toUpperCase();
      _position.text = e.position.toUpperCase();
      _location.text = (e.location ?? '').toUpperCase();
      _description.text = (e.description ?? '').toUpperCase();
      _stillEmployed = e.stillEmployed;
      // Pre-select country from existing data
      if (e.country != null && e.country!.isNotEmpty) {
        final match = _kCountries.where((c) => c.code == e.country).firstOrNull;
        _selectedCountryCode = e.country;
        _selectedCountryName = match?.name ?? e.country;
      }
      if (e.industryType != null && e.industryType!.isNotEmpty) {
        _selectedIndustryType = e.industryType;
      }
      if (e.startDate != null) {
        _startPicked = e.startDate;
        _startDate.text = DateFormat('MMM yyyy', 'id').format(e.startDate!);
      }
      if (e.endDate != null) {
        _endPicked = e.endDate;
        _endDate.text = DateFormat('MMM yyyy', 'id').format(e.endDate!);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _company,
      _position,
      _location,
      _description,
      _startDate,
      _endDate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMonth(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startPicked ?? DateTime(now.year - 1))
        : (_endPicked ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: isStart ? 'Pilih bulan mulai' : 'Pilih bulan selesai',
    );
    if (picked != null && mounted) {
      final val = DateTime(picked.year, picked.month);
      final fmt = DateFormat('MMM yyyy', 'id').format(val);
      setState(() {
        if (isStart) {
          _startPicked = val;
          _startDate.text = fmt;
        } else {
          _endPicked = val;
          _endDate.text = fmt;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Validate end date when not still employed
    if (!_stillEmployed && _endPicked == null) {
      CustomToast.show(
        context,
        message: 'Tanggal selesai wajib diisi jika sudah tidak bekerja',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    final data = <String, dynamic>{
      'company_name': _company.text.trim(),
      'position': _position.text.trim(),
      if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
      if (_selectedCountryCode != null && _selectedCountryCode!.isNotEmpty)
        'country': _selectedCountryCode,
      if (_selectedIndustryType != null && _selectedIndustryType!.isNotEmpty)
        'industry_type': _selectedIndustryType,
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'still_employed': _stillEmployed,
      if (_startPicked != null)
        'start_date': DateFormat('yyyy-MM-dd').format(_startPicked!),
      if (!_stillEmployed && _endPicked != null)
        'end_date': DateFormat('yyyy-MM-dd').format(_endPicked!),
    };

    final notifier = ref.read(workExperienceNotifierProvider.notifier);
    final ok = widget.existing == null
        ? await notifier.create(data)
        : await notifier.update(widget.existing!.id, data);

    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      CustomToast.showGlobal(
        message: widget.existing == null
            ? 'Pengalaman berhasil ditambahkan'
            : 'Pengalaman berhasil diperbarui',
        type: ToastType.success,
      );
      runWhenNavigatorUnlocked(() {
        if (!mounted) return;
        Navigator.pop(context);
      });
    } else {
      final err =
          ref.read(workExperienceNotifierProvider).error ?? 'Gagal menyimpan';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
  }

  Future<_IndustryTypeItem?> _showIndustryTypePicker(BuildContext ctx) async {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;
    return showModalBottomSheet<_IndustryTypeItem>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              child: Text(
                'Pilih Jenis Industri',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            const Divider(height: 1),
            ...List.generate(_kIndustryTypes.length, (i) {
              final item = _kIndustryTypes[i];
              final isSelected = _selectedIndustryType == item.value;
              return ListTile(
                leading: Icon(
                  Icons.factory_outlined,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  item.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? cs.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: cs.primary, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheetCtx, item),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<_CountryItem?> _showCountryPicker(BuildContext ctx) async {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;
    final searchCtrl = TextEditingController();
    List<_CountryItem> filtered = List.of(_kCountries);

    return showModalBottomSheet<_CountryItem>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModal) => DraggableScrollableSheet(
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
                child: Text(
                  'Pilih Negara',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari negara...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.primary, width: 1.6),
                    ),
                  ),
                  onChanged: (q) {
                    final lower = q.toLowerCase();
                    setModal(() {
                      filtered = _kCountries
                          .where(
                            (c) =>
                                c.name.toLowerCase().contains(lower) ||
                                c.code.toLowerCase().contains(lower),
                          )
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
                        child: Text(
                          'Tidak ditemukan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final isSelected = _selectedCountryCode == c.code;
                          return ListTile(
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              c.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? cs.primary
                                    : const Color(0xFF111827),
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: cs.primary,
                                    size: 18,
                                  )
                                : null,
                            onTap: () => Navigator.pop(sheetCtx, c),
                          );
                        },
                      ),
              ),
              SizedBox(height: MediaQuery.paddingOf(sheetCtx).bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? 'Tambah Pengalaman'
                          : 'Edit Pengalaman',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      ProfessionalTextField(
                        controller: _company,
                        label: 'Nama Perusahaan',
                        hintText: 'PT. Contoh Indonesia',
                        prefixIcon: Icons.business_rounded,
                        upperCase: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _IndustryTypePickerField(
                        value: _selectedIndustryType,
                        onTap: () async {
                          final picked = await _showIndustryTypePicker(context);
                          if (picked != null && mounted) {
                            setState(
                              () => _selectedIndustryType = picked.value,
                            );
                          }
                        },
                        onClear: () =>
                            setState(() => _selectedIndustryType = null),
                      ),
                      const SizedBox(height: 10),
                      ProfessionalTextField(
                        controller: _position,
                        label: 'Jabatan',
                        hintText: 'Staff, Manager, dll.',
                        prefixIcon: Icons.work_outline_rounded,
                        upperCase: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      ProfessionalTextField(
                        controller: _location,
                        label: 'Kota / Lokasi',
                        hintText: 'Jakarta, Kuala Lumpur, dll.',
                        prefixIcon: Icons.location_city_outlined,
                        upperCase: true,
                      ),
                      const SizedBox(height: 10),
                      _CountryPickerField(
                        selectedCode: _selectedCountryCode,
                        selectedName: _selectedCountryName,
                        onTap: () async {
                          final picked = await _showCountryPicker(context);
                          if (picked != null) {
                            setState(() {
                              _selectedCountryCode = picked.code;
                              _selectedCountryName = picked.name;
                            });
                          }
                        },
                        onClear: () => setState(() {
                          _selectedCountryCode = null;
                          _selectedCountryName = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ProfessionalTextField(
                              controller: _startDate,
                              label: 'Mulai',
                              hintText: 'Jan 2022',
                              prefixIcon: Icons.calendar_today_outlined,
                              readOnly: true,
                              onTap: () => _pickMonth(true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!_stillEmployed)
                            Expanded(
                              child: ProfessionalTextField(
                                controller: _endDate,
                                label: 'Selesai',
                                hintText: 'Des 2023',
                                prefixIcon: Icons.event_outlined,
                                readOnly: true,
                                onTap: () => _pickMonth(false),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _stillEmployed,
                              onChanged: (v) =>
                                  setState(() => _stillEmployed = v ?? false),
                              activeColor: AppColors.primaryDarkGreen,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _stillEmployed = !_stillEmployed,
                                ),
                                child: Text(
                                  'Masih bekerja di sini',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ProfessionalTextField(
                        controller: _description,
                        label: 'Deskripsi (opsional)',
                        hintText: 'Tugas dan Tanggung Jawab',
                        prefixIcon: Icons.description_outlined,
                        maxLines: 3,
                        upperCase: true,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDarkGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Simpan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
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
      ),
    );
  }
}
// =============================================================================
// Country picker support
// =============================================================================

class _CountryItem {
  const _CountryItem(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

/// Tappable field matching [ProfessionalDropdownField] / [ProfessionalTextField] styling.
class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.onTap,
    required this.onClear,
    this.selectedCode,
    this.selectedName,
  });

  final String? selectedCode;
  final String? selectedName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasValue = selectedCode != null && selectedCode!.isNotEmpty;
    final flag = hasValue
        ? (_kCountries.where((c) => c.code == selectedCode).firstOrNull?.flag ??
              '🌐')
        : null;
    return InkWell(
      onTap: () => runWhenNavigatorUnlocked(onTap),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Negara',
          hintText: 'Pilih negara',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.45),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: flag != null
                ? Text(flag, style: const TextStyle(fontSize: 20))
                : Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: cs.primary,
                  ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: hasValue
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: onClear,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                  ],
                )
              : Icon(
                  Icons.arrow_drop_down_rounded,
                  color: cs.onSurfaceVariant,
                ),
          suffixIconConstraints: BoxConstraints(
            minHeight: 48,
            minWidth: hasValue ? 88 : 48,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.error, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        isEmpty: !hasValue,
        child: hasValue
            ? Text(
                selectedName ?? selectedCode!,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// =============================================================================
// Industry type picker support
// =============================================================================

class _IndustryTypeItem {
  const _IndustryTypeItem(this.value, this.label);
  final String value;
  final String label;
}

const List<_IndustryTypeItem> _kIndustryTypes = [
  _IndustryTypeItem('SEMICONDUCTOR', 'Semiconductor'),
  _IndustryTypeItem('ELEKTRONIK', 'Elektronik'),
  _IndustryTypeItem('PABRIK LAIN', 'Pabrik Lain'),
  _IndustryTypeItem('JASA', 'Jasa'),
  _IndustryTypeItem('LAIN LAIN', 'Lain Lain'),
  _IndustryTypeItem('BELUM PERNAH BEKERJA', 'Belum Pernah Bekerja'),
];

class _IndustryTypePickerField extends StatelessWidget {
  const _IndustryTypePickerField({
    required this.onTap,
    required this.onClear,
    this.value,
  });

  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasValue = value != null && value!.isNotEmpty;
    final label = hasValue
        ? (_kIndustryTypes.where((i) => i.value == value).firstOrNull?.label ??
              value!)
        : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Jenis Industri',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(
            Icons.factory_outlined,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          suffixIcon: hasValue
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                )
              : Icon(Icons.arrow_drop_down_rounded, color: cs.onSurfaceVariant),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        isEmpty: !hasValue,
        child: hasValue
            ? Text(
                label!,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                'Pilih jenis industri',
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
      ),
    );
  }
}

// Country list — ISO 3166-1 alpha-2 codes + flag emoji
const List<_CountryItem> _kCountries = [
  _CountryItem('ID', 'Indonesia', '🇮🇩'),
  _CountryItem('MY', 'Malaysia', '🇲🇾'),
  _CountryItem('SG', 'Singapura', '🇸🇬'),
  _CountryItem('SA', 'Arab Saudi', '🇸🇦'),
  _CountryItem('AE', 'Uni Emirat Arab', '🇦🇪'),
  _CountryItem('QA', 'Qatar', '🇶🇦'),
  _CountryItem('KW', 'Kuwait', '🇰🇼'),
  _CountryItem('BH', 'Bahrain', '🇧🇭'),
  _CountryItem('OM', 'Oman', '🇴🇲'),
  _CountryItem('JP', 'Jepang', '🇯🇵'),
  _CountryItem('KR', 'Korea Selatan', '🇰🇷'),
  _CountryItem('TW', 'Taiwan', '🇹🇼'),
  _CountryItem('HK', 'Hong Kong', '🇭🇰'),
  _CountryItem('CN', 'China', '🇨🇳'),
  _CountryItem('US', 'Amerika Serikat', '🇺🇸'),
  _CountryItem('AU', 'Australia', '🇦🇺'),
  _CountryItem('NZ', 'Selandia Baru', '🇳🇿'),
  _CountryItem('GB', 'Inggris', '🇬🇧'),
  _CountryItem('DE', 'Jerman', '🇩🇪'),
  _CountryItem('NL', 'Belanda', '🇳🇱'),
  _CountryItem('FR', 'Prancis', '🇫🇷'),
  _CountryItem('IT', 'Italia', '🇮🇹'),
  _CountryItem('ES', 'Spanyol', '🇪🇸'),
  _CountryItem('CA', 'Kanada', '🇨🇦'),
  _CountryItem('BR', 'Brasil', '🇧🇷'),
  _CountryItem('ZA', 'Afrika Selatan', '🇿🇦'),
  _CountryItem('PH', 'Filipina', '🇵🇭'),
  _CountryItem('TH', 'Thailand', '🇹🇭'),
  _CountryItem('VN', 'Vietnam', '🇻🇳'),
  _CountryItem('IN', 'India', '🇮🇳'),
  _CountryItem('PK', 'Pakistan', '🇵🇰'),
  _CountryItem('BD', 'Bangladesh', '🇧🇩'),
  _CountryItem('NP', 'Nepal', '🇳🇵'),
  _CountryItem('LB', 'Lebanon', '🇱🇧'),
  _CountryItem('JO', 'Yordania', '🇯🇴'),
  _CountryItem('KZ', 'Kazakhstan', '🇰🇿'),
  _CountryItem('TR', 'Turki', '🇹🇷'),
];
