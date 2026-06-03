import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../../notifications/data/providers/notification_provider.dart';
import '../../../notifications/data/providers/notification_settings_provider.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/models/applicant_profile.dart';

const bool _hideGoogleSignInTemporarily = true;

/// Professional profile page with modern Material Design 3 styling
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
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin keluar dari akun?',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _openBuktiPenyerahanUpload() async {
    try {
      final types = await ref.read(documentTypesProvider.future);
      if (!mounted) return;
      final match = types
          .where((t) => t.code == 'bukti-penyerahan-dokumen')
          .firstOrNull;
      if (match != null) {
        context.push('/documents/upload?type=${match.id}');
      } else {
        context.push('/documents');
      }
    } catch (_) {
      if (!mounted) return;
      context.push('/documents');
    }
  }

  Future<void> _handleViewBiodataPdf() async {
    final ok = await ref.read(biodataPdfProvider.notifier).open();
    if (!ok && mounted) {
      final err = ref.read(biodataPdfProvider).error ?? 'Gagal membuka PDF.';
      CustomToast.show(
        context,
        message: err,
        type: ToastType.error,
      );
    }
  }

  Future<void> _handleViewPsychologyReferralPdf() async {
    final ok = await ref.read(psychologyReferralPdfProvider.notifier).open();
    if (!ok && mounted) {
      final err =
          ref.read(psychologyReferralPdfProvider).error ?? 'Gagal membuka PDF.';
      CustomToast.show(
        context,
        message: err,
        type: ToastType.error,
      );
    }
  }

  Future<void> _handleViewMedicalReferralPdf() async {
    final ok = await ref.read(medicalReferralPdfProvider.notifier).open();
    if (!ok && mounted) {
      final err =
          ref.read(medicalReferralPdfProvider).error ?? 'Gagal membuka PDF.';
      CustomToast.show(
        context,
        message: err,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final docsAsync = ref.watch(myDocumentsProvider);
    final notifState = ref.watch(notificationProvider);
    final workExpState = ref.watch(workExperienceNotifierProvider);
    final pdfState = ref.watch(biodataPdfProvider);
    final psychPdfState = ref.watch(psychologyReferralPdfProvider);
    final medicalPdfState = ref.watch(medicalReferralPdfProvider);

    final profile = profileState.profile;
    final fullName = profile?.fullName?.isNotEmpty == true
        ? profile!.fullName!
        : authState.user?.fullName?.isNotEmpty == true
            ? authState.user!.fullName!
            : authState.user?.email ?? 'Pengguna';

    final score = profile?.score?.toInt() ?? 0;
    final docCount = docsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final expCount = workExpState.items.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          // Professional Header
          _animated(
            _ProfessionalProfileHeader(
              fullName: fullName,
              profile: profile,
              score: score,
              onEditTap: () => context.push('/profile/edit'),
            ),
            0.0,
            0.40,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Quick Stats
                  _animated(
                    _ProfessionalQuickStats(
                      docCount: docCount,
                      expCount: expCount,
                      unreadCount: notifState.unreadCount,
                    ),
                    0.15,
                    0.55,
                  ),

                  if (profile?.inboundTransportStageCosts != null &&
                      profile!.inboundTransportStageCosts!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _animated(
                      _InboundTransportCostsCard(
                        rows: profile.inboundTransportStageCosts!,
                      ),
                      0.22,
                      0.60,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Profile Menu
                  _animated(
                    _ProfessionalMenuSection(
                      title: 'Profil Saya',
                      items: [
                        _ProfessionalMenuItem(
                          icon: Icons.person_outline_rounded,
                          color: AppColors.primaryDarkGreen,
                          title: 'Data Diri',
                          subtitle: 'Perbarui informasi pribadi',
                          onTap: () => context.push('/profile/edit'),
                        ),
                        _ProfessionalMenuItem(
                          icon: Icons.work_history_outlined,
                          color: const Color(0xFF8B5CF6),
                          title: 'Pengalaman Kerja',
                          subtitle: '$expCount riwayat pekerjaan',
                          onTap: () => context.push('/profile/work-experiences'),
                        ),
                      ],
                    ),
                    0.30,
                    0.68,
                  ),

                  const SizedBox(height: 20),

                  // Documents & Notifications
                  _animated(
                    _ProfessionalMenuSection(
                      title: 'Dokumen & Notifikasi',
                      items: [
                        _ProfessionalMenuItem(
                          icon: Icons.folder_open_outlined,
                          color: const Color(0xFFF59E0B),
                          title: 'Dokumen Saya',
                          subtitle: '$docCount dokumen terunggah',
                          onTap: () => context.push('/documents'),
                        ),
                        _ProfessionalMenuItem(
                          icon: Icons.notifications_outlined,
                          color: const Color(0xFF3B82F6),
                          title: 'Notifikasi',
                          subtitle: notifState.unreadCount > 0
                              ? '${notifState.unreadCount} belum dibaca'
                              : 'Semua sudah dibaca',
                          badge: notifState.unreadCount > 0
                              ? '${notifState.unreadCount}'
                              : null,
                          onTap: () => context.push('/notifications'),
                        ),
                        _ProfessionalNotificationToggle(),
                      ],
                    ),
                    0.45,
                    0.80,
                  ),

                  const SizedBox(height: 20),

                  // PDF Biodata (+ pengantar psikologi jika lamaran DITERIMA)
                  _animated(
                    _ProfessionalMenuSection(
                      title: 'Dokumen Saya',
                      items: [
                        _ProfessionalMenuItem(
                          icon: Icons.picture_as_pdf_outlined,
                          color: AppColors.error,
                          title: 'Biodata PDF',
                          subtitle: 'Lihat biodata dalam format PDF',
                          onTap: _handleViewBiodataPdf,
                          isLoading: pdfState.isLoading,
                        ),
                        if (profile?.hasInterviewLamaran == true)
                          _ProfessionalMenuItem(
                            icon: Icons.assignment_outlined,
                            color: const Color(0xFF2563EB),
                            title: 'Bukti Penyerahan Dokumen',
                            subtitle:
                                'Unduh template, lengkapi, lalu unggah PDF',
                            onTap: _openBuktiPenyerahanUpload,
                          ),
                        if (profile?.hasDiterimaLamaran == true)
                          _ProfessionalMenuItem(
                            icon: Icons.psychology_outlined,
                            color: const Color(0xFF0D9488),
                            title: 'Surat pengantar tes psikologi',
                            subtitle: 'PDF untuk klinik (tahap Diterima)',
                            onTap: _handleViewPsychologyReferralPdf,
                            isLoading: psychPdfState.isLoading,
                          ),
                        if (profile?.hasDiterimaLamaran == true)
                          _ProfessionalMenuItem(
                            icon: Icons.medical_services_outlined,
                            color: const Color(0xFFDC2626),
                            title: 'Surat pengantar medical',
                            subtitle: 'PDF medical check up (tahap Diterima)',
                            onTap: _handleViewMedicalReferralPdf,
                            isLoading: medicalPdfState.isLoading,
                          ),
                      ],
                    ),
                    0.50,
                    0.78,
                  ),

                  const SizedBox(height: 20),

                  // Linked Accounts (hidden on Android while Google sign-in is disabled)
                  if (Platform.isIOS || !_hideGoogleSignInTemporarily) ...[
                  // Linked Accounts
                  _animated(
                    _LinkedAccountsSection(
                      hasGoogle: authState.user?.hasGoogle ?? false,
                      hasApple: authState.user?.hasApple ?? false,
                    ),
                    0.55,
                    0.88,
                  ),

                  const SizedBox(height: 20),
                  ],

                  // Account
                  _animated(
                    _ProfessionalMenuSection(
                      title: 'Akun',
                      items: [
                        if (!(authState.user?.hasGoogle == true && authState.user?.hasApple == false && authState.user?.hasPassword == false) &&
                            !(authState.user?.hasApple == true && authState.user?.hasGoogle == false && authState.user?.hasPassword == false))
                          _ProfessionalMenuItem(
                            icon: Icons.lock_outline_rounded,
                            color: const Color(0xFF0891B2),
                            title: 'Ganti Password',
                            subtitle: 'Ubah password akun kamu',
                            onTap: () => context.push('/profile/change-password'),
                          ),
                        _ProfessionalMenuItem(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          title: 'Hapus Akun',
                          subtitle: 'Ajukan permintaan penghapusan akun',
                          onTap: () => context.push('/profile/account-deletion'),
                          isDestructive: true,
                        ),
                        _ProfessionalMenuItem(
                          icon: Icons.logout_rounded,
                          color: AppColors.error,
                          title: 'Keluar',
                          subtitle: 'Masuk dengan akun lain',
                          onTap: _handleLogout,
                          isDestructive: true,
                        ),
                      ],
                    ),
                    0.60,
                    0.95,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Navigation
          const BottomNavBar(currentRoute: '/profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Profile Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalProfileHeader extends StatelessWidget {
  const _ProfessionalProfileHeader({
    required this.fullName,
    required this.profile,
    required this.score,
    required this.onEditTap,
  });

  final String fullName;
  final ApplicantProfile? profile;
  final int score;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Title
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
                'Profil Saya',
                style: tt.headlineSmall?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDarkGreen,
                  AppColors.primaryDarkGreen.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDarkGreen.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getVerificationStatusDisplay(profile?.verificationStatus),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.percent_outlined,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Kelengkapan: $score%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEditTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
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

  String _getVerificationStatusDisplay(String? status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Terverifikasi';
      case 'SUBMITTED':
      case 'PENDING':
        return 'Menunggu Verifikasi';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'Belum Lengkap';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Quick Stats
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalQuickStats extends StatelessWidget {
  const _ProfessionalQuickStats({
    required this.docCount,
    required this.expCount,
    required this.unreadCount,
  });

  final int docCount;
  final int expCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.folder_outlined,
            color: const Color(0xFFF59E0B),
            value: docCount.toString(),
            label: 'Dokumen',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.work_history_outlined,
            color: const Color(0xFF8B5CF6),
            value: expCount.toString(),
            label: 'Pengalaman',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.notifications_outlined,
            color: const Color(0xFF3B82F6),
            value: unreadCount.toString(),
            label: 'Notifikasi',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Menu Section
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalMenuSection extends StatelessWidget {
  const _ProfessionalMenuSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: tt.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Items
        Container(
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Divider(
                    color: AppColors.divider.withValues(alpha: 0.2),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Menu Item
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalMenuItem extends StatelessWidget {
  const _ProfessionalMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool isDestructive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDestructive
                                  ? AppColors.error
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Trailing
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked Accounts Section
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedAccountsSection extends ConsumerWidget {
  const _LinkedAccountsSection({
    required this.hasGoogle,
    required this.hasApple,
  });

  final bool hasGoogle;
  final bool hasApple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Akun Terhubung',
              style: tt.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!_hideGoogleSignInTemporarily)
                _LinkedAccountTile(
                  provider: 'Google',
                  icon: Icons.g_mobiledata_rounded,
                  iconColor: const Color(0xFFDB4437),
                  isLinked: hasGoogle,
                  isLoading: isLoading,
                  onLink: () async {
                    final ok = await ref.read(authStateProvider.notifier).linkGoogle();
                    if (!context.mounted) return;
                    if (ok) {
                      CustomToast.show(context, message: 'Akun Google berhasil dihubungkan', type: ToastType.success);
                    } else {
                      final err = ref.read(authStateProvider).error;
                      if (err != null) CustomToast.show(context, message: err, type: ToastType.error);
                    }
                  },
                ),
              if (Platform.isIOS) ...[
                if (!_hideGoogleSignInTemporarily)
                Divider(color: AppColors.divider.withValues(alpha: 0.2), height: 1, indent: 20, endIndent: 20),
                _LinkedAccountTile(
                  provider: 'Apple',
                  icon: Icons.apple_rounded,
                  iconColor: Colors.black,
                  isLinked: hasApple,
                  isLoading: isLoading,
                  onLink: () async {
                    final ok = await ref.read(authStateProvider.notifier).linkApple();
                    if (!context.mounted) return;
                    if (ok) {
                      CustomToast.show(context, message: 'Akun Apple berhasil dihubungkan', type: ToastType.success);
                    } else {
                      final err = ref.read(authStateProvider).error;
                      if (err != null) CustomToast.show(context, message: err, type: ToastType.error);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkedAccountTile extends StatelessWidget {
  const _LinkedAccountTile({
    required this.provider,
    required this.icon,
    required this.iconColor,
    required this.isLinked,
    required this.isLoading,
    required this.onLink,
  });

  final String provider;
  final IconData icon;
  final Color iconColor;
  final bool isLinked;
  final bool isLoading;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLinked || isLoading ? null : onLink,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLinked ? 'Terhubung' : 'Belum terhubung',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isLinked
                            ? AppColors.primaryDarkGreen
                            : AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLinked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryDarkGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Aktif',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hubungkan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
// Professional Notification Toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNotificationToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifSettingsState = ref.watch(notificationSettingsProvider);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primaryDarkGreen,
                size: 22,
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Notification',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Terima notifikasi lowongan dan update',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Toggle Switch
            Switch(
              value: notifSettingsState.isEnabled,
              onChanged: (v) async {
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .toggle();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InboundTransportCostsCard extends StatelessWidget {
  const _InboundTransportCostsCard({required this.rows});

  final List<InboundTransportStageCostRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biaya transport (ringkas)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rincian per tahapan seleksi (inbound cost).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((r) {
            final parts = <String>[];
            if (r.amount != null) {
              parts.add('Rp ${r.amount!.toStringAsFixed(0)}');
            }
            if (r.tanggalProses?.isNotEmpty == true) {
              parts.add(r.tanggalProses!);
            }
            final sub = parts.join(' · ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      r.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      [
                        if (sub.isNotEmpty) sub,
                        if (r.keterangan.isNotEmpty) r.keterangan,
                      ].join(' — '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}