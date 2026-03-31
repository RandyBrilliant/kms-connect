import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../../../core/widgets/terms_privacy_modal.dart';
import '../../data/providers/auth_provider.dart';

/// Redesigned professional login page.
class LoginPageNew extends ConsumerStatefulWidget {
  const LoginPageNew({super.key});

  @override
  ConsumerState<LoginPageNew> createState() => _LoginPageNewState();
}

class _LoginPageNewState extends ConsumerState<LoginPageNew> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (ok) {
      context.go('/home');
      return;
    }
    _passwordCtrl.clear();

    final auth = ref.read(authStateProvider);
    if (auth.errorCode == 'email_not_verified') {
      final email = Uri.encodeComponent(_emailCtrl.text.trim());
      context.go('/email-verification?email=$email');
      return;
    }
    if (auth.error != null && auth.error!.isNotEmpty) {
      CustomToast.show(context, message: auth.error!, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final muted = Colors.white.withValues(alpha: 0.72);
    final year = DateTime.now().year;
    const footerSpace = 96.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ProfessionalGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + footerSpace,
                  ),
                  child: Column(
                    children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.business_center_rounded,
                                size: 44,
                                color: Color(0xFF0B7A43),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Selamat Datang',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masuk ke akun KMS Connect',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ProfessionalCard(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                            ProfessionalTextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              label: 'Email',
                              hintText: 'contoh@email.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              upperCase: false,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            ProfessionalTextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              label: 'Kata Sandi',
                              hintText: 'Masukkan kata sandi',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              upperCase: false,
                              onSubmitted: (_) => _handleLogin(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Kata sandi wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  final email = _emailCtrl.text.trim();
                                  final route = email.contains('@')
                                      ? '/forgot-password?email=${Uri.encodeComponent(email)}'
                                      : '/forgot-password';
                                  context.push(route);
                                },
                                child: const Text('Lupa Kata Sandi?'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ProfessionalButton(
                              label: 'Masuk',
                              icon: Icons.login_rounded,
                              onPressed: isLoading ? null : _handleLogin,
                              isLoading: isLoading,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    height: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'ATAU',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF8A948E),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/register'),
                                icon: const Icon(Icons.app_registration_rounded, size: 18),
                                label: const Text('Daftar Sekarang'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0B7A43),
                                  backgroundColor: const Color(0x140B7A43),
                                  side: const BorderSide(
                                    color: Color(0xFF0B7A43),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Dengan mendaftar, Anda menyetujui ',
                        children: [
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: muted,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => showTermsAndPrivacyModal(context),
                          ),
                          const TextSpan(text: ' dan '),
                          TextSpan(
                            text: 'Kebijakan Privasi',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: muted,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => showTermsAndPrivacyModal(context),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '© $year PT. Karyatama Mitra Sejati',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
