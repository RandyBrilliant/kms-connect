import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/utils/safe_navigation.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional_text_field.dart';

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

  final _oldFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
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
      CustomToast.showGlobal(
        message: 'Password berhasil diubah.',
        type: ToastType.success,
      );
      runWhenNavigatorUnlocked(() {
        if (!mounted) return;
        Navigator.pop(context);
      });
    } catch (e) {
      if (!mounted) return;
      String message = 'Gagal mengubah password.';

      final dynamic err = e;
      try {
        final dynamic response = err.response;
        final dynamic data = response?.data;
        if (data is Map) {
          final detail = data['detail'] ?? data['error'];
          if (detail is String && detail.isNotEmpty) {
            message = detail;
          } else {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    const accent = Color(0xFF0A7A43);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Kembali',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ganti Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ubah password akun Anda',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24 + bottomInset + bottomPad,
                  ),
                  child: ProfessionalCard(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 20,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Gunakan minimal 8 karakter. Kombinasikan huruf, angka, dan simbol untuk keamanan yang lebih baik.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                        color: const Color(0xFF1B4332),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            ProfessionalTextField(
                              controller: _oldPassword,
                              focusNode: _oldFocus,
                              label: 'Password Lama',
                              hintText: 'Masukkan password saat ini',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: !_showOld,
                              textInputAction: TextInputAction.next,
                              upperCase: false,
                              onSubmitted: (_) => _newFocus.requestFocus(),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _showOld = !_showOld),
                                icon: Icon(
                                  _showOld
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Password lama wajib diisi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            ProfessionalTextField(
                              controller: _newPassword,
                              focusNode: _newFocus,
                              label: 'Password Baru',
                              hintText: 'Minimal 8 karakter',
                              prefixIcon: Icons.lock_reset_rounded,
                              obscureText: !_showNew,
                              textInputAction: TextInputAction.next,
                              upperCase: false,
                              onSubmitted: (_) => _confirmFocus.requestFocus(),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _showNew = !_showNew),
                                icon: Icon(
                                  _showNew
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
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
                            const SizedBox(height: 14),
                            ProfessionalTextField(
                              controller: _confirmPassword,
                              focusNode: _confirmFocus,
                              label: 'Konfirmasi Password Baru',
                              hintText: 'Ulangi password baru',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: !_showConfirm,
                              textInputAction: TextInputAction.done,
                              upperCase: false,
                              onSubmitted: (_) => _handleSubmit(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _showConfirm = !_showConfirm),
                                icon: Icon(
                                  _showConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
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
                            const SizedBox(height: 28),
                            ProfessionalButton(
                              label: 'Simpan Password',
                              icon: Icons.save_rounded,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleSubmit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
