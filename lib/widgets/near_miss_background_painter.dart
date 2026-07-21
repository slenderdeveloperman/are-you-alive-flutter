import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Generated background for the "Near Miss" share preset: no photographic
/// asset exists for this theme, so the card leans into the same
/// terminal/glitch language as the rest of the app instead of stock art.
class NearMissBackgroundPainter extends CustomPainter {
  const NearMissBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintHazardBand(canvas, size, top: true);
    _paintHazardBand(canvas, size, top: false);
    _paintCountdownRing(canvas, size);
    _paintGlitchTicks(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF1A0505), Color(0xFF050303)],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);
  }

  void _paintHazardBand(Canvas canvas, Size size, {required bool top}) {
    final bandHeight = size.height * 0.07;
    final bandTop = top ? 0.0 : size.height - bandHeight;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, bandTop, size.width, bandHeight));

    final stripePaint = Paint()..color = const Color(0xFFB3261E).withValues(alpha: 0.5);
    const stripeWidth = 22.0;
    final span = size.width + bandHeight * 2;
    for (double x = -bandHeight; x < span; x += stripeWidth * 2) {
      final path = Path()
        ..moveTo(x, bandTop + bandHeight)
        ..lineTo(x + bandHeight, bandTop)
        ..lineTo(x + bandHeight + stripeWidth, bandTop)
        ..lineTo(x + stripeWidth, bandTop + bandHeight)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    canvas.restore();
  }

  void _paintCountdownRing(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final radius = size.width * 0.42;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018;
    canvas.drawCircle(center, radius, trackPaint);

    // Swept almost all the way around: the margin left before the deadline.
    final sweepPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    const sweepAngle = math.pi * 2 * 0.94;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      sweepPaint,
    );
  }

  void _paintGlitchTicks(Canvas canvas, Size size) {
    final random = math.Random(39);
    final tickPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < 14; i++) {
      final y = random.nextDouble() * size.height;
      final x = random.nextDouble() * size.width * 0.6;
      final width = size.width * (0.08 + random.nextDouble() * 0.18);
      canvas.drawRect(Rect.fromLTWH(x, y, width, 1.4), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
