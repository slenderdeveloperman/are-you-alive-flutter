import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/motion_tokens.dart';

/// A particle system overlay for the heart widget.
/// - Check-in: Emits upward-floating life particles (red/pink glow)
/// - Decay: Emits downward-drifting dust particles (grey ash)
class HeartParticles extends StatefulWidget {
  const HeartParticles({
    super.key,
    required this.heartSize,
    this.isCheckingIn = false,
    this.decayLevel = 0.0,
  });

  /// Size of the heart widget (particles spawn relative to this).
  final Size heartSize;

  /// When true, triggers a burst of upward life particles.
  final bool isCheckingIn;

  /// Decay level 0.0-1.0. When > 0.5, emits continuous dust particles.
  final double decayLevel;

  @override
  State<HeartParticles> createState() => _HeartParticlesState();
}

class _HeartParticlesState extends State<HeartParticles>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _particles = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  late AnimationController _tickController;
  bool _hasTriggeredCheckIn = false;

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _tickController.addListener(_updateParticles);
    _startDecaySpawner();
  }

  @override
  void didUpdateWidget(HeartParticles oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger life particles on check-in transition (false -> true)
    if (widget.isCheckingIn && !_hasTriggeredCheckIn) {
      _hasTriggeredCheckIn = true;
      _spawnLifeParticles();
    } else if (!widget.isCheckingIn) {
      _hasTriggeredCheckIn = false;
    }

    // Update decay spawner if decay level changed significantly
    if ((widget.decayLevel > 0.5) != (oldWidget.decayLevel > 0.5)) {
      _startDecaySpawner();
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  void _startDecaySpawner() {
    _spawnTimer?.cancel();
    if (widget.decayLevel > 0.5) {
      // Spawn dust particles periodically when decaying
      _spawnTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (mounted && widget.decayLevel > 0.5) {
          _spawnDustParticle();
        }
      });
    }
  }

  void _spawnLifeParticles() {
    // Spawn 8-12 life particles in a burst
    final count = 8 + _random.nextInt(5);
    // Reduced motion: keep the fade feedback, cut travel distance to ~25%.
    final velocityScale = MotionTokens.reducedMotion ? 0.25 : 1.0;
    for (var i = 0; i < count; i++) {
      final particle = _Particle(
        type: _ParticleType.life,
        x: widget.heartSize.width / 2 + (_random.nextDouble() - 0.5) * 60,
        y: widget.heartSize.height * 0.4 + (_random.nextDouble() - 0.5) * 40,
        vx: (_random.nextDouble() - 0.5) * 30 * velocityScale,
        vy: (-40 - _random.nextDouble() * 40) * velocityScale, // Float upward
        size: 3 + _random.nextDouble() * 4,
        lifetime: 1.5 + _random.nextDouble() * 0.5,
        age: 0,
        color: _random.nextBool()
            ? Colors.red.withValues(alpha: 0.8)
            : Colors.pink.withValues(alpha: 0.7),
      );
      _particles.add(particle);
    }
    _ensureTicking();
  }

  void _spawnDustParticle() {
    // Spawn 1-2 dust particles
    final count = 1 + _random.nextInt(2);
    final velocityScale = MotionTokens.reducedMotion ? 0.25 : 1.0;
    for (var i = 0; i < count; i++) {
      final particle = _Particle(
        type: _ParticleType.dust,
        x: widget.heartSize.width / 2 + (_random.nextDouble() - 0.5) * 80,
        y: widget.heartSize.height * 0.5 + (_random.nextDouble() - 0.5) * 30,
        vx: (_random.nextDouble() - 0.5) * 15 * velocityScale,
        vy: (15 + _random.nextDouble() * 20) * velocityScale, // Drift downward
        size: 2 + _random.nextDouble() * 3,
        lifetime: 2.0 + _random.nextDouble() * 1.0,
        age: 0,
        color: Colors.grey.withValues(alpha: 0.5 + _random.nextDouble() * 0.3),
      );
      _particles.add(particle);
    }
    _ensureTicking();
  }

  /// Starts the tick loop if it isn't already running. Call this any time a
  /// particle is added so the controller wakes back up.
  void _ensureTicking() {
    if (!_tickController.isAnimating) {
      _tickController.repeat();
    }
  }

  void _updateParticles() {
    if (!mounted) return;

    const dt = 1 / 60; // Assume ~60fps
    final toRemove = <_Particle>[];

    for (final particle in _particles) {
      particle.age += dt;

      if (particle.age >= particle.lifetime) {
        toRemove.add(particle);
        continue;
      }

      // Update position
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;

      // Add slight deceleration
      particle.vx *= 0.98;
      particle.vy *= 0.98;

      // Life particles slow down as they rise
      if (particle.type == _ParticleType.life) {
        particle.vy += 8 * dt; // Slight gravity to slow rise
      }
    }

    _particles.removeWhere((p) => toRemove.contains(p));

    if (mounted) {
      setState(() {});
    }

    if (_particles.isEmpty && _tickController.isAnimating) {
      _tickController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widget.heartSize,
      painter: _ParticlePainter(particles: _particles),
    );
  }
}

enum _ParticleType { life, dust }

class _Particle {
  _Particle({
    required this.type,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.lifetime,
    required this.age,
    required this.color,
  });

  final _ParticleType type;
  double x;
  double y;
  double vx;
  double vy;
  final double size;
  final double lifetime;
  double age;
  final Color color;

  double get opacity => (1.0 - (age / lifetime)).clamp(0.0, 1.0);
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles});

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity * particle.color.a)
        ..style = PaintingStyle.fill;

      // Add glow for life particles
      if (particle.type == _ParticleType.life) {
        final glowPaint = Paint()
          ..color = particle.color.withValues(alpha: particle.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          particle.size * 1.5,
          glowPaint,
        );
      }

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * particle.opacity,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
