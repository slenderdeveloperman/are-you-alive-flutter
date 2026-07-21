import 'package:flutter/material.dart';
import '../widgets/spiral_painter.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Duration _lastElapsed = Duration.zero;

  // Animation timing constants (matching JSX frame counts at ~60fps),
  // expressed as per-second rates / second durations so playback speed is
  // independent of the device's actual display refresh rate.
  static const double _spiralSpeedPerSecond = 0.0032 * 60;
  static const double _textSpeedPerSecond = 0.007 * 60;
  static const double _timeSpeedPerSecond = 1.0; // _time tracks real seconds
  static const double _pauseSeconds = 50 / 60.0;
  static const double _holdSeconds = 180 / 60.0;
  static const double _resetPauseSeconds = 60 / 60.0;

  // Animation state
  SpiralAnimationPhase _phase = SpiralAnimationPhase.spiralIn;
  double _progress = 0.0;
  double _textRevealProgress = 0.0;
  double _time = 0.0;
  double _holdElapsed = 0.0; // seconds, replaces frame-counted _holdCounter
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Continuous ticker
    )..addListener(_onTick);
    _controller.repeat();
  }

  void _onTick() {
    if (!mounted) return;

    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final deltaSeconds =
        (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = deltaSeconds.clamp(0.0, 0.1); // guard against pause jumps

    _time += dt * _timeSpeedPerSecond;

    switch (_phase) {
      case SpiralAnimationPhase.spiralIn:
        _progress += _spiralSpeedPerSecond * dt;
        if (_progress >= 1.0) {
          _phase = SpiralAnimationPhase.pause;
          _progress = 0.0;
          _holdElapsed = 0.0;
        }
        break;

      case SpiralAnimationPhase.pause:
        _holdElapsed += dt;
        if (_holdElapsed >= _pauseSeconds) {
          _phase = SpiralAnimationPhase.textOut;
          _textRevealProgress = 0.0;
        }
        break;

      case SpiralAnimationPhase.textOut:
        _textRevealProgress += _textSpeedPerSecond * dt;
        if (_textRevealProgress >= 1.0) {
          _phase = SpiralAnimationPhase.hold;
          _textRevealProgress = 1.0;
          _holdElapsed = 0.0;
        }
        break;

      case SpiralAnimationPhase.hold:
        _holdElapsed += dt;
        if (_holdElapsed >= _holdSeconds) {
          _phase = SpiralAnimationPhase.resetPause;
          _progress = 0.0;
          _holdElapsed = 0.0;
        }
        break;

      case SpiralAnimationPhase.resetPause:
        _holdElapsed += dt;
        _progress = (_holdElapsed / _resetPauseSeconds).clamp(0.0, 1.0);
        if (_holdElapsed >= _resetPauseSeconds) {
          // Animation complete - transition to next screen
          if (!_hasCompleted) {
            _hasCompleted = true;
            widget.onComplete();
          }
        }
        break;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: CustomPaint(
          painter: SpiralAnimationPainter(
            progress: _progress,
            phase: _phase,
            time: _time,
            textRevealProgress: _textRevealProgress,
          ),
        ),
      ),
    );
  }
}
