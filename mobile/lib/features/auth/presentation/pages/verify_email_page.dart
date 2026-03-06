import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/auth_provider.dart';

enum _VerifyStatus { loading, success, error }

class VerifyEmailPage extends ConsumerStatefulWidget {
  final String token;

  const VerifyEmailPage({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  _VerifyStatus _status = _VerifyStatus.loading;
  String _message = '';
  String? _verifiedEmail;
  bool _resendLoading = false;
  final _resendEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.token.isEmpty) {
      _status = _VerifyStatus.error;
      _message = 'Token verifikasi tidak ditemukan.';
    } else {
      _verifyToken();
    }
  }

  @override
  void dispose() {
    _resendEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    setState(() => _status = _VerifyStatus.loading);
    try {
      final response = await ApiClient().dio.get(
        ApiEndpoints.verifyEmail,
        queryParameters: {'token': widget.token},
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );
      setState(() {
        _status = _VerifyStatus.success;
        _message = apiResponse.detail ?? 'Email berhasil diverifikasi.';
        _verifiedEmail = apiResponse.data?['email'] as String?;
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map<String, dynamic> ? data['detail'] : null) as String?;
      setState(() {
        _status = _VerifyStatus.error;
        _message = detail ?? 'Token tidak valid atau kedaluwarsa.';
      });
    } catch (_) {
      setState(() {
        _status = _VerifyStatus.error;
        _message = 'Verifikasi email gagal. Silakan coba lagi.';
      });
    }
  }

  Future<void> _handleResend(String email) async {
    if (email.trim().isEmpty) {
      CustomToast.show(context, message: 'Email wajib diisi', type: ToastType.error);
      return;
    }
    setState(() => _resendLoading = true);
    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(email.trim().toLowerCase());
    if (!mounted) return;
    setState(() => _resendLoading = false);
    CustomToast.show(
      context,
      message: ok
          ? 'Email verifikasi berhasil dikirim. Silakan cek kotak masuk Anda.'
          : 'Gagal mengirim email. Silakan coba lagi.',
      type: ok ? ToastType.success : ToastType.error,
    );
  }

  void _showResendBottomSheet() {
    _resendEmailCtrl.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;

        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 0,
                  maxWidth: constraints.maxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kirim Ulang Email Verifikasi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masukkan alamat email yang didaftarkan untuk menerima tautan verifikasi baru.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _resendEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'contoh@email.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _resendLoading
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _handleResend(_resendEmailCtrl.text);
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          _resendLoading
                              ? 'Mengirim...'
                              : 'Kirim Email Verifikasi',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Verifikasi Email',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIcon(colorScheme),
              const SizedBox(height: 24),
              Text(
                _statusTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_status != _VerifyStatus.loading)
                Text(
                  _message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (_verifiedEmail != null && _status == _VerifyStatus.success) ...[
                const SizedBox(height: 6),
                Text(
                  _verifiedEmail!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_status == _VerifyStatus.success)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/home'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Lanjutkan ke Aplikasi'),
                  ),
                ),
              if (_status == _VerifyStatus.error) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _verifyToken,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _showResendBottomSheet,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Kirim Ulang Email Verifikasi'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Kembali ke Login',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    if (_status == _VerifyStatus.loading) {
      return SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: colorScheme.primary,
        ),
      );
    }
    final (icon, color) = _status == _VerifyStatus.success
        ? (Icons.mark_email_read_outlined, const Color(0xFF16A34A))
        : (Icons.error_outline_rounded, colorScheme.error);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: color),
    );
  }

  String get _statusTitle => switch (_status) {
        _VerifyStatus.loading => 'Memverifikasi...',
        _VerifyStatus.success => 'Email Terverifikasi!',
        _VerifyStatus.error => 'Verifikasi Gagal',
      };
}
