import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/m3_text_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _isLoading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await ApiClient().dio.post(
        ApiEndpoints.changePassword,
        data: {
          'old_password': _oldPassword.text.trim(),
          'new_password': _newPassword.text.trim(),
        },
      );

      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Password berhasil diubah.',
        type: ToastType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      String message = 'Gagal mengubah password.';

      // Try to extract the backend error detail
      final dynamic err = e;
      try {
        final dynamic response = err.response;
        final dynamic data = response?.data;
        if (data is Map) {
          final detail = data['detail'] ?? data['error'];
          if (detail is String && detail.isNotEmpty) {
            message = detail;
          } else {
            // Try field-level errors
            final errors = data['errors'];
            if (errors is Map) {
              final allMsgs = errors.values
                  .expand((v) => v is List ? v : [v.toString()])
                  .join(' ');
              if (allMsgs.isNotEmpty) message = allMsgs;
            }
          }
        }
      } catch (_) {}

      CustomToast.show(context, message: message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        children: [
          // ── Header ────────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AuthWaveHeader(height: headerH + topPad),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ganti Password',
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Ubah password akun kamu',
                              style: tt.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCFFAFE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0891B2).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF0891B2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Gunakan minimal 8 karakter. Kombinasikan huruf, angka, dan simbol untuk keamanan yang lebih baik.',
                              style: tt.bodySmall?.copyWith(
                                color: const Color(0xFF0E7490),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Old password
                    M3TextField(
                      controller: _oldPassword,
                      label: 'Password Lama',
                      hint: 'Masukkan password saat ini',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_showOld,
                      textInputAction: TextInputAction.next,
                      suffixWidget: GestureDetector(
                        onTap: () => setState(() => _showOld = !_showOld),
                        child: Icon(
                          _showOld
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Password lama wajib diisi.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // New password
                    M3TextField(
                      controller: _newPassword,
                      label: 'Password Baru',
                      hint: 'Minimal 8 karakter',
                      prefixIcon: Icons.lock_reset_rounded,
                      obscureText: !_showNew,
                      textInputAction: TextInputAction.next,
                      suffixWidget: GestureDetector(
                        onTap: () => setState(() => _showNew = !_showNew),
                        child: Icon(
                          _showNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Password baru wajib diisi.';
                        }
                        if (v.trim().length < 8) {
                          return 'Password minimal 8 karakter.';
                        }
                        if (v.trim() == _oldPassword.text.trim()) {
                          return 'Password baru tidak boleh sama dengan password lama.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm new password
                    M3TextField(
                      controller: _confirmPassword,
                      label: 'Konfirmasi Password Baru',
                      hint: 'Ulangi password baru',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_showConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSubmit(),
                      suffixWidget: GestureDetector(
                        onTap: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        child: Icon(
                          _showConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Konfirmasi password wajib diisi.';
                        }
                        if (v.trim() != _newPassword.text.trim()) {
                          return 'Konfirmasi password tidak cocok.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDarkGreen,
                          disabledBackgroundColor:
                              AppColors.primaryDarkGreen.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Simpan Password',
                                style: tt.labelLarge?.copyWith(
                                  color: Colors.white,
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
    );
  }
}
