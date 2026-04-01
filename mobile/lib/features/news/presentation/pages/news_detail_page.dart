import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: const Color(0xFFF8FAFB),
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
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CustomScrollView(
          clipBehavior: Clip.none,
          slivers: [
            SliverToBoxAdapter(
              child: _NewsHeroHeader(news: news),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: _animated(
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetaRow(
                            news: news,
                            readMinutes: _readMinutes(news.content),
                          ),
                          if (news.summary != null &&
                              news.summary!.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SummaryBlock(summary: news.summary!),
                          ],
                          SizedBox(height: news.summary != null && news.summary!.isNotEmpty ? 24 : 20),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 24),
                          _ContentBody(content: news.content),
                        ],
                      ),
                    ),
                  ),
                  0.1,
                  0.55,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          child: const _CircleBackButton(),
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

    if (news.heroImage != null) {
      return _ImageHeader(news: news, topPad: topPad);
    }
    return _GradientHeader(news: news, topPad: topPad);
  }
}

/// Header with a real hero image + dark scrim overlay.
class _ImageHeader extends StatelessWidget {
  final News news;
  final double topPad;

  const _ImageHeader({
    required this.news,
    required this.topPad,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final h = math.min(280.0, screenH * 0.38) + topPad;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: SizedBox(
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: news.heroImage!,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (news.isPinned) ...[
                    const _PinnedBadge(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    news.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
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

/// Header for news without a hero image — uses the brand green gradient.
class _GradientHeader extends StatelessWidget {
  final News news;
  final double topPad;

  const _GradientHeader({
    required this.news,
    required this.topPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 56, 20, 36),
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (news.isPinned) ...[
            const _PinnedBadge(),
            const SizedBox(height: 12),
          ],
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            news.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: Colors.white,
              letterSpacing: -0.35,
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
  const _PinnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Unggulan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
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
    final date = news.publishedAt ?? news.createdAt;
    final formatted = DateFormat('dd MMMM yyyy', 'id_ID').format(date);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetaChip(
          icon: Icons.calendar_today_outlined,
          label: formatted,
          cs: cs,
        ),
        _MetaChip(
          icon: Icons.menu_book_outlined,
          label: '$readMinutes mnt baca',
          cs: cs,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.78),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.75),
            width: 4,
          ),
        ),
      ),
      child: Text(
        summary,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.65,
          color: AppColors.textDark.withValues(alpha: 0.88),
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
    return SelectableText(
      content,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.75,
        color: AppColors.textDark.withValues(alpha: 0.9),
        letterSpacing: 0.05,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle Back Button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark.withValues(alpha: 0.85),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: AppColors.textDark.withValues(alpha: 0.85)),
        title: Text(
          'Berita',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      body: Center(
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
    final heroH = 280.0 + topPad;

    return ColoredBox(
      color: const Color(0xFFF8FAFB),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: _box(heroH, radius: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _box(36, width: 140, radius: 12),
                        const SizedBox(width: 10),
                        _box(36, width: 110, radius: 12),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _box(88, width: width - 40, radius: 16),
                    const SizedBox(height: 22),
                    _box(1, width: width - 40, radius: 0),
                    const SizedBox(height: 22),
                    for (var i = 0; i < 8; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _box(
                          14,
                          width: i % 3 == 2 ? width * 0.55 : width - 40,
                          radius: 6,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
