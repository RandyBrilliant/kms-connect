import 'package:flutter/material.dart';
import '../../../config/colors.dart';

/// Professional gradient background with subtle geometric patterns
/// Used for splash and login screens to create visual depth
class ProfessionalGradientBackground extends StatelessWidget {
  const ProfessionalGradientBackground({
    super.key,
    this.child,
    this.withGeometricPattern = true,
  });

  final Widget? child;
  final bool withGeometricPattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.professionalGradient),
      child: Stack(
        children: [
          // Subtle geometric pattern overlay
          if (withGeometricPattern)
            Positioned.fill(
              child: CustomPaint(painter: _GeometricPatternPainter()),
            ),

          ?child,
        ],
      ),
    );
  }
}

/// Subtle geometric pattern painter for professional background
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw subtle diagonal lines
    const spacing = 60.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    // Draw subtle circles in corners
    final circlePaint = Paint()
      ..color = const Color(0x05FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Top right
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      80,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      140,
      circlePaint,
    );

    // Bottom left
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.9),
      100,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.9),
      160,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
