import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../documents/domain/models/applicant_document.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(myDocumentsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    Future<void> handleDelete(
        ApplicantDocument doc, String name) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Hapus Dokumen',
              style: tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          content: Text(
            'Hapus "$name"?',
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
      try {
        await ref
            .read(documentRepositoryProvider)
            .deleteDocument(doc.id);
        if (context.mounted) {
          ref.invalidate(myDocumentsProvider);
          CustomToast.show(context,
              message: 'Dokumen berhasil dihapus',
              type: ToastType.success);
        }
      } catch (_) {
        if (context.mounted) {
          CustomToast.show(context,
              message: 'Gagal menghapus dokumen',
              type: ToastType.error);
        }
      }
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(
            context, '/documents/upload'),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Unggah'),
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                    child:
                        AuthWaveHeader(height: headerH + topPad)),
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Dokumen Saya',
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            docsAsync.when(
                              data: (d) => Text(
                                '${d.length} dokumen',
                                style: tt.bodySmall?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (e, s) =>
                                  const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.invalidate(myDocumentsProvider);
                          ref.invalidate(documentTypesProvider);
                        },
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
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryDarkGreen,
                      strokeWidth: 2.5)),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(myDocumentsProvider),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return _EmptyState(
                    onUpload: () => Navigator.pushNamed(
                        context, '/documents/upload'),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primaryDarkGreen,
                  onRefresh: () async {
                    ref.invalidate(myDocumentsProvider);
                    ref.invalidate(documentTypesProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 20, 100),
                    itemCount: docs.length,
                    separatorBuilder: (ctx, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      return _DocumentCard(
                        doc: doc,
                        onDelete: () => handleDelete(
                            doc,
                            doc.documentTypeName ??
                                'Dokumen'),
                      );
                    },
                  ),
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
// _DocumentCard
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.onDelete});
  final ApplicantDocument doc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (Color statusBg, Color statusFg, IconData statusIcon,
        String statusLabel) = switch (doc.reviewStatus) {
      'APPROVED' => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          Icons.check_circle_rounded,
          'Disetujui',
        ),
      'REJECTED' => (
          const Color(0xFFFFE4E6),
          AppColors.error,
          Icons.cancel_rounded,
          'Ditolak',
        ),
      _ => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.hourglass_top_rounded,
          'Menunggu',
        ),
    };

    final uploadedAt =
        DateFormat('dd MMM yyyy', 'id').format(doc.uploadedAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_outlined,
                  color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.documentTypeName ?? 'Dokumen',
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (uploadedAt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Diunggah $uploadedAt',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon,
                            size: 11, color: statusFg),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: tt.labelSmall?.copyWith(
                            color: statusFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.error),
              style: IconButton.styleFrom(
                backgroundColor:
                    AppColors.error.withValues(alpha: 0.08),
                minimumSize: const Size(36, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState / _ErrorState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;

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
              decoration: const BoxDecoration(
                color: AppColors.secondaryLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_file_outlined,
                  size: 40, color: AppColors.primaryDarkGreen),
            ),
            const SizedBox(height: 16),
            Text('Belum Ada Dokumen',
                style: tt.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Unggah dokumen persyaratan kamu\nuntuk melengkapi profil.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Unggah Dokumen'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
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
