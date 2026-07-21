# 007 — Extract shared motion tokens for the duplicated 200ms/easeOut values

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: LOW
- **Category**: Cohesion & tokens
- **Estimated scope**: 2 files touched + 1 new file, small

## Problem

Duration/curve pairs are hand-typed inline at every call site with no
shared source of truth. Two are exact duplicates within the same file, and
two more are near-duplicates that "almost match" (per AUDIT.md category 7):

```dart
// lib/widgets/share_preset_sheet.dart:170-172 — current (AnimatedScale)
return AnimatedScale(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
```

```dart
// lib/widgets/share_preset_sheet.dart:184-187 — current (AnimatedContainer, same widget tree)
child: AnimatedContainer(
  key: ValueKey('share-preset-container-${preset.id}'),
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
```

```dart
// lib/screens/home_screen.dart:703-709 — current (scale pop, near-duplicate: same 200ms, different curve)
return TweenAnimationBuilder<double>(
  tween: Tween(
    begin: 1.0,
    end: _streakJustChanged ? 1.15 : 1.0,
  ),
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOut,
```

```dart
// lib/screens/home_screen.dart:698-701 — current (streak count-up, different duration)
TweenAnimationBuilder<int>(
  tween: IntTween(begin: _previousStreak, end: _streakCount),
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeOutCubic,
```

```dart
// lib/screens/home_screen.dart:731-743 — current (button swap transition)
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    final slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
        );
```

Five call sites, three distinct (duration, curve) pairs, zero shared
constants. If a sixth screen is added and someone eyeballs "roughly 200ms
ease-out-ish", it'll drift again.

## Target

A new file `lib/theme/motion_tokens.dart` defines the named constants, and
the five call sites above reference them instead of inlining literals.

```dart
// lib/theme/motion_tokens.dart — new file
import 'package:flutter/animation.dart';

/// Shared motion constants. Add new tokens here rather than hand-typing
/// durations/curves at call sites — see AUDIT.md category 7 (cohesion).
abstract final class MotionTokens {
  /// Small in-place selection feedback (grid card highlight, scale pop).
  static const Duration selectionDuration = Duration(milliseconds: 200);

  /// Entrance/exit of a swapped subtree (AnimatedSwitcher transitions).
  static const Duration entranceDuration = Duration(milliseconds: 300);

  /// Larger celebratory value transitions (streak count-up).
  static const Duration celebrationDuration = Duration(milliseconds: 600);

  /// Standard ease-out for UI entering/responding. Use for anything
  /// spatially moving into place or reacting to input.
  static const Curve easeOut = Curves.easeOut;

  /// Slightly stronger ease-out for larger/celebratory movement (matches
  /// the existing `Curves.easeOutCubic` convention in this codebase).
  static const Curve easeOutStrong = Curves.easeOutCubic;
}
```

```dart
// lib/widgets/share_preset_sheet.dart — target
import '../theme/motion_tokens.dart';
...
return AnimatedScale(
  duration: MotionTokens.selectionDuration,
  curve: MotionTokens.easeOutStrong,
...
child: AnimatedContainer(
  key: ValueKey('share-preset-container-${preset.id}'),
  duration: MotionTokens.selectionDuration,
  curve: MotionTokens.easeOutStrong,
```

```dart
// lib/screens/home_screen.dart — target
import '../theme/motion_tokens.dart';
...
TweenAnimationBuilder<int>(
  tween: IntTween(begin: _previousStreak, end: _streakCount),
  duration: MotionTokens.celebrationDuration,
  curve: MotionTokens.easeOutStrong,
  builder: (context, value, child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 1.0,
        end: _streakJustChanged ? 1.15 : 1.0,
      ),
      duration: MotionTokens.selectionDuration,
      curve: MotionTokens.easeOut,
...
AnimatedSwitcher(
  duration: MotionTokens.entranceDuration,
  transitionBuilder: (child, animation) {
    final slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: MotionTokens.easeOut,
          ),
        );
```

## Repo conventions to follow

- `lib/theme/app_layout.dart` already exists as a small constants-holder
  class (referenced in `home_screen.dart` as `AppLayout.buttonHorizontalGutter`
  etc.) — `MotionTokens` should follow the exact same shape: an
  `abstract final class` with `static const` members, placed in the same
  `lib/theme/` directory.

## Steps

1. Create `lib/theme/motion_tokens.dart` with the `MotionTokens` class
   exactly as shown in Target (import `package:flutter/animation.dart`,
   which provides both `Duration`-independent `Curve`/`Curves` — note
   `Duration` itself is from `dart:core`, no import needed for it).
2. In `lib/widgets/share_preset_sheet.dart`, add
   `import '../theme/motion_tokens.dart';` near the top with the other
   relative imports, then replace both occurrences of
   `duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic`
   (the `AnimatedScale` at line ~170 and the `AnimatedContainer` at line
   ~184) with `duration: MotionTokens.selectionDuration, curve: MotionTokens.easeOutStrong`.
3. In `lib/screens/home_screen.dart`, add
   `import '../theme/motion_tokens.dart';` near the top with the other
   relative imports.
4. Replace the streak count-up `TweenAnimationBuilder<int>`'s
   `duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic`
   with `duration: MotionTokens.celebrationDuration, curve: MotionTokens.easeOutStrong`.
5. Replace the nested scale-pop `TweenAnimationBuilder<double>`'s
   `duration: const Duration(milliseconds: 200), curve: Curves.easeOut`
   with `duration: MotionTokens.selectionDuration, curve: MotionTokens.easeOut`.
6. Replace the `AnimatedSwitcher`'s `duration: const Duration(milliseconds: 300)`
   with `duration: MotionTokens.entranceDuration`, and its inner
   `CurvedAnimation`'s `curve: Curves.easeOut` with
   `curve: MotionTokens.easeOut`.

## Boundaries

- Do NOT touch `animated_button.dart`, `heart_particles.dart`,
  `spiral_painter.dart`, `are_you_alive_loop.dart`, `typewriter_text.dart`,
  or `glitch_text.dart` — their durations/curves are either bespoke
  (physically simulated, not simple Tween+Curve pairs) or not actually
  duplicated elsewhere, so tokenizing them would be premature abstraction.
  Only the five call sites listed in Problem/Target are in scope.
- Do NOT change any duration or curve *value* — this is a pure
  rename/extraction; `200ms`/`300ms`/`600ms` and
  `Curves.easeOut`/`Curves.easeOutCubic` stay numerically identical, only
  their spelling changes from inline literals to named constants.
- Do NOT introduce a general-purpose "design tokens" file covering colors,
  spacing, etc. — scope is motion only, matching the existing
  `AppLayout` precedent of one concern per file.
- If either target file no longer matches the excerpts above (drift since
  commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors, no
  unused imports. `flutter test` — expect existing tests still pass
  (`share_preset_sheet_test.dart` and `streak_and_death_test.dart` in
  particular, since both touched files have dedicated tests).
- **Feel check**: Run the app — the share preset grid's selection scale/glow,
  the streak count-up, the scale-pop on streak change, and the check-in
  button swap transition must all look and time identically to before this
  change, since no values changed, only their source.
- **Done when**: `grep -rn "Duration(milliseconds: 200)\|Duration(milliseconds: 300)\|Duration(milliseconds: 600)" lib/widgets/share_preset_sheet.dart lib/screens/home_screen.dart`
  returns no matches (all replaced by `MotionTokens` references), and the
  app behaves identically to before.
