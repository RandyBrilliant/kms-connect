import 'package:flutter/material.dart';

/// Reusable professional auth gradient + pattern background.
class ProfessionalGradientBackground extends StatelessWidget {
  const ProfessionalGradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF075B31),
            Color(0xFF0A7A43),
            Color(0xFF0E8E50),
            Color(0xFF149E5D),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _AuthPatternPainter()),
          child,
        ],
      ),
    );
  }
}

class _AuthPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gap = 36.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    final glowA = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.12, size.height * 0.08),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.08),
      size.width * 0.45,
      glowA,
    );

    final glowB = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.12),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.92),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.92),
      size.width * 0.55,
      glowB,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
