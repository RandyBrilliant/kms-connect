import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
//
// Opened via deep-link: /reset-password?uid=<base64>&token=<django-token>
// Calls POST /api/auth/confirm-reset-password/ with {uid, token, new_password}.
// ─────────────────────────────────────────────────────────────────────────────

class ResetPasswordPage extends StatefulWidget {
  final String uid;
  final String token;

  const ResetPasswordPage({super.key, required this.uid, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _success = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  /// Both uid and token must be non-empty for the page to be actionable.
  bool get _hasValidParams =>
      widget.uid.isNotEmpty && widget.token.isNotEmpty;

  /// Extracts a user-friendly error message from a [DioException].
  String _extractDetail(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          return errors.values
              .expand((v) => v is List ? v : [v.toString()])
              .join(' ');
        }
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi timeout. Periksa jaringan Anda.';
        case DioExceptionType.connectionError:
          return 'Tidak dapat terhubung ke server. Periksa jaringan Anda.';
        default:
          return 'Terjadi kesalahan. Silakan coba lagi.';
      }
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  Future<void> _handleReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await ApiClient().dio.post(
        ApiEndpoints.confirmPasswordReset,
        data: {
          'uid': widget.uid,
          'token': widget.token,
          'new_password': _newPasswordCtrl.text,
        },
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context,
          message: _extractDetail(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    const headerH = 140.0;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Wave header ──────────────────────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                    child: AuthWaveHeader(height: headerH + topPad)),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/login'),
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
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Reset Kata Sandi',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body — animated between states ──────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _success
                  ? _SuccessView(
                      key: const ValueKey('success'),
                      onGoLogin: () => context.go('/login'),
                    )
                  : !_hasValidParams
                      ? _InvalidLinkView(
                          key: const ValueKey('invalid'),
                          onGoLogin: () => context.go('/forgot-password'),
                        )
                      : _ResetForm(
                          key: const ValueKey('form'),
                          formKey: _formKey,
                          newPasswordCtrl: _newPasswordCtrl,
                          confirmPasswordCtrl: _confirmPasswordCtrl,
                          isLoading: _isLoading,
                          showNew: _showNew,
                          showConfirm: _showConfirm,
                          onToggleNew: () =>
                              setState(() => _showNew = !_showNew),
                          onToggleConfirm: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          onSubmit: _handleReset,
                          tt: tt,
                          cs: cs,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ResetForm — new password + confirm
// ─────────────────────────────────────────────────────────────────────────────

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    super.key,
    required this.formKey,
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.isLoading,
    required this.showNew,
    required this.showConfirm,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.tt,
    required this.cs,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool isLoading;
  final bool showNew;
  final bool showConfirm;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryLightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person_rounded,
                    size: 40, color: AppColors.primaryDarkGreen),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Buat Kata Sandi Baru',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kata sandi baru harus minimal 8 karakter.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            M3TextField(
              controller: newPasswordCtrl,
              label: 'Kata Sandi Baru',
              hint: 'Min. 8 karakter',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: !showNew,
              suffixWidget: IconButton(
                icon: Icon(
                  showNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onToggleNew,
                tooltip: showNew ? 'Sembunyikan' : 'Tampilkan',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kata sandi baru wajib diisi';
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            M3TextField(
              controller: confirmPasswordCtrl,
              label: 'Konfirmasi Kata Sandi',
              hint: 'Ulangi kata sandi baru',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: !showConfirm,
              suffixWidget: IconButton(
                icon: Icon(
                  showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onToggleConfirm,
                tooltip: showConfirm ? 'Sembunyikan' : 'Tampilkan',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Konfirmasi kata sandi wajib diisi';
                }
                if (v != newPasswordCtrl.text) {
                  return 'Kata sandi tidak cocok';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Simpan Kata Sandi Baru',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SuccessView — password changed confirmation
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key, required this.onGoLogin});
  final VoidCallback onGoLogin;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.secondaryLightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 44, color: AppColors.primaryDarkGreen),
          ),
          const SizedBox(height: 24),
          Text(
            'Kata Sandi Diperbarui!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Kata sandi Anda berhasil diatur ulang. Silakan login dengan kata sandi baru.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onGoLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Masuk Sekarang',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InvalidLinkView — shown when uid/token are missing or malformed
// ─────────────────────────────────────────────────────────────────────────────

class _InvalidLinkView extends StatelessWidget {
  const _InvalidLinkView({super.key, required this.onGoLogin});
  final VoidCallback onGoLogin;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.link_off_rounded,
                size: 40, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(
            'Tautan Tidak Valid',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Tautan reset kata sandi ini tidak valid atau sudah kedaluwarsa. '
            'Silakan minta tautan baru.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onGoLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Minta Tautan Baru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
