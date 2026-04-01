import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../data/providers/profile_provider.dart';

class AccountDeletionRequestPage extends ConsumerStatefulWidget {
  const AccountDeletionRequestPage({super.key});

  @override
  ConsumerState<AccountDeletionRequestPage> createState() =>
      _AccountDeletionRequestPageState();
}

class _AccountDeletionRequestPageState
    extends ConsumerState<AccountDeletionRequestPage> {
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountDeletionRequestProvider.notifier).loadRequest();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Konfirmasi Penghapusan Akun',
      message: 'Apakah Anda yakin ingin mengajukan permintaan penghapusan akun? '
          'Permintaan ini akan direview oleh admin.',
      confirmText: 'Ya, Ajukan',
      isDangerous: true,
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(accountDeletionRequestProvider.notifier)
        .submitRequest(reason: _reasonController.text.trim());

    if (!mounted) return;

    if (success) {
      CustomToast.showGlobal(
        message: 'Permintaan penghapusan akun berhasil diajukan.',
        type: ToastType.success,
      );
      _reasonController.clear();
    } else {
      final error = ref.read(accountDeletionRequestProvider).error;
      CustomToast.show(
        context,
        message: error ?? 'Gagal mengajukan permintaan.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Batalkan Permintaan?',
      message:
          'Apakah Anda yakin ingin membatalkan permintaan penghapusan akun?',
      confirmText: 'Ya, Batalkan',
      isDangerous: false,
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(accountDeletionRequestProvider.notifier)
        .cancelRequest();

    if (!mounted) return;

    if (success) {
      CustomToast.showGlobal(
        message: 'Permintaan berhasil dibatalkan.',
        type: ToastType.success,
      );
    } else {
      final error = ref.read(accountDeletionRequestProvider).error;
      CustomToast.show(
        context,
        message: error ?? 'Gagal membatalkan permintaan.',
        type: ToastType.error,
      );
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDangerous,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1B4332),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: const Color(0xFF52796F),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF52796F),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDangerous
                  ? AppColors.error
                  : const Color(0xFF0A7A43),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmText,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountDeletionRequestProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Kembali',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hapus Akun',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola permintaan penghapusan akun',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.isLoading && state.request == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          24 + bottomInset + bottomPad,
                        ),
                        child: state.hasRequest
                            ? ProfessionalCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: _buildExistingRequestView(state, tt, cs),
                                ),
                              )
                            : ProfessionalCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: _buildNewRequestForm(state, tt, cs),
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

  Widget _buildExistingRequestView(
    AccountDeletionRequestState state,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final request = state.request!;
    final statusColor = _getStatusColor(request.status);
    final statusBg = _getStatusBgColor(request.status);
    final statusIcon = _getStatusIcon(request.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Permintaan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF52796F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.statusDisplay,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 14),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal Pengajuan',
                value: DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                    .format(request.requestedAt),
                tt: tt,
                cs: cs,
              ),
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Alasan',
                  value: request.reason!,
                  tt: tt,
                  cs: cs,
                ),
              ],
              if (request.reviewedAt != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.check_circle_outline,
                  label: 'Tanggal Review',
                  value: DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                      .format(request.reviewedAt!),
                  tt: tt,
                  cs: cs,
                ),
              ],
              if (request.adminNotes != null &&
                  request.adminNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Catatan Admin',
                  value: request.adminNotes!,
                  tt: tt,
                  cs: cs,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStatusInfoCard(request.status, tt, cs),
        if (request.canBeCancelled) ...[
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: state.isLoading ? null : _handleCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0A7A43), width: 1.5),
                foregroundColor: const Color(0xFF0A7A43),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      'Batalkan Permintaan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNewRequestForm(
    AccountDeletionRequestState state,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_rounded,
                size: 22,
                color: AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peringatan Penting',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Penghapusan akun bersifat permanen dan tidak dapat dibatalkan '
                      'setelah disetujui oleh admin. Semua data Anda akan dihapus.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: const Color(0xFF9F1239),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data yang akan dihapus:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B4332),
                ),
              ),
              const SizedBox(height: 12),
              _buildDeletedDataItem(
                Icons.person_outline,
                'Data profil dan informasi pribadi',
                cs,
              ),
              _buildDeletedDataItem(
                Icons.work_outline,
                'Riwayat pengalaman kerja',
                cs,
              ),
              _buildDeletedDataItem(
                Icons.folder_outlined,
                'Dokumen yang diunggah',
                cs,
              ),
              _buildDeletedDataItem(
                Icons.description_outlined,
                'Riwayat lamaran pekerjaan',
                cs,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Alasan (Opsional)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B4332),
          ),
        ),
        const SizedBox(height: 8),
        ProfessionalTextField(
          controller: _reasonController,
          label: 'Alasan penghapusan',
          hintText: 'Mengapa Anda ingin menghapus akun?',
          prefixIcon: Icons.notes_outlined,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          upperCase: false,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: state.isLoading ? null : _handleSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Ajukan Penghapusan Akun',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme tt,
    required ColorScheme cs,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF52796F)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF52796F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B4332),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedDataItem(IconData icon, String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF52796F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1B4332),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoCard(String status, TextTheme tt, ColorScheme cs) {
    final (String title, String message, Color bgColor, Color textColor) =
        switch (status) {
      'PENDING' => (
          'Menunggu Review',
          'Permintaan Anda sedang direview oleh admin. Anda akan menerima '
              'notifikasi setelah permintaan diproses.',
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      'APPROVED' => (
          'Permintaan Disetujui',
          'Permintaan penghapusan akun Anda telah disetujui. Akun Anda akan '
              'dihapus dalam waktu dekat.',
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
        ),
      'REJECTED' => (
          'Permintaan Ditolak',
          'Permintaan penghapusan akun Anda ditolak. Silakan periksa catatan '
              'admin untuk informasi lebih lanjut.',
          const Color(0xFFFFE4E6),
          const Color(0xFF9F1239),
        ),
      _ => (
          'Informasi',
          'Status permintaan tidak diketahui.',
          const Color(0xFFF8FAF9),
          const Color(0xFF1B4332),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'PENDING' => const Color(0xFFD97706),
      'APPROVED' => const Color(0xFF059669),
      'REJECTED' => AppColors.error,
      'CANCELLED' => const Color(0xFF6B7280),
      _ => const Color(0xFF6B7280),
    };
  }

  Color _getStatusBgColor(String status) {
    return switch (status) {
      'PENDING' => const Color(0xFFFEF3C7),
      'APPROVED' => const Color(0xFFD1FAE5),
      'REJECTED' => const Color(0xFFFFE4E6),
      'CANCELLED' => const Color(0xFFF3F4F6),
      _ => const Color(0xFFF3F4F6),
    };
  }

  IconData _getStatusIcon(String status) {
    return switch (status) {
      'PENDING' => Icons.hourglass_top_rounded,
      'APPROVED' => Icons.check_circle_rounded,
      'REJECTED' => Icons.cancel_rounded,
      'CANCELLED' => Icons.block_rounded,
      _ => Icons.info_rounded,
    };
  }
}
