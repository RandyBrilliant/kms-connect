import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../data/providers/news_provider.dart';
import '../../domain/models/news.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NewsListPage extends ConsumerStatefulWidget {
  const NewsListPage({super.key});

  @override
  ConsumerState<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends ConsumerState<NewsListPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _scrollCtrl = ScrollController();
  final PageController _carouselCtrl = PageController();
  final TextEditingController _searchCtrl = TextEditingController();
  final _searchDebouncer = Debouncer(milliseconds: 400);

  int _currentPage = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _carouselCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  /// Trigger next-page load when user scrolls near the bottom.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      final search = _searchQuery.isEmpty ? null : _searchQuery;
      ref.read(paginatedNewsProvider(search).notifier).loadNextPage();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Human-readable relative publish time.
  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} mgg lalu';
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} mnt lalu';
    return 'Baru saja';
  }

  /// Staggered fade + slide-up entrance animation.
  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  void _onSearch(String value) {
    _searchDebouncer.run(() {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
          _currentPage = 0;
        });
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final search = _searchQuery.isEmpty ? null : _searchQuery;
    final newsState = ref.watch(paginatedNewsProvider(search));
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _buildBody(context, newsState, topPad, search),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/news'),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginatedState<News> state,
    double topPad,
    String? search,
  ) {
    // Initial loading
    if (state.isLoading) {
      return _NewsShimmer(topPad: topPad);
    }

    // Error on first page with no data
    if (state.error != null && state.items.isEmpty) {
      return _ErrorState(
        error: state.error!,
        onRetry: () =>
            ref.read(paginatedNewsProvider(search).notifier).loadFirstPage(),
      );
    }

    return _buildContent(context, state, topPad, search);
  }

  Widget _buildContent(
    BuildContext context,
    PaginatedState<News> state,
    double topPad,
    String? search,
  ) {
    final all = state.items;

    final featured =
        all.where((n) => n.isPinned && n.heroImage != null).toList();
    final announcements =
        all.where((n) => n.isPinned && n.heroImage == null).toList();
    final regular = all.where((n) => !n.isPinned).toList();

    return RefreshIndicator(
      color: AppColors.primaryDarkGreen,
      onRefresh: () async =>
          ref.read(paginatedNewsProvider(search).notifier).loadFirstPage(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Wave hero header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _animated(
              _NewsProfessionalHeader(
                topPad: topPad,
                searchCtrl: _searchCtrl,
                onSearch: _onSearch,
              ),
              0.0, 0.4,
            ),
          ),

          // ── Empty search state ─────────────────────────────────────────
          if (all.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _animated(
                const _EmptySearch(),
                0.2, 0.6,
              ),
            ),

          // ── Empty all news state ───────────────────────────────────────
          if (all.isEmpty && _searchQuery.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _animated(const _EmptyState(), 0.2, 0.6),
            ),

          // ── Featured carousel ──────────────────────────────────────────
          if (featured.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  const _NewsSectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Unggulan',
                    accentColor: AppColors.primaryDarkGreen,
                  ),
                  0.02, 0.42,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  _FeaturedCarousel(
                    items: featured,
                    pageCtrl: _carouselCtrl,
                    currentPage: _currentPage,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    relativeTime: _relativeTime,
                    onTap: (n) => context.push('/news/${n.id}'),
                  ),
                  0.05, 0.5,
                ),
              ),
            ),
          ],

          // ── Announcements ──────────────────────────────────────────────
          if (announcements.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  20, featured.isEmpty ? 24 : 24, 20, 10),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  const _NewsSectionHeader(
                    icon: Icons.campaign_rounded,
                    label: 'Pengumuman',
                    accentColor: Color(0xFFD97706),
                  ),
                  0.1, 0.45,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _animated(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RepaintBoundary(
                        child: _AnnouncementCard(
                          news: announcements[i],
                          relativeTime: _relativeTime,
                          onTap: () =>
                              context.push('/news/${announcements[i].id}'),
                        ),
                      ),
                    ),
                    0.1 + i * 0.05, 0.65,
                  ),
                  childCount: announcements.length,
                ),
              ),
            ),
          ],

          // ── Terbaru section header ─────────────────────────────────────
          if (regular.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                (featured.isEmpty && announcements.isEmpty) ? 24 : 24,
                20,
                10,
              ),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  const _NewsSectionHeader(
                    icon: Icons.newspaper_rounded,
                    label: 'Terbaru',
                    accentColor: AppColors.primaryDarkGreen,
                  ),
                  0.2, 0.5,
                ),
              ),
            ),

          // ── Regular cards ──────────────────────────────────────────────
          if (regular.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _animated(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RepaintBoundary(
                        child: _RegularCard(
                          news: regular[i],
                          relativeTime: _relativeTime,
                          onTap: () =>
                              context.push('/news/${regular[i].id}'),
                        ),
                      ),
                    ),
                    0.25 + math.min(i * 0.06, 0.5), 0.8,
                  ),
                  childCount: regular.length,
                ),
              ),
            ),

          // ── Loading-more indicator ─────────────────────────────────────
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),

          // ── End indicator ──────────────────────────────────────────────
          if (!state.hasMore && all.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28, top: 4),
                child: Center(
                  child: Text(
                    'Anda sudah melihat semuanya',
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
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional header (matches home / dashboard chrome)
// ─────────────────────────────────────────────────────────────────────────────

class _NewsProfessionalHeader extends StatelessWidget {
  const _NewsProfessionalHeader({
    required this.topPad,
    required this.searchCtrl,
    required this.onSearch,
  });

  final double topPad;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Berita & Pengumuman',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.35,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Informasi terkini untuk karier dan rekrutmen Anda',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchCtrl,
              onSubmitted: onSearch,
              onChanged: onSearch,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              decoration: InputDecoration(
                hintText: 'Cari judul atau kata kunci…',
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
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        },
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _NewsSectionHeader extends StatelessWidget {
  const _NewsSectionHeader({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: accentColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured Carousel
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedCarousel extends StatelessWidget {
  final List<News> items;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final String Function(DateTime) relativeTime;
  final void Function(News) onTap;

  const _FeaturedCarousel({
    required this.items,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardWidth = MediaQuery.of(context).size.width - 40;
    final imageHeight = cardWidth / (16 / 9);
    const contentHeight = 148.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: imageHeight + contentHeight,
          child: PageView.builder(
            controller: pageCtrl,
            onPageChanged: onPageChanged,
            itemCount: items.length,
            itemBuilder: (_, i) => _FeaturedCard(
              news: items[i],
              relativeTime: relativeTime,
              onTap: () => onTap(items[i]),
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? cs.primary
                      : cs.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final News news;
  final String Function(DateTime) relativeTime;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.news,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = news.publishedAt ?? news.createdAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: news.heroImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(
                        color: AppColors.secondaryLightGreen,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDarkGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: AppColors.secondaryLightGreen,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.primaryDarkGreen,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'UNGGULAN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDarkGreen,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: AppColors.textDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        news.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 15,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          relativeTime(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Baca',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primaryDarkGreen,
                        ),
                      ],
                    ),
                  ],
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
// Announcement Card  (pinned, no image)
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final News news;
  final String Function(DateTime) relativeTime;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.news,
    required this.relativeTime,
    required this.onTap,
  });

  static const _amber = Color(0xFFD97706);
  static const _amberBg = Color(0xFFFFFBEB);
  static const _amberBorder = Color(0xFFFDE68A);
  static const _amberIconBg = Color(0xFFFEF3C7);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = news.publishedAt ?? news.createdAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _amberBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amberBorder.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: _amber.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _amberIconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: _amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PENGUMUMAN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB45309),
                      letterSpacing: 0.7,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: _amber.withValues(alpha: 0.55),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                news.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
              if (news.summary != null && news.summary!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  news.summary!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.62),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Diposting ${relativeTime(date)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.48),
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
// Regular (compact horizontal) card
// ─────────────────────────────────────────────────────────────────────────────

class _RegularCard extends StatelessWidget {
  final News news;
  final String Function(DateTime) relativeTime;
  final VoidCallback onTap;

  const _RegularCard({
    required this.news,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = news.publishedAt ?? news.createdAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: news.heroImage != null
                      ? CachedNetworkImage(
                          imageUrl: news.heroImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              ColoredBox(color: AppColors.secondaryLightGreen),
                          errorWidget: (_, _, _) =>
                              const _ThumbnailPlaceholder(),
                        )
                      : const _ThumbnailPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        news.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.42),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          relativeTime(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.secondaryLightGreen,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          color: AppColors.primaryDarkGreen.withValues(alpha: 0.7),
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty States
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.22),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada berita',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pantau halaman ini untuk informasi terbaru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.22),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ditemukan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coba kata kunci lain atau kosongkan pencarian',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
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
                Icon(Icons.wifi_off_rounded, size: 52, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat berita',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.52),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _NewsShimmer extends StatefulWidget {
  final double topPad;
  const _NewsShimmer({required this.topPad});

  @override
  State<_NewsShimmer> createState() => _NewsShimmerState();
}

class _NewsShimmerState extends State<_NewsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  static const _base = Color(0xFFE8EDF0);
  static const _highlight = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double height, {double? width, double radius = 8}) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(_base, _highlight, _pulse.value),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    final imageHeight = cardWidth / (16 / 9);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, widget.topPad + 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _box(26, width: 4, radius: 2),
                    const SizedBox(width: 12),
                    Expanded(child: _box(22, width: cardWidth * 0.55)),
                  ],
                ),
                const SizedBox(height: 10),
                _box(13, width: cardWidth * 0.85),
                const SizedBox(height: 16),
                _box(48, width: cardWidth, radius: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: imageHeight, child: _box(imageHeight, radius: 0)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(16),
                        const SizedBox(height: 8),
                        _box(14, width: cardWidth * 0.72),
                        const SizedBox(height: 14),
                        _box(1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _box(12, width: 80),
                            const Spacer(),
                            _box(12, width: 48),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          sliver: SliverToBoxAdapter(child: _box(16, width: 100)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, _) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(92, width: 92, radius: 12),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _box(15),
                            const SizedBox(height: 6),
                            _box(13),
                            const SizedBox(height: 6),
                            _box(12, width: cardWidth * 0.42),
                            const SizedBox(height: 10),
                            _box(11, width: 72),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }
}
