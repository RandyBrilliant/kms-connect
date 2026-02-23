import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/document_provider.dart';
import '../../domain/models/applicant_document.dart';
import '../../domain/models/document_type.dart';

// 
// Page
// 

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage>
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

  //  Delete handler 

  Future<void> _handleDelete(
      BuildContext context, ApplicantDocument doc, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Dokumen',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Hapus dokumen "$name"? Tindakan ini tidak dapat dibatalkan.',
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

    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteDocument(doc.id);
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Dokumen berhasil dihapus', type: ToastType.success);
      ref.invalidate(myDocumentsProvider);
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Gagal menghapus dokumen', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(myDocumentsProvider);
    final typesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _animated(_buildTopBar(), 0.0, 0.35),

            // Body
            Expanded(
              child: documentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkGreen,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (e, _) => _buildError(e.toString()),
                data: (docs) => typesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDarkGreen,
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (e, _) => _buildError(e.toString()),
                  data: (types) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(myDocumentsProvider);
                      ref.invalidate(documentTypesProvider);
                    },
                    color: AppColors.primaryDarkGreen,
                    child: _buildBody(docs, types),
                  ),
                ),
              ),
            ),
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
              'Upload Dokumen',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/documents/upload'),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  size: 22, color: AppColors.primaryDarkGreen),
            ),
          ),
        ],
      ),
    );
  }

  //  Main body 

  Widget _buildBody(
      List<ApplicantDocument> docs, List<DocumentType> types) {
    // Group uploaded docs by document_type id
    final byType = <int, ApplicantDocument>{};
    for (final d in docs) {
      byType[d.documentType] = d;
    }

    final required = types.where((t) => t.isRequired).toList();
    final optional = types.where((t) => !t.isRequired).toList();

    // Count completeness
    final int uploaded = docs.length;
    final int totalRequired = required.length;
    final int uploadedRequired =
        required.where((t) => byType.containsKey(t.id)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        // Summary card
        _animated(
          _buildSummaryCard(
              uploaded: uploaded,
              uploadedRequired: uploadedRequired,
              totalRequired: totalRequired),
          0.10,
          0.45,
        ),
        const SizedBox(height: 16),

        // Required documents
        if (required.isNotEmpty) ...[
          _animated(
            _buildSectionHeader('Dokumen Wajib', Icons.assignment_rounded,
                const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            0.20,
            0.55,
          ),
          const SizedBox(height: 10),
          ...required.asMap().entries.map((e) {
            final i = e.key;
            final type = e.value;
            final doc = byType[type.id];
            return _animated(
              _DocumentTile(
                type: type,
                document: doc,
                onUpload: () =>
                    context.push('/documents/upload?type=${type.id}'),
                onDelete: doc != null
                    ? () => _handleDelete(context, doc, type.name)
                    : null,
              ),
              (0.25 + i * 0.07).clamp(0.0, 0.85),
              (0.55 + i * 0.07).clamp(0.3, 1.0),
            );
          }),
        ],

        // Optional documents
        if (optional.isNotEmpty) ...[
          const SizedBox(height: 16),
          _animated(
            _buildSectionHeader('Dokumen Tambahan', Icons.folder_outlined,
                const Color(0xFF6366F1), const Color(0xFFEEF2FF)),
            0.45,
            0.75,
          ),
          const SizedBox(height: 10),
          ...optional.asMap().entries.map((e) {
            final i = e.key;
            final type = e.value;
            final doc = byType[type.id];
            return _animated(
              _DocumentTile(
                type: type,
                document: doc,
                onUpload: () =>
                    context.push('/documents/upload?type=${type.id}'),
                onDelete: doc != null
                    ? () => _handleDelete(context, doc, type.name)
                    : null,
              ),
              (0.50 + i * 0.07).clamp(0.0, 0.90),
              (0.75 + i * 0.07).clamp(0.3, 1.0),
            );
          }),
        ],

        // Empty state
        if (types.isEmpty)
          _animated(_buildEmpty(), 0.2, 0.8),
      ],
    );
  }

  //  Summary card 

  Widget _buildSummaryCard({
    required int uploaded,
    required int uploadedRequired,
    required int totalRequired,
  }) {
    final pct = totalRequired == 0 ? 1.0 : uploadedRequired / totalRequired;
    final color = pct == 1.0
        ? AppColors.success
        : pct >= 0.5
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pct == 1.0
                  ? Icons.check_circle_rounded
                  : Icons.upload_file_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pct == 1.0
                      ? 'Semua dokumen wajib telah diunggah'
                      : '$uploadedRequired dari $totalRequired dokumen wajib',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total $uploaded dokumen diunggah',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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

  //  Section header 

  Widget _buildSectionHeader(
      String title, IconData icon, Color iconColor, Color iconBg) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  //  Empty state 

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
              child: const Icon(Icons.upload_file_rounded,
                  size: 44, color: AppColors.primaryDarkGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada tipe dokumen',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daftar tipe dokumen akan muncul setelah dikonfigurasi oleh admin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  //  Error state 

  Widget _buildError(String msg) {
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
              'Gagal memuat dokumen',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(myDocumentsProvider);
                ref.invalidate(documentTypesProvider);
              },
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
// _DocumentTile
// 

class _DocumentTile extends StatelessWidget {
  final DocumentType type;
  final ApplicantDocument? document;
  final VoidCallback onUpload;
  final VoidCallback? onDelete;

  const _DocumentTile({
    required this.type,
    required this.document,
    required this.onUpload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDoc = document != null;
    final String reviewStatus = document?.reviewStatus ?? '';
    final statusColor = _statusColor(reviewStatus);
    final statusLabel = _statusLabel(reviewStatus);
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: !hasDoc ? onUpload : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasDoc
                      ? statusColor.withValues(alpha: 0.12)
                      : type.isRequired
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasDoc
                      ? _statusIcon(reviewStatus)
                      : Icons.upload_file_outlined,
                  size: 22,
                  color: hasDoc
                      ? statusColor
                      : type.isRequired
                          ? AppColors.error
                          : AppColors.textLight,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            type.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (type.isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Wajib',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasDoc) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(document!.uploadedAt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        type.isRequired
                            ? 'Belum diunggah  ketuk untuk unggah'
                            : 'Opsional  ketuk untuk unggah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: type.isRequired
                              ? AppColors.error
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action button
              const SizedBox(width: 8),
              if (!hasDoc)
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textLight)
              else
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'replace',
                      child: Row(children: [
                        const Icon(Icons.refresh_rounded,
                            size: 18, color: AppColors.primaryDarkGreen),
                        const SizedBox(width: 10),
                        Text('Ganti',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('Hapus',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: AppColors.error)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'replace') onUpload();
                    if (v == 'delete') onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'Menunggu Review';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}