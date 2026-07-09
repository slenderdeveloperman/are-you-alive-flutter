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

/// Animation phases matching the original JSX implementation
enum SpiralAnimationPhase {
  spiralIn,
  pause,
  textOut,
  hold,
  resetPause,
}

/// Holds pre-computed spiral point data
class _SpiralPoint {
  const _SpiralPoint({
    required this.x,
    required this.y,
    required this.angle,
    required this.radius,
  });

  final double x;
  final double y;
  final double angle;
  final double radius;
}

/// CustomPainter that renders the full splash spiral animation with text reveal.
/// Ported from AreYouAlive-animation.jsx
class SpiralAnimationPainter extends CustomPainter {
  SpiralAnimationPainter({
    required this.progress,
    required this.phase,
    required this.time,
    required this.textRevealProgress,
  });

  final double progress;
  final SpiralAnimationPhase phase;
  final double time;
  final double textRevealProgress;

  // Spiral geometry constants (from JSX)
  static const double totalTurns = 5.2;
  static const int totalSteps = 800;
  static const double maxRadius = 180;
  static const double minRadius = 6;
  static const double pipeHeight = 38;
  static const double pipeWidth = 3.5;

  static const String text = 'ARE YOU ALIVE?';
  static const double charSpacing = 18;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale factor to fit the 550x550 design into the actual canvas size
    // and center the drawing area within the viewport.
    const canvasSize = 550.0;
    final scale = min(size.width, size.height) / canvasSize;
    final offsetX = (size.width - canvasSize * scale) / 2;
    final offsetY = (size.height - canvasSize * scale) / 2;
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // Draw on a virtual 550x550 canvas
    final centerX = canvasSize / 2;
    final centerY = canvasSize / 2;

    // Generate spiral points
    final spiralPoints = _generateSpiralPoints(centerX, centerY);

    // Calculate pipe position
    final outerPoint = spiralPoints.last;
    final pipeRestX = outerPoint.x - 12;
    final pipeRestY = outerPoint.y;

    // Calculate text position
    final textTotalWidth = text.length * charSpacing;
    final textLeftX = canvasSize / 2 - textTotalWidth / 2;
    final pipeEndX = textLeftX - 20;

    switch (phase) {
      case SpiralAnimationPhase.spiralIn:
        _drawSpiral(canvas, spiralPoints, progress);
        final pipeAlpha = min(1.0, progress * 3);
        _drawPipe(canvas, pipeRestX, pipeRestY, pipeAlpha);
        break;

      case SpiralAnimationPhase.pause:
        _drawPipe(canvas, pipeRestX, pipeRestY, 1.0);
        break;

      case SpiralAnimationPhase.textOut:
        // Ease-out animation for pipe movement
        final eased = 1 - pow(1 - textRevealProgress, 2.5);
        final pipeCurrentX = pipeRestX + (pipeEndX - pipeRestX) * eased;
        _drawPipe(canvas, pipeCurrentX, pipeRestY, 1.0);
        _drawSquigglyText(canvas, pipeCurrentX, pipeRestY, textLeftX, 1.0);
        break;

      case SpiralAnimationPhase.hold:
        _drawPipe(canvas, pipeEndX, pipeRestY, 1.0);
        _drawSquigglyText(canvas, pipeEndX, pipeRestY, textLeftX, 1.0);
        break;

      case SpiralAnimationPhase.resetPause:
        final fade = 1 - progress;
        _drawPipe(canvas, pipeEndX, pipeRestY, fade);
        _drawSquigglyText(canvas, pipeEndX, pipeRestY, textLeftX, fade);
        break;
    }

    canvas.restore();
  }

  List<_SpiralPoint> _generateSpiralPoints(double centerX, double centerY) {
    final points = <_SpiralPoint>[];

    for (int i = 0; i <= totalSteps; i++) {
      final t = i / totalSteps;
      final angle = t * totalTurns * pi * 2;
      final radius = minRadius + (maxRadius - minRadius) * t;
      final wobble = sin(angle * 3.1 + t * 5) * 2.2 +
          sin(angle * 7.3 + t * 11) * 1.0 +
          sin(angle * 13.7) * 0.6;
      final x = centerX + cos(angle) * (radius + wobble);
      final y = centerY + sin(angle) * (radius + wobble);
      points.add(_SpiralPoint(
        x: x,
        y: y,
        angle: angle,
        radius: radius + wobble,
      ));
    }

    return points;
  }

  void _drawSpiral(
      Canvas canvas, List<_SpiralPoint> points, double eatProgress) {
    final startIdx = (eatProgress * (points.length - 1)).floor();
    final endIdx = points.length - 1;
    if (startIdx >= endIdx) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw two passes for depth effect
    for (int pass = 0; pass < 2; pass++) {
      final off = (pass - 0.5) * 0.7;
      paint.strokeWidth = 1.8 - pass * 0.4;
      paint.color = Color.fromRGBO(30, 30, 30, 0.85 - pass * 0.15);

      final path = Path();
      bool first = true;

      for (int i = startIdx; i <= endIdx; i++) {
        final p = points[i];
        final px = p.x + off * cos(p.angle + pi / 2);
        final py = p.y + off * sin(p.angle + pi / 2);
        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }

      canvas.drawPath(path, paint);
    }

    // Draw suction wisp at eating front
    if (eatProgress > 0.02 && eatProgress < 0.98) {
      final fp = points[startIdx];
      final np = points[min(startIdx + 8, endIdx)];
      final pullAngle = atan2(np.y - fp.y, np.x - fp.x);

      final wispPath = Path();
      wispPath.moveTo(fp.x, fp.y);
      for (int s = 1; s <= 4; s++) {
        final st = s / 4;
        wispPath.lineTo(
          fp.x + cos(pullAngle + pi) * st * 10,
          fp.y +
              sin(pullAngle + pi) * st * 10 +
              sin(time * 14 + s) * 2.5 * (1 - st),
        );
      }

      paint
        ..color = const Color.fromRGBO(30, 30, 30, 0.25)
        ..strokeWidth = 1;
      canvas.drawPath(wispPath, paint);
    }
  }

  void _drawPipe(Canvas canvas, double x, double y, double alpha) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int stroke = 0; stroke < 3; stroke++) {
      final ox = sin(stroke * 7.7 + time * 0.3) * 0.5;
      final oy = cos(stroke * 5.3 + time * 0.2) * 0.3;

      final path = Path();
      path.moveTo(x + ox, y - pipeHeight / 2 + oy);
      path.quadraticBezierTo(
        x + ox + sin(stroke * 3.1) * 0.8,
        y + oy,
        x + ox,
        y + pipeHeight / 2 + oy,
      );

      paint
        ..color = Color.fromRGBO(30, 30, 30, alpha * (0.7 + stroke * 0.1))
        ..strokeWidth = pipeWidth - stroke * 0.5;
      canvas.drawPath(path, paint);
    }
  }

  void _drawSquigglyText(Canvas canvas, double pipeCurrentX, double pipeRestY,
      double textLeftX, double alpha) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < text.length; i++) {
      final charX = textLeftX + i * charSpacing;
      final revealEdge = pipeCurrentX + 8;

      // Character is revealed when the pipe has moved past it
      if (charX + charSpacing / 2 < revealEdge) continue;

      // Fade in as pipe moves away
      final distFromPipe = (charX + charSpacing / 2) - revealEdge;
      final charAlpha = min(1.0, distFromPipe / 12 + 0.15) * alpha;

      final ct = time * 0.5 + i * 0.8;
      final wx = sin(ct * 2.1 + i * 1.3) * 1.5;
      final wy = cos(ct * 1.7 + i * 0.9) * 2.0;
      final wr = sin(ct * 1.3 + i * 2.1) * 0.04;

      canvas.save();
      canvas.translate(charX + charSpacing / 2 + wx, pipeRestY + wy);
      canvas.rotate(wr);

      // Draw text with slight offset for depth
      for (int s = 0; s < 2; s++) {
        textPainter.text = TextSpan(
          text: text[i],
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color.fromRGBO(30, 30, 30, charAlpha),
          ),
        );
        textPainter.layout();

        final offsetX = sin(i * 7.1 + s * 3.3) * 0.4;
        final offsetY = cos(i * 5.3 + s * 2.1) * 0.4;
        textPainter.paint(
          canvas,
          Offset(
            -textPainter.width / 2 + offsetX,
            -textPainter.height / 2 + offsetY,
          ),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SpiralAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.time != time ||
        oldDelegate.textRevealProgress != textRevealProgress;
  }
}
