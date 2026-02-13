import 'dart:math';
import 'package:flutter/material.dart';

/// CustomPainter that renders the "ARE YOU ALIVE?" looping animation.
///
/// Animation phases:
/// - TRAVEL (0-3s): Pipe moves right→left, revealing text
/// - HOLD (3-5.5s): Text visible, pipe blinks at rest
/// - FADE (5.5-6.3s): Everything fades out
/// - PAUSE (6.3-7.5s): Blank screen
/// Ported from AreYouAlive-loop.jsx
class _AreYouAliveLoopPainter extends CustomPainter {
  _AreYouAliveLoopPainter({
    required this.time,
  });

  final double time;

  // Virtual canvas dimensions (matches JSX)
  static const double _canvasWidth = 550.0;
  static const double _canvasHeight = 550.0;

  // Text configuration
  static const String _text = 'ARE YOU ALIVE?';
  static const double _charSpacing = 18.0;
  static const double _pipeHeight = 38.0;

  // Timing (seconds)
  static const double _travelDuration = 3.0;
  static const double _holdDuration = 2.5;
  static const double _fadeDuration = 0.8;
  static const double _pauseDuration = 1.2;
  static const double _totalCycle =
      _travelDuration + _holdDuration + _fadeDuration + _pauseDuration;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale to fit the actual canvas while maintaining aspect ratio
    final scale = min(size.width / _canvasWidth, size.height / _canvasHeight);
    canvas.save();

    // Center the scaled content
    final scaledWidth = _canvasWidth * scale;
    final scaledHeight = _canvasHeight * scale;
    canvas.translate(
      (size.width - scaledWidth) / 2,
      (size.height - scaledHeight) / 2,
    );
    canvas.scale(scale, scale);

    // Calculate text layout positions
    final textTotalWidth = _text.length * _charSpacing;
    final textLeftX = _canvasWidth / 2 - textTotalWidth / 2;
    final textY = _canvasHeight / 2;

    // Pipe travels from right of text to left of text
    final pipeStartX = textLeftX + textTotalWidth + 10;
    final pipeEndX = textLeftX - 16;

    // Determine current phase and progress within cycle
    final cycleTime = time % _totalCycle;

    if (cycleTime < _travelDuration) {
      // TRAVEL: Pipe moves from right to left, revealing text
      final t = _easeInOut(cycleTime / _travelDuration);
      final pipeX = pipeStartX + (pipeEndX - pipeStartX) * t;

      _drawText(canvas, pipeX, textLeftX, textY, 1.0);
      _drawPipe(canvas, pipeX, textY, 1.0);
    } else if (cycleTime < _travelDuration + _holdDuration) {
      // HOLD: Full text visible, pipe at rest blinking
      _drawText(canvas, pipeEndX, textLeftX, textY, 1.0);
      _drawPipe(canvas, pipeEndX, textY, 1.0);
    } else if (cycleTime < _travelDuration + _holdDuration + _fadeDuration) {
      // FADE: Everything fades out
      final fadeT =
          (cycleTime - _travelDuration - _holdDuration) / _fadeDuration;
      final alpha = 1.0 - fadeT;
      _drawText(canvas, pipeEndX, textLeftX, textY, alpha);
      _drawPipe(canvas, pipeEndX, textY, alpha);
    }
    // PAUSE: Nothing drawn (blank)

    canvas.restore();
  }

  /// Easing function matching JSX: easeInOut
  double _easeInOut(double t) {
    return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
  }

  /// Draw the blinking pipe cursor
  void _drawPipe(Canvas canvas, double x, double y, double alpha) {
    // Blink: on/off cycle based on time
    final blink = sin(time * 5.5) > -0.15;
    if (!blink) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw multiple strokes for depth effect
    for (int stroke = 0; stroke < 3; stroke++) {
      final ox = sin(stroke * 7.7 + time * 0.3) * 0.5;
      final oy = cos(stroke * 5.3 + time * 0.2) * 0.3;

      final path = Path();
      path.moveTo(x + ox, y - _pipeHeight / 2 + oy);
      path.quadraticBezierTo(
        x + ox + sin(stroke * 3.1) * 0.8,
        y + oy,
        x + ox,
        y + _pipeHeight / 2 + oy,
      );

      paint
        ..color = Color.fromRGBO(255, 255, 255, alpha * (0.7 + stroke * 0.1))
        ..strokeWidth = 3.5 - stroke * 0.5;
      canvas.drawPath(path, paint);
    }
  }

  /// Draw the squiggly text with character-by-character reveal
  void _drawText(
      Canvas canvas, double pipeCurrentX, double textLeftX, double textY, double alpha) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < _text.length; i++) {
      // Per-character wobble using seed
      final seed = i * 0.8;
      final wx = sin(seed * 2.1 + i * 1.3) * 1.5;
      final wy = cos(seed * 1.7 + i * 0.9) * 2.0;
      final wr = sin(seed * 1.3 + i * 2.1) * 0.04;

      final cx = textLeftX + i * _charSpacing + _charSpacing / 2 + wx;
      final cy = textY + wy;

      // Only show if pipe has passed this character (character is to the right of pipe)
      final charCenter = textLeftX + i * _charSpacing + _charSpacing / 2;
      if (charCenter < pipeCurrentX + 8) continue;

      // Fade in based on distance from pipe
      final dist = charCenter - (pipeCurrentX + 8);
      final charAlpha = min(1.0, dist / 14 + 0.2) * alpha;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(wr);

      // Draw text with slight offset for depth (2 passes)
      for (int s = 0; s < 2; s++) {
        textPainter.text = TextSpan(
          text: _text[i],
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color.fromRGBO(255, 255, 255, charAlpha),
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
  bool shouldRepaint(_AreYouAliveLoopPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

/// Widget that displays the continuously looping "ARE YOU ALIVE?" animation.
///
/// The animation cycles through:
/// 1. TRAVEL (3.0s): Pipe moves right→left, revealing characters
/// 2. HOLD (2.5s): Text visible, pipe blinks
/// 3. FADE (0.8s): Everything fades out
/// 4. PAUSE (1.2s): Blank
/// Total cycle: 7.5 seconds
class AreYouAliveLoop extends StatefulWidget {
  const AreYouAliveLoop({super.key});

  @override
  State<AreYouAliveLoop> createState() => _AreYouAliveLoopState();
}

class _AreYouAliveLoopState extends State<AreYouAliveLoop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Run continuously - we track time manually for the animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Arbitrary, we loop forever
    )..addListener(_onTick);

    _controller.repeat();
  }

  void _onTick() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final deltaSeconds = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // Clamp delta to prevent large jumps (e.g., after app pause)
    final clampedDelta = deltaSeconds.clamp(0.0, 0.1);

    setState(() {
      _time += clampedDelta;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AreYouAliveLoopPainter(time: _time),
      size: Size.infinite,
    );
  }
}
