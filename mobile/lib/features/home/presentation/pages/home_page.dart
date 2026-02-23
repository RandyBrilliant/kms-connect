import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../profile/data/providers/profile_provider.dart';
import '../../../news/data/providers/news_provider.dart';
import '../../../news/domain/models/news.dart';
import '../../../notifications/data/providers/notification_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  // Accent colors for news card icons, cycling by index
  static const List<Color> _newsIconBg = [
    Color(0xFFDBEAFE), // blue-100
    Color(0xFFEDE9FE), // purple-100
    Color(0xFFD1FAE5), // green-100
    Color(0xFFFEF3C7), // amber-100
    Color(0xFFFFE4E6), // rose-100
  ];
  static const List<Color> _newsIconFg = [
    Color(0xFF2563EB), // blue-600
    Color(0xFF7C3AED), // purple-600
    Color(0xFF16A34A), // green-600
    Color(0xFFD97706), // amber-600
    Color(0xFFE11D48), // rose-600
  ];
  static const List<IconData> _newsIcons = [
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
    _ctrl?.dispose();
    super.dispose();
  }

  /// Wraps [child] in a staggered fade + slide-up entrance animation.
  Widget _animated(Widget child, double begin, double end) {
    final controller = _ctrl;
    if (controller == null) return child;
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  /// Returns "Xj lalu", "Xh lalu", "Xm lalu" relative to now.
  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}h lalu';
    if (diff.inHours >= 1) return '${diff.inHours}j lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m lalu';
    return 'Baru saja';
  }

  /// Extracts just the first name from fullName or the part before '@' in email.
  String _firstName(String? fullName, String? email) {
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Kamu';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final profileState = ref.watch(profileNotifierProvider);
    final newsAsync = ref.watch(newsProvider(null));
    final notifState = ref.watch(notificationProvider);

    // full_name priority: user.fullName → profile.fullName → email prefix → fallback
    final displayName = user?.fullName?.isNotEmpty == true
        ? user!.fullName!
        : profileState.profile?.fullName?.isNotEmpty == true
            ? profileState.profile!.fullName!
            : user?.email ?? 'Pengguna';
    final firstName = _firstName(displayName, user?.email);

    final score = profileState.profile?.score?.toInt() ?? 0;
    final statusLabel =
        profileState.profile?.verificationStatusDisplay ?? 'Draf';
    final statusColor = _statusColor(profileState.profile?.verificationStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar ────────────────────────────────────────────
                    _animated(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE8D5C4),
                              border: Border.all(
                                  color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF8B6550),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Greeting text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selamat datang,',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    height: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Bell button
                          _NotificationBell(
                            onTap: () => context.push('/notifications'),
                            unreadCount: notifState.unreadCount,
                          ),
                        ],
                      ),
                    ),

                    0.0, 0.40),
                    // ── Big greeting ───────────────────────────────────────
                    _animated(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                          children: [
                            const TextSpan(text: 'Halo,\n'),
                            TextSpan(
                              text: firstName,
                              style: const TextStyle(
                                  color: AppColors.primaryDarkGreen),
                            ),
                            const TextSpan(text: ' 👋'),
                          ],
                        ),
                      ),
                    ),

                    0.1, 0.50),
                    // ── Stat cards ─────────────────────────────────────────
                    _animated(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Row(
                        children: [
                          // Left – Profile score (green)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: _ProfileScoreCard(
                                score: profileState.isLoading ? null : score,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Right – Verification status (white)
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

                    0.25, 0.65),
                    // ── Pengumuman Terbaru ─────────────────────────────────
                    _animated(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pengumuman Terbaru',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/news'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Lihat semua',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDarkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    0.40, 0.75),

                    // ── News list ──────────────────────────────────────
                    _animated(newsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDarkGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Gagal memuat berita.',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      data: (newsList) {
                        if (newsList.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Belum ada pengumuman.',
                                style: TextStyle(
                                  color: AppColors.textMedium,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }
                        final items = newsList.length > 5
                            ? newsList.sublist(0, 5)
                            : newsList;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          child: Column(
                            children: items.asMap().entries.map((e) {
                              return _NewsCard(
                                news: e.value,
                                iconBg: _newsIconBg[
                                    e.key % _newsIconBg.length],
                                iconFg: _newsIconFg[
                                    e.key % _newsIconFg.length],
                                icon: _newsIcons[
                                    e.key % _newsIcons.length],
                                relativeTime: _relativeTime(
                                    e.value.publishedAt ??
                                        e.value.createdAt),
                                onTap: () =>
                                    context.push('/news/${e.value.id}'),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ), 0.55, 0.88),
                  ],
                ),
              ),
            ),

            // ── Bottom nav ──────────────────────────────────────────────
            const BottomNavBar(currentRoute: '/home'),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Bell with red dot badge
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  final int unreadCount;
  const _NotificationBell({required this.onTap, this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                size: 22,
                color: Color(0xFF0F172A),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Visibility(
                visible: unreadCount > 0,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Score Card (green, left)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileScoreCard extends StatelessWidget {
  final int? score; // null = loading
  const _ProfileScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow circle
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
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
                        color: Colors.white.withOpacity(0.20),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    // "Lengkapi" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Profil',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                score == null
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '$score%',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                const SizedBox(height: 4),
                const Text(
                  'Kelengkapan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
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
// Status Card (white, right)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLoading;
  const _StatusCard(
      {required this.label, required this.color, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in colored circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(
                Icons.verified_user_outlined,
                color: color,
                size: 20,
              ),
            ),
            const Spacer(),
            isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: label.length > 9 ? 16 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 4),
            const Text(
              'Status Lamaran',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News Card (compact, icon + title + time + summary)
// ─────────────────────────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final News news;
  final Color iconBg;
  final Color iconFg;
  final IconData icon;
  final String relativeTime;
  final VoidCallback onTap;

  const _NewsCard({
    required this.news,
    required this.iconBg,
    required this.iconFg,
    required this.icon,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              child: Icon(icon, color: iconFg, size: 20),
            ),
            const SizedBox(width: 12),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeTime,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (news.summary != null && news.summary!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      news.summary!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
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
    );
  }
}
