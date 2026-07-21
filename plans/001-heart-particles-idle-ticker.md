# 001 — Stop HeartParticles ticking when idle

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: HIGH
- **Category**: Performance
- **Estimated scope**: 1 file, small

## Problem

`lib/widgets/heart_particles.dart:38-46` starts an `AnimationController` with
`..repeat()` in `initState` and never stops it. The controller's listener
(`_updateParticles`) fires on every animation frame (60-120 times/sec
depending on device refresh rate) for as long as the widget is mounted —
which is effectively the entire time the app is open, since `HeartParticles`
is always present behind the heart on `HomeScreen`. Each tick calls
`setState`, forcing a `CustomPaint` rebuild, even when `_particles` is empty
— which is true almost all of the time (bursts last 1.5-3s; dust only spawns
above `decayLevel > 0.5`).

Current code:

```dart
// lib/widgets/heart_particles.dart:37-46 — current
@override
void initState() {
  super.initState();
  _tickController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  _tickController.addListener(_updateParticles);
  _startDecaySpawner();
}
```

```dart
// lib/widgets/heart_particles.dart:125-158 — current
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
}
```

This wastes a `setState`-triggered rebuild every frame, indefinitely, for
zero visual benefit almost all of the time — a real, always-on battery/frame
budget cost on a screen the user is expected to leave open.

## Target

The ticker only runs while there is something to animate. It starts when the
first particle is spawned and stops itself once `_particles` is empty again,
instead of running forever from `initState`.

```dart
// lib/widgets/heart_particles.dart:37-46 — target
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
```

```dart
// lib/widgets/heart_particles.dart — target: _updateParticles stops the ticker when empty
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

    particle.x += particle.vx * dt;
    particle.y += particle.vy * dt;

    particle.vx *= 0.98;
    particle.vy *= 0.98;

    if (particle.type == _ParticleType.life) {
      particle.vy += 8 * dt;
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

/// Starts the tick loop if it isn't already running. Call this any time a
/// particle is added so the controller wakes back up.
void _ensureTicking() {
  if (!_tickController.isAnimating) {
    _tickController.repeat();
  }
}
```

Both `_spawnLifeParticles` and `_spawnDustParticle` must call `_ensureTicking()`
after adding to `_particles`, so the controller restarts when new particles
arrive after having stopped.

## Repo conventions to follow

- This file already uses `SingleTickerProviderStateMixin` + a manually
  ticked `AnimationController` pattern (not a declarative `Tween`) — keep
  that pattern, just gate `repeat()`/`stop()` around it.
- `are_you_alive_loop.dart` is the sibling file using the same
  "controller ticks forever, driven by a listener" pattern — that one is
  intentionally always-visible (the loop animation always runs), so do NOT
  apply this stop/start pattern there. Only `heart_particles.dart` is in
  scope.

## Steps

1. In `lib/widgets/heart_particles.dart`, remove `..repeat()` from the
   `AnimationController` construction in `initState` (leave the
   `addListener(_updateParticles)` call and `_startDecaySpawner()` call as
   they are).
2. Add a private method `_ensureTicking()` that calls
   `_tickController.repeat()` only if `!_tickController.isAnimating`.
3. At the end of `_spawnLifeParticles()` (after the `for` loop that adds
   particles), call `_ensureTicking()`.
4. At the end of `_spawnDustParticle()` (after the `for` loop that adds
   particles), call `_ensureTicking()`.
5. At the end of `_updateParticles()`, after `_particles.removeWhere(...)`
   and the existing `setState` call, add: if `_particles.isEmpty` and
   `_tickController.isAnimating`, call `_tickController.stop()`.

## Boundaries

- Do NOT touch `are_you_alive_loop.dart`, `spiral_painter.dart`, or any
  other file — this plan is scoped to `heart_particles.dart` only.
- Do NOT change the particle physics (velocities, gravity, decay constants)
  — only the ticker's start/stop lifecycle.
- Do NOT add new dependencies.
- If `heart_particles.dart` no longer matches the excerpts above (drift
  since commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` from
  `~/Projects/ARE YOU ALIVE?/are-you-alive-flutter` — expect no new
  warnings/errors. `flutter test` — expect existing tests still pass.
- **Feel check**: Run the app, check in (triggers a life-particle burst) and
  confirm particles still animate identically (burst, float up, fade out).
  Then leave the app idle on the home screen with no particles active — in
  DevTools' Performance/Widget rebuild overlay, confirm `HeartParticles` is
  no longer rebuilding every frame while idle. Let decay exceed 0.5 (or
  temporarily lower the threshold for testing) and confirm dust particles
  still spawn periodically and animate correctly, and that the ticker stops
  again once dust spawning stops and existing dust particles finish.
- **Done when**: `HeartParticles` produces zero rebuilds while `_particles`
  is empty, and particle bursts/dust look visually identical to before.
