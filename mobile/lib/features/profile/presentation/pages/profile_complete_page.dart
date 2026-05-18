import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/profile_completion.dart';

String _sectionTitle(ProfileSetupSection s) {
  switch (s) {
    case ProfileSetupSection.personal:
      return 'Data Pribadi';
    case ProfileSetupSection.educationPhysical:
      return 'Pendidikan & Fisik';
    case ProfileSetupSection.addressKtp:
      return 'Alamat KTP';
    case ProfileSetupSection.documents:
      return 'Data Dokumen';
    case ProfileSetupSection.passport:
      return 'Data Paspor';
    case ProfileSetupSection.family:
      return 'Data Keluarga';
    case ProfileSetupSection.spouse:
      return 'Data Pasangan';
    case ProfileSetupSection.heir:
      return 'Ahli Waris';
  }
}

IconData _sectionIcon(ProfileSetupSection s) {
  switch (s) {
    case ProfileSetupSection.personal:
      return Icons.person_outline_rounded;
    case ProfileSetupSection.educationPhysical:
      return Icons.school_outlined;
    case ProfileSetupSection.addressKtp:
      return Icons.home_outlined;
    case ProfileSetupSection.documents:
      return Icons.folder_outlined;
    case ProfileSetupSection.passport:
      return Icons.flight_outlined;
    case ProfileSetupSection.family:
      return Icons.family_restroom_outlined;
    case ProfileSetupSection.spouse:
      return Icons.favorite_outline_rounded;
    case ProfileSetupSection.heir:
      return Icons.support_agent_outlined;
  }
}

/// Full-screen onboarding checklist when biodata is still incomplete (draft).
class ProfileCompletePage extends ConsumerStatefulWidget {
  const ProfileCompletePage({super.key});

  @override
  ConsumerState<ProfileCompletePage> createState() =>
      _ProfileCompletePageState();
}

class _ProfileCompletePageState extends ConsumerState<ProfileCompletePage> {
  bool _isSendingVerification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileNotifierProvider.notifier).loadProfile(force: true);
    });
  }

  Future<void> _proceedToEmailVerification() async {
    final email = ref.read(authStateProvider).user?.email;
    if (email == null) return;

    setState(() => _isSendingVerification = true);
    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(email);
    if (!mounted) return;
    setState(() => _isSendingVerification = false);

    if (!ok) {
      CustomToast.show(
        context,
        message: 'Gagal mengirim kode verifikasi. Silakan coba lagi.',
        type: ToastType.error,
      );
      return;
    }

    CustomToast.show(
      context,
      message: 'Kode verifikasi telah dikirim ke email Anda.',
      type: ToastType.success,
    );
    context.go('/email-verification?email=${Uri.encodeComponent(email)}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profileState = ref.watch(profileNotifierProvider);
    final authUser = ref.watch(authStateProvider).user;

    ref.listen<ProfileState>(profileNotifierProvider, (prev, next) {
      final p = next.profile;
      if (p == null) return;
      if (shouldBlockForIncompleteProfile(p)) return;
      if (!mounted) return;
      final verified = ref.read(authStateProvider).user?.emailVerified ?? false;
      if (verified) {
        context.go('/home');
      }
    });

    final profile = profileState.profile;
    final report =
        profile != null ? evaluateProfileCompletion(profile) : null;
    final profileComplete = report?.isFullyComplete ?? false;
    final needsEmailVerification = authUser != null && !authUser.emailVerified;

    return Scaffold(
      body: ProfessionalGradientBackground(
        child: SafeArea(
          child: profileState.isLoading && profile == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileComplete && needsEmailVerification
                                ? 'Profil lengkap'
                                : 'Lengkapi profil Anda',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profileComplete && needsEmailVerification
                                ? 'Biodata sudah lengkap. Lanjutkan ke verifikasi email untuk mengaktifkan akun.'
                                : 'Isi seluruh bagian biodata di halaman edit profil. '
                                    'Progress di bawah membantu melihat bagian yang masih kurang.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.45,
                            ),
                          ),
                          if (report != null) ...[
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: report.fraction.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                color: AppColors.secondaryLightGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${report.completedCount} dari ${report.totalCount} bagian selesai',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: report == null
                          ? const SizedBox.shrink()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              itemCount: report.sections.length,
                              itemBuilder: (context, index) {
                                final entry =
                                    report.sections.entries.elementAt(index);
                                final section = entry.key;
                                final done = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: done
                                            ? cs.primaryContainer
                                            : cs.surfaceContainerHighest,
                                        child: Icon(
                                          _sectionIcon(section),
                                          color: done
                                              ? cs.onPrimaryContainer
                                              : cs.onSurfaceVariant,
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(
                                        _sectionTitle(section),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      trailing: Icon(
                                        done
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked,
                                        color: done
                                            ? AppColors.primaryDarkGreen
                                            : AppColors.textMedium,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!profileComplete)
                            ProfessionalButton(
                              label: 'Buka edit profil',
                              icon: Icons.edit_note_rounded,
                              onPressed: () async {
                                await context.push('/profile/edit');
                                if (!mounted) return;
                                await ref
                                    .read(profileNotifierProvider.notifier)
                                    .loadProfile(force: true);
                              },
                            ),
                          if (profileComplete && needsEmailVerification) ...[
                            ProfessionalButton(
                              label: 'Lanjut ke verifikasi email',
                              icon: Icons.mark_email_read_outlined,
                              isLoading: _isSendingVerification,
                              onPressed: _isSendingVerification
                                  ? null
                                  : _proceedToEmailVerification,
                            ),
                            const SizedBox(height: 12),
                            ProfessionalOutlinedButton(
                              label: 'Periksa profil',
                              icon: Icons.edit_note_rounded,
                              onPressed: () async {
                                await context.push('/profile/edit');
                                if (!mounted) return;
                                await ref
                                    .read(profileNotifierProvider.notifier)
                                    .loadProfile(force: true);
                              },
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
