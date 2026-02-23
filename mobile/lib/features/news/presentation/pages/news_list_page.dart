import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
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
  late final AnimationController _entranceCtrl;
  final PageController _carouselCtrl = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _carouselCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns human-readable relative time (e.g. "2 jam lalu", "3 hari lalu").
  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} mgg lalu';
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} mnt lalu';
    return 'Baru saja';
  }

  /// Effective publish date: publishedAt if set, otherwise createdAt.
  DateTime _date(News n) => n.publishedAt ?? n.createdAt;

  /// Wraps [child] in a staggered fade + slide-up entrance.
  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _entranceCtrl,
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsProvider(null));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: _AppBar(onBack: () => context.go('/home')),
      body: newsAsync.when(
        loading: () => const _ShimmerSkeleton(),
        error: (err, _) => _ErrorView(
          error: err,
          onRetry: () => ref.invalidate(newsProvider(null)),
        ),
        data: _buildContent,
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/news'),
    );
  }

  Widget _buildContent(List<News> all) {
    if (all.isEmpty) return const _EmptyView();

    // Partition news into their display sections.
    final featured = all.where((n) => n.isPinned && n.heroImage != null).toList();
    final announcements = all.where((n) => n.isPinned && n.heroImage == null).toList();
    final regular = all.where((n) => !n.isPinned).toList();

    return RefreshIndicator(
      color: AppColors.primaryDarkGreen,
      onRefresh: () async => ref.invalidate(newsProvider(null)),
      child: CustomScrollView(
        slivers: [
          // ── Featured carousel ─────────────────────────────────────────
          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: _animated(
                _FeaturedCarousel(
                  items: featured,
                  pageCtrl: _carouselCtrl,
                  currentPage: _currentPage,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  relativeTime: _relativeTime,
                  onTap: (n) => context.push('/news/${n.id}'),
                ),
                0.0, 0.45,
              ),
            ),

          // ── Announcements (pinned, no image) ──────────────────────────
          if (announcements.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, featured.isEmpty ? 20 : 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _animated(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnnouncementCard(
                        news: announcements[i],
                        relativeTime: _relativeTime,
                      ),
                    ),
                    0.1 + i * 0.05, 0.65,
                  ),
                  childCount: announcements.length,
                ),
              ),
            ),

          // ── Section header "Terbaru" ───────────────────────────────────
          if (regular.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  Text(
                    'Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  0.2, 0.5,
                ),
              ),
            ),

          // ── Regular news list ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _animated(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RegularCard(
                      news: regular[i],
                      relativeTime: _relativeTime,
                      onTap: () => context.push('/news/${regular[i].id}'),
                    ),
                  ),
                  0.25 + math.min(i * 0.06, 0.5), 0.8,
                ),
                childCount: regular.length,
              ),
            ),
          ),

          // ── End of list indicator ──────────────────────────────────────
          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28, top: 4),
                child: Center(
                  child: Text(
                    'Anda sudah melihat semuanya',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textLight,
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
// AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  const _AppBar({required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.textDark,
            onPressed: onBack,
          ),
          title: Text(
            'Berita & Pengumuman',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
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
    // Compute full card height based on available width.
    final cardWidth = MediaQuery.of(context).size.width - 32;
    final imageHeight = cardWidth / (16 / 9);
    // Content area below the image (title + summary + footer) approx 145px.
    const contentHeight = 145.0;

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

        // Page indicator dots (only shown for multiple items).
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
                      ? AppColors.primaryDarkGreen
                      : AppColors.primaryDarkGreen.withOpacity(0.25),
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

/// Single card shown inside the [_FeaturedCarousel] PageView.
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
    final date = news.publishedAt ?? news.createdAt;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Image with "UNGGULAN" badge ────────────────────────────
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: news.heroImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.secondaryLightGreen,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDarkGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.secondaryLightGreen,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textLight,
                          size: 40,
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
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'UNGGULAN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1.35,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        news.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          relativeTime(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
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
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
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
// Announcement Card  (pinned, no hero image) — amber alert style
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final News news;
  final String Function(DateTime) relativeTime;

  const _AnnouncementCard({required this.news, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final date = news.publishedAt ?? news.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PENGUMUMAN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB45309),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            news.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
          if (news.summary != null && news.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              news.summary!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Diposting ${relativeTime(date)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textLight,
            ),
          ),
        ],
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
    final date = news.publishedAt ?? news.createdAt;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: news.heroImage != null
                      ? CachedNetworkImage(
                          imageUrl: news.heroImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.secondaryLightGreen,
                          ),
                          errorWidget: (_, __, ___) => _PlaceholderThumbnail(),
                        )
                      : _PlaceholderThumbnail(),
                ),
              ),

              const SizedBox(width: 12),

              // ── Text content ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        news.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      relativeTime(date),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
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

class _PlaceholderThumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.secondaryLightGreen,
      child: const Center(
        child: Icon(
          Icons.article_outlined,
          color: AppColors.primaryDarkGreen,
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 56,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada berita',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pantau terus untuk informasi terbaru',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat berita',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
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
                color: AppColors.textMedium,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
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
// Shimmer Loading Skeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Self-contained shimmer skeleton shown while news data is loading.
/// Uses a single [AnimationController] shared across all shimmer boxes.
class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
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

  /// A single shimmer rectangle.
  Widget _box(double height, {double? width, double radius = 8}) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
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
    final cardWidth = MediaQuery.of(context).size.width - 32;
    final imageHeight = cardWidth / (16 / 9);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Featured card skeleton
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
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
                      _box(14, width: cardWidth * 0.75),
                      const SizedBox(height: 14),
                      _box(1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _box(11, width: 80),
                          const Spacer(),
                          _box(11, width: 50),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section header skeleton
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          sliver: SliverToBoxAdapter(child: _box(16, width: 70)),
        ),

        // List item skeletons
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
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
                            _box(12, width: cardWidth * 0.4),
                            const SizedBox(height: 14),
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
