import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../../../core/widgets/terms_privacy_modal.dart';
import '../../data/providers/auth_provider.dart';

/// Login page with two views managed entirely by local state:
///
///  [_LoginView.methods]  – three sign-in method buttons (Google / Apple / Email)
///  [_LoginView.email]    – email + password form with "Daftar Akun Baru"
///
/// Switching between views animates the card content with a horizontal slide.
/// No separate route is used — this avoids GoRouter redirect race conditions.
class LoginPageNew extends ConsumerStatefulWidget {
  const LoginPageNew({super.key});

  @override
  ConsumerState<LoginPageNew> createState() => _LoginPageNewState();
}

enum _LoginView { methods, email }

class _LoginPageNewState extends ConsumerState<LoginPageNew>
    with TickerProviderStateMixin {
  // ── View state ─────────────────────────────────────────────────────────────
  _LoginView _currentView = _LoginView.methods;

  // ── Email form ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // Nullable so hot reload (which keeps State but skips initState) cannot leave
  // new `late` fields uninitialized. [_ensureAnimationControllers] runs from
  // both initState and build to guarantee controllers exist.
  AnimationController? _entranceCtrl;
  Animation<Offset>? _cardSlide;
  Animation<double>? _cardOpacity;
  Animation<double>? _headerOpacity;

  AnimationController? _switchCtrl;
  Animation<Offset>? _slideIn;
  Animation<double>? _switchFade;

  void _ensureAnimationControllers() {
    // Hot reload can leave State alive with only *some* fields reset — never
    // bail out early just because [_entranceCtrl] exists; [_switchCtrl] may
    // still be null (the original LateInitializationError case).
    if (_entranceCtrl != null && _switchCtrl != null) return;

    if (_entranceCtrl == null) {
      _entranceCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _cardSlide =
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceCtrl!,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
        ),
      );
      _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceCtrl!,
          curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
        ),
      );
      _headerOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceCtrl!,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      );
    }

    if (_switchCtrl == null) {
      _switchCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      )..value = 1.0;
      _slideIn = Tween<Offset>(
        begin: const Offset(1.2, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _switchCtrl!, curve: Curves.easeOutCubic),
      );
      _switchFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _switchCtrl!,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureAnimationControllers();
    _entranceCtrl!.forward();
  }

  @override
  void dispose() {
    _entranceCtrl?.dispose();
    _switchCtrl?.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── View switching ─────────────────────────────────────────────────────────

  Future<void> _showEmailForm() async {
    _ensureAnimationControllers();
    FocusScope.of(context).unfocus();
    _switchCtrl!.value = 0; // position "in" content off to the right
    setState(() => _currentView = _LoginView.email);
    await _switchCtrl!.forward();
    // Focus email field once the card finishes animating in.
    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      _emailFocus.requestFocus();
    }
  }

  Future<void> _showMethodPicker() async {
    _ensureAnimationControllers();
    FocusScope.of(context).unfocus();
    _emailCtrl.clear();
    _passwordCtrl.clear();
    _switchCtrl!.value = 0;
    setState(() => _currentView = _LoginView.methods);
    await _switchCtrl!.forward();
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      _passwordCtrl.clear();
      final authState = ref.read(authStateProvider);
      if (authState.errorCode == 'email_not_verified') {
        final email = Uri.encodeComponent(_emailCtrl.text.trim());
        context.go('/email-verification?email=$email');
      } else if (authState.error != null) {
        CustomToast.show(context, message: authState.error!, type: ToastType.error);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final resp = await ref.read(authStateProvider.notifier).googleSignIn();
    if (!mounted) return;
    if (resp == null) {
      final error = ref.read(authStateProvider).error;
      if (error != null) {
        CustomToast.show(context, message: error, type: ToastType.error);
      }
      return;
    }
    context.go(resp.needsRegistration ? '/social-complete' : '/home');
  }

  Future<void> _handleAppleSignIn() async {
    final resp = await ref.read(authStateProvider.notifier).appleSignIn();
    if (!mounted) return;
    if (resp == null) {
      final error = ref.read(authStateProvider).error;
      if (error != null) {
        CustomToast.show(context, message: error, type: ToastType.error);
      }
      return;
    }
    context.go(resp.needsRegistration ? '/social-complete' : '/home');
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email harus diisi';
    final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!re.hasMatch(v.trim())) return 'Format email tidak valid';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password harus diisi';
    if (v.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _ensureAnimationControllers();
    final isLoading = ref.watch(authStateProvider).isLoading;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 56),

                    // ── Header ──────────────────────────────────────────────
                    FadeTransition(
                      opacity: _headerOpacity!,
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gradientStart,
                                        AppColors.gradientEnd,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.business_center_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Selamat Datang',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _currentView == _LoginView.methods
                                  ? 'Pilih metode untuk masuk ke KMS Connect'
                                  : 'Masukkan email dan password Anda',
                              key: ValueKey(_currentView),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Card ─────────────────────────────────────────────────
                    SlideTransition(
                      position: _cardSlide!,
                      child: FadeTransition(
                        opacity: _cardOpacity!,
                        child: ProfessionalCard(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            // ClipRect ensures content doesn't overflow
                            // during the horizontal slide animation.
                            child: ClipRect(
                              child: AnimatedBuilder(
                                animation: _switchCtrl!,
                                builder: (_, _) {
                                  // While the animation is playing, show a
                                  // crossfade-style slide between views.
                                  final settled = _switchCtrl!.value >= 1.0;
                                  if (settled) {
                                    return _currentView == _LoginView.methods
                                        ? _buildMethodPicker(isLoading)
                                        : _buildEmailForm(isLoading);
                                  }
                                  // Animating: show outgoing slide-out (or skip
                                  // for very short transitions).
                                  return FadeTransition(
                                    opacity: _switchFade!,
                                    child: SlideTransition(
                                      position: _slideIn!,
                                      child: _currentView == _LoginView.methods
                                          ? _buildMethodPicker(isLoading)
                                          : _buildEmailForm(isLoading),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Footer ───────────────────────────────────────────────
                    FadeTransition(
                      opacity: _cardOpacity!,
                      child: GestureDetector(
                        onTap: () => showTermsAndPrivacyModal(context),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            _footerText('Dengan masuk, Anda menyetujui', bold: false),
                            _footerText('Syarat & Ketentuan', bold: true, underline: true),
                            _footerText('dan', bold: false),
                            _footerText('Kebijakan Privasi', bold: true, underline: true),
                            _footerText('kami', bold: false),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeTransition(
                      opacity: _cardOpacity!,
                      child: Text(
                        '\u00a9 ${DateTime.now().year} PT. Karyatama Mitra Sejati',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Method picker view ────────────────────────────────────────────────────

  Widget _buildMethodPicker(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('methods'),
      children: [
        Text(
          'Masuk atau Daftar',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Pilih salah satu cara untuk melanjutkan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textMedium,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Google
        _AuthMethodButton(
          onPressed: isLoading ? null : _handleGoogleSignIn,
          label: 'Lanjutkan dengan Google',
          assetIcon: 'assets/images/google_logo.png',
          backgroundColor: Colors.white,
          textColor: AppColors.textDark,
          borderColor: AppColors.divider,
        ),

        // Apple (iOS only)
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          _AuthMethodButton(
            onPressed: isLoading ? null : _handleAppleSignIn,
            label: 'Lanjutkan dengan Apple',
            icon: Icons.apple_rounded,
            backgroundColor: Colors.black,
            textColor: Colors.white,
          ),
        ],

        const SizedBox(height: 12),

        // Divider
        _orDivider(),

        const SizedBox(height: 12),

        // Email — never disabled (not an auth operation, just a UI toggle)
        _AuthMethodButton(
          onPressed: _showEmailForm,
          label: 'Lanjutkan dengan Email',
          icon: Icons.email_outlined,
          backgroundColor: AppColors.primaryDarkGreen,
          textColor: Colors.white,
        ),
      ],
    );
  }

  // ── Email form view ───────────────────────────────────────────────────────

  Widget _buildEmailForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        key: const ValueKey('email'),
        children: [
          // Back button + title row
          Row(
            children: [
              InkWell(
                onTap: isLoading ? null : _showMethodPicker,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundOffWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Masuk dengan Email',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Email field
          ProfessionalTextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            label: 'Email',
            hintText: 'nama@contoh.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
            enabled: !isLoading,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),

          const SizedBox(height: 20),

          // Password field
          ProfessionalTextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Password',
            hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            enabled: !isLoading,
            onSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMedium,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const SizedBox(height: 12),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (ctx) => InkWell(
                onTap: isLoading ? null : () => GoRouter.of(ctx).push('/forgot-password'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Lupa Password?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLoading
                          ? AppColors.textMedium
                          : AppColors.primaryDarkGreen,
                      decoration: TextDecoration.underline,
                      decorationColor: isLoading
                          ? AppColors.textMedium
                          : AppColors.primaryDarkGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          ProfessionalButton(
            onPressed: isLoading ? null : _handleLogin,
            label: 'Masuk',
            isLoading: isLoading,
            icon: Icons.login_rounded,
          ),

          const SizedBox(height: 24),

          _orDivider(label: 'belum punya akun?'),

          const SizedBox(height: 20),

          ProfessionalOutlinedButton(
            onPressed: isLoading ? null : () => context.go('/register'),
            label: 'Daftar Akun Baru',
            icon: Icons.person_add_outlined,
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _orDivider({String label = 'atau'}) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _footerText(String text, {required bool bold, bool underline = false}) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: Colors.white.withValues(alpha: bold ? 1.0 : 0.7),
        decoration: underline ? TextDecoration.underline : null,
      ),
    );
  }
}

// ── Reusable sign-in method button ────────────────────────────────────────────

class _AuthMethodButton extends StatelessWidget {
  const _AuthMethodButton({
    required this.onPressed,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.assetIcon,
    this.icon,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final String? assetIcon;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor ?? backgroundColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetIcon != null)
              Image.asset(
                assetIcon!,
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.g_mobiledata_rounded, size: 24, color: textColor),
              )
            else if (icon != null)
              Icon(icon, size: 24, color: textColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
