import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A [CustomPaint] widget that draws the official four-colour Google "G" ring.
///
/// Drop it into any button `icon:` slot or wrap it in a [SizedBox] for
/// explicit sizing.
///
/// ```dart
/// OutlinedButton.icon(
///   icon: const GoogleLogoIcon(),
///   label: Text('Continue with Google'),
///   ...
/// )
/// ```
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  /// Diameter of the painted logo in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.39;
    final rect = Rect.fromCircle(center: center, radius: r);

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        rect, -math.pi * 0.20, math.pi * 0.70, false, arc(const Color(0xFF4285F4)));
    canvas.drawArc(
        rect, math.pi * 0.50, math.pi * 0.50, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(
        rect, math.pi * 1.00, math.pi * 0.50, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(
        rect, math.pi * 1.50, math.pi * 0.50, false, arc(const Color(0xFFEA4335)));

    // Horizontal bar on the right ("G" cutout illusion)
    canvas.drawLine(
      center,
      Offset(center.dx + r, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.15
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
