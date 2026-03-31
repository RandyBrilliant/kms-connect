import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/update/app_update_service.dart';
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileNotifierProvider.notifier).loadProfile();
      AppUpdateService().checkAndRunPlayStoreUpdate();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB), // Light gray background
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
                  // ── Professional header ─────────────────────────────────
                  _animated(
                    _ProfessionalHeader(
                      displayName: displayName,
                      firstName: firstName,
                      unreadCount: notifState.unreadCount,
                      onNotificationTap: () =>
                          context.push('/notifications'),
                    ),
                    0.0, 0.40,
                  ),

                  const SizedBox(height: 20),

                  // ── Dashboard stats ───────────────────────────────────────
                  _animated(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Top stats row
                          Row(
                            children: [
                              Expanded(
                                child: _DashboardStatCard(
                                  title: 'Kelengkapan Profil',
                                  value: profileState.isLoading ? null : score,
                                  unit: '%',
                                  icon: Icons.person_outline_rounded,
                                  color: AppColors.primaryDarkGreen,
                                  onTap: () => context.push('/profile'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _DashboardStatCard(
                                  title: 'Status Lamaran',
                                  value: null,
                                  customLabel: statusLabel,
                                  icon: Icons.work_outline_rounded,
                                  color: statusColor,
                                  isLoading: profileState.isLoading,
                                  onTap: () => context.push('/profile'),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Quick actions row
                          _DashboardQuickActions(),
                        ],
                      ),
                    ),
                    0.20, 0.60,
                  ),

                  const SizedBox(height: 32),

                  // ── Professional news section ────────────────────────────────
                  _animated(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _ProfessionalSectionHeader(
                            title: 'Pengumuman Terbaru',
                            actionLabel: 'Lihat semua',
                            onAction: () => context.go('/news'),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _ProfessionalNewsList(
                            newsState: newsState,
                            onTap: (id) => context.push('/news/$id'),
                          ),
                        ],
                      ),
                    ),
                    0.35, 0.90,
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
// Professional Header — clean flat design with user info and notifications
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalHeader extends StatelessWidget {
  const _ProfessionalHeader({
    required this.displayName,
    required this.firstName,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  final String displayName;
  final String firstName;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting;
    IconData greetingIcon;
    if (hour < 12) {
      greeting = 'Selamat Pagi';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
      greetingIcon = Icons.wb_cloudy_outlined;
    } else {
      greeting = 'Selamat Malam';
      greetingIcon = Icons.nights_stay_outlined;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: User info + Notification
          Row(
            children: [
              // User Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDarkGreen,
                      AppColors.primaryDarkGreen.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDarkGreen.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          greetingIcon,
                          size: 16,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          greeting,
                          style: tt.bodyMedium?.copyWith(
                            color: AppColors.textMedium,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      style: tt.headlineSmall?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Notification Bell
              _ProfessionalNotificationBell(
                unreadCount: unreadCount,
                onTap: onNotificationTap,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Dashboard Title
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Dashboard Karir',
                style: tt.titleLarge?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Notification Bell
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNotificationBell extends StatelessWidget {
  const _ProfessionalNotificationBell({required this.onTap, this.unreadCount = 0});

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: AppColors.textMedium,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: unreadCount > 9 
                        ? const Icon(
                            Icons.add, 
                            size: 8, 
                            color: Colors.white,
                          )
                        : Center(
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Stat Card - Modern professional design
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    this.value,
    this.unit,
    this.customLabel,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  final String title;
  final int? value;
  final String? unit;
  final String? customLabel;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
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
              // Icon and title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Value
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 2.5,
                  ),
                )
              else if (customLabel != null)
                Text(
                  customLabel!,
                  style: tt.headlineSmall?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                )
              else
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${value ?? 0}',
                        style: tt.headlineLarge?.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      if (unit != null)
                        TextSpan(
                          text: unit!,
                          style: tt.titleLarge?.copyWith(
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Progress indicator for percentage
              if (value != null && unit == '%') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (value! / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
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
// Dashboard Quick Actions
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Aksi Cepat',
            style: tt.titleMedium?.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickActionButton(
                icon: Icons.work_outline_rounded,
                label: 'Lowongan',
                color: const Color(0xFF3B82F6),
                onTap: () => context.go('/jobs'),
              ),
              _QuickActionButton(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                color: AppColors.primaryDarkGreen,
                onTap: () => context.push('/profile'),
              ),
              _QuickActionButton(
                icon: Icons.description_outlined,
                label: 'Lamaran',
                color: const Color(0xFFF59E0B),
                onTap: () => context.push('/jobs/my-applications'),
              ),
              _QuickActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.go('/chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                label,
                style: tt.bodySmall?.copyWith(
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
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
// Professional Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalSectionHeader extends StatelessWidget {
  const _ProfessionalSectionHeader({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        color: AppColors.primaryDarkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primaryDarkGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional News List - Modern design with improved typography
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNewsList extends StatelessWidget {
  const _ProfessionalNewsList({
    required this.newsState,
    required this.onTap,
  });

  final PaginatedState<News> newsState;
  final void Function(int id) onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // Loading state
    if (newsState.isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryDarkGreen,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Error state
    if (newsState.error != null && newsState.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat pengumuman',
              style: tt.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba lagi nanti',
              style: tt.bodyMedium?.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (newsState.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada pengumuman',
              style: tt.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pengumuman akan tampil di sini',
              style: tt.bodyMedium?.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    final list = newsState.items;
    final items = list.length > 5 ? list.sublist(0, 5) : list;
    
    return Container(
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
        children: [
          for (var i = 0; i < items.length; i++)
            _ProfessionalNewsCard(
              news: items[i],
              isLast: i == items.length - 1,
              onTap: () => onTap(items[i].id),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional News Card - Clean modern design
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNewsCard extends StatelessWidget {
  const _ProfessionalNewsCard({
    required this.news,
    required this.isLast,
    required this.onTap,
  });

  final News news;
  final bool isLast;
  final VoidCallback onTap;

  static String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: !isLast ? Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.2),
                width: 1,
              ),
            ) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkGreen,
                  shape: BoxShape.circle,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            news.title,
                            style: tt.bodyLarge?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _relativeTime(news.publishedAt ?? news.createdAt),
                            style: tt.labelSmall?.copyWith(
                              color: AppColors.primaryDarkGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Summary if available
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        news.summary!,
                        style: tt.bodyMedium?.copyWith(
                          color: AppColors.textMedium,
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
