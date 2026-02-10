import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _playSplashSound();
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      widget.onComplete();
    });
  }

  Future<void> _playSplashSound() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(AssetSource('sounds/eerie_beep.mp3'));
    } catch (_) {
      // Continue silently if audio fails; splash should still proceed.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
