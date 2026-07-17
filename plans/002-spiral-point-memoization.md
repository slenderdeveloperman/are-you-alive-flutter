# 002 — Memoize spiral point geometry instead of regenerating it every frame

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: HIGH
- **Category**: Performance
- **Estimated scope**: 1 file, small

## Problem

`lib/widgets/spiral_painter.dart`'s `SpiralAnimationPainter.paint` calls
`_generateSpiralPoints(centerX, centerY)` on every single call to `paint`:

```dart
// lib/widgets/spiral_painter.dart:132-146 — current
@override
void paint(Canvas canvas, Size size) {
  const canvasSize = 550.0;
  final scale = min(size.width, size.height) / canvasSize;
  final offsetX = (size.width - canvasSize * scale) / 2;
  final offsetY = (size.height - canvasSize * scale) / 2;
  canvas.save();
  canvas.translate(offsetX, offsetY);
  canvas.scale(scale, scale);

  final centerX = canvasSize / 2;
  final centerY = canvasSize / 2;

  // Generate spiral points
  final spiralPoints = _generateSpiralPoints(centerX, centerY);
  ...
```

```dart
// lib/widgets/spiral_painter.dart:168-186 — current
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
```

`totalSteps` is 800, so every frame during the splash animation this does
800 iterations each computing `sin`/`cos` three times (via the wobble terms)
plus two more for `x`/`y` — roughly 4000 transcendental function calls per
frame, purely to reconstruct a shape whose geometry never actually changes.
`centerX`/`centerY` are always `canvasSize / 2` (constants — `275.0`), and
none of `progress`, `phase`, `time`, or `textRevealProgress` affect what
`_generateSpiralPoints` computes — only how much of the resulting list
`_drawSpiral` slices and draws (`startIdx`). This runs on every app launch
(the splash is seen 100% of the time) and is pure waste, especially on
lower-end Android hardware.

## Target

The 800-point list is computed once and cached, then reused across every
`paint` call. Since the points depend only on compile-time constants
(`centerX`/`centerY` are always `canvasSize / 2`), compute them lazily on
first use and cache statically on the painter class.

```dart
// lib/widgets/spiral_painter.dart — target
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

  // Spiral point geometry is invariant (depends only on the constants
  // above), so it's computed once and cached instead of every paint call.
  static List<_SpiralPoint>? _cachedSpiralPoints;

  static List<_SpiralPoint> _spiralPoints(double centerX, double centerY) {
    return _cachedSpiralPoints ??= _generateSpiralPoints(centerX, centerY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const canvasSize = 550.0;
    final scale = min(size.width, size.height) / canvasSize;
    final offsetX = (size.width - canvasSize * scale) / 2;
    final offsetY = (size.height - canvasSize * scale) / 2;
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    final centerX = canvasSize / 2;
    final centerY = canvasSize / 2;

    // Cached — computed once, reused every frame.
    final spiralPoints = _spiralPoints(centerX, centerY);
    ...
```

`_generateSpiralPoints` becomes a `static` method (its body is unchanged —
it does not read any instance field, only the two parameters it already
takes).

## Repo conventions to follow

- `HeartPainter` (`lib/widgets/heart_painter.dart`) rebuilds its path fresh
  every paint call too, but that path (a fixed heart outline) is cheap
  (7 `cubicTo` calls) — leave it alone, it's not in scope and not a
  performance problem. This plan only touches the 800-point trig-heavy
  spiral generation.
- Keep `shouldRepaint` unchanged — repainting still needs to happen every
  frame (to redraw the pipe/text/eaten portion), only the point *geometry*
  is cached, not the repaint decision.

## Steps

1. In `lib/widgets/spiral_painter.dart`, inside `SpiralAnimationPainter`,
   add a static nullable field: `static List<_SpiralPoint>? _cachedSpiralPoints;`
   placed after the existing `static const` fields (after `charSpacing`).
2. Add a static helper method directly below it:
   ```dart
   static List<_SpiralPoint> _spiralPoints(double centerX, double centerY) {
     return _cachedSpiralPoints ??= _generateSpiralPoints(centerX, centerY);
   }
   ```
3. Change the `_generateSpiralPoints` method signature from an instance
   method to `static`: `static List<_SpiralPoint> _generateSpiralPoints(double centerX, double centerY) {` — the body is unchanged, it already only uses its two parameters and local variables.
4. In `paint`, change the call site from
   `final spiralPoints = _generateSpiralPoints(centerX, centerY);` to
   `final spiralPoints = _spiralPoints(centerX, centerY);`.

## Boundaries

- Do NOT change `_drawSpiral`, `_drawPipe`, `_drawSquigglyText`, or any
  drawing logic — only the point-generation caching.
- Do NOT touch `_AreYouAliveLoopPainter` in `are_you_alive_loop.dart` (a
  different class in a different file with much cheaper per-character math,
  not in scope).
- Do NOT add new dependencies or introduce a package-level cache — a static
  field on the painter class is sufficient since `canvasSize` is a
  hardcoded constant, not a runtime value.
- If `spiral_painter.dart` no longer matches the excerpts above (drift
  since commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors.
  `flutter test` — expect existing tests still pass.
- **Feel check**: Run the app and watch the splash screen play through its
  full spiral-in → pause → text-out → hold → reset-pause cycle. The spiral
  shape, its wobble, and the text reveal must look pixel-identical to
  before — this is a pure caching change with no visual difference. In
  DevTools' Performance panel, profile the splash screen before/after and
  confirm CPU time in `SpiralAnimationPainter.paint` / `_generateSpiralPoints`
  drops substantially (the trig loop should show near-zero cost after the
  first frame).
- **Done when**: The splash animation is visually unchanged, and
  `_generateSpiralPoints` executes exactly once per app run (not once per
  frame).
