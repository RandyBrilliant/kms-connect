import 'package:flutter/material.dart';

/// Decorative geometric shapes for professional backgrounds
/// Adds visual interest without being distracting
class GeometricDecoration extends StatelessWidget {
  const GeometricDecoration({
    super.key,
    this.opacity = 0.05,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GeometricDecorationPainter(opacity: opacity),
      child: const SizedBox.expand(),
    );
  }
}

class _GeometricDecorationPainter extends CustomPainter {
  _GeometricDecorationPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0x07FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Top right circle
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      60,
      paint,
    );

    // Top right ring
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      100,
      strokePaint,
    );

    // Bottom left triangle
    final trianglePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.85)
      ..lineTo(size.width * 0.2, size.height * 0.85)
      ..lineTo(size.width * 0.15, size.height * 0.95)
      ..close();
    canvas.drawPath(trianglePath, paint);

    // Bottom left hexagon outline
    final hexagonPath = Path();
    final hexCenter = Offset(size.width * 0.15, size.height * 0.9);
    const hexRadius = 40.0;
    hexagonPath.moveTo(
      hexCenter.dx + hexRadius * 0.866025,
      hexCenter.dy - hexRadius * 0.5,
    );
    for (int i = 1; i < 6; i++) {
      hexagonPath.lineTo(
        hexCenter.dx + hexRadius * 0.866025 * (i % 2 == 0 ? -1 : 1),
        hexCenter.dy + hexRadius * (i < 3 ? -0.5 : 0.5) * (i == 2 || i == 4 ? -1 : 1),
      );
    }
    hexagonPath.close();
    canvas.drawPath(hexagonPath, strokePaint);

    // Center right small circles cluster
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.5),
      15,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.52),
      10,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.48),
      8,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
