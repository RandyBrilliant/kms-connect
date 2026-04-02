import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../config/colors.dart';
import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/professional_text_field.dart';
import '../../../../../core/widgets/professional_phone_field.dart';
import '../../../../../core/widgets/professional/professional_button.dart';
import '../../../data/providers/auth_provider.dart';
import '../../providers/registration_provider.dart';

/// Step 1 of 2 – Professional redesigned credentials input.
///
/// Uses ProfessionalTextField for consistent styling and enhanced UX.
/// Implements keyboard auto-scroll for better mobile experience.
class RegistrationStep1Credentials extends ConsumerStatefulWidget {
  const RegistrationStep1Credentials({super.key});

  @override
  ConsumerState<RegistrationStep1Credentials> createState() =>
      _RegistrationStep1CredentialsState();
}

class _RegistrationStep1CredentialsState
    extends ConsumerState<RegistrationStep1Credentials> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Restore data when returning from step 2
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(registrationProvider);
      if (s.email?.isNotEmpty == true) _emailCtrl.text = s.email!;
      if (s.phoneNumber?.isNotEmpty == true) _phoneCtrl.text = s.phoneNumber!;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;
    
    ref.read(registrationProvider.notifier).setCredentials(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          phoneNumber: _phoneCtrl.text.trim(),
        );
    ref.read(registrationProvider.notifier).nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 740;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          SizedBox(height: isCompact ? 12 : 20),
          Text(
            'Informasi Akun',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Langkah 1 dari 2 • Masukkan email dan kata sandi',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          SizedBox(height: isCompact ? 24 : 32),

          // Email field
          ProfessionalTextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            label: 'Email',
            hintText: 'contoh@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
              if (!v.contains('@')) return 'Format email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field
          ProfessionalTextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Kata Sandi',
            hintText: 'Minimal 8 karakter',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _confirmFocus.requestFocus(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textMedium,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              tooltip: _obscurePassword ? 'Tampilkan' : 'Sembunyikan',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password field
          ProfessionalTextField(
            controller: _confirmCtrl,
            focusNode: _confirmFocus,
            label: 'Konfirmasi Kata Sandi',
            hintText: 'Ulangi kata sandi',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _phoneFocus.requestFocus(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textMedium,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              tooltip: _obscureConfirm ? 'Tampilkan' : 'Sembunyikan',
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Kata sandi tidak cocok';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone number field
          ProfessionalPhoneField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            label: 'Nomor Telepon',
            hintText: '81234567890',
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: isCompact ? 24 : 32),

          // Next button
          ProfessionalButton(
            label: 'Selanjutnya',
            onPressed: _handleNext,
            icon: Icons.arrow_forward_rounded,
          ),
          SizedBox(height: isCompact ? 20 : 28),

          // Login link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun? ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                ),
              ),
              InkWell(
                onTap: () => context.go('/login'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Masuk',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkGreen,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryDarkGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
