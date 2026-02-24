import 'package:flutter/material.dart';

/// Reusable green-wave header used on the login and registration screens.
///
/// Renders a [ClipPath]-ed [CustomPaint] that draws a green gradient with
/// decorative circle accents and a gentle wave at the bottom edge.
///
/// ```dart
/// AuthWaveHeader(height: headerH)
/// ```
class AuthWaveHeader extends StatelessWidget {
  const AuthWaveHeader({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const AuthWaveClipper(),
      child: CustomPaint(
        painter: const AuthWavePainter(),
        child: SizedBox(width: double.infinity, height: height),
      ),
    );
  }
}

/// Wave-shaped clipper shared by [AuthWaveHeader].
///
/// Draws a gentle double-arc wave at the bottom so the header blends
/// organically into the white form panel below.
class AuthWaveClipper extends CustomClipper<Path> {
  const AuthWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 36)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height + 18,
        size.width * 0.55,
        size.height - 18,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height - 54,
        size.width,
        size.height - 20,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> _) => false;
}

/// Gradient + decorative circles painter shared by [AuthWaveHeader].
class AuthWavePainter extends CustomPainter {
  const AuthWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Primary gradient
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B4D27), Color(0xFF2B6E36), Color(0xFF3A7D44)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Large decorative circles (subtle, semi-transparent)
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.85, -size.height * 0.1), size.width * 0.5, p);
    canvas.drawCircle(
        Offset(-size.width * 0.1, size.height * 0.9), size.width * 0.4, p);

    // Smaller accent circle
    final p2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.15), size.width * 0.28, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
