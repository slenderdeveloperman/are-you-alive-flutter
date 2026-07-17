# 004 — Give the check-in button's press/glow feedback proper easing

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: MEDIUM
- **Category**: Easing & duration
- **Estimated scope**: 1 file, small

## Problem

`lib/widgets/animated_button.dart` is the app's one real call-to-action (the
"Yes, I'm alive" check-in button). Its press-down scale animation uses
`AnimatedScale` with no `curve` argument:

```dart
// lib/widgets/animated_button.dart:74-76 — current
child: AnimatedScale(
  scale: _isPressed ? widget.pressedScale : 1.0,
  duration: widget.pressDuration,
  child: AnimatedBuilder(
```

Flutter's `AnimatedScale` defaults `curve` to `Curves.linear` when
unspecified. A linear scale-down/scale-up on a button press feels
mechanical rather than snappy — AUDIT.md's easing decision order calls for
`ease-out` on entering/responsive feedback.

The glow pulse (release feedback) is also unewed: it's driven directly off
the raw `AnimationController.value` with no curve applied at all:

```dart
// lib/widgets/animated_button.dart:76-100 — current
child: AnimatedBuilder(
  animation: _glowController,
  builder: (context, child) {
    // Glow intensity decreases as animation progresses
    final glowOpacity = (1 - _glowController.value) * 0.5;
    final glowBlur = 20 * (1 - _glowController.value);
    final glowSpread = 2 * (1 - _glowController.value);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: _glowController.value < 1
            ? [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: glowOpacity),
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ]
            : null,
      ),
      child: child,
    );
  },
  child: widget.child,
),
```

`AnimationController.forward(from: 0)` (called on tap-up in
`_handleTapUp`) runs the controller linearly from 0 to 1 — so the glow fades
out at a constant rate, which reads as weaker/flatter than an eased fade.

## Target

Both animations use `Curves.easeOut` — matching the `Curves.easeOutCubic` /
`Curves.easeOut` convention already used elsewhere in the app (e.g.
`share_preset_sheet.dart:172,187`, `home_screen.dart:709`) for
entering/responsive feedback.

```dart
// lib/widgets/animated_button.dart:74-76 — target
child: AnimatedScale(
  scale: _isPressed ? widget.pressedScale : 1.0,
  duration: widget.pressDuration,
  curve: Curves.easeOut,
  child: AnimatedBuilder(
```

For the glow, wrap the raw controller in a `CurvedAnimation` so
`_glowController.value` reads are replaced with an eased value:

```dart
// lib/widgets/animated_button.dart — target: add a curved glow animation
class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: widget.glowDuration,
      vsync: this,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );
  }
```

```dart
// lib/widgets/animated_button.dart — target: use the curved value in the builder
child: AnimatedBuilder(
  animation: _glowAnimation,
  builder: (context, child) {
    // Glow intensity decreases as animation progresses (eased)
    final glowOpacity = (1 - _glowAnimation.value) * 0.5;
    final glowBlur = 20 * (1 - _glowAnimation.value);
    final glowSpread = 2 * (1 - _glowAnimation.value);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: _glowAnimation.value < 1
            ? [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: glowOpacity),
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ]
            : null,
      ),
      child: child,
    );
  },
  child: widget.child,
),
```

## Repo conventions to follow

- `share_preset_sheet.dart:170-187` uses
  `AnimatedScale(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, ...)`
  and `AnimatedContainer(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, ...)`
  as the established pattern for scale-based feedback with explicit easing
  — this plan applies the same idea (explicit `Curves.easeOut`) to
  `animated_button.dart`.
- `home_screen.dart:158-160` wraps a raw `AnimationController` in a
  `CurvedAnimation` (`CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut)`)
  — this is the existing repo pattern for adding easing to
  controller-driven (non-implicit) animations, reused here for the glow.

## Steps

1. In `lib/widgets/animated_button.dart`, add `curve: Curves.easeOut,` to
   the `AnimatedScale` widget in `build()`, immediately after the
   `duration: widget.pressDuration,` line.
2. Add a new field `late Animation<double> _glowAnimation;` on
   `_AnimatedButtonState`, next to `late AnimationController _glowController;`.
3. In `initState()`, after `_glowController` is constructed, add:
   `_glowAnimation = CurvedAnimation(parent: _glowController, curve: Curves.easeOut);`
4. In `build()`, change `animation: _glowController,` to
   `animation: _glowAnimation,` on the `AnimatedBuilder`.
5. Inside that `AnimatedBuilder`'s `builder`, replace all three reads of
   `_glowController.value` (`glowOpacity`, `glowBlur`, `glowSpread`) and the
   `_glowController.value < 1` check with `_glowAnimation.value` instead.

## Boundaries

- Do NOT change `pressedScale`, `pressDuration`, or `glowDuration` default
  values — only add curves.
- Do NOT touch the `GestureDetector`/tap-handling logic
  (`_handleTapDown`/`_handleTapUp`/`_handleTapCancel`) — out of scope.
- Do NOT change how `_glowController.forward(from: 0)` is invoked in
  `home_screen.dart` — that call site is unaffected by this change.
- If `animated_button.dart` no longer matches the excerpts above (drift
  since commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors.
  `flutter test` — expect existing tests still pass (check
  `widget_test.dart` if it references `AnimatedButton`).
- **Feel check**: Run the app, press and hold the check-in button — the
  scale-down to 0.95 should feel like it settles quickly rather than
  moving at a constant rate (subtle at 100ms, but should read as slightly
  snappier). Release the button and watch the red glow pulse — it should
  now feel like it fades with a decaying rate (fast initial fade, gentle
  tail) rather than a flat linear fade. Use DevTools' "Slow animations"
  option (or manually lengthen `glowDuration` temporarily to ~1000ms while
  testing) to confirm the eased curve visually, then confirm it still
  looks correct at the real 200ms duration.
- **Done when**: Both the press-scale and glow-fade visibly ease rather
  than move linearly, with no change to their overall durations or peak
  intensities.
