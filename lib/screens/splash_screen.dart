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

  // Animation timing constants (matching JSX frame counts at ~60fps)
  static const double _spiralSpeed = 0.0032;
  static const double _textSpeed = 0.007;
  static const int _pauseFrames = 50;
  static const int _holdFrames = 180;
  static const int _resetPauseFrames = 60;

  // Animation state
  SpiralAnimationPhase _phase = SpiralAnimationPhase.spiralIn;
  double _progress = 0.0;
  double _textRevealProgress = 0.0;
  double _time = 0.0;
  int _holdCounter = 0;
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

    // Increment time for continuous animations (wobble, squiggle)
    _time += 0.016; // ~60fps

    switch (_phase) {
      case SpiralAnimationPhase.spiralIn:
        _progress += _spiralSpeed;
        if (_progress >= 1.0) {
          _phase = SpiralAnimationPhase.pause;
          _progress = 0.0;
          _holdCounter = 0;
        }
        break;

      case SpiralAnimationPhase.pause:
        _holdCounter++;
        if (_holdCounter >= _pauseFrames) {
          _phase = SpiralAnimationPhase.textOut;
          _textRevealProgress = 0.0;
        }
        break;

      case SpiralAnimationPhase.textOut:
        _textRevealProgress += _textSpeed;
        if (_textRevealProgress >= 1.0) {
          _phase = SpiralAnimationPhase.hold;
          _textRevealProgress = 1.0;
          _holdCounter = 0;
        }
        break;

      case SpiralAnimationPhase.hold:
        _holdCounter++;
        if (_holdCounter >= _holdFrames) {
          _phase = SpiralAnimationPhase.resetPause;
          _progress = 0.0;
          _holdCounter = 0;
        }
        break;

      case SpiralAnimationPhase.resetPause:
        _holdCounter++;
        _progress = _holdCounter / _resetPauseFrames;
        if (_holdCounter >= _resetPauseFrames) {
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
