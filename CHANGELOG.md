# Changelog

## Unreleased — share fixes, near-miss preset, emergency contact (phases A+B)

Session of 2026-07-20/21.

### Share card fixes

- Preset text vertical alignment: the layout measured line-gaps between
  lines but rendered a trailing gap after every line, so text blocks sat
  off-center and the last line could spill past the zone into the scrim.
- Battery preset text zone recentered onto the artwork's spiral (was
  rendering below it, over the wax seal).
- Known issue flagged, not fixed: `certificate_preset.png` and
  `battery_preset.png` have swapped visual content relative to their names.

### Near-miss share preset

- New `ShareTheme.nearMiss` ("Near Miss") with a generated countdown-ring
  + hazard-stripe background (no static asset). Hidden until the last
  check-in landed within 6h of the 39h deadline; copy shows the real
  margin and hour mark (e.g. "T-MINUS 1h 58m. Hour 37 of 39.").

### Emergency contact (plan 009, phases A+B of D)

- **Phase A (client)**: OS single-contact picker (no contacts permission),
  `AYA-XXXXXX` pairing codes, WhatsApp nudge via `wa.me` deep link with
  share-sheet fallback (needs no phone number), three-state screen behind
  a new shield icon on the bottom pill, state in secure storage.
- **Phase B (backend + client)**: Neon project (Data API + Neon Auth),
  RPC-only `invites` table (`backend/neon/001_invites.sql`) with atomic
  one-shot claim and opportunistic TTL cleanup; `PairingService` with
  anonymous-JWT caching/refresh. Verified end-to-end against the live API,
  including denial of direct table access.
- Phases C (claim path on the contact's phone) and D (status sync on app
  open) are still pending — see `plans/009-emergency-contact-pairing.md`.

### Docs

- README rewritten from Flutter boilerplate to a real project overview.

## Unreleased — motion, accessibility, and press-feedback pass

Range: `e46c6d0..72ad449` (10 commits). Full context on the animation work
lives in [`plans/`](plans/README.md); this file is the narrative summary,
including the follow-up rounds that aren't captured there.

### 1. Animation audit fixes (`improve-animations`, plans 001–008)

All 8 findings from an animation audit, implemented and verified
(`flutter analyze` clean, `flutter test` passing after each).

- **Performance**
  - `HeartParticles` no longer ticks forever from `initState` — the
    controller only runs while particles are actually active, cutting an
    unconditional 60–120 rebuilds/sec for the app's whole open duration.
  - `SpiralAnimationPainter` memoizes its 800-point spiral geometry instead
    of regenerating it (trig-heavy) on every paint call during the splash's
    spiral-in phase.
  - `SplashScreen` now drives its phase timers off real elapsed time
    (`AnimationController.lastElapsedDuration`) instead of assuming 60fps —
    the old fixed `0.016`/tick increment made the splash play ~2x too fast
    on 90/120Hz devices (most current Android phones).
- **Easing & interruptibility**
  - The check-in button's press-scale and glow now use explicit
    `Curves.easeOut` (was implicitly linear).
  - The erratic heartbeat no longer restarts `stop()`+`repeat()` mid-cycle,
    which could visibly reverse the heart's scale before finishing a beat.
    New beat profiles are queued and only applied at a clean
    `AnimationStatus` boundary via `_onHeartbeatStatusChanged`.
- **Accessibility (reduced motion)**
  - `MotionTokens.reducedMotion` (new shared getter) gates: the check-in
    shake, `GlitchText`'s decorative character-glitch (now a full no-op),
    and `HeartParticles`' travel distance (dropped to ~25%).
  - Base heartbeat pulse and color feedback are left untouched —
    informational, not decorative.
- **Cohesion**
  - New `lib/theme/motion_tokens.dart` consolidates duration/curve values
    that were duplicated across widgets (200ms/300ms/600ms +
    easeOut/easeOutCubic pairs, plus the reduced-motion getter).
- **Missed opportunity**
  - Badges earned in the last 10 minutes now play a scale+glow entrance
    (0.7→1.0, `easeOutBack` overshoot) on the badge grid instead of
    rendering statically like older badges.
- **Testability**
  - `HomeScreen` and `BadgesScreen` both take optional
    `nowProvider`/`random` injection points (mirroring the existing
    `nowProvider` pattern) so time- and randomness-dependent motion is
    deterministic in tests.
  - `test/heartbeat_erratic_test.dart` (new): regression test for the
    interruptibility fix — drives the app into the erratic phase with a
    seeded `Random` and asserts no beat leg is shorter than the 350ms
    minimum. Verified it fails against the pre-fix code (observed a 170ms
    truncated leg) before trusting it.

### 2. Engineering review fixes (`plan-eng-review`)

- Consolidated the four independent raw `WidgetsBinding` reduced-motion
  checks down to the shared `MotionTokens.reducedMotion` getter.
- Threaded `HomeScreen`'s `nowProvider` into the `BadgesScreen` it opens, so
  time-dependent logic stays test-injectable across the screen boundary.
- Added `test/badges_screen_test.dart` (new) covering the badge celebration
  scale animation.

### 3. Apple design review (`apple-design`) — press feedback

Per "respond on pointer-down, not on release": `BottomActionPill`'s three
icon buttons and the badge grid tap target were bare `GestureDetector`s with
zero visual response until the tap fully completed. Both now reuse
`AnimatedButton` for instant press-scale feedback.

- `AnimatedButton` gained an `enableGlow` flag (default `true`, unchanged
  for the check-in CTA) so lighter-weight tap targets get press-scale
  without inheriting the CTA's red glow pulse.
- Icon buttons' touch target bumped from ~40px to the 44px minimum via
  wider padding.

### 4. Code review fix — stale pending heartbeat profile

`_applyHeartbeatPhase` now clears `_pendingBeatDuration`/
`_pendingScaleMultiplier` on every phase change, not just when consuming
them. Previously, a profile queued during one erratic session but never
reached (phase changed before the next beat boundary) stayed queued and
could be silently reapplied by `_onHeartbeatStatusChanged` during a later,
unrelated erratic session.

### Verification

`flutter analyze` clean throughout; `flutter test` 51/51 passing after the
final fix. Pushed to `origin/working`.

### Known open items (not yet fixed — surfaced by code review, unscoped)

- `badges_screen.dart:31` — `_isRecentlyUnlocked` doesn't guard against a
  negative `Duration` on clock skew.
- Badge celebration animation doesn't check `MotionTokens.reducedMotion`.
- `_pendingBeatDuration`/`_pendingScaleMultiplier` are two separate
  nullable fields in `home_screen.dart` — a structural footgun if they ever
  desync.
- `AnimatedButton`'s glow is duplicated rather than reused in
  `badges_screen.dart`'s celebration glow.
- `spiral_painter.dart`'s point cache is keyed on nothing — currently safe
  since `canvasSize` is a constant, but latent if that ever changes.
