import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Hapus Pengalaman',
              style: tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          content: Text(
            'Hapus "${exp.companyName}" dari riwayat pekerjaan?',
            style: tt.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final ok =
          await ref.read(workExperienceNotifierProvider.notifier)
              .delete(exp.id);
      if (context.mounted) {
        if (ok) {
          CustomToast.show(context,
              message: 'Pengalaman berhasil dihapus',
              type: ToastType.success);
        } else {
          final err = ref.read(workExperienceNotifierProvider).error
              ?? 'Gagal menghapus';
          CustomToast.show(context,
              message: err, type: ToastType.error);
        }
      }
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                            color: Colors.white
                                .withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Pengalaman Kerja',
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${state.items.length} riwayat',
                              style: tt.bodySmall?.copyWith(
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryDarkGreen,
                        strokeWidth: 2.5),
                  )
                : state.items.isEmpty
                    ? _EmptyState(onAdd: () => openForm())
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            20, 20, 20, 100),
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
      final item = _kCountries
          .where((c) => c.code == exp.country)
          .firstOrNull;
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
    final end = exp.stillEmployed
        ? 'Sekarang'
        : _formatDate(exp.endDate);
    final duration =
        start.isEmpty ? '' : '$start - $end';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: cs.surface,
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
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.primaryDarkGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.position,
                        style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        exp.companyName,
                        style: tt.bodySmall?.copyWith(
                            color: AppColors.primaryDarkGreen,
                            fontWeight: FontWeight.w600),
                      ),
                      if ((exp.location ?? exp.country) != null &&
                          (exp.location ?? exp.country)!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12,
                                color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              _buildLocationLabel(exp),
                              style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant),
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
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined,
                              size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 16,
                              color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Hapus',
                              style: TextStyle(
                                  color: AppColors.error)),
                        ])),
                  ],
                ),
              ],
            ),
            if (duration.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
            if (exp.description != null &&
                exp.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exp.description!,
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondaryLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.work_history_outlined,
                  size: 40, color: AppColors.primaryDarkGreen),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Pengalaman Kerja',
              style: tt.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan riwayat pekerjaan kamu\nuntuk memperkuat profil.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Pengalaman'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
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
  DateTime? _startPicked;
  DateTime? _endPicked;
  bool _stillEmployed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _company.text = e.companyName;
      _position.text = e.position;
      _location.text = e.location ?? '';
      _description.text = e.description ?? '';
      _stillEmployed = e.stillEmployed;
      // Pre-select country from existing data
      if (e.country != null && e.country!.isNotEmpty) {
        final match = _kCountries.where((c) => c.code == e.country).firstOrNull;
        _selectedCountryCode = e.country;
        _selectedCountryName = match?.name ?? e.country;
      }
      if (e.startDate != null) {
        _startPicked = e.startDate;
        _startDate.text =
            DateFormat('MMM yyyy', 'id').format(e.startDate!);
      }
      if (e.endDate != null) {
        _endPicked = e.endDate;
        _endDate.text =
            DateFormat('MMM yyyy', 'id').format(e.endDate!);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _company, _position, _location, _description, _startDate, _endDate
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
      CustomToast.show(context,
          message: 'Tanggal selesai wajib diisi jika sudah tidak bekerja',
          type: ToastType.warning);
      return;
    }
    setState(() => _isLoading = true);
    final data = <String, dynamic>{
      'company_name': _company.text.trim(),
      'position': _position.text.trim(),
      if (_location.text.trim().isNotEmpty)
        'location': _location.text.trim(),
      if (_selectedCountryCode != null && _selectedCountryCode!.isNotEmpty)
        'country': _selectedCountryCode,
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'still_employed': _stillEmployed,
      if (_startPicked != null)
        'start_date':
            DateFormat('yyyy-MM-dd').format(_startPicked!),
      if (!_stillEmployed && _endPicked != null)
        'end_date': DateFormat('yyyy-MM-dd').format(_endPicked!),
    };

    final notifier =
        ref.read(workExperienceNotifierProvider.notifier);
    final ok = widget.existing == null
        ? await notifier.create(data)
        : await notifier.update(widget.existing!.id, data);

    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      CustomToast.show(context,
          message: widget.existing == null
              ? 'Pengalaman berhasil ditambahkan'
              : 'Pengalaman berhasil diperbarui',
          type: ToastType.success);
    } else {
      final err = ref.read(workExperienceNotifierProvider).error
          ?? 'Gagal menyimpan';
      CustomToast.show(context, message: err, type: ToastType.error);
    }
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
      backgroundColor: cs.surfaceContainerLow,
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
                width: 32, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Pilih Negara',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  controller: searchCtrl,
                  hintText: 'Cari negara...',
                  leading: const Icon(Icons.search_rounded, size: 20),
                  onChanged: (q) {
                    final lower = q.toLowerCase();
                    setModal(() {
                      filtered = _kCountries
                          .where((c) =>
                              c.name.toLowerCase().contains(lower) ||
                              c.code.toLowerCase().contains(lower))
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
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final isSelected =
                              _selectedCountryCode == c.code;
                          return ListTile(
                            leading: Text(c.flag,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(c.name,
                                style: tt.bodyMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? cs.primary
                                        : null)),
                            trailing: isSelected
                                ? Icon(Icons.check_rounded,
                                    color: cs.primary, size: 18)
                                : null,
                            onTap: () =>
                                Navigator.pop(sheetCtx, c),
                          );
                        },
                      ),
              ),
              SizedBox(
                  height: MediaQuery.paddingOf(sheetCtx).bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  widget.existing == null
                      ? 'Tambah Pengalaman'
                      : 'Edit Pengalaman',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                  ),
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
                  MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    M3TextField(
                      controller: _company,
                      label: 'Nama Perusahaan',
                      hint: 'PT. Contoh Indonesia',
                      prefixIcon: Icons.business_rounded,
                      textCapitalization:
                          TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _position,
                      label: 'Jabatan',
                      hint: 'Staff, Manager, dll.',
                      prefixIcon: Icons.work_outline_rounded,
                      textCapitalization:
                          TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _location,
                      label: 'Kota / Lokasi',
                      hint: 'Jakarta, Kuala Lumpur, dll.',
                      prefixIcon: Icons.location_city_outlined,
                      textCapitalization:
                          TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    _CountryPickerField(
                      selectedCode: _selectedCountryCode,
                      selectedName: _selectedCountryName,
                      onTap: () async {
                        final picked =
                            await _showCountryPicker(context);
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
                          child: M3TextField(
                            controller: _startDate,
                            label: 'Mulai',
                            hint: 'Jan 2022',
                            prefixIcon:
                                Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: () => _pickMonth(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!_stillEmployed)
                          Expanded(
                            child: M3TextField(
                              controller: _endDate,
                              label: 'Selesai',
                              hint: 'Des 2023',
                              prefixIcon:
                                  Icons.event_outlined,
                              readOnly: true,
                              onTap: () => _pickMonth(false),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _stillEmployed,
                          onChanged: (v) => setState(
                              () => _stillEmployed = v ?? false),
                          activeColor: AppColors.primaryDarkGreen,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        GestureDetector(
                          onTap: () => setState(() =>
                              _stillEmployed = !_stillEmployed),
                          child: Text(
                            'Masih bekerja di sini',
                            style: tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    M3TextField(
                      controller: _description,
                      label: 'Deskripsi (opsional)',
                      hint: 'Tanggung jawab dan pencapaian',
                      prefixIcon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _isLoading ? null : _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AppColors.primaryDarkGreen,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                              )
                            : Text(
                                'Simpan',
                                style: tt.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
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
// =============================================================================
// Country picker support
// =============================================================================

class _CountryItem {
  const _CountryItem(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

/// Tappable field that looks like a filled text field.
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
        ? (_kCountries
                .where((c) => c.code == selectedCode)
                .firstOrNull
                ?.flag ??
            '🌐')
        : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Negara',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: flag != null
                ? Text(flag, style: const TextStyle(fontSize: 20))
                : Icon(Icons.flag_outlined,
                    size: 20, color: cs.onSurfaceVariant),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: hasValue
              ? IconButton(
                  icon:
                      Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                  onPressed: onClear,
                )
              : Icon(Icons.arrow_drop_down_rounded,
                  color: cs.onSurfaceVariant),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        isEmpty: !hasValue,
        child: hasValue
            ? Text(
                selectedName ?? selectedCode!,
                style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text('Pilih negara',
                style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.38))),
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