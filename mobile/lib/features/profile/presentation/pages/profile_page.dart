import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../../notifications/data/providers/notification_provider.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/applicant_profile.dart';

// 
// Page
// 

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileNotifierProvider.notifier).loadProfile();
      ref.read(workExperienceNotifierProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar',
          style: Theme.of(ctx)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah kamu yakin ingin keluar dari akun?',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final docsAsync = ref.watch(myDocumentsProvider);
    final notifState = ref.watch(notificationProvider);
    final workExpState = ref.watch(workExperienceNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    final profile = profileState.profile;
    final fullName = profile?.fullName?.isNotEmpty == true
        ? profile!.fullName!
        : authState.user?.fullName?.isNotEmpty == true
            ? authState.user!.fullName!
            : authState.user?.email ?? 'Pengguna';

    final score = profile?.score?.toInt() ?? 0;
    final docCount = docsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final expCount = workExpState.items.length;
    final headerH = math.max(size.height * 0.30, 220.0);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                //  Hero 
                SliverToBoxAdapter(
                  child: _animated(
                    _ProfileHero(
                      headerHeight: headerH,
                      fullName: fullName,
                      profile: profile,
                      score: score,
                      onEditTap: () => context.push('/profile/edit'),
                    ),
                    0.0,
                    0.45,
                  ),
                ),

                //  Quick stats 
                SliverToBoxAdapter(
                  child: _animated(
                    _QuickStatsRow(
                      docCount: docCount,
                      expCount: expCount,
                      unreadCount: notifState.unreadCount,
                    ),
                    0.15,
                    0.55,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                //  Profil menu 
                SliverToBoxAdapter(
                  child: _animated(
                    _MenuSection(
                      label: 'Profil Saya',
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          color: const Color(0xFF2563EB),
                          bg: const Color(0xFFDBEAFE),
                          title: 'Data Diri',
                          subtitle: 'Perbarui informasi pribadi',
                          onTap: () => context.push('/profile/edit'),
                        ),
                        _MenuItem(
                          icon: Icons.work_history_outlined,
                          color: const Color(0xFF7C3AED),
                          bg: const Color(0xFFEDE9FE),
                          title: 'Pengalaman Kerja',
                          subtitle: '$expCount riwayat pekerjaan',
                          onTap: () =>
                              context.push('/profile/work-experiences'),
                        ),
                      ],
                    ),
                    0.30,
                    0.68,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                //  Dokumen & notifikasi 
                SliverToBoxAdapter(
                  child: _animated(
                    _MenuSection(
                      label: 'Dokumen & Notifikasi',
                      items: [
                        _MenuItem(
                          icon: Icons.folder_open_outlined,
                          color: const Color(0xFFD97706),
                          bg: const Color(0xFFFEF3C7),
                          title: 'Dokumen Saya',
                          subtitle: '$docCount dokumen terunggah',
                          onTap: () => context.push('/documents'),
                        ),
                        _MenuItem(
                          icon: Icons.notifications_outlined,
                          color: AppColors.primaryDarkGreen,
                          bg: AppColors.secondaryLightGreen,
                          title: 'Notifikasi',
                          subtitle: notifState.unreadCount > 0
                              ? '${notifState.unreadCount} belum dibaca'
                              : 'Semua sudah dibaca',
                          badge: notifState.unreadCount > 0
                              ? '${notifState.unreadCount}'
                              : null,
                          onTap: () => context.push('/notifications'),
                        ),
                      ],
                    ),
                    0.45,
                    0.80,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                //  Akun 
                SliverToBoxAdapter(
                  child: _animated(
                    _MenuSection(
                      label: 'Akun',
                      items: [
                        _MenuItem(
                          icon: Icons.logout_rounded,
                          color: AppColors.error,
                          bg: const Color(0xFFFFE4E6),
                          title: 'Keluar',
                          subtitle: 'Masuk dengan akun lain',
                          onTap: _handleLogout,
                          isDestructive: true,
                        ),
                      ],
                    ),
                    0.55,
                    0.90,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
          const BottomNavBar(currentRoute: '/profile'),
        ],
      ),
    );
  }
}

// 
// _ProfileHero
// 

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.headerHeight,
    required this.fullName,
    required this.profile,
    required this.score,
    required this.onEditTap,
  });

  final double headerHeight;
  final String fullName;
  final ApplicantProfile? profile;
  final int score;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: headerHeight + topPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AuthWaveHeader(height: headerHeight + topPad),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profil Saya',
                      style: tt.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _CircleIconBtn(
                      icon: Icons.edit_outlined,
                      onTap: onEditTap,
                    ),
                  ],
                ),
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 4,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          score >= 80
                              ? Colors.greenAccent
                              : score >= 50
                                  ? Colors.amberAccent
                                  : Colors.white70,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fullName,
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _VerificationBadge(
                  status: profile?.verificationStatus ?? 'DRAFT',
                  label: profile?.verificationStatusDisplay ?? 'Draf',
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 
// _QuickStatsRow
// 

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.docCount,
    required this.expCount,
    required this.unreadCount,
  });

  final int docCount;
  final int expCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.folder_rounded,
            label: 'Dokumen',
            value: '$docCount',
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.work_history_rounded,
            label: 'Pengalaman',
            value: '$expCount',
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.notifications_rounded,
            label: 'Notif',
            value: '$unreadCount',
            highlight: unreadCount > 0,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final Color iconColor =
        highlight ? AppColors.primaryDarkGreen : cs.onSurfaceVariant;
    final Color bg = highlight
        ? AppColors.secondaryLightGreen
        : cs.surfaceContainerHighest;
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: highlight
                          ? AppColors.primaryDarkGreen
                          : cs.onSurface,
                    ),
                  ),
                  Text(
                    label,
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// 
// _MenuSection
// 

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.label, required this.items});

  final String label;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            color: cs.surface,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      color: cs.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? AppColors.error
                          : cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded,
                size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// 
// Shared small widgets
// 

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (Color bg, Color text, IconData icon) = switch (status) {
      'ACCEPTED' => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          Icons.verified_rounded,
        ),
      'SUBMITTED' => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.hourglass_top_rounded,
        ),
      'REJECTED' => (
          const Color(0xFFFFE4E6),
          const Color(0xFF9F1239),
          Icons.cancel_outlined,
        ),
      _ => (
          Colors.white.withValues(alpha: 0.18),
          Colors.white,
          Icons.edit_note_rounded,
        ),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
