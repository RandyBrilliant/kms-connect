import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../data/providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final authState = ref.watch(authStateProvider);
    final docsAsync = ref.watch(myDocumentsProvider);
    final user = authState.user;

    final fullName = user?.fullName?.isNotEmpty == true
        ? user!.fullName!
        : profileState.profile?.fullName?.isNotEmpty == true
            ? profileState.profile!.fullName!
            : user?.email ?? 'Pengguna';

    final score = profileState.profile?.score?.toInt() ?? 0;
    final statusLabel =
        profileState.profile?.verificationStatusDisplay ?? 'Draf';
    final statusColor =
        _statusColor(profileState.profile?.verificationStatus);
    final docCount = docsAsync.whenOrNull(data: (d) => d.length) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────────────────
            _animated(_buildAppBar(context), 0.0, 0.4),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkGreen,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (e, _) => _buildErrorState(context, ref),
                data: (profile) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    children: [
                      _animated(
                        _buildHero(context, fullName, statusLabel, statusColor,
                            score, docCount, profileState.isLoading),
                        0.08, 0.55,
                      ),
                      const SizedBox(height: 12),
                      _animated(
                        _buildDocumentsSection(context, docsAsync),
                        0.30, 0.72,
                      ),
                      const SizedBox(height: 12),
                      _animated(
                        _buildAccountSection(context, ref, profile),
                        0.50, 0.90,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const BottomNavBar(currentRoute: '/profile'),
          ],
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: const Text(
              'Profil Saya',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.settings_outlined,
            onTap: () => context.push('/profile/edit'),
          ),
        ],
      ),
    );
  }

  // ── Hero (avatar + name + 3 stat boxes) ──────────────────────────────────
  Widget _buildHero(
    BuildContext context,
    String fullName,
    String statusLabel,
    Color statusColor,
    int score,
    int docCount,
    bool isLoading,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          // Avatar with edit badge
          GestureDetector(
            onTap: () => context.push('/profile/edit'),
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryLightGreen,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 52,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          // Subtitle row: coloured dot + status + sep dot + "Pelamar"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.divider,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pelamar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3 stat boxes
          Row(
            children: [
              _StatBox(
                value: isLoading ? null : '$score%',
                label: 'Kelengkapan',
                valueColor: AppColors.primaryDarkGreen,
              ),
              const SizedBox(width: 10),
              _StatBox(
                value: isLoading ? null : statusLabel,
                label: 'Status',
                valueColor: statusColor,
                smallValue: true,
              ),
              const SizedBox(width: 10),
              _StatBox(
                value: '$docCount',
                label: 'Dokumen',
                valueColor: const Color(0xFF0F172A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dokumen Saya ─────────────────────────────────────────────────────────
  Widget _buildDocumentsSection(BuildContext context, AsyncValue docsAsync) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dokumen Saya',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/documents'),
                child: const Text(
                  'Ubah',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          docsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkGreen,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            error: (_, __) => _docEmptyState(context),
            data: (docs) {
              if (docs.isEmpty) return _docEmptyState(context);
              final items =
                  docs.length > 3 ? docs.sublist(0, 3) : docs;
              return Column(
                children: items
                    .map((d) => _DocumentTile(
                          doc: d,
                          onTap: () => context.push('/documents'),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _docEmptyState(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/documents'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.upload_file_outlined,
                size: 36, color: AppColors.textLight),
            const SizedBox(height: 8),
            const Text(
              'Belum ada dokumen. Unggah sekarang',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  // ── Account settings + logout ─────────────────────────────────────────────
  Widget _buildAccountSection(
      BuildContext context, WidgetRef ref, profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Akun',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Data Diri',
            onTap: () => context.push('/profile/edit'),
          ),

          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.work_outline_rounded,
            label: 'Pengalaman Kerja',
            onTap: () => context.push('/profile/work-experiences'),
          ),

          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.upload_file_rounded,
            label: 'Upload Dokumen',
            onTap: () => context.push('/documents'),
          ),

          if (profile.canSubmit) ...[
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.send_outlined,
              label: 'Kirim untuk Verifikasi',
              onTap: () => _handleSubmitForVerification(context, ref),
              accent: true,
            ),
          ],

          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifikasi',
            onTap: () => context.push('/notifications'),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context, ref),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat profil',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Periksa koneksi internet, lalu coba lagi.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.refresh(profileProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _statusColor(String? status) {
    switch (status) {
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      case 'SUBMITTED':
        return AppColors.warning;
      default:
        return AppColors.textLight;
    }
  }

  Future<void> _handleSubmitForVerification(
      BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.submitForVerification();
    if (context.mounted) {
      if (success) {
        CustomToast.show(context,
            message: 'Profil berhasil dikirim untuk verifikasi',
            type: ToastType.success);
        ref.refresh(profileProvider);
      } else {
        CustomToast.show(context,
            message: notifier.state.error ?? 'Gagal mengirim profil',
            type: ToastType.error);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatBox
// ─────────────────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String? value; // null → show spinner
  final String label;
  final Color valueColor;
  final bool smallValue;

  const _StatBox({
    required this.value,
    required this.label,
    required this.valueColor,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundOffWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            value == null
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: valueColor, strokeWidth: 2),
                  )
                : Text(
                    value!,
                    style: TextStyle(
                      fontSize: smallValue ? 12 : 18,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
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
// _DocumentTile
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentTile extends StatelessWidget {
  final dynamic doc;
  final VoidCallback onTap;

  const _DocumentTile({required this.doc, required this.onTap});

  String _relative(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return 'Diperbarui ${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return 'Diperbarui ${diff.inHours} jam lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final typeName = doc.documentType?.name ?? 'Dokumen';
    final dateStr = _relative(doc.updatedAt ?? doc.createdAt);
    final code =
        (doc.documentType?.code ?? '').toString().toLowerCase();

    final Color iconBg;
    final Color iconFg;
    final IconData iconData;

    if (code == 'ktp') {
      iconBg = const Color(0xFFFEE2E2);
      iconFg = const Color(0xFFDC2626);
      iconData = Icons.badge_outlined;
    } else if (code.contains('photo') || code.contains('foto')) {
      iconBg = const Color(0xFFF3E8FF);
      iconFg = const Color(0xFF7C3AED);
      iconData = Icons.photo_outlined;
    } else if (code.contains('passport') || code.contains('paspor')) {
      iconBg = const Color(0xFFE0F2FE);
      iconFg = const Color(0xFF0284C7);
      iconData = Icons.airplane_ticket_outlined;
    } else {
      iconBg = const Color(0xFFDBEAFE);
      iconFg = const Color(0xFF2563EB);
      iconData = Icons.description_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconFg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.more_vert_rounded,
                  color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsTile
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        accent ? AppColors.primaryDarkGreen : const Color(0xFF475569);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IconBtn
// ─────────────────────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundOffWhite,
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF0F172A)),
      ),
    );
  }
}
