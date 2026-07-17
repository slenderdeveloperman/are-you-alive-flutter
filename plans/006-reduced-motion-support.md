# 006 — Respect the system reduce-motion setting

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: MEDIUM
- **Category**: Accessibility
- **Estimated scope**: 3 files, small-medium

## Problem

No file in the app reads `MediaQuery.disableAnimations` (or the underlying
`PlatformDispatcher.accessibilityFeatures.disableAnimations`, which is what
that flag wraps — this mirrors iOS "Reduce Motion" / Android
"Remove animations"). Confirmed via repo-wide search — zero matches for
`disableAnimations`, `accessibilityFeatures`, or `reducedMotion` anywhere in
`lib/`. Every animation in the app runs unconditionally: the continuous
heartbeat pulse, the erratic-phase scale swings, the check-in shake, the
particle bursts/dust, and `GlitchText`'s recurring character glitches.

Per AUDIT.md category 6, reduced motion should mean *fewer and gentler*
animations, not zero — feedback that aids comprehension should stay,
purely decorative movement should go.

## Target

Three independent, targeted changes, each gated on whether the OS
accessibility flag is set:

**1. `lib/widgets/glitch_text.dart` — disable the purely decorative glitch
entirely.** The glitch effect carries no information (it's cosmetic noise
on top of already-legible text), so under reduced motion it simply never
triggers.

```dart
// lib/widgets/glitch_text.dart:65-77 — current
void _scheduleNextGlitch() {
  _glitchTimer?.cancel();

  // Randomize interval: 2-4 seconds around the base interval
  final variance = widget.glitchInterval.inMilliseconds ~/ 2;
  final delay = Duration(
    milliseconds: widget.glitchInterval.inMilliseconds +
        _random.nextInt(variance * 2) -
        variance,
  );

  _glitchTimer = Timer(delay, _triggerGlitch);
}
```

```dart
// lib/widgets/glitch_text.dart — target
void _scheduleNextGlitch() {
  _glitchTimer?.cancel();

  if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
      .disableAnimations) {
    return; // Reduced motion: skip the purely decorative glitch effect.
  }

  // Randomize interval: 2-4 seconds around the base interval
  final variance = widget.glitchInterval.inMilliseconds ~/ 2;
  final delay = Duration(
    milliseconds: widget.glitchInterval.inMilliseconds +
        _random.nextInt(variance * 2) -
        variance,
  );

  _glitchTimer = Timer(delay, _triggerGlitch);
}
```

**2. `lib/widgets/heart_particles.dart` — keep the fade feedback, cut the
amount of drift.** Life/dust particles still spawn and fade (that motion
communicates "check-in happened" / "heart is decaying"), but their
travel distance is reduced so they read as a gentle glow/dust shimmer
rather than a burst of movement.

```dart
// lib/widgets/heart_particles.dart:85-104 — current
void _spawnLifeParticles() {
  // Spawn 8-12 life particles in a burst
  final count = 8 + _random.nextInt(5);
  for (var i = 0; i < count; i++) {
    final particle = _Particle(
      type: _ParticleType.life,
      x: widget.heartSize.width / 2 + (_random.nextDouble() - 0.5) * 60,
      y: widget.heartSize.height * 0.4 + (_random.nextDouble() - 0.5) * 40,
      vx: (_random.nextDouble() - 0.5) * 30,
      vy: -40 - _random.nextDouble() * 40, // Float upward
      size: 3 + _random.nextDouble() * 4,
      lifetime: 1.5 + _random.nextDouble() * 0.5,
      age: 0,
      color: _random.nextBool()
          ? Colors.red.withValues(alpha: 0.8)
          : Colors.pink.withValues(alpha: 0.7),
    );
    _particles.add(particle);
  }
}
```

```dart
// lib/widgets/heart_particles.dart — target
bool get _reducedMotion => WidgetsBinding
    .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

void _spawnLifeParticles() {
  // Spawn 8-12 life particles in a burst
  final count = 8 + _random.nextInt(5);
  // Reduced motion: keep the fade feedback, cut travel distance to ~25%.
  final velocityScale = _reducedMotion ? 0.25 : 1.0;
  for (var i = 0; i < count; i++) {
    final particle = _Particle(
      type: _ParticleType.life,
      x: widget.heartSize.width / 2 + (_random.nextDouble() - 0.5) * 60,
      y: widget.heartSize.height * 0.4 + (_random.nextDouble() - 0.5) * 40,
      vx: (_random.nextDouble() - 0.5) * 30 * velocityScale,
      vy: (-40 - _random.nextDouble() * 40) * velocityScale,
      size: 3 + _random.nextDouble() * 4,
      lifetime: 1.5 + _random.nextDouble() * 0.5,
      age: 0,
      color: _random.nextBool()
          ? Colors.red.withValues(alpha: 0.8)
          : Colors.pink.withValues(alpha: 0.7),
    );
    _particles.add(particle);
  }
}
```

The same `velocityScale` pattern applies to `_spawnDustParticle`'s `vx`/`vy`
(lines 106-123).

**3. `lib/screens/home_screen.dart` — drop the positional check-in shake;
dampen the erratic heartbeat swing.** The shake is pure positional jitter
whose "check-in succeeded" information is already fully conveyed by the
button's glow pulse, the heart's color change, and the streak counter
animation — it's safe to skip outright. The heartbeat's erratic scale
*swing* (the `_erraticScaleMultiplier` term) is decorative amplification on
top of the base pulse, which already communicates the erratic state on its
own — dampen the swing's range instead of removing the base pulse.

```dart
// lib/screens/home_screen.dart:256-259 — current
// Start shake animation, then transition to heartbeat
_shakeController.forward().then((_) {
  _shakeController.reset();
});
```

```dart
// lib/screens/home_screen.dart — target
// Start shake animation, then transition to heartbeat.
// Reduced motion: skip the positional shake — the glow pulse and color
// change already communicate the check-in.
if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
    .disableAnimations) {
  _shakeController.forward().then((_) {
    _shakeController.reset();
  });
}
```

```dart
// lib/screens/home_screen.dart:622-630 — current (inside _applyErraticBeatProfile)
final beatDuration = Duration(
  milliseconds: 350 + _random.nextInt(550), // 350-899ms
);
_erraticScaleMultiplier = 0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02
```

```dart
// lib/screens/home_screen.dart — target
final beatDuration = Duration(
  milliseconds: 350 + _random.nextInt(550), // 350-899ms
);
final reducedMotion = WidgetsBinding
    .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
// Reduced motion: keep the erratic *timing* (still communicates urgency)
// but dampen the extra scale swing to a barely-there range.
_erraticScaleMultiplier = reducedMotion
    ? 0.98 + (_random.nextDouble() * 0.02) // 0.98-1.00
    : 0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02
```

(This edit interacts with plan 005's rewrite of `_applyErraticBeatProfile`
— see Boundaries below for ordering.)

## Repo conventions to follow

- `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`
  is the correct API to use in code paths that don't have a `BuildContext`
  handy (e.g. `_spawnLifeParticles`, `_applyErraticBeatProfile`,
  `_scheduleNextGlitch`) — it's the same underlying flag
  `MediaQuery.of(context).disableAnimations` reads from, so no new
  dependency or context-threading is needed.
- No file in this repo currently has a shared "is reduced motion" helper —
  this plan intentionally inlines the check at each of the three call
  sites rather than inventing a new shared utility, to keep the change
  minimal and scoped. (A future consolidation pass — see plan 007 — could
  extract this into `lib/utils/` if more call sites appear.)

## Steps

1. In `lib/widgets/glitch_text.dart`, at the top of `_scheduleNextGlitch()`
   (before the `_glitchTimer?.cancel();` line's following code, i.e. right
   after `_glitchTimer?.cancel();`), add the early-return reduced-motion
   check shown in Target.
2. In `lib/widgets/heart_particles.dart`, add a private getter `_reducedMotion`
   as shown in Target, placed near the top of `_HeartParticlesState` (e.g.
   just above `_startDecaySpawner`).
3. In `_spawnLifeParticles()`, add the `velocityScale` local variable and
   multiply both `vx` and `vy` by it, as shown in Target.
4. In `_spawnDustParticle()` (lines 106-123), apply the identical pattern:
   add `final velocityScale = _reducedMotion ? 0.25 : 1.0;` and multiply
   that method's `vx`/`vy` by it too.
5. In `lib/screens/home_screen.dart`'s `_onCheckIn()`, wrap the
   `_shakeController.forward().then(...)` call in the reduced-motion `if`
   check shown in Target.
6. In `_applyErraticBeatProfile()`, replace the direct
   `_erraticScaleMultiplier = 0.92 + (_random.nextDouble() * 0.10);`
   assignment with the `reducedMotion` ternary shown in Target. If plan 005
   has already been executed and this method's structure has changed
   (queued `_pendingScaleMultiplier` instead of a direct assignment), apply
   the same ternary to whichever variable now holds the computed scale
   multiplier value — the dampening logic is the same regardless of
   whether it's applied immediately or queued.

## Boundaries

- Do NOT touch the base heartbeat pulse (`_heartbeatAnimation`,
  `Tween<double>(begin: 1.0, end: 0.9)`) — it stays fully active under
  reduced motion; it's informational (communicates alive/normal state), not
  decorative.
- Do NOT touch `SpiralAnimationPainter`/splash screen — the splash is a
  brief, one-time, non-repeating sequence, not continuous ambient motion,
  and out of scope for this plan.
- Do NOT fully disable particle spawning — some fade/feedback must remain
  per AUDIT.md ("not zero"); only reduce travel distance.
- This plan touches `_applyErraticBeatProfile` in `home_screen.dart`, the
  same method plan 005 rewrites. If executing both plans, apply plan 005
  first, then layer this plan's `reducedMotion` ternary on top of
  whichever variable (`_erraticScaleMultiplier` directly, or
  `_pendingScaleMultiplier` per plan 005's Target) ends up holding the
  computed value in the post-005 code.
- If any of the three files no longer match the excerpts above (drift since
  commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors.
  `flutter test` — expect existing tests still pass.
- **Feel check**: On iOS Simulator, enable Settings → Accessibility →
  Motion → Reduce Motion. On Android emulator, enable Settings →
  Accessibility → Remove animations (or set
  `Settings.Global.ANIMATOR_DURATION_SCALE`/via `adb shell settings put
  secure reduce_motion_enabled 1` if your Flutter/Android version wires
  that through to `disableAnimations` — confirm via a temporary debug
  print of `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`
  if the OS toggle doesn't visibly change the flag in your test
  environment). With reduced motion on: check in and confirm no shake
  jitter occurs, but the button glow and heart color change still play;
  during the erratic phase, confirm the heartbeat still pulses (base
  animation) but with a much smaller extra "wobble" than before; leave the
  glitchy timer message on screen for 10+ seconds and confirm it never
  glitches. With reduced motion off, confirm all four behaviors (shake,
  erratic swing, glitch, full-velocity particles) are unchanged from
  before this plan.
- **Done when**: All continuous/decorative motion is reduced or removed
  under the OS reduce-motion setting while state-communicating feedback
  (heartbeat pulse, color transitions, glow) remains, and nothing changes
  when the setting is off.
