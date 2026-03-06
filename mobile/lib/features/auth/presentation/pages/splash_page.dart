import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../data/providers/auth_provider.dart';

/// Full-screen animated splash shown once at app start.
/// Waits for [AuthState.initialized] then fades out to /home or /login.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _iconCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _exitCtrl;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _exitOpacity;

  bool _animsDone = false;
  bool _navTriggered = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Icon: elastic pop-in + fade
    _iconScale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // App name: slide up + fade
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );

    // Tagline: simple fade
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn),
    );

    // Exit: fade to white, then navigate
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    // Icon pops in
    await _iconCtrl.forward();
    if (!mounted) return;

    // Name slides up simultaneously with tagline loading
    await Future.delayed(const Duration(milliseconds: 100));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    await _taglineCtrl.forward();
    if (!mounted) return;

    _animsDone = true;
    _tryNavigate();
  }

  /// Called both after animations complete and when auth state changes.
  void _tryNavigate() {
    if (!_animsDone || _navTriggered) return;
    final auth = ref.read(authStateProvider);
    if (!auth.initialized) return;
    _doNavigate(auth.isAuthenticated);
  }

  Future<void> _doNavigate(bool isAuthenticated) async {
    if (_navTriggered) return;
    _navTriggered = true;

    // Minimum visual dwell so the splash doesn't flash by too fast
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _exitCtrl.forward();
    if (!mounted) return;
    context.go(isAuthenticated ? '/home' : '/login');
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // React to auth state changes (fires when _checkAuth completes)
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.initialized && !(previous?.initialized ?? false)) {
        _tryNavigate();
      }
    });

    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.primaryDarkGreen,
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Decorative background ────────────────────────────────────────
            CustomPaint(
              painter: _SplashBackgroundPainter(),
              size: size,
            ),

            // ── Centered brand content ───────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo badge
                  ScaleTransition(
                    scale: _iconScale,
                    child: FadeTransition(
                      opacity: _iconOpacity,
                      child: _LogoBadge(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App name
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Text(
                        'KMS Connect',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Platform Rekrutmen PMI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Loading indicator
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo badge widget ─────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.eco_rounded,
                size: 46,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────
class _SplashBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient
    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1B4D27), // deep forest green
        Color(0xFF2B6E36), // primary brand green
        Color(0xFF3D8B4E), // medium green
      ],
      stops: [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      gradientRect,
      Paint()..shader = gradient.createShader(gradientRect),
    );

    // Decorative circles — organic feel
    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Large circle top-right
    canvas.drawCircle(
      Offset(size.width * 1.05, -size.height * 0.08),
      size.width * 0.65,
      bubblePaint,
    );

    // Medium circle bottom-left
    canvas.drawCircle(
      Offset(-size.width * 0.15, size.height * 1.05),
      size.width * 0.55,
      bubblePaint,
    );

    // Small accent circles
    final accentPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.2),
      size.width * 0.3,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      size.width * 0.22,
      accentPaint,
    );

    // Subtle leaf-arc shapes
    _drawLeafArc(
      canvas,
      Offset(size.width * 0.72, size.height * 0.16),
      size.width * 0.18,
      -math.pi / 5,
      Colors.white.withValues(alpha: 0.05),
    );
    _drawLeafArc(
      canvas,
      Offset(size.width * 0.2, size.height * 0.82),
      size.width * 0.14,
      math.pi / 4,
      Colors.white.withValues(alpha: 0.05),
    );

    // Bottom wave
    final wavePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.82);
    wavePath.cubicTo(
      size.width * 0.25, size.height * 0.76,
      size.width * 0.55, size.height * 0.88,
      size.width, size.height * 0.80,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);
  }

  void _drawLeafArc(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final path = Path()
      ..moveTo(0, -radius)
      ..cubicTo(radius, -radius, radius, radius, 0, radius)
      ..cubicTo(-radius, radius, -radius, -radius, 0, -radius)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
