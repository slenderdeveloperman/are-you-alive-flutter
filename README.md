# Are You Alive?

A dead-simple dead-man's switch. The app asks one question — *are you
alive?* — and gives you a 39-hour window to tap yes. Miss the window and
the app declares you dead: eulogy screen, streak reset, existential dread.

No location sharing, no social feed, no data harvesting. The entire core
loop runs on-device.

## Features

- **39-hour check-in loop** — one button, a countdown, and a local
  notification when time runs short. Miss it and you get the eulogy.
- **Streaks & badges** — eight badges (Cliffhanger, Last Breath, Iron
  Routine, Phoenix, …) computed from local check-in history.
- **Share cards** — stat cards rendered over preset artwork: "Survey Plate"
  (Vesalius) and "Melencolia" (Dürer), both public-domain Renaissance
  engravings treated in the ESTD. INDICA / F.C.C.D.B. brand's ink/parchment
  duotone and filing-stamp format (archive code `FLD-AYA-01`), plus a
  near-miss card that only unlocks when you checked in within 6 hours of
  the deadline.
- **Emergency contact** — pick one person from your contacts; they get a
  WhatsApp nudge with a pairing code and an invite to install the app.
  Installing via the link (or typing the code by hand) pairs the two
  devices through a tiny Neon backend; the inviter sees "{name} has your
  back" the next time they open the app.

## Architecture

Local-first Flutter app. State lives in `SharedPreferences` (plus iOS
Keychain via `flutter_secure_storage` for pairing identity); the check-in
timer, death detection, badges, and share cards need no network at all.

The only networked feature is emergency-contact pairing:

- **Backend**: Neon Postgres + Data API (project `ARE-YOU-ALIVE`,
  aws-ap-southeast-1). Schema and access model live in
  [`backend/neon/`](backend/neon/) — the `invites`, `watchdogs`, and
  `witness_alert_outbox` tables are reachable only through narrowly scoped
  `SECURITY DEFINER` RPCs. The API's `anonymous` role has no table access.
  Subject-owned watchdog RPCs additionally require a 256-bit capability kept
  in secure storage on the subject device; Neon stores only its SHA-256 digest
  (`007_watchdog_capability.sql`).
- **Client**: `lib/services/pairing_service.dart` mints short-lived
  anonymous JWTs from the Neon Auth token endpoint, caches them, and
  refreshes on 401. Network failures surface as `null`, distinct from the
  authoritative `not_found` used to detect orphaned invites.
- **Endpoints**: `lib/config/backend_config.dart` (public by design — all
  security is server-side grants + RLS).
- **Claim path**: the invite link carries the pairing code via the Play
  Store's `&referrer=` parameter; `lib/services/invite_claim_service.dart`
  reads it back on first launch (Android only) via
  `play_install_referrer`. Installing by searching the store instead of
  tapping the link loses that signal, so `WelcomeScreen` also has a manual
  "have an invite code?" entry — the universal path, not just an iOS
  fallback.
- **Status sync**: `EmergencyContactService.syncStatus()` checks a pending
  invite against the backend from both `HomeScreen` (every app open) and
  `EmergencyContactScreen` (on open), and is the one place that
  distinguishes "still pending," "claimed," and "the code no longer
  exists" (which resets local state instead of leaving a stale pending
  card forever).

The witness delivery worker lives in
[`backend/witness-worker/`](backend/witness-worker/). It leases outbox rows,
sends idempotent Resend messages, and consumes signed delivery webhooks. Run
its contract tests with `npm test` and typecheck with `npm run typecheck` from
that directory. Production activation still requires the Neon migrations,
provider configuration, the GitHub Actions scheduler in
[`.github/workflows/aya-watchdog.yml`](.github/workflows/aya-watchdog.yml),
and the offline-subject end-to-end test. The scheduler uses the public
repository's standard GitHub-hosted runner; if the repository becomes private,
the five-minute cadence would consume about 8,640 rounded runner minutes per
30-day month before other workflows, exceeding GitHub Free's 2,000-minute
allowance. Production email is configured through Resend for
`alerts.indica.slenderscape.com` in `sa-east-1`; Vercel's integration does not
provide a second-region failover automatically.

To apply the schema, provision the out-of-band `aya_worker` login role, then
run migrations `001` through `009` in lexical order:

```bash
AYA_DATABASE_URL="$(npx -y neon@latest connection-string --project-id <project-id> --role-name neondb_owner)"
for migration in backend/neon/*.sql; do
  psql "$AYA_DATABASE_URL" -f "$migration"
done
```

## Development

```bash
flutter analyze          # keep clean — run after any change
flutter test             # full suite
flutter build appbundle --release   # Android release build
```

Version format is always `x.y.z+buildNumber` in `pubspec.yaml`.

Feature and fix plans live in [`plans/`](plans/README.md); the narrative
history is in [`CHANGELOG.md`](CHANGELOG.md).
