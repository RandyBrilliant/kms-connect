import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../data/providers/document_provider.dart';
import '../../domain/models/document_checklist_item.dart';
import '../../utils/bundled_document_templates.dart';

/// Matches backend `account.document_specs` / `seed_document_types` (PHASE_INITIAL).
const _kDocPhaseInitialSubtitle =
    'Saat pendaftaran: KTP, ijazah, kartu keluarga, BPJS, paspor, foto TKI; CV dan sertifikat (opsional).';

/// Matches PHASE_POST_INTERVIEW in the same seed/specs.
const _kDocPhasePostSubtitle =
    'Setelah lulus wawancara: surat izin keluarga, surat kesehatan, perjanjian penempatan, buku nikah (opsional), dll.';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(documentChecklistProvider);
    ref.invalidate(myDocumentsProvider);
    ref.invalidate(documentTypesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(documentChecklistProvider);
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
                            'Dokumen Saya',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          checklistAsync.when(
                            data: (items) {
                              final uploaded = items
                                  .where((i) => i.isUploaded)
                                  .length;
                              return Text(
                                '$uploaded/${items.length} dokumen diunggah',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _invalidateAll(ref),
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
                child: checklistAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (e, _) =>
                      _ErrorState(onRetry: () => _invalidateAll(ref)),
                  data: (items) {
                    final initial = items
                        .where((i) => i.type.isInitialPhase)
                        .toList();
                    final postInterview = items
                        .where((i) => i.type.isPostInterviewPhase)
                        .toList();
                    final otherPhase = items
                        .where(
                          (i) =>
                              !i.type.isInitialPhase &&
                              !i.type.isPostInterviewPhase,
                        )
                        .toList();

                    return RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: const Color(0xFF0A7A43),
                      onRefresh: () async => _invalidateAll(ref),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          24 + bottomInset + bottomPad,
                        ),
                        children: [
                          _ProgressCard(items: items),
                          const SizedBox(height: 20),
                          ..._buildPhaseSection(
                            context,
                            ref,
                            initial,
                            'Tahap awal — pendaftaran',
                            _kDocPhaseInitialSubtitle,
                          ),
                          ..._buildPhaseSection(
                            context,
                            ref,
                            postInterview,
                            'Setelah wawancara',
                            _kDocPhasePostSubtitle,
                          ),
                          ..._buildPhaseSection(
                            context,
                            ref,
                            otherPhase,
                            'Dokumen lainnya',
                            '',
                          ),
                        ],
                      ),
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

  /// Groups checklist by backend phase (INITIAL / POST_INTERVIEW), then wajib vs tambahan.
  List<Widget> _buildPhaseSection(
    BuildContext context,
    WidgetRef ref,
    List<DocumentChecklistItem> phaseItems,
    String phaseTitle,
    String phaseSubtitle,
  ) {
    if (phaseItems.isEmpty) {
      return const [];
    }
    final sorted = List<DocumentChecklistItem>.from(phaseItems)
      ..sort((a, b) => a.type.sortOrder.compareTo(b.type.sortOrder));
    final required = sorted.where((i) => i.isRequired).toList();
    final optional = sorted.where((i) => !i.isRequired).toList();

    return [
      _PhaseHeading(title: phaseTitle, subtitle: phaseSubtitle),
      const SizedBox(height: 12),
      if (required.isNotEmpty) ...[
        _SectionHeader(
          icon: Icons.star_rounded,
          label: 'Dokumen Wajib',
          color: AppColors.error,
          count:
              '${required.where((i) => i.isUploaded).length}/${required.length}',
        ),
        const SizedBox(height: 10),
        ...required.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChecklistCard(
              item: item,
              onUpload: () =>
                  context.push('/documents/upload?type=${item.type.id}'),
              onDelete: () => _handleDelete(context, ref, item),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (optional.isNotEmpty) ...[
        _OptionalSectionIntro(
          uploaded: optional.where((i) => i.isUploaded).length,
          total: optional.length,
        ),
        const SizedBox(height: 10),
        ...optional.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChecklistCard(
              item: item,
              onUpload: () =>
                  context.push('/documents/upload?type=${item.type.id}'),
              onDelete: () => _handleDelete(context, ref, item),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    DocumentChecklistItem item,
  ) async {
    if (item.document == null) return;
    // Approved documents cannot be deleted
    if (item.isApproved) {
      CustomToast.show(
        context,
        message: 'Dokumen yang sudah disetujui tidak dapat dihapus.',
        type: ToastType.warning,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Dokumen',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Hapus "${item.type.name}"?',
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

    try {
      await ref
          .read(documentRepositoryProvider)
          .deleteDocument(item.document!.id);
      if (!context.mounted) return;
      _invalidateAll(ref);
      CustomToast.showGlobal(
        message: 'Dokumen berhasil dihapus',
        type: ToastType.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal menghapus dokumen',
        type: ToastType.error,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Progress Card
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.items});
  final List<DocumentChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final requiredItems = items.where((i) => i.isRequired).toList();
    final optionalItems = items.where((i) => !i.isRequired).toList();
    final requiredUploaded = requiredItems.where((i) => i.isUploaded).length;
    final optionalUploaded = optionalItems.where((i) => i.isUploaded).length;
    final approved = items.where((i) => i.isApproved).length;
    final rejected = items.where((i) => i.isRejected).length;
    final pending = items.where((i) => i.isPending).length;
    final progress = requiredItems.isEmpty
        ? 1.0
        : requiredUploaded / requiredItems.length;
    final allRequiredDone =
        requiredItems.isNotEmpty && requiredUploaded == requiredItems.length;

    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: allRequiredDone
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    allRequiredDone
                        ? Icons.verified_rounded
                        : Icons.assignment_outlined,
                    color: allRequiredDone
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allRequiredDone
                            ? 'Dokumen Wajib Lengkap!'
                            : 'Lengkapi Dokumen Wajib',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$requiredUploaded dari ${requiredItems.length} dokumen wajib diunggah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (optionalItems.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Opsional: $optionalUploaded/${optionalItems.length} diunggah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: cs.surfaceContainerHighest,
                color: allRequiredDone
                    ? const Color(0xFF059669)
                    : AppColors.primaryDarkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.check_circle_rounded,
                  label: '$approved Disetujui',
                  color: const Color(0xFF059669),
                ),
                _StatChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$pending Menunggu',
                  color: const Color(0xFF92400E),
                ),
                if (rejected > 0)
                  _StatChip(
                    icon: Icons.cancel_rounded,
                    label: '$rejected Ditolak',
                    color: AppColors.error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Optional docs section (explicit header + hint — pelamar tetap perlu melihat & unggah)
// ---------------------------------------------------------------------------

class _OptionalSectionIntro extends StatelessWidget {
  const _OptionalSectionIntro({required this.uploaded, required this.total});
  final int uploaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 16,
              color: AppColors.info,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Dokumen opsional',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '$uploaded/$total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Unggah jika berlaku untuk Anda (mis. sertifikat, buku nikah). '
          'Disarankan dilengkapi untuk kelengkapan berkas.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.86),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Phase heading (matches seed phases: INITIAL vs POST_INTERVIEW)
// ---------------------------------------------------------------------------

class _PhaseHeading extends StatelessWidget {
  const _PhaseHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });
  final IconData icon;
  final String label;
  final Color color;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Text(
          count,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Checklist Card
// ---------------------------------------------------------------------------

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.item,
    required this.onUpload,
    required this.onDelete,
  });
  final DocumentChecklistItem item;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (Color iconBg, Color iconFg, IconData icon) = _iconData;
    final (Color statusBg, Color statusFg, String statusLabel) = _statusData;

    final doc = item.document;
    final hasNotes = doc != null && doc.reviewNotes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: item.isRejected
            ? Border.all(color: const Color(0xFFFFCDD2), width: 1.2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ProfessionalCard(
          child: InkWell(
            onTap: item.isUploaded ? null : onUpload,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconFg, size: 22),
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
                                    item.type.name,
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.isRequired)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Opsional',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.type.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.type.description,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (item.type.code == 'cv') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => openCvTemplatePdf(context),
                        icon: Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                          color: AppColors.primaryDarkGreen,
                        ),
                        label: Text(
                          'Lihat contoh template CV',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                  if (item.type.code == 'ijin-keluarga') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            openIjinKeluargaTemplatePdf(context),
                        icon: Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                          color: AppColors.primaryDarkGreen,
                        ),
                        label: Text(
                          'Unduh template izin keluarga (PDF)',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                  if (item.type.code ==
                      'surat-keterangan-status-perkawinan') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            openSuratStatusPerkawinanTemplateDoc(context),
                        icon: Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.primaryDarkGreen,
                        ),
                        label: Text(
                          'Unduh template status perkawinan (Word)',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: tt.labelSmall?.copyWith(
                            color: statusFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (doc != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'dd MMM yyyy',
                            'id',
                          ).format(doc.uploadedAt),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (item.isUploaded) ...[
                        if (item.isApproved)
                          _LockedBadge()
                        else ...[
                          _SmallButton(
                            icon: Icons.upload_rounded,
                            label: item.isRejected ? 'Unggah Ulang' : 'Ganti',
                            color: AppColors.primaryDarkGreen,
                            onTap: onUpload,
                          ),
                          const SizedBox(width: 6),
                          _SmallButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            onTap: onDelete,
                          ),
                        ],
                      ] else
                        _SmallButton(
                          icon: Icons.upload_rounded,
                          label: 'Unggah',
                          color: AppColors.primaryDarkGreen,
                          onTap: onUpload,
                        ),
                    ],
                  ),
                  if (hasNotes) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.isRejected
                            ? const Color(0xFFFFF1F2)
                            : item.isApproved
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.isRejected
                              ? const Color(0xFFFFCDD2)
                              : item.isApproved
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFDE68A),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item.isRejected
                                    ? Icons.info_outline_rounded
                                    : Icons.comment_outlined,
                                size: 13,
                                color: item.isRejected
                                    ? AppColors.error
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Keterangan',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: item.isRejected
                                      ? AppColors.error
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              if (doc.reviewedByName != null) ...[
                                Text(
                                  ' \u2022 ${doc.reviewedByName}',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doc.reviewNotes,
                            style: tt.bodySmall?.copyWith(
                              color: item.isRejected
                                  ? const Color(0xFFB91C1C)
                                  : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color bg, Color fg, IconData icon) get _iconData {
    if (!item.isUploaded) {
      return (
        const Color(0xFFF3F4F6),
        const Color(0xFF9CA3AF),
        Icons.cloud_upload_outlined,
      );
    }
    return switch (item.document!.reviewStatus) {
      'APPROVED' => (
        const Color(0xFFD1FAE5),
        const Color(0xFF065F46),
        Icons.check_circle_rounded,
      ),
      'REJECTED' => (
        const Color(0xFFFFE4E6),
        AppColors.error,
        Icons.cancel_rounded,
      ),
      _ => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        Icons.hourglass_top_rounded,
      ),
    };
  }

  (Color bg, Color fg, String label) get _statusData {
    if (!item.isUploaded) {
      return (
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
        'Belum Diunggah',
      );
    }
    return switch (item.document!.reviewStatus) {
      'APPROVED' => (
        const Color(0xFFD1FAE5),
        const Color(0xFF065F46),
        'Disetujui',
      ),
      'REJECTED' => (const Color(0xFFFFE4E6), AppColors.error, 'Ditolak'),
      _ => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Menunggu Review',
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Locked Badge (shown on approved documents instead of Ganti/Hapus buttons)
// ---------------------------------------------------------------------------

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF065F46)),
          const SizedBox(width: 4),
          Text(
            'Terkunci',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF065F46),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small Button helper
// ---------------------------------------------------------------------------

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error State
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ProfessionalCard(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.primaryDarkGreen.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 14),
                Text(
                  'Gagal Memuat Dokumen',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
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
