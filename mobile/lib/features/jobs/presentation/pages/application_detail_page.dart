import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _ApplicationDetailPageState
    extends ConsumerState<ApplicationDetailPage>
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
    _slideContent = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
  }

  bool _isConfirming = false;

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAttendance(BuildContext ctx) async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.confirmAttendance(widget.applicationId);
      ref.invalidate(applicationDetailProvider(widget.applicationId));
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Kehadiran berhasil dikonfirmasi!'),
            backgroundColor: Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final applicationAsync =
        ref.watch(applicationDetailProvider(widget.applicationId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: applicationAsync.when(
        data: (application) => _buildContent(context, application),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(applicationDetailProvider(widget.applicationId)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, JobApplication application) {
    return CustomScrollView(
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoCard(
                    application: application,
                    onConfirm: application.canConfirm
                        ? () => _confirmAttendance(context)
                        : null,
                    isConfirming: _isConfirming,
                  ),
                    const SizedBox(height: 16),
                    // Announcements section (PRA_SELEKSI / INTERVIEW only)
                    if (!_kChatAllowedStatuses.contains(application.status)) ...[
                      _SectionHeader(title: 'Pengumuman Batch'),
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
    );
  }

  SliverAppBar _buildSliverHeader(
      BuildContext context, JobApplication application) {
    final tt = Theme.of(context).textTheme;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      backgroundColor: AppColors.primaryDarkGreen,
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
                  Color(0xFF1B4D27),
                  Color(0xFF2B6E36),
                  Color(0xFF3A7D44),
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
                      style: tt.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (application.companyName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        application.companyName!,
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.application,
    this.onConfirm,
    this.isConfirming = false,
  });

  final JobApplication application;
  final VoidCallback? onConfirm;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMMM yyyy', 'id_ID');
    final fmtDt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            // Jadwal Pra-Seleksi dari batch (jika sudah dijadwalkan)
            if (application.praSeleksiDate != null &&
                application.batchName != null) ...[
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
            ],
            // Jadwal Interview dari batch (hanya setelah masuk tahap INTERVIEW ke atas)
            if (application.interviewDate != null &&
                application.batchName != null &&
                (application.status == 'INTERVIEW' ||
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
            // Confirm attendance button (PRA_SELEKSI / INTERVIEW stage)
            if (onConfirm != null) ...[
              FilledButton.icon(
                onPressed: isConfirming ? null : onConfirm,
                icon: isConfirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.how_to_reg_outlined, size: 16),
                label: Text(isConfirming
                    ? 'Mengkonfirmasi...'
                    : 'Konfirmasi Kehadiran'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17A2B8),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Chat button — only available from DITERIMA onwards
            if (_kChatAllowedStatuses.contains(application.status))
              FilledButton.icon(
                onPressed: () => context.push(
                    '/jobs/applications/${application.id}/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Chat dengan Admin'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDarkGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
              Text(value,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
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
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDarkGreen,
          ),
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
    final tt = Theme.of(context).textTheme;
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
                      color: cs.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),

          // ── Right: card ──────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  left: 10, bottom: isLast ? 0 : 12),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.toStatusDisplay,
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: dotColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fmt.format(item.changedAt),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (item.changedByName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'oleh ${item.changedByName}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (item.note != null &&
                          item.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.note!,
                            style: tt.bodySmall,
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
    final color = application.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        application.statusDisplay,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
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
    final annoAsync = ref.watch(applicationAnnouncementsProvider(applicationId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return annoAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Gagal memuat pengumuman.',
          style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
        ),
      ),
      data: (announcements) {
        if (announcements.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  'Belum ada pengumuman dari admin.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return Column(
          children: announcements
              .map(
                (anno) => _AnnouncementCard(
                  announcement: anno,
                  fmt: fmt,
                ),
              )
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 16, color: AppColors.primaryDarkGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  fmt.format(announcement.createdAt),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.body,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
            if (announcement.createdByName != null) ...[
              const SizedBox(height: 6),
              Text(
                'oleh ${announcement.createdByName}',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

