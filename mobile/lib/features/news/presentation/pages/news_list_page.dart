import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/auth_wave_header.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _buildBody(context, newsState, topPad, search),
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

    const headerHeight = 160.0;

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
              _HeroHeader(
                topPad: topPad,
                headerHeight: headerHeight,
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
          if (featured.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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

          // ── Announcements ──────────────────────────────────────────────
          if (announcements.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, featured.isEmpty ? 20 : 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  _SectionLabel(
                    icon: Icons.campaign_rounded,
                    label: 'Pengumuman',
                    color: const Color(0xFFD97706),
                  ),
                  0.1, 0.45,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                16,
                (featured.isEmpty && announcements.isEmpty) ? 20 : 20,
                16,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  _SectionLabel(
                    icon: Icons.schedule_rounded,
                    label: 'Terbaru',
                    color: AppColors.primaryDarkGreen,
                  ),
                  0.2, 0.5,
                ),
              ),
            ),

          // ── Regular cards ──────────────────────────────────────────────
          if (regular.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
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
// Hero Header  (wave + search)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final double topPad;
  final double headerHeight;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;

  const _HeroHeader({
    required this.topPad,
    required this.headerHeight,
    required this.searchCtrl,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Wave background ──────────────────────────────────────────────
        AuthWaveHeader(height: headerHeight + topPad),

        // ── Text + search bar ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berita & Pengumuman',
                style: tt.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Informasi terkini untuk Anda',
                style: tt.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 16),
              // ── Search bar ─────────────────────────────────────────────
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchCtrl,
                  onSubmitted: onSearch,
                  onChanged: onSearch,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Cari berita…',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.primaryDarkGreen.withValues(alpha: 0.7),
                    ),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
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
    final cardWidth = MediaQuery.of(context).size.width - 32;
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
    final tt = Theme.of(context).textTheme;
    final date = news.publishedAt ?? news.createdAt;

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Hero image with UNGGULAN badge ─────────────────────────
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
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'UNGGULAN',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDarkGreen,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Content ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (news.summary != null && news.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      news.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        relativeTime(date),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Baca',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
    final tt = Theme.of(context).textTheme;
    final date = news.publishedAt ?? news.createdAt;

    return Material(
      color: _amberBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _amberBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _amberIconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      size: 16,
                      color: _amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PENGUMUMAN',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB45309),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _amber.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                news.title,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (news.summary != null && news.summary!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  news.summary!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Diposting ${relativeTime(date)}',
                style: tt.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
    final tt = Theme.of(context).textTheme;
    final date = news.publishedAt ?? news.createdAt;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: news.heroImage != null
                      ? CachedNetworkImage(
                          imageUrl: news.heroImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              ColoredBox(color: AppColors.secondaryLightGreen),
                          errorWidget: (_, _, _) => const _ThumbnailPlaceholder(),
                        )
                      : const _ThumbnailPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              // ── Text ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        news.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 12,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          relativeTime(date),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.45),
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
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 60,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada berita',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Pantau terus untuk informasi terbaru',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 60,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba kata kunci yang berbeda',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: cs.error),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat berita',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
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
    const headerHeight = 160.0 + 20.0; // header + search bar area
    final cardWidth = MediaQuery.of(context).size.width - 32;
    final imageHeight = cardWidth / (16 / 9);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Header placeholder
        SliverToBoxAdapter(
          child: SizedBox(height: headerHeight + widget.topPad),
        ),
        // Featured card skeleton
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: imageHeight, child: _box(imageHeight, radius: 0)),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(15),
                        const SizedBox(height: 8),
                        _box(13, width: cardWidth * 0.7),
                        const SizedBox(height: 14),
                        _box(1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _box(11, width: 76),
                            const Spacer(),
                            _box(11, width: 44),
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
        // Section label skeleton
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          sliver: SliverToBoxAdapter(child: _box(14, width: 80)),
        ),
        // List item skeletons
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, _) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(88, width: 88, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _box(14),
                            const SizedBox(height: 6),
                            _box(13),
                            const SizedBox(height: 6),
                            _box(12, width: cardWidth * 0.45),
                            const SizedBox(height: 12),
                            _box(11, width: 70),
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
