# 003 — Drive splash animation off real elapsed time, not a fixed frame assumption

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: HIGH
- **Category**: Performance / Correctness (timing)
- **Estimated scope**: 1 file, small

## Problem

`lib/screens/splash_screen.dart`'s `_onTick` advances all splash animation
state by a fixed per-call increment, assuming the ticker fires at exactly
60fps:

```dart
// lib/screens/splash_screen.dart:13-40 — current (relevant excerpt)
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animation timing constants (matching JSX frame counts at ~60fps)
  static const double _spiralSpeed = 0.0032;
  static const double _textSpeed = 0.007;
  static const int _pauseFrames = 50;
  static const int _holdFrames = 180;
  static const int _resetPauseFrames = 60;
  ...
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
        ...
```

`AnimationController.repeat()` drives its listener via a `Ticker`, which
fires once per rendered frame — i.e. at the display's actual refresh rate,
not a fixed 60Hz. Most current Android phones run at 90Hz or 120Hz. On a
120Hz device, `_onTick` fires twice as often per second as this code
assumes, so `_time`, `_progress`, `_textRevealProgress`, and the frame
counters (`_holdCounter` vs `_pauseFrames`/`_holdFrames`/`_resetPauseFrames`)
all advance twice as fast — the entire splash sequence (spiral-in → pause →
text reveal → hold → reset) plays roughly twice as fast as intended, on
every launch, on a majority of modern Android hardware. This is the first
thing every user sees.

The sibling file `lib/widgets/are_you_alive_loop.dart` already solves this
correctly by measuring real elapsed time between ticks:

```dart
// lib/widgets/are_you_alive_loop.dart:207-230 — reference (already correct)
class _AreYouAliveLoopState extends State<AreYouAliveLoop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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
```

## Target

`splash_screen.dart` measures real per-tick elapsed time the same way, and
converts the existing per-frame constants (`_spiralSpeed`, `_textSpeed`,
`_pauseFrames`, `_holdFrames`, `_resetPauseFrames`, and the `_time += 0.016`
increment) into per-second rates so the total duration of each phase is
independent of refresh rate.

The constants were tuned "at ~60fps", so the conversion is: a per-frame
increment `k` becomes a per-second rate `k * 60`, and a frame count `n`
becomes a duration `n / 60.0` seconds.

```dart
// lib/screens/splash_screen.dart — target (relevant excerpt)
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
          if (!_hasCompleted) {
            _hasCompleted = true;
            widget.onComplete();
          }
        }
        break;
    }

    setState(() {});
  }
```

Note `_holdCounter` (an `int` frame count) is renamed `_holdElapsed` (a
`double` seconds accumulator) since frame counting no longer makes sense
once ticks aren't assumed to be uniform — update every reference to
`_holdCounter` accordingly, including its declaration near the other state
fields.

## Repo conventions to follow

- Mirror `are_you_alive_loop.dart:219-225` exactly for the delta-time
  calculation pattern (`lastElapsedDuration`, subtract `_lastElapsed`,
  convert `inMicroseconds` to seconds, `.clamp(0.0, 0.1)` to guard against
  large jumps after an app pause/backgrounding).

## Steps

1. In `lib/screens/splash_screen.dart`, add `Duration _lastElapsed = Duration.zero;`
   as a field on `_SplashScreenState`, near `late AnimationController _controller;`.
2. Replace the four `static const` timing fields
   (`_spiralSpeed`, `_textSpeed`, `_pauseFrames`, `_holdFrames`,
   `_resetPauseFrames`) with the per-second versions shown in Target:
   `_spiralSpeedPerSecond`, `_textSpeedPerSecond`, `_timeSpeedPerSecond`,
   `_pauseSeconds`, `_holdSeconds`, `_resetPauseSeconds`.
3. Rename the `int _holdCounter = 0;` field to `double _holdElapsed = 0.0;`
   and update its declaration.
4. Rewrite `_onTick()` to compute `deltaSeconds`/`dt` from
   `_controller.lastElapsedDuration` exactly as shown in Target, and replace
   every phase's frame-counting logic with the seconds-based logic shown
   (each `_spiralSpeed` becomes `_spiralSpeedPerSecond * dt`, each
   `_holdCounter++` becomes `_holdElapsed += dt`, each frame-count
   comparison becomes a seconds comparison against `_pauseSeconds` /
   `_holdSeconds` / `_resetPauseSeconds`).
5. In the `resetPause` case, replace
   `_progress = _holdCounter / _resetPauseFrames;` with
   `_progress = (_holdElapsed / _resetPauseSeconds).clamp(0.0, 1.0);` (the
   clamp guards against `dt` overshooting past 1.0 on a slow frame).

## Boundaries

- Do NOT change `SpiralAnimationPainter`, `SpiralPainter`, or any drawing
  code — only the timing/state-advancement logic in `_onTick`.
- Do NOT change the visual constants (`totalTurns`, `maxRadius`, etc. in
  `spiral_painter.dart`) — out of scope.
- Do NOT change `widget.onComplete()` call semantics — it must still fire
  exactly once, guarded by `_hasCompleted`.
- If `splash_screen.dart` no longer matches the excerpts above (drift since
  commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors, no
  unused `_holdCounter`/old constant references left behind. `flutter test`
  — expect existing tests still pass.
- **Feel check**: Run the app on a simulator/device and time the splash
  sequence with a stopwatch — spiral-in should take ~3.0-3.5s (0.0032/frame
  × ~60fps-equivalent ≈ 1/0.0032/60 ≈ 5.2s total spiral, sanity-check against
  pre-change behavior on the same device rather than an absolute number),
  and the overall sequence should feel identical in *speed* to before this
  change on whatever device you're testing on. The critical check is
  device-independence: if you can test on both a 60Hz and a 90Hz/120Hz
  device (or throttle refresh rate in developer options), the total splash
  duration should now match across both — before this fix it would have
  been visibly faster on the higher refresh-rate device.
- **Done when**: Splash duration is consistent across devices with
  different refresh rates, and the sequence's relative pacing (spiral-in →
  pause → text-out → hold → reset) is unchanged from what it looked like
  before this fix on a 60Hz reference device.
