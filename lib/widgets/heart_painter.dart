import 'package:flutter/material.dart';

class HeartPainter extends CustomPainter {
  final double fillAmount;

  HeartPainter({required this.fillAmount});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Create heart path
    final heartPath = Path();

    // Starting point at bottom center
    heartPath.moveTo(width / 2, height);

    // Left curve
    heartPath.cubicTo(
      width * 0.1, height * 0.7,
      0, height * 0.5,
      0, height * 0.3,
    );

    // Left top curve
    heartPath.cubicTo(
      0, height * 0.05,
      width * 0.35, height * 0.05,
      width / 2, height * 0.2,
    );

    // Right top curve
    heartPath.cubicTo(
      width * 0.65, height * 0.05,
      width, height * 0.05,
      width, height * 0.3,
    );

    // Right curve back to bottom
    heartPath.cubicTo(
      width, height * 0.5,
      width * 0.9, height * 0.7,
      width / 2, height,
    );

    heartPath.close();

    // Draw heart outline
    final outlinePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(heartPath, outlinePaint);

    // Draw filled portion
    if (fillAmount > 0) {
      canvas.save();
      canvas.clipPath(heartPath);

      // Calculate fill rect from bottom
      final fillHeight = height * fillAmount;
      final fillRect = Rect.fromLTWH(
        0,
        height - fillHeight,
        width,
        fillHeight,
      );

      // Gradient fill
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.withValues(alpha: 0.9),
            const Color(0xFF990000),
          ],
        ).createShader(fillRect);

      canvas.drawRect(fillRect, fillPaint);

      canvas.restore();
    }

    // Draw glow effect
    if (fillAmount > 0) {
      final glowPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.1 * fillAmount)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawPath(heartPath, glowPaint);
    }
  }

  @override
  bool shouldRepaint(HeartPainter oldDelegate) {
    return oldDelegate.fillAmount != fillAmount;
  }
}
