import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/shimmer_loading.dart';
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
  final _scrollCtrl = ScrollController();

  // ── Filter state ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchDebouncer = Debouncer(milliseconds: 400);
  String? _selectedType; // FULL_TIME | PART_TIME | CONTRACT | INTERNSHIP
  String? _selectedLocation;

  /// The debounced search text — only updates after the debounce timer fires,
  /// so we don't fire an API request on every single keystroke.
  String _debouncedSearch = '';

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
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  /// Trigger next-page load when user scrolls near the bottom.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.position.pixels;
    // Start loading when within 200px of the bottom.
    if (maxScroll - currentScroll <= 200) {
      final filters = _getFilters();
      ref.read(paginatedJobsProvider(filters).notifier).loadNextPage();
    }
  }

  /// Returns cached [JobFilters]; only creates a new object when values change
  /// so provider equality keeps the network request stable.
  JobFilters _getFilters() {
    final search =
        _debouncedSearch.isEmpty ? null : _debouncedSearch.trim();
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
    final jobsState = ref.watch(paginatedJobsProvider(filters));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(paginatedJobsProvider(filters).notifier)
                    .loadFirstPage();
              },
              color: cs.primary,
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
              slivers: [
                SliverToBoxAdapter(
                  child: _animated(
                    _JobsProfessionalHeader(
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
                      onSearchChanged: (_) {
                        _searchDebouncer.run(() {
                          if (mounted) {
                            setState(() {
                              _debouncedSearch = _searchCtrl.text;
                            });
                          }
                        });
                      },
                      onSearchCleared: () {
                        _searchDebouncer.cancel();
                        setState(() {
                          _searchCtrl.clear();
                          _debouncedSearch = '';
                        });
                      },
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
                      state: jobsState,
                      onCardTap: (id) => context.push('/jobs/$id'),
                      onRetry: () => ref
                          .read(paginatedJobsProvider(filters).notifier)
                          .loadFirstPage(),
                    ),
                    0.30, 0.85,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
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

class _JobsContent extends StatelessWidget {
  const _JobsContent({
    required this.state,
    required this.onCardTap,
    required this.onRetry,
  });

  final PaginatedState<Job> state;
  final void Function(int id) onCardTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Initial loading
    if (state.isLoading) {
      return const ShimmerList(count: 4);
    }

    // Error on first page
    if (state.error != null && state.items.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: onRetry);
    }

    // Empty state
    if (state.items.isEmpty) {
      return const _EmptyState();
    }

    // Data with optional loading-more indicator
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < state.items.length; i++)
            RepaintBoundary(
              child: _JobCard(
                job: state.items[i],
                onTap: () => onCardTap(state.items[i].id),
              ),
            ),
          // Loading-more indicator
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          // "All loaded" footer
          if (!state.hasMore && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Semua lowongan telah dimuat',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.42),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Professional header (aligned with Berita / Beranda)
// ─────────────────────────────────────────────────────────────────────────────

class _JobsProfessionalHeader extends StatelessWidget {
  const _JobsProfessionalHeader({required this.onMyApplicationsTap});

  final VoidCallback onMyApplicationsTap;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 26,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lowongan Kerja',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.35,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Temukan pekerjaan yang sesuai dengan profil Anda',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onMyApplicationsTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDarkGreen,
                    side: BorderSide(
                      color: AppColors.primaryDarkGreen.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: Text(
                    'Lamaranku',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            decoration: InputDecoration(
              hintText: 'Cari jabatan, perusahaan…',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.42),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.primaryDarkGreen.withValues(alpha: 0.85),
              ),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: onSearchCleared,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primaryDarkGreen,
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      'Semua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: selectedType == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selectedType == null
                            ? AppColors.primaryDarkGreen
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    selected: selectedType == null,
                    onSelected: (_) => onTypeSelected(null),
                    selectedColor:
                        AppColors.primaryDarkGreen.withValues(alpha: 0.12),
                    checkmarkColor: AppColors.primaryDarkGreen,
                    showCheckmark: false,
                    side: BorderSide(
                      color: selectedType == null
                          ? AppColors.primaryDarkGreen.withValues(alpha: 0.6)
                          : cs.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                for (final c in typeChips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        c.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: selectedType == c.value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedType == c.value
                              ? AppColors.primaryDarkGreen
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      selected: selectedType == c.value,
                      onSelected: (sel) =>
                          onTypeSelected(sel ? c.value : null),
                      selectedColor:
                          AppColors.primaryDarkGreen.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primaryDarkGreen,
                      showCheckmark: false,
                      side: BorderSide(
                        color: selectedType == c.value
                            ? AppColors.primaryDarkGreen
                                .withValues(alpha: 0.6)
                            : cs.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
                width: 1,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: AppColors.primaryDarkGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.companyName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 14),

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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: (_deadlinePassed || _deadlineSoon)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _deadlinePassed
                            ? AppColors.error
                            : _deadlineSoon
                                ? AppColors.warning
                                : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryDarkGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDarkGreen,
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
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
            children: [
              Icon(
                Icons.work_off_rounded,
                size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada lowongan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coba ubah kata kunci atau filter jenis pekerjaan',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                  height: 1.45,
                ),
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
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
                Icons.cloud_off_rounded,
                size: 52,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat lowongan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.52),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
