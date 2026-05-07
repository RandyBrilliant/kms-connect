import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../data/providers/job_provider.dart';
import '../../domain/models/batch_announcement.dart';
import '../../domain/models/job_application.dart';
import '../../domain/models/application_status_history.dart';

/// Statuses that allow individual chat. All others use batch announcements.
const _kChatAllowedStatuses = {'DITERIMA', 'BERANGKAT', 'SELESAI'};

class ApplicationDetailPage extends ConsumerStatefulWidget {
  const ApplicationDetailPage({super.key, required this.applicationId});

  final int applicationId;

  @override
  ConsumerState<ApplicationDetailPage> createState() =>
      _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends ConsumerState<ApplicationDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideContent;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeHeader = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideContent =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );
  }

  bool _isConfirming = false;
  bool _isCompleting = false;
  // Tracks which document step is currently being confirmed (prevents double-tap).
  String? _confirmingStepCode;

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAttendance({required String stage}) async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.confirmAttendance(widget.applicationId, stage: stage);
      ref.invalidate(applicationDetailProvider(widget.applicationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kehadiran tahap ${_stageLabel(stage)} berhasil dikonfirmasi!',
            ),
            backgroundColor: Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengkonfirmasi: $e'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _confirmDocumentStep({required String stepCode}) async {
    if (_confirmingStepCode != null) return;
    setState(() => _confirmingStepCode = stepCode);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.confirmDocumentStep(widget.applicationId, stepCode: stepCode);
      ref.invalidate(applicationDetailProvider(widget.applicationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Langkah berhasil dikonfirmasi!'),
            backgroundColor: Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengkonfirmasi langkah: $e'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingStepCode = null);
    }
  }

  Future<void> _confirmCompletedPlacement() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.completeApplication(widget.applicationId);
      ref.invalidate(applicationDetailProvider(widget.applicationId));
      ref.invalidate(myApplicationsProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status berhasil diubah ke Selesai.'),
            backgroundColor: Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status ke Selesai: $e'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationAsync = ref.watch(
      applicationDetailProvider(widget.applicationId),
    );
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: applicationAsync.when(
        data: (application) => _buildContent(context, application),
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryDarkGreen,
            strokeWidth: 2.5,
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat detail lamaran',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.52),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(
                      applicationDetailProvider(widget.applicationId),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Coba Lagi',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, JobApplication application) {
    return RefreshIndicator(
      color: AppColors.primaryDarkGreen,
      onRefresh: () async {
        ref.invalidate(applicationDetailProvider(widget.applicationId));
        ref.invalidate(applicationAnnouncementsProvider(widget.applicationId));
        await ref.read(applicationDetailProvider(widget.applicationId).future);
      },
      child: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────
          _buildSliverHeader(context, application),

          // ── Body ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideContent,
              child: FadeTransition(
                opacity: _animCtrl,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoCard(
                        application: application,
                        onConfirmStage: (stage) =>
                            _confirmAttendance(stage: stage),
                        isConfirming: _isConfirming,
                        onConfirmCompletedPlacement: _confirmCompletedPlacement,
                        isCompletingPlacement: _isCompleting,
                        onConfirmDocumentStep: (stepCode) =>
                            _confirmDocumentStep(stepCode: stepCode),
                        confirmingStepCode: _confirmingStepCode,
                      ),
                      const SizedBox(height: 16),
                      // Batch + interview cohort broadcasts (merged on the server).
                      if (application.batch != null ||
                          application.interviewCohort != null) ...[
                        _SectionHeader(title: 'Pengumuman'),
                        const SizedBox(height: 8),
                        _AnnouncementsSection(
                          applicationId: widget.applicationId,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (application.statusHistory.isNotEmpty) ...[
                        _SectionHeader(title: 'Riwayat Status'),
                        const SizedBox(height: 8),
                        _StatusTimeline(history: application.statusHistory),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverHeader(
    BuildContext context,
    JobApplication application,
  ) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      backgroundColor: const Color(0xFF075B31),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: FadeTransition(
          opacity: _fadeHeader,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF075B31),
                  Color(0xFF0A7A43),
                  Color(0xFF0E8E50),
                  Color(0xFF149E5D),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      application.jobTitle ?? 'Detail Lamaran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (application.companyName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        application.companyName!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _StatusPillLarge(application: application),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stageLabel(String status) {
    switch (status) {
      case 'PRA_SELEKSI':
        return 'Pra-Seleksi';
      case 'INTERVIEW':
        return 'Interview';
      case 'CADANGAN':
        return 'Cadangan';
      case 'DITERIMA':
        return 'Diterima';
      case 'BERANGKAT':
        return 'Berangkat';
      case 'SELESAI':
        return 'Selesai';
      case 'DITOLAK':
        return 'Ditolak';
      default:
        return status;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.application,
    this.onConfirmStage,
    this.isConfirming = false,
    this.onConfirmCompletedPlacement,
    this.isCompletingPlacement = false,
    this.onConfirmDocumentStep,
    this.confirmingStepCode,
  });

  final JobApplication application;
  final ValueChanged<String>? onConfirmStage;
  final bool isConfirming;
  final VoidCallback? onConfirmCompletedPlacement;
  final bool isCompletingPlacement;
  /// Called when pelamar taps "Konfirmasi" for a document step. Arg is step code.
  final ValueChanged<String>? onConfirmDocumentStep;
  /// The step code currently being confirmed (shows loading indicator).
  final String? confirmingStepCode;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMMM yyyy', 'id_ID');
    final fmtDt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: 'Tanggal Melamar',
              value: fmt.format(application.appliedAt),
            ),
            if (application.batchName != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.group_outlined,
                label: 'Batch',
                value: application.batchName!,
              ),
            ],
            if (application.batchTahapLabel != null &&
                application.batchTahapLabel!.trim().isNotEmpty) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.layers_outlined,
                label: 'Tahapan',
                value: application.batchTahapLabel!,
              ),
            ],
            if (application.interviewCohortName != null &&
                application.interviewCohortName!.trim().isNotEmpty) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.calendar_month_outlined,
                label: 'Sesi Interview',
                value: application.interviewCohortName!,
              ),
            ],
            // Jadwal Pra-Seleksi dari batch (jika sudah dijadwalkan)
            if (application.praSeleksiDate != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.event_available_outlined,
                label: 'Jadwal Pra-Seleksi',
                value: fmtDt.format(application.praSeleksiDate!),
              ),
              if (application.praSeleksiLocation != null &&
                  application.praSeleksiLocation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Lokasi Pra-Seleksi',
                    value: application.praSeleksiLocation!,
                  ),
                ),
              if (application.praSeleksiNotes != null &&
                  application.praSeleksiNotes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _ScheduleNotesBlock(text: application.praSeleksiNotes!),
                ),
            ],
            // Jadwal interview — gunakan data cohort (fallback batch di server).
            if (application.interviewDate != null &&
                (application.status == 'INTERVIEW' ||
                    application.status == 'CADANGAN' ||
                    application.status == 'DITERIMA' ||
                    application.status == 'BERANGKAT' ||
                    application.status == 'SELESAI')) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.event_available_outlined,
                label: 'Jadwal Interview',
                value: fmtDt.format(application.interviewDate!),
              ),
              if (application.interviewLocation != null &&
                  application.interviewLocation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _InfoRow(
                    icon: Icons.location_city_outlined,
                    label: 'Lokasi Interview',
                    value: application.interviewLocation!,
                  ),
                ),
              if (application.interviewNotes != null &&
                  application.interviewNotes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _ScheduleNotesBlock(text: application.interviewNotes!),
                ),
            ],
            // Pra-Seleksi confirmation
            if (application.status == 'PRA_SELEKSI' ||
                application.praSeleksiConfirmedAt != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: application.praSeleksiConfirmedAt != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                label: 'Konfirmasi Pra-Seleksi',
                value: application.praSeleksiConfirmedAt != null
                    ? fmtDt.format(application.praSeleksiConfirmedAt!)
                    : 'Belum dikonfirmasi',
              ),
            ],
            // Interview confirmation
            if (application.status == 'INTERVIEW' ||
                application.interviewConfirmedAt != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: application.interviewConfirmedAt != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                label: 'Konfirmasi Interview',
                value: application.interviewConfirmedAt != null
                    ? fmtDt.format(application.interviewConfirmedAt!)
                    : 'Belum dikonfirmasi',
              ),
            ],
            if (application.assignedByName != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.manage_accounts_outlined,
                label: 'Ditugaskan oleh',
                value: application.assignedByName!,
              ),
            ],
            if (application.placementEndDate != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.work_history_outlined,
                label: 'Akhir Penempatan',
                value: fmt.format(application.placementEndDate!),
              ),
            ],
            if (application.cooldownEligibleDate != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.timelapse_rounded,
                label: 'Bisa Mendaftar Kembali',
                value: fmt.format(application.cooldownEligibleDate!),
              ),
            ],
            const SizedBox(height: 12),
            _AttendanceStageSection(
              application: application,
              isConfirming: isConfirming,
              onConfirmStage: onConfirmStage,
            ),
            if (application.status == 'DITERIMA' &&
                application.documentCollectionProgress != null) ...[
              const SizedBox(height: 14),
              _DocumentCollectionSection(
                progress: application.documentCollectionProgress!,
                onConfirmStep: onConfirmDocumentStep,
                confirmingStepCode: confirmingStepCode,
              ),
            ],
            if (application.status == 'BERANGKAT' &&
                onConfirmCompletedPlacement != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: isCompletingPlacement
                    ? null
                    : onConfirmCompletedPlacement,
                icon: isCompletingPlacement
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(
                  isCompletingPlacement ? 'Memproses...' : 'Konfirmasi Selesai',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_kChatAllowedStatuses.contains(application.status))
              FilledButton.icon(
                onPressed: () =>
                    context.push('/jobs/applications/${application.id}/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(
                  'Chat dengan Admin',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCollectionSection extends StatelessWidget {
  const _DocumentCollectionSection({
    required this.progress,
    this.onConfirmStep,
    this.confirmingStepCode,
  });

  final DocumentCollectionProgress progress;
  /// Called when pelamar taps "Konfirmasi" on a step. Arg is step code.
  final ValueChanged<String>? onConfirmStep;
  /// Step code currently being confirmed (shows a loading spinner).
  final String? confirmingStepCode;

  @override
  Widget build(BuildContext context) {
    final fmtDt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final confirmedCount = progress.items.where((i) => i.confirmed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pengumpulan Dokumen',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            // Confirmed badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: confirmedCount == progress.totalCount
                    ? const Color(0xFF28A745).withValues(alpha: 0.12)
                    : AppColors.divider.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$confirmedCount/${progress.totalCount} dikonfirmasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: confirmedCount == progress.totalCount
                      ? const Color(0xFF28A745)
                      : AppColors.textMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.doneCount}/${progress.totalCount} data siap',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: progress.isComplete
                ? const Color(0xFF28A745)
                : AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        ...progress.items.map((item) {
          final isConfirming = confirmingStepCode == item.code;
          // Can confirm only when data is ready and not yet confirmed.
          final canConfirm =
              item.done && !item.confirmed && onConfirmStep != null;

          IconData leadingIcon;
          Color leadingColor;
          if (item.confirmed) {
            leadingIcon = Icons.verified_rounded;
            leadingColor = const Color(0xFF28A745);
          } else if (item.done) {
            leadingIcon = Icons.check_circle_outline_rounded;
            leadingColor = const Color(0xFF17A2B8);
          } else {
            leadingIcon = Icons.radio_button_unchecked_rounded;
            leadingColor = AppColors.textMedium;
          }

          String subtitle;
          if (item.confirmed && item.confirmedAt != null) {
            subtitle = 'Dikonfirmasi • ${fmtDt.format(item.confirmedAt!)}';
          } else if (item.confirmed) {
            subtitle = 'Dikonfirmasi';
          } else if (item.done) {
            subtitle = 'Data siap — belum dikonfirmasi';
          } else {
            subtitle = 'Menunggu admin melengkapi data';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: item.confirmed
                  ? const Color(0xFFF0FBF4)
                  : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.confirmed
                    ? const Color(0xFF28A745).withValues(alpha: 0.3)
                    : AppColors.divider.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(leadingIcon, size: 17, color: leadingColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: item.confirmed
                              ? const Color(0xFF28A745)
                              : AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canConfirm || isConfirming) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isConfirming
                        ? null
                        : () => onConfirmStep!(item.code),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      backgroundColor: const Color(0xFF17A2B8),
                      disabledBackgroundColor:
                          const Color(0xFF17A2B8).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isConfirming
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Konfirmasi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _AttendanceStageSection extends StatelessWidget {
  const _AttendanceStageSection({
    required this.application,
    required this.isConfirming,
    required this.onConfirmStage,
  });

  final JobApplication application;
  final bool isConfirming;
  final ValueChanged<String>? onConfirmStage;

  bool _isDocumentStage(String stage) => stage == 'DITERIMA';
  bool _isCompletionStage(String stage) => stage == 'SELESAI';
  bool _requiresAttendanceConfirmation(String stage) =>
      stage == 'PRA_SELEKSI' || stage == 'INTERVIEW';

  String _label(String status) {
    switch (status) {
      case 'PRA_SELEKSI':
        return 'Pra-Seleksi';
      case 'INTERVIEW':
        return 'Interview';
      case 'CADANGAN':
        return 'Cadangan';
      case 'DITERIMA':
        return 'Diterima';
      case 'BERANGKAT':
        return 'Berangkat';
      case 'SELESAI':
        return 'Selesai';
      case 'DITOLAK':
        return 'Ditolak';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtDt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kehadiran per Tahapan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        ...JobApplication.stageOrder.map((stage) {
          final reached =
              application.reachedStages.contains(stage) ||
              application.status == stage;
          final isCompletionStage = _isCompletionStage(stage);
          final requiresAttendanceConfirmation =
              _requiresAttendanceConfirmation(stage);
          final attended = application.attendanceByStage[stage] == true;
          final stageDone =
              (!requiresAttendanceConfirmation && reached) ||
              attended ||
              (isCompletionStage && application.status == 'SELESAI');
          final attendedAt = application.attendanceMarkedAtByStage[stage];
          final progress = application.documentCollectionProgress;
          final isDocumentStage = _isDocumentStage(stage);
          final docsComplete = progress?.isComplete ?? false;
          final canTap =
              reached &&
              requiresAttendanceConfirmation &&
              !stageDone &&
              !isConfirming &&
              !isCompletionStage &&
              onConfirmStage != null &&
              (!isDocumentStage || docsComplete);

          // For DITERIMA: count per-step confirmations for the subtitle
          final confirmedStepCount = isDocumentStage && progress != null
              ? progress.items.where((i) => i.confirmed).length
              : 0;

          final subtitle = !reached
              ? 'Belum mencapai tahapan'
              : !requiresAttendanceConfirmation
              ? (stage == 'CADANGAN'
                    ? 'Anda masuk daftar cadangan — menunggu konfirmasi slot.'
                    : stage == 'DITERIMA'
                    ? (progress == null
                          ? 'Konfirmasi setiap langkah dokumen di bawah ini.'
                          : '$confirmedStepCount/${progress.totalCount} langkah dikonfirmasi')
                    : stage == 'BERANGKAT'
                    ? 'Tahapan berangkat tidak memerlukan konfirmasi kehadiran.'
                    : stage == 'DITOLAK'
                    ? 'Tahapan ditolak tidak memerlukan konfirmasi kehadiran.'
                    : 'Tahapan ini tidak memerlukan konfirmasi kehadiran.')
              : stageDone
              ? (isCompletionStage
                    ? 'Berhasil selesai. Anda sudah menyelesaikan tahapan ini.'
                    : (isDocumentStage
                          ? 'Dokumen lengkap • ${attendedAt != null ? fmtDt.format(attendedAt) : "-"}'
                          : 'Hadir • ${attendedAt != null ? fmtDt.format(attendedAt) : "-"}'))
              : isCompletionStage
              ? 'Status akan otomatis selesai setelah Anda konfirmasi selesai.'
              : (isDocumentStage
                    ? (progress == null
                          ? 'Checklist dokumen belum tersedia'
                          : (docsComplete
                                ? 'Checklist ${progress.doneCount}/${progress.totalCount} selesai — siap konfirmasi'
                                : 'Checklist ${progress.doneCount}/${progress.totalCount} belum lengkap'))
                    : 'Belum hadir');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  stageDone
                      ? Icons.check_circle_rounded
                      : (reached
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.lock_outline_rounded),
                  color: stageDone
                      ? const Color(0xFF28A745)
                      : AppColors.textMedium,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(stage),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canTap)
                  FilledButton(
                    onPressed: () => onConfirmStage!(stage),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      backgroundColor: const Color(0xFF17A2B8),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      isDocumentStage ? 'Dokumen Selesai' : 'Hadir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ScheduleNotesBlock extends StatelessWidget {
  const _ScheduleNotesBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDarkGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryDarkGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status timeline
// ─────────────────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.history});

  final List<ApplicationStatusHistory> history;

  @override
  Widget build(BuildContext context) {
    // Most-recent first
    final sorted = [...history]
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return Column(
      children: List.generate(sorted.length, (index) {
        final item = sorted[index];
        final isLast = index == sorted.length - 1;
        return _TimelineItem(item: item, isLast: isLast);
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final ApplicationStatusHistory item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    // Determine dot color from status
    final dotApp = JobApplication(
      id: 0,
      applicant: 0,
      job: 0,
      status: item.toStatus,
      appliedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final dotColor = dotApp.statusColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: dot + line ─────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.divider.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right: card ──────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 10, bottom: isLast ? 0 : 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.toStatusDisplay,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dotColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt.format(item.changedAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                        ),
                      ),
                      if (item.changedByName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'oleh ${item.changedByName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                      if (item.note != null && item.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            item.note!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
// Large status pill shown in hero header
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPillLarge extends StatelessWidget {
  const _StatusPillLarge({required this.application});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Text(
        application.statusDisplay,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcements section (PRA_SELEKSI / INTERVIEW)
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection({required this.applicationId});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annoAsync = ref.watch(
      applicationAnnouncementsProvider(applicationId),
    );
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return annoAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryDarkGreen,
          ),
        ),
      ),
      error: (_, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Gagal memuat pengumuman.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.error,
          ),
        ),
      ),
      data: (announcements) {
        if (announcements.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: AppColors.textMedium.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Belum ada pengumuman dari admin.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: announcements
              .map((anno) => _AnnouncementCard(announcement: anno, fmt: fmt))
              .toList(),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.fmt});

  final BatchAnnouncement announcement;
  final DateFormat fmt;

  static String? _sourceChipLabel(BatchAnnouncement a) {
    switch (a.kind) {
      case 'cohort':
        return 'Sesi Interview';
      case 'batch':
        return 'Pra-Seleksi';
      default:
        break;
    }
    if (a.cohort != null) return 'Sesi Interview';
    if (a.batch != null) return 'Pra-Seleksi';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chipLabel = _sourceChipLabel(announcement);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                        color: AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              announcement.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (chipLabel != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  chipLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  fmt.format(announcement.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.body,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
            if (announcement.createdByName != null) ...[
              const SizedBox(height: 6),
              Text(
                'oleh ${announcement.createdByName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
