import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/auth_provider.dart';

/// Beautiful 6-digit OTP verification page for email verification.
///
/// Displayed after registration so the user can verify their email
/// without leaving the app. Features auto-focus, paste support,
/// countdown timer, and animated success state.
class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSuccess = false;

  // Countdown for resend
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  // Success animation
  late final AnimationController _successAnimCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();

    // Automatically send a verification email when the page opens.
    _autoSendVerification();

    _successAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimCtrl,
        curve: Curves.elasticOut,
      ),
    );
    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _successAnimCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Automatically sends a verification code when the page first opens.
  Future<void> _autoSendVerification() async {
    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(widget.email);
    if (!mounted) return;
    if (ok) {
      _startCountdown();
      CustomToast.show(context,
          message: 'Kode verifikasi telah dikirim ke ${widget.email}',
          type: ToastType.success);
    } else {
      // Even on failure, start countdown to prevent rapid retries.
      _startCountdown();
    }
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onCodeChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute characters across fields
      final chars = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (chars.length > 1) {
        _handlePaste(chars);
        return;
      }
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-submit when all 6 digits are entered
    if (_code.length == 6) {
      _handleVerify();
    }
  }

  void _handlePaste(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < 6; i++) {
      if (i < digits.length) {
        _controllers[i].text = digits[i];
      }
    }
    if (digits.length >= 6) {
      _focusNodes[5].requestFocus();
      // Auto-submit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _code.length == 6) _handleVerify();
      });
    } else if (digits.isNotEmpty) {
      final nextIdx = digits.length.clamp(0, 5);
      _focusNodes[nextIdx].requestFocus();
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handleVerify() async {
    // Guard against re-entry while already verifying.
    if (_isVerifying) return;

    final code = _code;
    if (code.length != 6) {
      CustomToast.show(context,
          message: 'Masukkan 6 digit kode verifikasi',
          type: ToastType.warning);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await ApiClient().dio.post(
        ApiEndpoints.verifyEmailCode,
        data: {
          'email': widget.email,
          'code': code,
        },
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );

      if (!mounted) return;

      // Both "success" and "email_already_verified" mean the email is good.
      final verified =
          apiResponse.isSuccess || apiResponse.code == 'email_already_verified';

      if (verified) {
        setState(() {
          _isSuccess = true;
          _isVerifying = false;
        });
        _successAnimCtrl.forward();

        // Refresh user data to update email_verified status
        await ref.read(authStateProvider.notifier).refreshUser();

        // Navigate to home after animation
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) {
          CustomToast.show(context,
              message: 'Email berhasil diverifikasi! Selamat datang.',
              type: ToastType.success,
              duration: const Duration(seconds: 3));
          context.go('/home');
        }
      } else {
        // Unexpected non-success code from backend
        setState(() => _isVerifying = false);
        _clearCode();
        CustomToast.show(context,
            message: apiResponse.detail ?? 'Verifikasi gagal.',
            type: ToastType.error);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);

      final data = e.response?.data;
      final detail =
          (data is Map<String, dynamic> ? data['detail'] : null) as String?;

      _clearCode();
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

  Future<void> _handleResend() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    final ok = await ref
        .read(authStateProvider.notifier)
        .resendVerificationEmail(widget.email);

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safePadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              //  Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isSuccess
                    ? ScaleTransition(
                        key: const ValueKey('success'),
                        scale: _successScale,
                        child: FadeTransition(
                          opacity: _successOpacity,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 56,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        key: const ValueKey('email'),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_unread_rounded,
                          size: 48,
                          color: cs.primary,
                        ),
                      ),
              ),

              const SizedBox(height: 28),

              //  Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _isSuccess ? 'Email Terverifikasi!' : 'Verifikasi Email',
                  key: ValueKey(_isSuccess),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _isSuccess
                        ? const Color(0xFF16A34A)
                        : cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              //  Subtitle
              if (!_isSuccess) ...[
                Text(
                  'Masukkan 6 digit kode yang telah dikirim ke',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'Akun Anda telah berhasil diverifikasi.\nMengarahkan ke halaman utama...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 40),

              //  OTP input fields
              if (!_isSuccess) ...[
                _buildCodeInput(cs),

                const SizedBox(height: 32),

                //  Verify button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _isVerifying || _code.length != 6 ? null : _handleVerify,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor:
                          cs.onSurface.withAlpha(30),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    child: _isVerifying
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Text('Verifikasi'),
                  ),
                ),

                const SizedBox(height: 28),

                //  Resend section
                _buildResendSection(cs),

                const SizedBox(height: 16),

                //  Info card
                _buildInfoCard(cs),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final hasValue = _controllers[index].text.isNotEmpty;
        final isFocused = _focusNodes[index].hasFocus;

        return Flexible(
          child: Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : (index == 3 ? 12 : 6),
              right: index == 5 ? 0 : (index == 2 ? 12 : 6),
            ),
            constraints: const BoxConstraints(maxWidth: 52),
            child: KeyboardListener(
              focusNode: FocusNode(), // wrapper, actual focus on TextField
              onKeyEvent: (event) => _onKeyDown(index, event),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: hasValue
                      ? cs.primaryContainer.withAlpha(40)
                      : cs.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFocused
                        ? cs.primary
                        : hasValue
                            ? cs.primary.withAlpha(100)
                            : cs.outlineVariant.withAlpha(120),
                    width: isFocused ? 2 : 1.5,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: cs.primary.withAlpha(25),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6, // Allow paste
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: 0,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) => _onCodeChanged(index, value),
                  onTap: () {
                    // Select all text when tapped for easy replace
                    _controllers[index].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controllers[index].text.length,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResendSection(ColorScheme cs) {
    return Column(
      children: [
        Text(
          'Tidak menerima kode?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _resendCountdown > 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: cs.onSurfaceVariant.withAlpha(150),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Kirim ulang dalam ${_resendCountdown}s',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                ],
              )
            : TextButton(
                onPressed: _isResending ? null : _handleResend,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _isResending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Text(
                        'Kirim Ulang Kode',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
      ],
    );
  }

  Widget _buildInfoCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withAlpha(60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: cs.onSurfaceVariant.withAlpha(180),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Periksa folder spam jika email tidak masuk\n'
                  '• Kode berlaku selama 10 menit\n'
                  '• Anda bisa langsung paste kode dari email',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withAlpha(180),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
