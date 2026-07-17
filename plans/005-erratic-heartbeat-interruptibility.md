# 005 — Stop the erratic heartbeat from reversing direction mid-beat

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: MEDIUM
- **Category**: Interruptibility
- **Estimated scope**: 1 file, small

## Problem

`lib/screens/home_screen.dart`'s erratic heartbeat (active during the 24-39h
"erratic" window) re-randomizes its beat duration and scale multiplier every
250-1149ms, and does so by forcibly restarting the controller's repeat cycle
every time:

```dart
// lib/screens/home_screen.dart:617-640 — current
void _startErraticHeartbeat() {
  _erraticBeatTimer?.cancel();
  _applyErraticBeatProfile();
}

void _applyErraticBeatProfile() {
  if (!mounted || _heartbeatPhase != _HeartbeatPhase.erratic) {
    return;
  }

  final beatDuration = Duration(
    milliseconds: 350 + _random.nextInt(550), // 350-899ms
  );
  _erraticScaleMultiplier = 0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02

  _heartbeatController.duration = beatDuration;
  _heartbeatController.stop();
  _heartbeatController.repeat(reverse: true);

  final nextChangeDelay = Duration(
    milliseconds: 250 + _random.nextInt(900), // 250-1149ms
  );
  _erraticBeatTimer = Timer(nextChangeDelay, _applyErraticBeatProfile);
}
```

`AnimationController.stop()` does not reset `.value` — it just halts the
ticker at whatever value the controller is currently at (could be
mid-beat, e.g. `0.6` while shrinking toward `0.9`). Calling `.repeat(reverse: true)`
immediately after starts a brand-new repeating simulation from that current
value, but a freshly-started `repeat()` simulation always begins by moving
*toward* the upper bound first, regardless of which direction the
controller was actually travelling when it was stopped. Concretely: if the
heart was mid-shrink (value decreasing from 1.0 toward 0.9) when the 250-
1149ms timer fires, the new simulation can make it immediately start
*growing* back toward 1.0 instead of continuing to shrink — a visible
direction reversal ("hiccup") on the app's central, always-visible focal
element, happening as often as 4 times a second during the ~15-hour erratic
window.

This is the definition of an interruptible animation done wrong: the
retrigger doesn't carry the animation's current direction/velocity forward,
it restarts a new cycle that ignores it.

## Target

Apply the new duration/scale multiplier only at a natural boundary of the
current beat (when the controller reaches `0.0` or `1.0`, i.e.
`AnimationStatus.dismissed` or `AnimationStatus.completed`) instead of
forcing a mid-cycle restart. Between boundaries, let the current beat finish
undisturbed — the profile change is queued and applied at the next
boundary, which is at most one beat-cycle away (350-899ms) and is
imperceptible as a delay since the heart is already mid-beat.

```dart
// lib/screens/home_screen.dart — target: apply profile changes only at beat boundaries
void _setupAnimation() {
  // Heartbeat animation - continuous scale pulsing
  _heartbeatController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );

  _heartbeatAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
    CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
  );

  _heartbeatController.addStatusListener(_onHeartbeatStatusChanged);

  // Shake animation - rapid horizontal vibration
  ...
}

void _onHeartbeatStatusChanged(AnimationStatus status) {
  if (_heartbeatPhase != _HeartbeatPhase.erratic) return;
  if (status != AnimationStatus.dismissed &&
      status != AnimationStatus.completed) {
    return;
  }
  if (_pendingBeatDuration == null) return;

  // We're at a clean boundary (value is exactly 0.0 or 1.0) — safe to
  // change duration and restart the repeat cycle with no direction jump.
  _heartbeatController.duration = _pendingBeatDuration;
  _erraticScaleMultiplier = _pendingScaleMultiplier!;
  _pendingBeatDuration = null;
  _pendingScaleMultiplier = null;

  _heartbeatController.stop();
  _heartbeatController.repeat(reverse: true);
}

void _startErraticHeartbeat() {
  _erraticBeatTimer?.cancel();
  _applyErraticBeatProfile();
}

void _applyErraticBeatProfile() {
  if (!mounted || _heartbeatPhase != _HeartbeatPhase.erratic) {
    return;
  }

  // Queue the new profile; _onHeartbeatStatusChanged applies it at the
  // next beat boundary instead of restarting mid-cycle.
  _pendingBeatDuration = Duration(
    milliseconds: 350 + _random.nextInt(550), // 350-899ms
  );
  _pendingScaleMultiplier =
      0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02

  final nextChangeDelay = Duration(
    milliseconds: 250 + _random.nextInt(900), // 250-1149ms
  );
  _erraticBeatTimer = Timer(nextChangeDelay, _applyErraticBeatProfile);
}
```

Two new fields are needed on `_HomeScreenState`:

```dart
// lib/screens/home_screen.dart — target: new fields near _erraticScaleMultiplier
Duration? _pendingBeatDuration;
double? _pendingScaleMultiplier;
```

The very first entry into the erratic phase (`_startErraticHeartbeat`,
called from `_applyHeartbeatPhase`'s `case _HeartbeatPhase.erratic:` branch)
still needs an initial kick — since the controller may already be sitting
at a boundary (freshly `.reset()` from the `inactive`/`expired` case, or
mid-cycle from `normal`), the first profile application should apply
immediately rather than waiting for a boundary, since there's no in-flight
erratic beat to interrupt yet. Handle this by giving `_applyErraticBeatProfile`
an `immediate` parameter used only on first entry.

```dart
// lib/screens/home_screen.dart — target: immediate first application
void _startErraticHeartbeat() {
  _erraticBeatTimer?.cancel();
  _applyErraticBeatProfile(immediate: true);
}

void _applyErraticBeatProfile({bool immediate = false}) {
  if (!mounted || _heartbeatPhase != _HeartbeatPhase.erratic) {
    return;
  }

  final beatDuration = Duration(
    milliseconds: 350 + _random.nextInt(550), // 350-899ms
  );
  final scaleMultiplier =
      0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02

  if (immediate) {
    _heartbeatController.duration = beatDuration;
    _erraticScaleMultiplier = scaleMultiplier;
    _heartbeatController.stop();
    _heartbeatController.repeat(reverse: true);
  } else {
    _pendingBeatDuration = beatDuration;
    _pendingScaleMultiplier = scaleMultiplier;
  }

  final nextChangeDelay = Duration(
    milliseconds: 250 + _random.nextInt(900), // 250-1149ms
  );
  _erraticBeatTimer = Timer(nextChangeDelay, _applyErraticBeatProfile);
}
```

## Repo conventions to follow

- `_heartbeatController`/`_heartbeatAnimation` setup lives in
  `_setupAnimation()` (`home_screen.dart:151-179`) — add the new
  `addStatusListener` call there, next to the existing controller/animation
  construction, following the same style as the adjacent
  `_shakeAnimation` setup.
- Field declarations for animation state live together near
  `double _erraticScaleMultiplier = 1.0;` (`home_screen.dart:51`) — add
  `_pendingBeatDuration`/`_pendingScaleMultiplier` there.

## Steps

1. In `lib/screens/home_screen.dart`, add two new fields near
   `double _erraticScaleMultiplier = 1.0;`:
   `Duration? _pendingBeatDuration;` and `double? _pendingScaleMultiplier;`.
2. In `_setupAnimation()`, immediately after the `_heartbeatAnimation = ...`
   assignment, add: `_heartbeatController.addStatusListener(_onHeartbeatStatusChanged);`.
3. Add the new method `_onHeartbeatStatusChanged(AnimationStatus status)` as
   shown in Target, placed near `_applyErraticBeatProfile`.
4. Change `_startErraticHeartbeat()` to call
   `_applyErraticBeatProfile(immediate: true);` instead of
   `_applyErraticBeatProfile();`.
5. Change `_applyErraticBeatProfile()`'s signature to
   `void _applyErraticBeatProfile({bool immediate = false})`.
6. Inside `_applyErraticBeatProfile`, replace the direct
   `_heartbeatController.duration = beatDuration; _erraticScaleMultiplier = ...; _heartbeatController.stop(); _heartbeatController.repeat(reverse: true);`
   block with the `if (immediate) { ... } else { ... }` branching shown in
   Target — the `immediate` branch keeps the old direct-apply behavior
   (used only on first entry to the erratic phase), the non-`immediate`
   branch just stores the pending values for `_onHeartbeatStatusChanged` to
   apply later.
7. In `dispose()`, no change needed — `_heartbeatController.dispose()`
   already cleans up listeners automatically.

## Boundaries

- Do NOT change the random ranges (350-899ms duration, 0.92-1.02 scale
  multiplier, 250-1149ms retrigger delay) — only when/how the profile is
  applied.
- Do NOT change `_HeartbeatPhase.normal` or `.inactive`/`.expired` handling
  in `_applyHeartbeatPhase` — only the erratic phase's profile-application
  timing is in scope.
- Do NOT add a new animation library or spring package — stay within
  `AnimationController`/`CurvedAnimation`.
- If `home_screen.dart`'s heartbeat code no longer matches the excerpts
  above (drift since commit `e46c6d0`), STOP and report instead of
  improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors.
  `flutter test` — expect existing tests still pass.
- **Feel check**: This requires reaching the erratic phase, which normally
  needs 24h+ elapsed — use the app's `nowProvider` test hook (see
  `streak_and_death_test.dart` for the pattern) or temporarily lower
  `_erraticWindowStart` while testing locally (revert before considering
  the plan done). Watch the heart closely for at least 15-20 seconds during
  the erratic phase: confirm the heart never visibly "jumps" or reverses
  direction abruptly mid-shrink/mid-grow — each beat should complete its
  current direction before the next randomized profile takes over. Compare
  side-by-side with the pre-fix build if possible; the fixed version should
  look like a continuously erratic but *smooth* beat, never a stutter.
- **Done when**: The heartbeat's scale value only changes direction at
  natural beat boundaries (peak/trough), never mid-beat, even though the
  beat duration and intensity keep randomizing every 250-1149ms.
