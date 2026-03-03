import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../notifications/data/providers/notification_provider.dart';
import '../../../news/data/providers/news_provider.dart';
import '../../../news/domain/models/news.dart';
import '../../../profile/data/providers/profile_provider.dart';
import '../widgets/bottom_nav_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Accent palette for news icon badges – cycles by card index.
  static const _iconBg = [
    Color(0xFFDBEAFE), // blue-100
    Color(0xFFEDE9FE), // purple-100
    Color(0xFFD1FAE5), // green-100
    Color(0xFFFEF3C7), // amber-100
    Color(0xFFFFE4E6), // rose-100
  ];
  static const _iconFg = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFE11D48),
  ];
  static const _icons = [
    Icons.smart_toy_outlined,
    Icons.lightbulb_outline,
    Icons.campaign_outlined,
    Icons.star_outline,
    Icons.info_outline,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileNotifierProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Wraps [child] in a staggered fade + slide-up entrance driven by [_ctrl].
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

  static String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}h lalu';
    if (diff.inHours >= 1) return '${diff.inHours}j lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m lalu';
    return 'Baru saja';
  }

  static String _firstName(String? fullName, String? email) {
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Kamu';
  }

  static Color _statusColor(String? status) {
    switch (status) {
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      case 'SUBMITTED':
        return AppColors.warning;
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final newsState = ref.watch(paginatedNewsProvider(null));
    final notifState = ref.watch(notificationProvider);
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    final user = authState.user;
    final displayName = user?.fullName?.isNotEmpty == true
        ? user!.fullName!
        : profileState.profile?.fullName?.isNotEmpty == true
            ? profileState.profile!.fullName!
            : user?.email ?? 'Pengguna';
    final firstName = _firstName(displayName, user?.email);

    final score = profileState.profile?.score?.toInt() ?? 0;
    final statusLabel =
        profileState.profile?.verificationStatusDisplay ?? 'Draf';
    final statusColor =
        _statusColor(profileState.profile?.verificationStatus);

    // Header height: 26 % of screen height, floor at 210 px.
    final headerH = math.max(size.height * 0.26, 210.0);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Offline indicator ───────────────────────────────────────────
          const OfflineBanner(),

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh all homepage data sources concurrently.
                await Future.wait([
                  ref.read(profileNotifierProvider.notifier).loadProfile(force: true),
                  ref.read(notificationProvider.notifier).load(),
                  ref.read(paginatedNewsProvider(null).notifier).loadFirstPage(),
                ]);
              },
              color: cs.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero wave header ─────────────────────────────────
                  _animated(
                    _HeroHeader(
                      headerHeight: headerH,
                      displayName: displayName,
                      firstName: firstName,
                      unreadCount: notifState.unreadCount,
                      onNotificationTap: () =>
                          context.push('/notifications'),
                    ),
                    0.0, 0.40,
                  ),

                  const SizedBox(height: 20),

                  // ── Stat cards ───────────────────────────────────────
                  _animated(
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: _ProfileScoreCard(
                                score:
                                    profileState.isLoading ? null : score,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: _StatusCard(
                                label: statusLabel,
                                color: statusColor,
                                isLoading: profileState.isLoading,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    0.20, 0.60,
                  ),

                  const SizedBox(height: 28),

                  // ── Section header ───────────────────────────────────
                  _animated(
                    _SectionHeader(
                      title: 'Pengumuman Terbaru',
                      actionLabel: 'Lihat semua',
                      onAction: () => context.go('/news'),
                    ),
                    0.35, 0.72,
                  ),

                  const SizedBox(height: 4),

                  // ── News list ────────────────────────────────────────
                  _animated(
                    _NewsList(
                      newsState: newsState,
                      iconBg: _iconBg,
                      iconFg: _iconFg,
                      icons: _icons,
                      relativeTime: _relativeTime,
                      onTap: (id) => context.push('/news/$id'),
                    ),
                    0.50, 0.90,
                  ),
                ],
              ),
            ),
            ),
          ),

          // ── Bottom navigation ──────────────────────────────────────────
          const BottomNavBar(currentRoute: '/home'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header  — wave background + greeting + notification bell
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.headerHeight,
    required this.displayName,
    required this.firstName,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  final double headerHeight;
  final String displayName;
  final String firstName;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: headerHeight + topPad,
      child: Stack(
        children: [
          // Full-bleed wave background
          Positioned.fill(
            child: AuthWaveHeader(height: headerHeight + topPad),
          ),

          // Content below the status bar
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar + name + bell
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
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang,',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            displayName,
                            style: tt.titleMedium
                                ?.copyWith(color: Colors.white, height: 1.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _NotificationBell(
                      unreadCount: unreadCount,
                      onTap: onNotificationTap,
                    ),
                  ],
                ),

                const Spacer(),

                // Large greeting
                RichText(
                  text: TextSpan(
                    style: tt.headlineMedium
                        ?.copyWith(color: Colors.white, height: 1.25),
                    children: [
                      const TextSpan(text: 'Halo, '),
                      TextSpan(
                        text: firstName,
                        style: tt.headlineMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const TextSpan(text: ' 👋'),
                    ],
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
// Notification Bell
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap, this.unreadCount = 0});

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.notifications_outlined,
                    size: 22, color: Colors.white),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
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
// Profile Score Card  (green filled)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileScoreCard extends StatelessWidget {
  const _ProfileScoreCard({required this.score});

  /// `null` means data is still loading.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow orb
          Positioned(
            top: -12,
            right: -12,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon bubble
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: Colors.white, size: 20),
                    ),
                    // Label chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Profil',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                score == null
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        '$score%',
                        style: tt.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  'Kelengkapan',
                  style: tt.labelMedium?.copyWith(color: Colors.white70),
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
// Status Card  (surface / bordered)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.color,
    required this.isLoading,
  });

  final String label;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 150,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.verified_user_outlined,
                  color: color, size: 20),
            ),
            const Spacer(),
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: color, strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: (label.length > 9
                            ? tt.titleLarge
                            : tt.headlineSmall)
                        ?.copyWith(
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 4),
            Text(
              'Status Lamaran',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header row
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: cs.primary,
            ),
            child: Text(
              actionLabel,
              style: tt.labelMedium?.copyWith(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News List  — handles loading / error / empty / data
// ─────────────────────────────────────────────────────────────────────────────

class _NewsList extends StatelessWidget {
  const _NewsList({
    required this.newsState,
    required this.iconBg,
    required this.iconFg,
    required this.icons,
    required this.relativeTime,
    required this.onTap,
  });

  final PaginatedState<News> newsState;
  final List<Color> iconBg;
  final List<Color> iconFg;
  final List<IconData> icons;
  final String Function(DateTime) relativeTime;
  final void Function(int id) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Loading state
    if (newsState.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
        ),
      );
    }

    // Error state
    if (newsState.error != null && newsState.items.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Text(
            'Gagal memuat berita.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    // Empty state
    if (newsState.items.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Text(
            'Belum ada pengumuman.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final list = newsState.items;
    final items = list.length > 5 ? list.sublist(0, 5) : list;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            RepaintBoundary(
              child: _NewsCard(
                news: items[i],
                iconBg: iconBg[i % iconBg.length],
                iconFg: iconFg[i % iconFg.length],
                icon: icons[i % icons.length],
                relativeTime:
                    relativeTime(items[i].publishedAt ?? items[i].createdAt),
                onTap: () => onTap(items[i].id),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News Card
// ─────────────────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.news,
    required this.iconBg,
    required this.iconFg,
    required this.icon,
    required this.relativeTime,
    required this.onTap,
  });

  final News news;
  final Color iconBg;
  final Color iconFg;
  final IconData icon;
  final String relativeTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
                child: Icon(icon, color: iconFg, size: 21),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            news.title,
                            style: tt.labelLarge
                                ?.copyWith(color: cs.onSurface, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTime,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (news.summary != null &&
                        news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        news.summary!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
