import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../data/providers/auth_provider.dart';

enum _VerifyStatus { loading, success, error }

const _kSuccessColor = Color(0xFF16A34A);
const _kErrorColor = Color(0xFFDC2626);

class VerifyEmailPage extends ConsumerStatefulWidget {
  final String token;

  const VerifyEmailPage({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage>
    with SingleTickerProviderStateMixin {
  _VerifyStatus _status = _VerifyStatus.loading;
  String _message = '';
  String? _verifiedEmail;
  bool _resendLoading = false;
  final _resendEmailCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic)),
    );
    _scaleIn = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0, 0.8, curve: Curves.elasticOut)),
    );

    if (widget.token.isEmpty) {
      _status = _VerifyStatus.error;
      _message = 'Token verifikasi tidak ditemukan.';
      WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
    } else {
      _verifyToken();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
      _animCtrl.forward();
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map<String, dynamic> ? data['detail'] : null) as String?;
      setState(() {
        _status = _VerifyStatus.error;
        _message = detail ?? 'Token tidak valid atau kedaluwarsa.';
      });
      _animCtrl.forward();
    } catch (_) {
      setState(() {
        _status = _VerifyStatus.error;
        _message = 'Verifikasi email gagal. Silakan coba lagi.';
      });
      _animCtrl.forward();
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                Text(
                  'Kirim Ulang Email Verifikasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan alamat email yang didaftarkan untuk menerima tautan verifikasi baru.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                ProfessionalTextField(
                  controller: _resendEmailCtrl,
                  label: 'Email',
                  hintText: 'contoh@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                
                ProfessionalButton(
                  label: _resendLoading ? 'Mengirim...' : 'Kirim Email Verifikasi',
                  onPressed: _resendLoading
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _handleResend(_resendEmailCtrl.text);
                        },
                  isLoading: _resendLoading,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _statusTitle {
    return switch (_status) {
      _VerifyStatus.loading => 'Memverifikasi...',
      _VerifyStatus.success => 'Email Terverifikasi!',
      _VerifyStatus.error => 'Verifikasi Gagal',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfessionalGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Verifikasi Email',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: Opacity(
                          opacity: _fadeIn.value,
                          child: _buildContent(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Status icon
            _buildStatusIcon(),
            const SizedBox(height: 28),

            // Title
            Text(
              _statusTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _status == _VerifyStatus.success
                    ? _kSuccessColor
                    : _status == _VerifyStatus.error
                        ? _kErrorColor
                        : AppColors.textDark,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            if (_status != _VerifyStatus.loading)
              Text(
                _message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

            // Verified email
            if (_verifiedEmail != null && _status == _VerifyStatus.success) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _kSuccessColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _verifiedEmail!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kSuccessColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 36),

            // Action buttons
            if (_status == _VerifyStatus.loading)
              Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mohon tunggu...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),

            if (_status == _VerifyStatus.success)
              ProfessionalButton(
                label: 'Lanjutkan ke Aplikasi',
                onPressed: () => context.go('/home'),
              ),

            if (_status == _VerifyStatus.error) ...[
              ProfessionalButton(
                label: 'Coba Lagi',
                onPressed: _verifyToken,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _showResendBottomSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDarkGreen,
                    side: BorderSide(
                      color: AppColors.primaryDarkGreen,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Kirim Ulang Email Verifikasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            
            if (_status != _VerifyStatus.loading) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Kembali ke Login',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDarkGreen,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primaryDarkGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_status == _VerifyStatus.loading) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primaryDarkGreen,
          ),
        ),
      );
    }

    final isSuccess = _status == _VerifyStatus.success;
    final color = isSuccess ? _kSuccessColor : _kErrorColor;
    final icon = isSuccess
        ? Icons.mark_email_read_rounded
        : Icons.error_outline_rounded;

    return ScaleTransition(
      scale: _scaleIn,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 52, color: color),
      ),
    );
  }
}
