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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kDigitCount = 6;
const _kResendSeconds = 60;
const _kSuccessColor = Color(0xFF16A34A);
const _kSuccessDelay = Duration(milliseconds: 1800);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// 6-digit OTP verification page shown after registration.
///
/// Features: auto-focus, paste support, countdown timer, animated success.
class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  // -- Controllers & focus ------------------------------------------------
  final _controllers =
      List.generate(_kDigitCount, (_) => TextEditingController());
  final _focusNodes = List.generate(_kDigitCount, (_) => FocusNode());

  // -- State --------------------------------------------------------------
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSuccess = false;
  int _resendCountdown = _kResendSeconds;
  Timer? _countdownTimer;

  // -- Animation ----------------------------------------------------------
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successOpacity;

  // -- Helpers ------------------------------------------------------------
  String get _code => _controllers.map((c) => c.text).join();

  // -- Lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    // Registration already sent the first email -- just start the countdown.
    _startCountdown();

    // Listen to focus changes so the OTP cell decorations rebuild.
    for (final node in _focusNodes) {
      node.addListener(_onFocusChanged);
    }

    // Success animation setup.
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
    _successOpacity = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    // Auto-focus the first digit field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _successCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.removeListener(_onFocusChanged);
      n.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  // -- Countdown ----------------------------------------------------------

  void _startCountdown() {
    _resendCountdown = _kResendSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // -- OTP input logic ----------------------------------------------------

  void _onDigitChanged(int index, String value) {
    // Paste: distribute characters across all fields.
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _pasteFill(digits);
      return;
    }

    // Advance to the next field.
    if (value.isNotEmpty && index < _kDigitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-submit when all 6 digits are filled.
    if (_code.length == _kDigitCount) _verify();
  }

  void _pasteFill(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _kDigitCount; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= _kDigitCount) {
      _focusNodes.last.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _code.length == _kDigitCount) _verify();
      });
    } else if (digits.isNotEmpty) {
      _focusNodes[digits.length.clamp(0, _kDigitCount - 1)].requestFocus();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
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

  // -- Network actions ----------------------------------------------------

  Future<void> _verify() async {
    if (_isVerifying) return;

    final code = _code;
    if (code.length != _kDigitCount) {
      CustomToast.show(context,
          message: 'Masukkan 6 digit kode verifikasi',
          type: ToastType.warning);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await ApiClient().dio.post(
        ApiEndpoints.verifyEmailCode,
        data: {'email': widget.email, 'code': code},
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
        _successCtrl.forward();

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

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 32,
            ),
            child: _isSuccess
                ? _SuccessContent(
                    scaleAnimation: _successScale,
                    opacityAnimation: _successOpacity,
                    cs: cs,
                  )
                : _VerifyContent(
                    email: widget.email,
                    controllers: _controllers,
                    focusNodes: _focusNodes,
                    isVerifying: _isVerifying,
                    isResending: _isResending,
                    resendCountdown: _resendCountdown,
                    code: _code,
                    cs: cs,
                    onDigitChanged: _onDigitChanged,
                    onKeyEvent: _onKeyEvent,
                    onVerify: _verify,
                    onResend: _resend,
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success state content
// ---------------------------------------------------------------------------

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({
    required this.scaleAnimation,
    required this.opacityAnimation,
    required this.cs,
  });

  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: opacityAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0x1916A34A), // 10% green
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: _kSuccessColor,
              ),
            ),
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
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verification form content
// ---------------------------------------------------------------------------

class _VerifyContent extends StatelessWidget {
  const _VerifyContent({
    required this.email,
    required this.controllers,
    required this.focusNodes,
    required this.isVerifying,
    required this.isResending,
    required this.resendCountdown,
    required this.code,
    required this.cs,
    required this.onDigitChanged,
    required this.onKeyEvent,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool isVerifying;
  final bool isResending;
  final int resendCountdown;
  final String code;
  final ColorScheme cs;
  final void Function(int index, String value) onDigitChanged;
  final void Function(int index, KeyEvent event) onKeyEvent;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Icon ---------------------------------------------------------
        Container(
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
        const SizedBox(height: 28),

        // -- Title --------------------------------------------------------
        Text(
          'Verifikasi Email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),

        // -- Subtitle -----------------------------------------------------
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
          email,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // -- OTP digits ---------------------------------------------------
        _OtpRow(
          controllers: controllers,
          focusNodes: focusNodes,
          cs: cs,
          onDigitChanged: onDigitChanged,
          onKeyEvent: onKeyEvent,
        ),
        const SizedBox(height: 32),

        // -- Verify button ------------------------------------------------
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: isVerifying || code.length != _kDigitCount
                ? null
                : onVerify,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              disabledBackgroundColor: cs.onSurface.withAlpha(30),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            child: isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verifikasi'),
          ),
        ),
        const SizedBox(height: 28),

        // -- Resend section -----------------------------------------------
        _ResendSection(
          countdown: resendCountdown,
          isResending: isResending,
          cs: cs,
          onResend: onResend,
        ),
        const SizedBox(height: 16),

        // -- Tips card ----------------------------------------------------
        _TipsCard(cs: cs),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// OTP digit row
// ---------------------------------------------------------------------------

class _OtpRow extends StatelessWidget {
  const _OtpRow({
    required this.controllers,
    required this.focusNodes,
    required this.cs,
    required this.onDigitChanged,
    required this.onKeyEvent,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final ColorScheme cs;
  final void Function(int, String) onDigitChanged;
  final void Function(int, KeyEvent) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kDigitCount, (i) {
        // Extra gap between 3rd and 4th digit (visual grouping).
        final leftMargin = i == 0 ? 0.0 : (i == 3 ? 14.0 : 6.0);
        final rightMargin =
            i == _kDigitCount - 1 ? 0.0 : (i == 2 ? 14.0 : 6.0);

        return _OtpCell(
          controller: controllers[i],
          focusNode: focusNodes[i],
          cs: cs,
          leftMargin: leftMargin,
          rightMargin: rightMargin,
          onChanged: (v) => onDigitChanged(i, v),
          onKeyEvent: (e) => onKeyEvent(i, e),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Single OTP cell
// ---------------------------------------------------------------------------

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.controller,
    required this.focusNode,
    required this.cs,
    required this.leftMargin,
    required this.rightMargin,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme cs;
  final double leftMargin;
  final double rightMargin;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;
    final isFocused = focusNode.hasFocus;

    return Container(
      width: 48,
      height: 56,
      margin: EdgeInsets.only(left: leftMargin, right: rightMargin),
      decoration: BoxDecoration(
        color: hasValue
            ? cs.primaryContainer.withAlpha(40)
            : cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? cs.primary
              : hasValue
                  ? cs.primary.withAlpha(100)
                  : cs.outlineVariant.withAlpha(120),
          width: isFocused ? 2.0 : 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                    color: cs.primary.withAlpha(25),
                    blurRadius: 8,
                    spreadRadius: 1)
              ]
            : null,
      ),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          onKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _kDigitCount, // allows paste
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: onChanged,
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resend section
// ---------------------------------------------------------------------------

class _ResendSection extends StatelessWidget {
  const _ResendSection({
    required this.countdown,
    required this.isResending,
    required this.cs,
    required this.onResend,
  });

  final int countdown;
  final bool isResending;
  final ColorScheme cs;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tidak menerima kode?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (countdown > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined,
                  size: 16, color: cs.onSurfaceVariant.withAlpha(150)),
              const SizedBox(width: 6),
              Text(
                'Kirim ulang dalam ${countdown}s',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withAlpha(150),
                ),
              ),
            ],
          )
        else
          TextButton(
            onPressed: isResending ? null : onResend,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: isResending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary),
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
}

// ---------------------------------------------------------------------------
// Tips info card
// ---------------------------------------------------------------------------

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: cs.onSurfaceVariant.withAlpha(180)),
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
                  '${String.fromCharCode(8226)} Periksa folder spam jika email tidak masuk\n'
                  '${String.fromCharCode(8226)} Kode berlaku selama 10 menit\n'
                  '${String.fromCharCode(8226)} Anda bisa langsung paste kode dari email',
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
