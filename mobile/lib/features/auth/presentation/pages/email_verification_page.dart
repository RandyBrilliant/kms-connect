import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _kDigitCount = 6;
const _kResendSeconds = 60;
const _kSuccessColor = Color(0xFF16A34A);
const _kSuccessDelay = Duration(milliseconds: 1800);

class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  final _controllers =
      List.generate(_kDigitCount, (_) => TextEditingController());
  final _focusNodes = List.generate(_kDigitCount, (_) => FocusNode());
  final _currentEmailCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSuccess = false;
  int _resendCountdown = _kResendSeconds;
  Timer? _countdownTimer;
  late String _verificationEmail;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  String get _code => _controllers.map((c) => c.text).join();
  static final _emailRx = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$');

  @override
  void initState() {
    super.initState();
    _verificationEmail = widget.email.trim().toLowerCase();
    _currentEmailCtrl.text = _verificationEmail;
    _startCountdown();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
        _animCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animCtrl.dispose();
    _currentEmailCtrl.dispose();
    _newEmailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleBack() {
    // Clear any pending state and navigate back
    context.go('/register');
  }

  void _startCountdown() {
    _resendCountdown = _kResendSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= _kDigitCount) {
        for (var i = 0; i < _kDigitCount; i++) {
          _controllers[i].text = digits[i];
        }
        _focusNodes[_kDigitCount - 1].requestFocus();
        if (_code.length == _kDigitCount) _verify();
        return;
      }
      _controllers[index].text = value.substring(value.length - 1);
    }

    setState(() {}); // Rebuild to update cell colors

    if (value.isNotEmpty && index < _kDigitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_code.length == _kDigitCount) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length != _kDigitCount) return;

    setState(() => _isVerifying = true);

    try {
      final response = await ApiClient().dio.post(
        ApiEndpoints.verifyEmailCode,
        data: {'email': _verificationEmail, 'code': code},
      );

      final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (d) => d as Map<String, dynamic>,
      );

      if (!mounted) return;

      final verified =
          apiResp.isSuccess || apiResp.code == 'email_already_verified';

      if (verified) {
        setState(() {
          _isSuccess = true;
          _isVerifying = false;
        });

        ref.read(authStateProvider.notifier).markEmailVerified();
        await ref.read(authStateProvider.notifier).refreshUser();
        await Future.delayed(_kSuccessDelay);
        if (!mounted) return;

        CustomToast.show(context,
            message: 'Email berhasil diverifikasi! Selamat datang.',
            type: ToastType.success,
            duration: const Duration(seconds: 3));
        context.go('/home');
      } else {
        setState(() => _isVerifying = false);
        _clearCode();
        CustomToast.show(context,
            message: apiResp.detail ?? 'Verifikasi gagal.',
            type: ToastType.error);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _clearCode();
      final detail = (e.response?.data is Map<String, dynamic>)
          ? (e.response!.data as Map<String, dynamic>)['detail'] as String?
          : null;
      CustomToast.show(context,
          message: detail ?? 'Kode verifikasi tidak valid.',
          type: ToastType.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _clearCode();
      CustomToast.show(context,
          message: 'Terjadi kesalahan. Silakan coba lagi.',
          type: ToastType.error);
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0 || _isResending) return;
    setState(() => _isResending = true);

    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(_verificationEmail);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (ok) {
      _startCountdown();
      _clearCode();
      CustomToast.show(context,
          message: 'Kode verifikasi baru telah dikirim ke email Anda.',
          type: ToastType.success);
    } else {
      CustomToast.show(context,
          message: 'Gagal mengirim ulang kode. Silakan coba lagi.',
          type: ToastType.error);
    }
  }

  Future<void> _showUpdateEmailBottomSheet() async {
    _currentEmailCtrl.text = _verificationEmail;
    _newEmailCtrl.clear();
    _passwordCtrl.clear();
    var obscurePassword = true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: bottomInset),
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ubah Email Verifikasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Jika ada salah ketik, masukkan email yang benar dan password akun Anda.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ProfessionalTextField(
                          controller: _currentEmailCtrl,
                          label: 'Email saat ini',
                          hintText: '-',
                          prefixIcon: Icons.alternate_email_rounded,
                          readOnly: true,
                          enabled: false,
                          upperCase: false,
                        ),
                        const SizedBox(height: 12),
                        ProfessionalTextField(
                          controller: _newEmailCtrl,
                          label: 'Email baru',
                          hintText: 'contoh@email.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.none,
                          upperCase: false,
                        ),
                        const SizedBox(height: 12),
                        ProfessionalTextField(
                          controller: _passwordCtrl,
                          label: 'Password akun',
                          hintText: 'Masukkan password akun',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.done,
                          upperCase: false,
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ProfessionalButton(
                          label: saving ? 'Menyimpan...' : 'Simpan Email Baru',
                          isLoading: saving,
                          onPressed: saving
                              ? null
                              : () async {
                                  final nextEmail =
                                      _newEmailCtrl.text.trim().toLowerCase();
                                  final password = _passwordCtrl.text;
                                  if (nextEmail.isEmpty || password.isEmpty) {
                                    CustomToast.show(
                                      ctx,
                                      message:
                                          'Email baru dan password wajib diisi.',
                                      type: ToastType.error,
                                    );
                                    return;
                                  }
                                  if (!_emailRx.hasMatch(nextEmail)) {
                                    CustomToast.show(
                                      ctx,
                                      message: 'Format email baru tidak valid.',
                                      type: ToastType.error,
                                    );
                                    return;
                                  }
                                  if (nextEmail == _verificationEmail) {
                                    CustomToast.show(
                                      ctx,
                                      message:
                                          'Email baru harus berbeda dari email saat ini.',
                                      type: ToastType.error,
                                    );
                                    return;
                                  }

                                  saving = true;
                                  setModalState(() {});

                                  final error = await ref
                                      .read(authStateProvider.notifier)
                                      .updateUnverifiedEmail(
                                        currentEmail: _verificationEmail,
                                        newEmail: nextEmail,
                                        password: password,
                                      );

                                  if (!ctx.mounted) return;
                                  saving = false;
                                  setModalState(() {});

                                  if (error != null) {
                                    CustomToast.show(
                                      ctx,
                                      message: error,
                                      type: ToastType.error,
                                    );
                                    return;
                                  }

                                  if (!mounted) return;
                                  setState(() {
                                    _verificationEmail = nextEmail;
                                    _currentEmailCtrl.text = nextEmail;
                                  });
                                  _clearCode();
                                  _startCountdown();
                                  Navigator.of(ctx).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    _focusNodes[0].requestFocus();
                                    context.go(
                                      '/email-verification?email=${Uri.encodeComponent(nextEmail)}',
                                    );
                                  });
                                  CustomToast.showGlobal(
                                    message:
                                        'Email diperbarui. Kode verifikasi baru sudah dikirim.',
                                    type: ToastType.success,
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                      onTap: _handleBack,
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
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: Opacity(
                          opacity: _fadeIn.value,
                          child: _isSuccess
                              ? _buildSuccessContent()
                              : _buildVerifyContent(),
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

  Widget _buildSuccessContent() {
    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _kSuccessColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: _kSuccessColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Email Terverifikasi!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _kSuccessColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Akun Anda telah berhasil diverifikasi.\nMengarahkan ke halaman utama...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _kSuccessColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyContent() {
    return ProfessionalCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_rounded,
                size: 40,
                color: AppColors.primaryDarkGreen,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Masukkan Kode Verifikasi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Masukkan 6 digit kode yang telah dikirim ke',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _verificationEmail,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDarkGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // OTP digits - responsive to avoid overflow
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate cell size to fit within available width
                final availableWidth = constraints.maxWidth;
                final gaps = 4 * 6.0 + 10.0; // 4 small gaps + 1 larger gap
                final cellWidth = ((availableWidth - gaps) / 6).clamp(36.0, 46.0);
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_kDigitCount, (i) {
                    final gap = i == 0 ? 0.0 : (i == 3 ? 10.0 : 6.0);
                    return Padding(
                      padding: EdgeInsets.only(left: gap),
                      child: _buildOtpCell(i, cellWidth),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 32),

            // Verify button
            ProfessionalButton(
              label: 'Verifikasi',
              onPressed: _isVerifying || _code.length != _kDigitCount ? null : _verify,
              isLoading: _isVerifying,
            ),
            const SizedBox(height: 24),

            // Resend section
            _buildResendSection(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isSuccess ? null : _showUpdateEmailBottomSheet,
              child: Text(
                'Email salah? Ubah email',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDarkGreen,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primaryDarkGreen,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tips
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpCell(int index, double width) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final height = (width * 1.15).clamp(48.0, 56.0);
    final fontSize = (width * 0.5).clamp(18.0, 22.0);

    return SizedBox(
      width: width,
      height: height,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            // If current field is empty and backspace is pressed, go to previous and clear it
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              setState(() {});
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onDigitChanged(index, v),
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: height * 0.2),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasValue 
                    ? AppColors.primaryDarkGreen 
                    : AppColors.divider,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryDarkGreen,
                width: 2.5,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          'Tidak menerima kode?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        if (_resendCountdown > 0)
          Text(
            'Kirim ulang dalam ${_resendCountdown}s',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          )
        else
          GestureDetector(
            onTap: _isResending ? null : _resend,
            child: _isResending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Kirim Ulang Kode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkGreen,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryDarkGreen,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundOffWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 20,
            color: AppColors.textMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Periksa folder spam jika email tidak ditemukan di kotak masuk.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
