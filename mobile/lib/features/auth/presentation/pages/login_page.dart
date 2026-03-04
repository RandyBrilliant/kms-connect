import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/google_logo_icon.dart';
import '../../../../core/widgets/m3_text_field.dart';
import '../../data/providers/auth_provider.dart';

/// M3-compliant login page with animated hero header and form panel.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  //  Form state
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // Email-not-verified banner state
  String? _unverifiedEmail;
  bool _resendLoading = false;

  //  Entrance animation
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _headerScale;
  late final Animation<double> _headerOpacity;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _panelSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    ));

    _panelOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _headerScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _unverifiedEmail = null);

    final success = await ref
        .read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      final authState = ref.read(authStateProvider);
      if (authState.errorCode == 'email_not_verified') {
        // Immediately navigate to verification page (it auto-sends the code).
        final email = _emailCtrl.text.trim();
        context.go('/email-verification?email=${Uri.encodeComponent(email)}');
      } else if (authState.error != null) {
        CustomToast.show(context, message: authState.error!, type: ToastType.error);
      }
    }
  }

  Future<void> _handleResendVerification() async {
    final email = _unverifiedEmail;
    if (email == null) return;
    setState(() => _resendLoading = true);
    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(email);
    if (!mounted) return;
    setState(() => _resendLoading = false);
    if (ok) {
      // Navigate to the verification code entry page
      context.push('/email-verification?email=${Uri.encodeComponent(email)}');
    } else {
      CustomToast.show(
        context,
        message: 'Gagal mengirim kode verifikasi. Silakan coba lagi.',
        type: ToastType.error,
      );
    }
  }

  void _handleGoogleLogin() async {
    final outcome =
        await ref.read(authStateProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    switch (outcome) {
      case GoogleAuthOutcomeError(:final message):
        CustomToast.show(context, message: message, type: ToastType.error);
      case GoogleAuthOutcomeCancelled():
        break; // user dismissed picker — nothing to do
      case GoogleAuthOutcomeSuccess() || GoogleAuthOutcomeNeedsCompletion():
        break; // router handles navigation via needsGoogleCompletion flag
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final headerHeight = math.max(size.height * 0.34, 240.0);

    return Scaffold(
      // Scaffold does NOT resize — we handle insets manually so the header
      // stays pinned and only the form panel scrolls up with the keyboard.
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative header — always stays at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: ScaleTransition(
                scale: _headerScale,
                alignment: Alignment.topCenter,
                child: AuthWaveHeader(height: headerHeight),
              ),
            ),
          ),

          // Scrollable content — shrinks naturally; keyboard inset added as
          // bottom padding so the last field is always reachable.
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: headerHeight * 0.22),
                  FadeTransition(
                    opacity: _headerOpacity,
                    child: ScaleTransition(
                      scale: _headerScale,
                      child: _HeaderContent(),
                    ),
                  ),
                  SlideTransition(
                    position: _panelSlide,
                    child: FadeTransition(
                      opacity: _panelOpacity,
                      child: _FormPanel(
                            formKey: _formKey,
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            emailFocus: _emailFocus,
                            passwordFocus: _passwordFocus,
                            obscurePassword: _obscurePassword,
                            isLoading: isLoading,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onLogin: _handleLogin,
                            onGoogleLogin: _handleGoogleLogin,                              unverifiedEmail: _unverifiedEmail,
                              isResendLoading: _resendLoading,
                              onResend: _handleResendVerification,                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

//  Header Content -----------------------------------------------------------

class _HeaderContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.eco_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'KMS Connect',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Platform Rekrutmen TKI',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

//  Form Panel ---------------------------------------------------------------

class _FormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;
  final VoidCallback onGoogleLogin;
  final String? unverifiedEmail;
  final bool isResendLoading;
  final Future<void> Function() onResend;

  const _FormPanel({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.unverifiedEmail,
    required this.isResendLoading,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(color: colorScheme.surface),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masuk',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan akun terdaftar Anda',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            // Email
            M3TextField(
              controller: emailCtrl,
              focusNode: emailFocus,
              nextFocusNode: passwordFocus,
              label: 'Email atau No. Telepon',
              hint: 'contoh@email.com',
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email atau nomor telepon wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            M3TextField(
              controller: passwordCtrl,
              focusNode: passwordFocus,
              label: 'Kata Sandi',
              hint: '',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onLogin(),
              suffixWidget: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onToggleObscure,
                tooltip: obscurePassword ? 'Tampilkan' : 'Sembunyikan',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/reset-password'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Lupa Kata Sandi?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Primary CTA
            FilledButton(
              onPressed: isLoading ? null : onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Masuk'),
            ),

            // Email-not-verified banner
            if (unverifiedEmail != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mail_outlined,
                            size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Text(
                          'Email belum diverifikasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Email $unverifiedEmail belum diverifikasi. Kirim kode verifikasi untuk melanjutkan.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isResendLoading ? null : onResend,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF92400E),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: isResendLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD97706)),
                              )
                            : const Text('Kirim Kode Verifikasi'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                      color: colorScheme.outlineVariant, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'ATAU',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                      color: colorScheme.outlineVariant, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Google button
            OutlinedButton.icon(
              onPressed: isLoading ? null : onGoogleLogin,
              icon: const GoogleLogoIcon(),
              label: Text(
                'Lanjutkan dengan Google',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                backgroundColor: colorScheme.surface,
                side: BorderSide(color: colorScheme.outlineVariant),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Register link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: Text(
                    'Daftar sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

