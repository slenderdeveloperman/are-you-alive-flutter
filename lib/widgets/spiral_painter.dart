import 'dart:math';
import 'package:flutter/material.dart';

/// CustomPainter that draws an Archimedean spiral that can collapse inward.
///
/// The [progress] parameter controls the collapse animation:
/// - 0.0 = full spiral visible (4 rotations from center outward)
/// - 1.0 = spiral collapsed to a point at center
class SpiralPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SpiralPainter({
    required this.progress,
    this.color = Colors.black,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;

    // Collapse the spiral by reducing the effective radius
    final currentRadius = maxRadius * (1 - progress);

    // Don't draw if collapsed
    if (currentRadius < 1) return;

    final path = Path();
    const rotations = 4;
    const points = 200;

    for (int i = 0; i < points; i++) {
      final t = i / points;
      final angle = t * rotations * 2 * pi;
      final radius = t * currentRadius;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpiralPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
