# 008 — Celebrate recently-unlocked badges instead of rendering them identically to old ones

- **Status**: DONE
- **Commit**: e46c6d0
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 1 file, small-medium

## Problem

`lib/screens/badges_screen.dart` contains zero animation code — confirmed by
reading the full file. Every badge chip in the grid, whether earned decades
ago or unlocked seconds before the screen opened, renders identically via
`_BadgeGridItem` → `CylindricalBadgeChip`. Badge unlocks are exactly the
"rare, high-emotion moment" AUDIT.md category 8 calls out as deserving
delight, and this app already has the data to distinguish a fresh unlock
from an old one: `BadgeProgress.earnedAtMs`
(`lib/models/badge_models.dart:46,55`) is a millisecond timestamp set once,
the first time `BadgeService` detects `unlocked && !earnedMap.containsKey(...)`
(`lib/services/badge_service.dart:213-217`). A badge earned in the check-in
that just happened (which calls `_refreshBadgeSnapshot()` right before the
user can navigate to this screen — see `home_screen.dart:273`) will have an
`earnedAtMs` within the last few seconds of `DateTime.now()` when
`BadgesScreen` opens.

```dart
// lib/screens/badges_screen.dart:63-72 — current
itemCount: widget.snapshot.badges.length,
itemBuilder: (context, index) {
  final badge = widget.snapshot.badges[index];
  return _BadgeGridItem(
    badge: badge,
    isExpanded: _expandedBadgeId == badge.definition.id,
    onTap: () => _toggleExpanded(badge),
  );
},
```

```dart
// lib/screens/badges_screen.dart:90-114 — current
class _BadgeGridItem extends StatelessWidget {
  const _BadgeGridItem({
    required this.badge,
    required this.isExpanded,
    required this.onTap,
  });

  final BadgeProgress badge;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: CylindricalBadgeChip(
          badge: badge,
          iconOnly: true,
        ),
      ),
    );
  }
}
```

## Target

Any badge whose `earnedAtMs` is within the last 10 minutes (comfortably
covers "just unlocked this check-in, then navigated to Badges") plays a
one-time entrance celebration when the grid first builds: a scale-and-glow
pulse from 0.7→1.0 with a brief overshoot, matching the app's existing
"glow pulse" aesthetic from `animated_button.dart`'s check-in feedback.
Badges unlocked longer ago render exactly as they do today — instant,
static.

```dart
// lib/screens/badges_screen.dart — target: threshold + detection helper
class _BadgesScreenState extends State<BadgesScreen> {
  BadgeId? _expandedBadgeId;

  static const _recentUnlockThreshold = Duration(minutes: 10);

  bool _isRecentlyUnlocked(BadgeProgress badge) {
    final earnedAtMs = badge.earnedAtMs;
    if (!badge.earned || earnedAtMs == null) return false;
    final earnedAt = DateTime.fromMillisecondsSinceEpoch(earnedAtMs);
    return DateTime.now().difference(earnedAt) <= _recentUnlockThreshold;
  }
  ...
```

```dart
// lib/screens/badges_screen.dart — target: pass the flag down
itemBuilder: (context, index) {
  final badge = widget.snapshot.badges[index];
  return _BadgeGridItem(
    badge: badge,
    isExpanded: _expandedBadgeId == badge.definition.id,
    onTap: () => _toggleExpanded(badge),
    celebrateUnlock: _isRecentlyUnlocked(badge),
  );
},
```

```dart
// lib/screens/badges_screen.dart — target: _BadgeGridItem plays the celebration
class _BadgeGridItem extends StatefulWidget {
  const _BadgeGridItem({
    required this.badge,
    required this.isExpanded,
    required this.onTap,
    required this.celebrateUnlock,
  });

  final BadgeProgress badge;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool celebrateUnlock;

  @override
  State<_BadgeGridItem> createState() => _BadgeGridItemState();
}

class _BadgeGridItemState extends State<_BadgeGridItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Overshoot slightly past 1.0 then settle — celebratory, not just a
    // plain fade-in. elasticOut is too bouncy for a 56px chip; easeOutBack
    // gives a subtle single overshoot.
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    if (widget.celebrateUnlock) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: widget.celebrateUnlock
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3FAE7A)
                                .withValues(alpha: 0.5 * _glowOpacity.value),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ]
                      : const [],
                ),
                child: child,
              ),
            );
          },
          child: CylindricalBadgeChip(
            badge: widget.badge,
            iconOnly: true,
          ),
        ),
      ),
    );
  }
}
```

## Repo conventions to follow

- The green `#3FAE7A` color used for the celebration glow is the existing
  "earned"/"unlocked" accent color already used in this same file's
  `_BadgeDetailSheet` (`badges_screen.dart:172,184` —
  `const Color(0xFF3FAE7A)`) — reuse it rather than introducing a new
  color.
- `animated_button.dart`'s glow pulse (`BoxShadow` with animated
  `blurRadius`/`spreadRadius` driven by an `AnimationController` via
  `AnimatedBuilder`) is the established "glow feedback" pattern in this
  repo — this plan reuses that same shape (`AnimatedBuilder` +
  `BoxShadow`), not a new mechanism.
- Per AUDIT.md category 3, never `scale(0)` — this plan starts the tween at
  `0.7`, not `0.0`.

## Steps

1. In `lib/screens/badges_screen.dart`, add
   `static const _recentUnlockThreshold = Duration(minutes: 10);` and the
   `_isRecentlyUnlocked(BadgeProgress badge)` method shown in Target to
   `_BadgesScreenState`, placed near the top of the class (above `build`).
2. In the `GridView.builder`'s `itemBuilder`, add
   `celebrateUnlock: _isRecentlyUnlocked(badge),` as a new named argument
   to the `_BadgeGridItem(...)` constructor call.
3. Convert `_BadgeGridItem` from a `StatelessWidget` to a `StatefulWidget`
   as shown in Target: add the `celebrateUnlock` field to the widget class,
   change `class _BadgeGridItem extends StatelessWidget` to
   `class _BadgeGridItem extends StatefulWidget`, remove the old `build`
   method from the widget class, and add
   `@override State<_BadgeGridItem> createState() => _BadgeGridItemState();`.
4. Add the new `_BadgeGridItemState` class shown in Target, with
   `SingleTickerProviderStateMixin`, the `AnimationController`/`_scale`/
   `_glowOpacity` setup in `initState`, proper `dispose()`, and the `build`
   method wrapping `CylindricalBadgeChip` in the animated
   `Transform.scale` + glow `DecoratedBox`.

## Boundaries

- Do NOT modify `cylindrical_badge_chip.dart` — the celebration is applied
  externally by wrapping the existing widget, not by changing it.
- Do NOT modify `badge_service.dart` or `badge_models.dart` — `earnedAtMs`
  already exists and is sufficient; no new persistence or "seen" tracking
  is needed.
- Do NOT add a celebration to `_BadgeDetailSheet` (the tap-to-expand modal)
  — this plan is scoped to the grid entrance only.
- Do NOT change grid layout, spacing, or the `isExpanded`/`onTap` behavior.
- If `badges_screen.dart` no longer matches the excerpts above (drift since
  commit `e46c6d0`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze` — expect no new warnings/errors.
  `flutter test` — expect existing tests still pass.
- **Feel check**: Trigger a real badge unlock (or temporarily lower a badge
  threshold / hand-set an entry in the `metrics.badges.earnedJson`
  SharedPreferences key to `DateTime.now()` for testing, reverting after),
  then open the Badges screen — confirm that specific badge chip scales in
  from slightly-small with a brief overshoot past full size and a green
  glow pulse, while all other already-earned badges appear instantly with
  no animation. Reopen the Badges screen after the 10-minute threshold has
  passed (or lower `_recentUnlockThreshold` temporarily to test) and
  confirm the same badge now renders statically, no celebration replay.
- **Done when**: Only badges earned within the last 10 minutes animate in
  on grid build; everything else is pixel-identical to pre-change
  behavior.
