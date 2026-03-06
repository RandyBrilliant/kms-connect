import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../data/providers/job_provider.dart';
import '../../domain/models/job.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _DetailError(
          message: '$err',
          onRetry: () => ref.invalidate(jobDetailProvider(widget.jobId)),
          onBack: context.pop,
        ),
        data: (job) => _buildContent(context, job),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Job job) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final isCompact = size.height < 740;
    final headerH = math.max(size.height * 0.30, isCompact ? 200.0 : 240.0);

    return Stack(
      children: [
        // ── Scrollable body ──────────────────────────────────────────
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // Extra bottom padding so content clears the CTA button.
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Coloured hero header ───────────────────────────────
              _animated(
                _JobHeroHeader(
                  job: job,
                  headerHeight: headerH,
                  topPad: topPad,
                  onBack: context.pop,
                ),
                0.0, 0.40,
              ),

              const SizedBox(height: 20),

              // ── Info chips ─────────────────────────────────────────
              _animated(
                _InfoChipsRow(job: job),
                0.15, 0.55,
              ),

              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────
              _animated(
                _ContentSection(
                  icon: Icons.description_outlined,
                  title: 'Deskripsi Pekerjaan',
                  body: job.description,
                ),
                0.25, 0.65,
              ),

              // ── Requirements ───────────────────────────────────────
              if (job.requirements != null &&
                  job.requirements!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _animated(
                  _ContentSection(
                    icon: Icons.checklist_rounded,
                    title: 'Persyaratan',
                    body: job.requirements!,
                  ),
                  0.35, 0.75,
                ),
              ],
            ],
          ),
        ),

        // ── Sticky back button (over header) ────────────────────────
        Positioned(
          top: topPad + 8,
          left: 12,
          child: _CircleBackButton(onTap: context.pop),
        ),

        // ── Sticky bottom info bar ────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _animated(
            const _AdminAssignedNotice(),
            0.45, 0.85,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job Hero Header  (green gradient, no wave — full rectangular)
// ─────────────────────────────────────────────────────────────────────────────

class _JobHeroHeader extends StatelessWidget {
  const _JobHeroHeader({
    required this.job,
    required this.headerHeight,
    required this.topPad,
    required this.onBack,
  });

  final Job job;
  final double headerHeight;
  final double topPad;
  final VoidCallback onBack;

  String get _initials {
    final words = job.companyName.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return job.companyName
        .substring(0, math.min(2, job.companyName.length))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      height: headerHeight + topPad,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D27), Color(0xFF2B6E36), Color(0xFF3A7D44)],
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 60, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Company avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: tt.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Job title
                Text(
                  job.title,
                  style: tt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Company + type chip row
                Row(
                  children: [
                    Icon(Icons.business_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.75)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        job.companyName,
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        job.employmentTypeDisplay,
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Chips Row
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({required this.job});

  final Job job;

  bool get _deadlinePassed =>
      job.deadline != null && job.deadline!.isBefore(DateTime.now());

  bool get _deadlineSoon =>
      job.deadline != null &&
      !_deadlinePassed &&
      job.deadline!.difference(DateTime.now()).inDays <= 7;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Color deadlineColor() {
      if (_deadlinePassed) return AppColors.error;
      if (_deadlineSoon) return AppColors.warning;
      return cs.onSurfaceVariant;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (job.locationDisplay != '-')
            _InfoChip(
              icon: Icons.location_on_rounded,
              label: job.locationDisplay,
            ),
          if (job.salaryMin != null)
            _InfoChip(
              icon: Icons.payments_rounded,
              label: job.salaryDisplay,
            ),
          if (job.postedAt != null)
            _InfoChip(
              icon: Icons.schedule_rounded,
              label:
                  'Diposting ${DateFormat('dd MMM yyyy', 'id_ID').format(job.postedAt!)}',
            ),
          if (job.deadline != null)
            _InfoChip(
              icon: _deadlinePassed
                  ? Icons.event_busy_rounded
                  : Icons.event_available_rounded,
              label: _deadlinePassed
                  ? 'Berakhir ${DateFormat('dd MMM', 'id_ID').format(job.deadline!)}'
                  : 'Deadline ${DateFormat('dd MMM yyyy', 'id_ID').format(job.deadline!)}',
              iconColor: deadlineColor(),
              labelStyle: tt.labelMedium?.copyWith(
                color: deadlineColor(),
                fontWeight: (_deadlinePassed || _deadlineSoon)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              bgColor: deadlineColor().withValues(alpha: 0.08),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelStyle,
    this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final TextStyle? labelStyle;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: labelStyle ??
                tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Section Card  (description / requirements)
// ─────────────────────────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 18, color: AppColors.primaryDarkGreen),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: cs.outlineVariant, height: 1),
              const SizedBox(height: 14),
              Text(
                body,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.6,
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
// Admin-assigned notice bar  (replaces apply CTA)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminAssignedNotice extends StatelessWidget {
  const _AdminAssignedNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primaryDarkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Penugasan ke lowongan ini dikelola oleh admin.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle back button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.40),
            width: 1.2,
          ),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _DetailError extends StatelessWidget {
  const _DetailError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Gagal memuat detail lowongan',
              style: tt.titleMedium?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 6),
          Text(message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Kembali'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
