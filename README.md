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
- **Share cards** — stat cards rendered over preset artwork (certificate,
  battery, and a near-miss card that only unlocks when you checked in
  within 6 hours of the deadline).
- **Emergency contact** *(in progress, plan 009)* — pick one person; they
  get a WhatsApp nudge with a pairing code and an invite to install the
  app. Pairing state syncs through a tiny Neon backend.

## Architecture

Local-first Flutter app. State lives in `SharedPreferences` (plus iOS
Keychain via `flutter_secure_storage` for pairing identity); the check-in
timer, death detection, badges, and share cards need no network at all.

The only networked feature is emergency-contact pairing:

- **Backend**: Neon Postgres + Data API (project `ARE-YOU-ALIVE`,
  aws-ap-southeast-1). Schema and access model live in
  [`backend/neon/001_invites.sql`](backend/neon/001_invites.sql) — a single
  `invites` table reachable only through three `SECURITY DEFINER` RPCs
  (`create_invite`, `claim_invite`, `get_invite_status`). The API's
  `anonymous` role has EXECUTE on those functions and nothing else.
- **Client**: `lib/services/pairing_service.dart` mints short-lived
  anonymous JWTs from the Neon Auth token endpoint, caches them, and
  refreshes on 401. Network failures surface as `null`, distinct from the
  authoritative `not_found` used to detect orphaned invites.
- **Endpoints**: `lib/config/backend_config.dart` (public by design — all
  security is server-side grants + RLS).

To re-apply the schema:

```bash
psql "$(npx -y neon@latest connection-string --project-id <project-id> --role-name neondb_owner)" \
  -f backend/neon/001_invites.sql
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
