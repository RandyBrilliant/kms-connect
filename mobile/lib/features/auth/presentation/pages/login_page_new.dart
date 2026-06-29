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

/// Professional login page for job listing platform
/// Features modern card design with email/password authentication
class LoginPageNew extends ConsumerStatefulWidget {
  const LoginPageNew({super.key});

  @override
  ConsumerState<LoginPageNew> createState() => _LoginPageNewState();
}

class _LoginPageNewState extends ConsumerState<LoginPageNew>
    with SingleTickerProviderStateMixin {
  // Form state
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // Animation
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _headerOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _entranceCtrl.forward();
  }

  void _setupAnimations() {
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardSlide = Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
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

    final success = await ref
        .read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      // Clear password for security purposes on login failure
      _passwordCtrl.clear();
      
      final authState = ref.read(authStateProvider);
      if (authState.errorCode == 'email_not_verified') {
        final email = _emailCtrl.text.trim();
        context.go('/email-verification?email=${Uri.encodeComponent(email)}');
      } else if (authState.error != null) {
        CustomToast.show(
          context,
          message: authState.error!,
          type: ToastType.error,
        );
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email harus diisi';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password harus diisi';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 60),

                    // Header with logo and title
                    FadeTransition(
                      opacity: _headerOpacity,
                      child: Column(
                        children: [
                          // Logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
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
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
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
                          Text(
                            'Masuk untuk melanjutkan ke KMS Connect',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Login form card
                    SlideTransition(
                      position: _cardSlide,
                      child: FadeTransition(
                        opacity: _cardOpacity,
                        child: ProfessionalCard(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                  onSubmitted: (_) =>
                                      _passwordFocus.requestFocus(),
                                ),

                                const SizedBox(height: 20),

                                // Password field
                                ProfessionalTextField(
                                  controller: _passwordCtrl,
                                  focusNode: _passwordFocus,
                                  label: 'Password',
                                  hintText: '••••••••',
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
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Builder(
                                    builder: (btnContext) => InkWell(
                                      onTap: isLoading
                                          ? null
                                          : () {
                                              GoRouter.of(btnContext).push('/forgot-password');
                                            },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
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

                                // Login button
                                ProfessionalButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  label: 'Masuk',
                                  isLoading: isLoading,
                                  icon: Icons.login_rounded,
                                ),

                                const SizedBox(height: 20),

                                // Divider
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'atau',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Register button
                                ProfessionalOutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.push('/register'),
                                  label: 'Daftar Akun Baru',
                                  icon: Icons.person_add_outlined,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms and Privacy links
                    FadeTransition(
                      opacity: _cardOpacity,
                      child: GestureDetector(
                        onTap: () => showTermsAndPrivacyModal(context),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              'Dengan masuk, Anda menyetujui',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              'Syarat & Ketentuan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            Text(
                              'dan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              'Kebijakan Privasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            Text(
                              'kami',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Copyright
                    FadeTransition(
                      opacity: _cardOpacity,
                      child: Text(
                        '© ${DateTime.now().year} PT. Karyatama Mitra Sejati',
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
}
