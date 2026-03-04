import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/document_provider.dart';
import '../../domain/models/document_checklist_item.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          _Header(
            headerH: headerH,
            topPad: topPad,
            checklistAsync: checklistAsync,
            tt: tt,
            onBack: () => Navigator.pop(context),
            onRefresh: () => _invalidateAll(ref),
          ),
          Expanded(
            child: checklistAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryDarkGreen,
                  strokeWidth: 2.5,
                ),
              ),
              error: (e, _) => _ErrorState(
                onRetry: () => _invalidateAll(ref),
              ),
              data: (items) {
                final required =
                    items.where((i) => i.isRequired).toList();
                final optional =
                    items.where((i) => !i.isRequired).toList();

                return RefreshIndicator(
                  color: AppColors.primaryDarkGreen,
                  onRefresh: () async => _invalidateAll(ref),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _ProgressCard(items: items),
                      const SizedBox(height: 20),
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
                              onUpload: () => context.push(
                                '/documents/upload?type=${item.type.id}',
                              ),
                              onDelete: () =>
                                  _handleDelete(context, ref, item),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (optional.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Dokumen Tambahan',
                          color: AppColors.info,
                          count:
                              '${optional.where((i) => i.isUploaded).length}/${optional.length}',
                        ),
                        const SizedBox(height: 10),
                        ...optional.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChecklistCard(
                              item: item,
                              onUpload: () => context.push(
                                '/documents/upload?type=${item.type.id}',
                              ),
                              onDelete: () =>
                                  _handleDelete(context, ref, item),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Dokumen',
            style:
                tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        content: Text(
          'Hapus "${item.type.name}"?',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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

    try {
      await ref
          .read(documentRepositoryProvider)
          .deleteDocument(item.document!.id);
      if (!context.mounted) return;
      _invalidateAll(ref);
      CustomToast.show(context,
          message: 'Dokumen berhasil dihapus',
          type: ToastType.success);
    } catch (_) {
      if (!context.mounted) return;
      CustomToast.show(context,
          message: 'Gagal menghapus dokumen',
          type: ToastType.error);
    }
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.headerH,
    required this.topPad,
    required this.checklistAsync,
    required this.tt,
    required this.onBack,
    required this.onRefresh,
  });

  final double headerH;
  final double topPad;
  final AsyncValue<List<DocumentChecklistItem>> checklistAsync;
  final TextTheme tt;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: headerH + topPad,
      child: Stack(
        children: [
          Positioned.fill(
              child: AuthWaveHeader(height: headerH + topPad)),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dokumen Saya',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      checklistAsync.when(
                        data: (items) {
                          final uploaded =
                              items.where((i) => i.isUploaded).length;
                          return Text(
                            '$uploaded/${items.length} dokumen diunggah',
                            style: tt.bodySmall?.copyWith(
                              color:
                                  Colors.white.withValues(alpha: 0.8),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, e) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final requiredItems = items.where((i) => i.isRequired).toList();
    final requiredUploaded =
        requiredItems.where((i) => i.isUploaded).length;
    final approved = items.where((i) => i.isApproved).length;
    final rejected = items.where((i) => i.isRejected).length;
    final pending = items.where((i) => i.isPending).length;
    final progress = requiredItems.isEmpty
        ? 1.0
        : requiredUploaded / requiredItems.length;
    final allRequiredDone = requiredItems.isNotEmpty &&
        requiredUploaded == requiredItems.length;

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
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$requiredUploaded dari ${requiredItems.length} dokumen wajib diunggah',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
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
            Row(
              children: [
                _StatChip(
                  icon: Icons.check_circle_rounded,
                  label: '$approved Disetujui',
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$pending Menunggu',
                  color: const Color(0xFF92400E),
                ),
                const SizedBox(width: 10),
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
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
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          count,
          style: tt.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final (Color statusBg, Color statusFg, String statusLabel) =
        _statusData;

    final doc = item.document;
    final hasNotes = doc != null && doc.reviewNotes.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: item.isRejected
            ? const BorderSide(
                color: Color(0xFFFFCDD2), width: 1.2)
            : BorderSide.none,
      ),
      color: cs.surface,
      child: InkWell(
        onTap: item.isUploaded ? null : onUpload,
        borderRadius: BorderRadius.circular(16),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.type.name,
                                style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isRequired)
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 6),
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (item.type.description
                            .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.type.description,
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                      DateFormat('dd MMM yyyy', 'id')
                          .format(doc.uploadedAt),
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  if (item.isUploaded) ...[
                    if (item.isApproved)
                      _LockedBadge()
                    else ...[
                      _SmallButton(
                        icon: Icons.upload_rounded,
                        label: item.isRejected
                            ? 'Unggah Ulang'
                            : 'Ganti',
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.isRejected
                                ? Icons
                                    .info_outline_rounded
                                : Icons.comment_outlined,
                            size: 13,
                            color: item.isRejected
                                ? AppColors.error
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Keterangan',
                            style:
                                tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: item.isRejected
                                  ? AppColors.error
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          if (doc.reviewedByName !=
                              null) ...[
                            Text(
                              ' \u2022 ${doc.reviewedByName}',
                              style: tt.labelSmall
                                  ?.copyWith(
                                      color: cs
                                          .onSurfaceVariant),
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
      'REJECTED' => (
          const Color(0xFFFFE4E6),
          AppColors.error,
          'Ditolak',
        ),
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
          const Icon(
            Icons.lock_rounded,
            size: 13,
            color: Color(0xFF065F46),
          ),
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
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
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
// Circle header button
// ---------------------------------------------------------------------------

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
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
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('Gagal Memuat Dokumen',
                style: tt.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
