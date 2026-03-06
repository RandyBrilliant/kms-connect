import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../data/providers/news_provider.dart';
import '../../domain/models/news.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NewsDetailPage extends ConsumerStatefulWidget {
  final int newsId;
  const NewsDetailPage({super.key, required this.newsId});

  @override
  ConsumerState<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends ConsumerState<NewsDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

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
    super.dispose();
  }

  /// Staggered fade + slide-up entrance.
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

  /// Estimated reading time in minutes (avg 200 words/min).
  int _readMinutes(String content) {
    final words = content.trim().split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 60);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsDetailProvider(widget.newsId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: newsAsync.when(
        loading: () => const _DetailShimmer(),
        error: (err, _) => _ErrorState(
          error: err,
          onRetry: () => ref.invalidate(newsDetailProvider(widget.newsId)),
        ),
        data: (news) => _buildContent(context, news),
      ),
    );
  }

  Widget _buildContent(BuildContext context, News news) {
    return Stack(
      children: [
        // ── Scrollable body ────────────────────────────────────────────
        CustomScrollView(
          slivers: [
            // ── Hero header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _NewsHeroHeader(news: news),
            ),

            // ── Meta row (date, read time) ───────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  _MetaRow(news: news, readMinutes: _readMinutes(news.content)),
                  0.1, 0.5,
                ),
              ),
            ),

            // ── Summary block ────────────────────────────────────────
            if (news.summary != null && news.summary!.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _animated(
                    _SummaryBlock(summary: news.summary!),
                    0.15, 0.55,
                  ),
                ),
              ),

            // ── Divider ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
            ),

            // ── Content body ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _animated(
                  _ContentBody(content: news.content),
                  0.2, 0.65,
                ),
              ),
            ),
          ],
        ),

        // ── Overlaid back button ───────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: _CircleBackButton(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header  (hero image or green gradient)
// ─────────────────────────────────────────────────────────────────────────────

class _NewsHeroHeader extends StatelessWidget {
  final News news;
  const _NewsHeroHeader({required this.news});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final tt = Theme.of(context).textTheme;

    if (news.heroImage != null) {
      return _ImageHeader(news: news, topPad: topPad, tt: tt);
    }
    return _GradientHeader(news: news, topPad: topPad, tt: tt);
  }
}

/// Header with a real hero image + dark scrim overlay.
class _ImageHeader extends StatelessWidget {
  final News news;
  final double topPad;
  final TextTheme tt;

  const _ImageHeader({
    required this.news,
    required this.topPad,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: math.min(260.0, screenH * 0.38) + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Hero image ───────────────────────────────────────────────
          CachedNetworkImage(
            imageUrl: news.heroImage!,
            fit: BoxFit.cover,
            placeholder: (_, _) => ColoredBox(
              color: AppColors.secondaryLightGreen,
            ),
            errorWidget: (_, _, _) => ColoredBox(
              color: AppColors.primaryDarkGreen,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 48,
                ),
              ),
            ),
          ),

          // ── Gradient scrim ───────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),

          // ── Title + badges ───────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (news.isPinned) ...[
                  _PinnedBadge(),
                  const SizedBox(height: 10),
                ],
                Text(
                  news.title,
                  style: tt.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
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

/// Header for news without a hero image — uses the brand green gradient.
class _GradientHeader extends StatelessWidget {
  final News news;
  final double topPad;
  final TextTheme tt;

  const _GradientHeader({
    required this.news,
    required this.topPad,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 60, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B5E2E),
            AppColors.primaryDarkGreen,
            const Color(0xFF3A8B4F),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (news.isPinned) ...[
            _PinnedBadge(),
            const SizedBox(height: 12),
          ],
          // News icon stamp
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            news.title,
            style: tt.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned Badge
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            'Unggulan',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta Row  (date + reading time)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final News news;
  final int readMinutes;

  const _MetaRow({required this.news, required this.readMinutes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final date = news.publishedAt ?? news.createdAt;
    final formatted = DateFormat('dd MMMM yyyy', 'id_ID').format(date);

    return Row(
      children: [
        _MetaChip(
          icon: Icons.calendar_today_outlined,
          label: formatted,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 8),
        _MetaChip(
          icon: Icons.menu_book_outlined,
          label: '$readMinutes mnt baca',
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Block  — highlighted lead paragraph
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBlock extends StatelessWidget {
  final String summary;
  const _SummaryBlock({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: cs.primary.withValues(alpha: 0.65),
            width: 3.5,
          ),
        ),
      ),
      child: Text(
        summary,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.8),
          height: 1.65,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Body  — full article text
// ─────────────────────────────────────────────────────────────────────────────

class _ContentBody extends StatelessWidget {
  final String content;
  const _ContentBody({required this.content});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Text(
      content,
      style: tt.bodyLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.85),
        height: 1.75,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle Back Button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: cs.onSurface),
      ),
      backgroundColor: cs.surfaceContainerLowest,
      body: Center(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
// Shimmer Skeleton  (detail loading state)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailShimmer extends StatefulWidget {
  const _DetailShimmer();

  @override
  State<_DetailShimmer> createState() => _DetailShimmerState();
}

class _DetailShimmerState extends State<_DetailShimmer>
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
    final topPad = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _box(260 + topPad, radius: 0)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                _box(28, width: 130, radius: 20),
                const SizedBox(width: 8),
                _box(28, width: 100, radius: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Color.lerp(_base, _highlight, 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _box(14, width: i % 3 == 2 ? width * 0.65 : null),
              ),
              childCount: 10,
            ),
          ),
        ),
      ],
    );
  }
}
