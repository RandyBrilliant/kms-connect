import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/google_logo_icon.dart';
import '../../../../../core/widgets/m3_text_field.dart';
import '../../providers/registration_provider.dart';

/// Step 1 of 2  email, password, confirm password, optional referral code.
///
/// Intentionally contains no header / step-indicator (the parent
/// [RegistrationPageNew] owns that).  Only the form and CTAs live here.
///
/// Performance note: text fields use [M3TextField] which derives all
/// [TextStyle]s from the ambient [Theme], avoiding per-keystroke
/// [TextStyle] allocations.
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
  final _referralCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _referralFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Restore email & referral when returning from step 2 (passwords are
    // intentionally left blank for security).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(registrationProvider);
      if (s.email?.isNotEmpty == true) _emailCtrl.text = s.email!;
      if (s.referralCode?.isNotEmpty == true) _referralCtrl.text = s.referralCode!;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _referralFocus.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(registrationProvider.notifier).setCredentials(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          referralCode: _referralCtrl.text.trim(),
        );
    ref.read(registrationProvider.notifier).nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          //  Section label 
          const SizedBox(height: 20),
          Text(
            'Informasi Akun',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Langkah 1 dari 2  Masukkan email dan kata sandi',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          //  Email 
          M3TextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            nextFocusNode: _passwordFocus,
            label: 'Email',
            hint: 'contoh@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
              if (!v.contains('@')) return 'Format email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Password 
          M3TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            nextFocusNode: _confirmFocus,
            label: 'Kata Sandi',
            hint: 'Minimal 8 karakter',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixWidget: _VisibilityToggle(
              obscure: _obscurePassword,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Confirm password 
          M3TextField(
            controller: _confirmCtrl,
            focusNode: _confirmFocus,
            nextFocusNode: _referralFocus,
            label: 'Konfirmasi Kata Sandi',
            hint: 'Ulangi kata sandi',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.next,
            suffixWidget: _VisibilityToggle(
              obscure: _obscureConfirm,
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Kata sandi tidak cocok';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Referral code (optional) 
          M3TextField(
            controller: _referralCtrl,
            focusNode: _referralFocus,
            label: 'Kode Rujukan (Opsional)',
            hint: 'Contoh: S-ABC123',
            prefixIcon: Icons.qr_code_outlined,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleNext(),
            validator: (v) {
              if (v != null && v.isNotEmpty && v.trim().length < 5) {
                return 'Kode rujukan tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          //  Next button 
          FilledButton(
            onPressed: _handleNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Selanjutnya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 28),

          //  OR divider 
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ATAU',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          const SizedBox(height: 20),

          //  Google sign-up 
          OutlinedButton.icon(
            onPressed: () => CustomToast.show(
              context,
              message: 'Google Sign-In akan segera tersedia',
              type: ToastType.info,
            ),
            icon: const GoogleLogoIcon(),
            label: Text(
              'Daftar dengan Google',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface,
              backgroundColor: cs.surface,
              side: BorderSide(color: cs.outlineVariant),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 28),

          //  Login link 
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun? ',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Masuk',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

//  Reusable visibility-toggle icon 

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onTap;
  const _VisibilityToggle({required this.obscure, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: onTap,
      tooltip: obscure ? 'Tampilkan' : 'Sembunyikan',
    );
  }
}

