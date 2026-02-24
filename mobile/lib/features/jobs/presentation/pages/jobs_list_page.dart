import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../data/providers/job_provider.dart';
import '../../domain/models/job.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class JobsListPage extends ConsumerStatefulWidget {
  const JobsListPage({super.key});

  @override
  ConsumerState<JobsListPage> createState() => _JobsListPageState();
}

class _JobsListPageState extends ConsumerState<JobsListPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── Filter state ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String? _selectedType; // FULL_TIME | PART_TIME | CONTRACT | INTERNSHIP
  String? _selectedLocation;

  JobFilters? _cachedFilters;

  // Employment-type filter chips definition.
  static const _typeChips = [
    (label: 'Penuh Waktu', value: 'FULL_TIME'),
    (label: 'Paruh Waktu', value: 'PART_TIME'),
    (label: 'Kontrak', value: 'CONTRACT'),
    (label: 'Magang', value: 'INTERNSHIP'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Returns cached [JobFilters]; only creates a new object when values change
  /// so provider equality keeps the network request stable.
  JobFilters _getFilters() {
    final search =
        _searchCtrl.text.isEmpty ? null : _searchCtrl.text.trim();
    final next = JobFilters(
      search: search,
      employmentType: _selectedType,
      locationCountry:
          _selectedLocation?.isEmpty == true ? null : _selectedLocation,
    );
    if (_cachedFilters == null || _cachedFilters != next) {
      _cachedFilters = next;
    }
    return _cachedFilters!;
  }

  // ── Animation helpers ────────────────────────────────────────────────────

  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filters = _getFilters();
    final jobsAsync = ref.watch(jobsProvider(filters));
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    final headerH = math.max(size.height * 0.22, 180.0);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Scrollable content ───────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero wave header ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _animated(
                    _HeroHeader(
                      headerHeight: headerH,
                      onMyApplicationsTap: () =>
                          context.push('/jobs/my-applications'),
                    ),
                    0.0, 0.40,
                  ),
                ),

                // ── Search + filter bar ───────────────────────────────
                SliverToBoxAdapter(
                  child: _animated(
                    _SearchFilterBar(
                      searchCtrl: _searchCtrl,
                      searchFocus: _searchFocus,
                      selectedType: _selectedType,
                      typeChips: _typeChips,
                      onSearchChanged: (_) => setState(() {}),
                      onSearchCleared: () =>
                          setState(() => _searchCtrl.clear()),
                      onTypeSelected: (v) =>
                          setState(() => _selectedType = v),
                    ),
                    0.15, 0.55,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Job list ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _animated(
                    _JobsContent(
                      jobsAsync: jobsAsync,
                      filters: filters,
                      onCardTap: (id) => context.push('/jobs/$id'),
                      onRetry: () => ref.invalidate(jobsProvider(filters)),
                    ),
                    0.30, 0.85,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),

          // ── Bottom nav ───────────────────────────────────────────────
          const BottomNavBar(currentRoute: '/jobs'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Jobs Content  — loading / error / empty / data as a plain box widget
// ─────────────────────────────────────────────────────────────────────────────

class _JobsContent extends ConsumerWidget {
  const _JobsContent({
    required this.jobsAsync,
    required this.filters,
    required this.onCardTap,
    required this.onRetry,
  });

  final AsyncValue<List<Job>> jobsAsync;
  final JobFilters filters;
  final void Function(int id) onCardTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return jobsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
        ),
      ),
      error: (err, _) => _ErrorState(message: '$err', onRetry: onRetry),
      data: (jobs) {
        if (jobs.isEmpty) return const _EmptyState();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < jobs.length; i++)
                _JobCard(
                  job: jobs[i],
                  onTap: () => onCardTap(jobs[i].id),
                ),
            ],
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.headerHeight,
    required this.onMyApplicationsTap,
  });

  final double headerHeight;
  final VoidCallback onMyApplicationsTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: headerHeight + topPad,
      child: Stack(
        children: [
          Positioned.fill(
            child: AuthWaveHeader(height: headerHeight + topPad),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + title + action button
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.38),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.work_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Lowongan Kerja',
                        style: tt.titleMedium
                            ?.copyWith(color: Colors.white, height: 1.2),
                      ),
                    ),
                    // "Lamaranku" ghost button
                    OutlinedButton.icon(
                      onPressed: onMyApplicationsTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 1.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                      label: Text(
                        'Lamaranku',
                        style: tt.labelMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Big title
                Text(
                  'Temukan\nPekerjaan Impianmu',
                  style: tt.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Filter Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.searchCtrl,
    required this.searchFocus,
    required this.selectedType,
    required this.typeChips,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onTypeSelected,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final String? selectedType;
  final List<({String label, String value})> typeChips;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String?> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchCtrl,
              focusNode: searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
              style: tt.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Cari jabatan, perusahaan…',
                hintStyle: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: cs.onSurfaceVariant, size: 22),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: cs.onSurfaceVariant, size: 20),
                        onPressed: onSearchCleared,
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "Semua" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Semua'),
                    selected: selectedType == null,
                    onSelected: (_) => onTypeSelected(null),
                    selectedColor:
                        AppColors.primaryDarkGreen.withValues(alpha: 0.12),
                    checkmarkColor: AppColors.primaryDarkGreen,
                    labelStyle: tt.labelMedium?.copyWith(
                      color: selectedType == null
                          ? AppColors.primaryDarkGreen
                          : cs.onSurfaceVariant,
                      fontWeight: selectedType == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    showCheckmark: false,
                    side: BorderSide(
                      color: selectedType == null
                          ? AppColors.primaryDarkGreen.withValues(alpha: 0.6)
                          : cs.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                for (final c in typeChips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.label),
                      selected: selectedType == c.value,
                      onSelected: (sel) =>
                          onTypeSelected(sel ? c.value : null),
                      selectedColor:
                          AppColors.primaryDarkGreen.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primaryDarkGreen,
                      labelStyle: tt.labelMedium?.copyWith(
                        color: selectedType == c.value
                            ? AppColors.primaryDarkGreen
                            : cs.onSurfaceVariant,
                        fontWeight: selectedType == c.value
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      showCheckmark: false,
                      side: BorderSide(
                        color: selectedType == c.value
                            ? AppColors.primaryDarkGreen
                                .withValues(alpha: 0.6)
                            : cs.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
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
// Job Card
// ─────────────────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  // Returns the first two characters of the company name for the avatar.
  String get _initials {
    final words = job.companyName.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return job.companyName.substring(0, math.min(2, job.companyName.length))
        .toUpperCase();
  }

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar + title + arrow ─────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company initial avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: tt.titleSmall?.copyWith(
                          color: AppColors.primaryDarkGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.companyName,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant, size: 20),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant, height: 1),
              const SizedBox(height: 12),

              // ── Meta row: location + type chip ───────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (job.locationDisplay != '-')
                    _MetaChip(
                      icon: Icons.location_on_outlined,
                      label: job.locationDisplay,
                    ),
                  _TypeBadge(label: job.employmentTypeDisplay),
                  if (job.salaryMin != null)
                    _MetaChip(
                      icon: Icons.payments_outlined,
                      label: job.salaryDisplay,
                    ),
                ],
              ),

              // ── Deadline ─────────────────────────────────────────────
              if (job.deadline != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _deadlinePassed
                          ? Icons.event_busy_rounded
                          : Icons.event_rounded,
                      size: 14,
                      color: _deadlinePassed
                          ? AppColors.error
                          : _deadlineSoon
                              ? AppColors.warning
                              : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _deadlinePassed
                          ? 'Sudah berakhir · ${DateFormat('dd MMM', 'id_ID').format(job.deadline!)}'
                          : 'Deadline ${DateFormat('dd MMM yyyy', 'id_ID').format(job.deadline!)}',
                      style: tt.labelSmall?.copyWith(
                        color: _deadlinePassed
                            ? AppColors.error
                            : _deadlineSoon
                                ? AppColors.warning
                                : cs.onSurfaceVariant,
                        fontWeight: (_deadlinePassed || _deadlineSoon)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chip widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style:
                tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: AppColors.primaryDarkGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.work_off_rounded, size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text('Tidak ada lowongan ditemukan',
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text('Coba ubah filter pencarianmu',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Gagal memuat lowongan',
              style: tt.titleMedium?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 6),
          Text(message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
