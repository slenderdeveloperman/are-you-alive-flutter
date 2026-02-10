import 'package:flutter/material.dart';

class HeartPainter extends CustomPainter {
  final double fillAmount;
  final bool isActive;
  final double decayLevel; // 0.0 = healthy, 1.0 = dead

  HeartPainter({
    required this.fillAmount,
    this.isActive = true,
    this.decayLevel = 0.0,
  });

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

    // Calculate decay-adjusted colors
    final effectiveDecay = decayLevel.clamp(0.0, 1.0);

    // Base colors
    final Color healthyOutline = Colors.red.withValues(alpha: 0.3);
    final Color deadOutline = Colors.grey.withValues(alpha: 0.3);
    final Color healthyFillTop = Colors.red.withValues(alpha: 0.9);
    final Color deadFillTop = Colors.grey.withValues(alpha: 0.4);
    final Color healthyFillBottom = const Color(0xFF990000);
    final Color deadFillBottom = const Color(0xFF333333);
    final Color healthyGlow = Colors.red.withValues(alpha: 0.1 * fillAmount);
    final Color deadGlow = Colors.grey.withValues(alpha: 0.02 * fillAmount);

    // Lerp colors based on decay level
    Color outlineColor;
    Color fillColorTop;
    Color fillColorBottom;
    Color glowColor;

    if (isActive) {
      outlineColor = Color.lerp(healthyOutline, deadOutline, effectiveDecay)!;
      fillColorTop = Color.lerp(healthyFillTop, deadFillTop, effectiveDecay)!;
      fillColorBottom = Color.lerp(healthyFillBottom, deadFillBottom, effectiveDecay)!;
      glowColor = Color.lerp(healthyGlow, deadGlow, effectiveDecay)!;
    } else {
      // Inactive state (before check-in) - grey colors
      outlineColor = Colors.grey.withValues(alpha: 0.3);
      fillColorTop = Color.lerp(
        Colors.grey.withValues(alpha: 0.6),
        Colors.grey.withValues(alpha: 0.3),
        effectiveDecay,
      )!;
      fillColorBottom = Color.lerp(
        const Color(0xFF444444),
        const Color(0xFF222222),
        effectiveDecay,
      )!;
      glowColor = Colors.grey.withValues(alpha: 0.05 * fillAmount);
    }

    // Draw heart outline
    final outlinePaint = Paint()
      ..color = outlineColor
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
            fillColorTop,
            fillColorBottom,
          ],
        ).createShader(fillRect);

      canvas.drawRect(fillRect, fillPaint);

      canvas.restore();
    }

    // Draw cracks based on decay level
    if (effectiveDecay > 0.25) {
      _drawCracks(canvas, size, effectiveDecay, isActive);
    }

    // Draw glow effect (reduced as decay increases)
    if (fillAmount > 0) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawPath(heartPath, glowPaint);
    }
  }

  void _drawCracks(Canvas canvas, Size size, double decay, bool active) {
    final width = size.width;
    final height = size.height;

    // Crack color - darker as decay increases
    final crackColor = active
        ? Color.lerp(
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.7),
            decay,
          )!
        : Color.lerp(
            Colors.black.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.5),
            decay,
          )!;

    final crackPaint = Paint()
      ..color = crackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Stage 1 cracks (decay 0.25 - 0.50): Minor cracks from center
    if (decay >= 0.25) {
      final crack1 = Path();
      crack1.moveTo(width * 0.5, height * 0.4);
      crack1.lineTo(width * 0.45, height * 0.5);
      crack1.lineTo(width * 0.48, height * 0.55);
      canvas.drawPath(crack1, crackPaint);
    }

    // Stage 2 cracks (decay 0.50 - 0.75): More visible cracks
    if (decay >= 0.50) {
      final crack2 = Path();
      crack2.moveTo(width * 0.5, height * 0.4);
      crack2.lineTo(width * 0.55, height * 0.48);
      crack2.lineTo(width * 0.58, height * 0.52);
      canvas.drawPath(crack2, crackPaint);

      final crack3 = Path();
      crack3.moveTo(width * 0.45, height * 0.5);
      crack3.lineTo(width * 0.38, height * 0.55);
      canvas.drawPath(crack3, crackPaint);
    }

    // Stage 3 cracks (decay 0.75 - 1.0): Heavy cracks
    if (decay >= 0.75) {
      crackPaint.strokeWidth = 2.0;

      final crack4 = Path();
      crack4.moveTo(width * 0.48, height * 0.55);
      crack4.lineTo(width * 0.45, height * 0.65);
      crack4.lineTo(width * 0.5, height * 0.75);
      canvas.drawPath(crack4, crackPaint);

      final crack5 = Path();
      crack5.moveTo(width * 0.58, height * 0.52);
      crack5.lineTo(width * 0.65, height * 0.58);
      crack5.lineTo(width * 0.62, height * 0.65);
      canvas.drawPath(crack5, crackPaint);

      // Upper cracks
      final crack6 = Path();
      crack6.moveTo(width * 0.3, height * 0.25);
      crack6.lineTo(width * 0.35, height * 0.32);
      crack6.lineTo(width * 0.4, height * 0.35);
      canvas.drawPath(crack6, crackPaint);

      final crack7 = Path();
      crack7.moveTo(width * 0.7, height * 0.25);
      crack7.lineTo(width * 0.65, height * 0.32);
      crack7.lineTo(width * 0.6, height * 0.35);
      canvas.drawPath(crack7, crackPaint);
    }

    // Stage 4: Expired (decay >= 1.0) - Additional fracture lines
    if (decay >= 1.0) {
      crackPaint.strokeWidth = 2.5;

      // Deep center crack
      final crack8 = Path();
      crack8.moveTo(width * 0.5, height * 0.3);
      crack8.lineTo(width * 0.48, height * 0.4);
      crack8.lineTo(width * 0.52, height * 0.5);
      crack8.lineTo(width * 0.5, height * 0.6);
      crack8.lineTo(width * 0.48, height * 0.7);
      crack8.lineTo(width * 0.5, height * 0.85);
      canvas.drawPath(crack8, crackPaint);
    }
  }

  @override
  bool shouldRepaint(HeartPainter oldDelegate) {
    return oldDelegate.fillAmount != fillAmount ||
        oldDelegate.isActive != isActive ||
        oldDelegate.decayLevel != decayLevel;
  }
}
