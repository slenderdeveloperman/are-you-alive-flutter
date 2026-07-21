# 009 — Emergency contact: pick, nudge, pair

- **Status**: PHASE A DONE (2026-07-21) — B/C/D pending
- **Category**: Feature (first networked feature)
- **Estimated scope**: ~6 new files, 3 modified, plus a Supabase project
- **Depends on**: nothing in-app; Supabase project setup (free tier)

## Goal

Let the user pick one emergency contact, nudge that person over WhatsApp to
install the app, and reflect inside the inviter's app when the contact
actually installs and accepts — closing the loop that later powers free
FCM-based escalation (see research notes, 2026-07-21 session).

Explicitly out of scope for this plan: the escalation itself (missed-two-
check-ins detection, server cron, SMS/WhatsApp sending). This plan only
builds selection + invite + pairing + status sync.

## Architecture overview

```
Phone A (inviter)                     Phone B (contact)
─────────────────                     ─────────────────
pick contact (system picker,
no permission needed)
        │
generate pairing code AYA-XXXXXX
        │
INSERT invites row ──────────► Supabase `invites` table
        │                              ▲
share via wa.me link                   │
(text contains code + Play link        │
 with &referrer=code)                  │
        │                              │
        └──── WhatsApp ──────► tap link, install
                                       │
                               read Play Install Referrer
                               (or manual code entry on iOS)
                                       │
                               "Yash chose you" accept screen
                                       │
                               UPDATE invites SET claimed ──►
        ┌──────────────────────────────┘
on app open: SELECT status
"✓ Ravi has your back"
```

Key privacy property: the server never sees the contact's phone number or
either person's name. The number stays on Phone A; names travel only inside
the person-to-person WhatsApp message and an optional display-name field the
claimer types in. The `invites` row is two anonymous device UUIDs and a code.

## Phase A — client-only (ships before any backend exists)

1. **Contact selection.** Use the OS single-contact picker
   (`ACTION_PICK` on Android, `CNContactPickerViewController` on iOS) via
   `flutter_native_contact_picker` or a small platform channel. No
   `READ_CONTACTS` permission, no Play data-safety declaration for contacts.
   Persist `{name, phone}` in SharedPreferences
   (`emergency.contact.name` / `emergency.contact.phone`).

2. **UI.** New "Emergency contact" card (likely on HomeScreen below the
   badge summary, or a settings row — decide at build time). Three states:
   - empty → "Choose someone" CTA
   - pending → "⏳ Waiting on {name}" + re-send nudge button
   - confirmed → "✓ {name} has your back" (Phase D flips this)

3. **The nudge.** Two delivery paths, tried in order:
   - *Deep link (optimization):* `wa.me/<E.164 digits>?text=` via
     `url_launcher`, jumping straight into the right chat. Requires number
     normalization — see item 5.
   - *Share sheet (the correctness path):* `share_plus` with the same text.
     The user picks the recipient inside WhatsApp themselves, so **no phone
     number is needed at all**. This is the fallback for parse failures,
     missing WhatsApp, or any doubt — worst case is one extra tap, never an
     error dialog.

   Message text carries the story, the code, and the store link:

   > {UserName} picked you as their emergency contact on Are You Alive? —
   > if they ever go silent too long, you're the one who gets told.
   > Install and enter code AYA-7F3K2M to accept:
   > https://play.google.com/store/apps/details?id=com.areyoualive.are_you_alive_flutter&referrer=AYA-7F3K2M

4. **Pairing code.** 6 chars, Crockford base32, `Random.secure()`, prefixed
   `AYA-`. Generated and stored locally at invite time; regenerating
   invalidates the old one (single active invite).

5. **Phone normalization (deep-link path only).** Use `phone_numbers_parser`
   (pure-Dart libphonenumber port) with the device region
   (`PlatformDispatcher.locale.countryCode`) as the default country, output
   E.164. Never hand-roll this — phone prefix formats are a documented
   repeat bug source across projects. Unit-test with Indian formats
   specifically ("98765 43210", "+91 98765-43210", "098765 43210",
   "0091..."). Any parse failure routes silently to the share sheet.

6. **Durable local state.** Store the device UUID, pairing code, and
   contact info via `flutter_secure_storage` (iOS Keychain persists across
   uninstall/reinstall) and keep Android Auto Backup enabled for prefs
   (best-effort restore on same-account reinstall). This is the cheap
   mitigation for reinstall-orphaning; full accounts stay deferred.

Phase A is fully testable and shippable with the pending state simply never
resolving (or resolving via a manual "they told me they installed it"
override, which stays useful forever as the no-backend fallback).

## Phase B — Supabase pairing table

One table, RLS-guarded, accessed directly via the anon key (no edge
functions needed for pairing):

```sql
create table invites (
  code         text primary key,          -- 'AYA-7F3K2M'
  inviter_id   uuid not null,             -- device-generated uuid, stored locally
  created_at   timestamptz default now(),
  claimed_at   timestamptz,
  claimer_id   uuid,                      -- claimer's device uuid
  claimer_name text                       -- optional, typed by claimer
);
```

RLS policies:
- INSERT: anyone may insert a row with their own `inviter_id` (device
  identity is a locally generated UUID — no accounts, no auth flow).
- UPDATE: only rows where `claimed_at is null`, and only setting
  `claimed_at / claimer_id / claimer_name` (claim is one-shot; enforce with
  a `with check` clause or a `claim_invite(code)` SQL function — prefer the
  function, it makes the one-shot semantics atomic).
- SELECT: by exact `code` match only (no listing).

Housekeeping: a scheduled cleanup (pg_cron) deletes *unclaimed* invites
older than 30 days so abandoned/reinstall-orphaned rows don't accumulate.
Claimed rows are the pairing itself and are kept.

Client side: a thin `PairingService` (`lib/services/pairing_service.dart`)
wrapping `supabase_flutter` with three calls: `createInvite()`,
`claimInvite(code, name)`, `getInviteStatus(code)`. Supabase URL + anon key
in a new `lib/config/backend_config.dart`. `getInviteStatus` must
distinguish three results: `pending`, `claimed`, and `notFound` — the last
one is load-bearing (see Phase D).

## Phase C — the claim path on the contact's phone

1. **Android referrer.** On first launch, read the Play Install Referrer
   (`android_play_install_referrer` package) and look for an `AYA-` code.
   NOTE: Firebase Dynamic Links is shut down (Aug 2025) — do not use it;
   referrer + manual entry is the whole strategy.
2. **Manual entry (iOS + universal fallback).** Onboarding gains an
   unobtrusive "Have an invite code?" affordance. Same claim path.
3. **Accept screen.** "{claimer sees}: Someone chose you as their emergency
   contact." → optional name field → Accept → `claimInvite()`. Then normal
   onboarding continues; the claimer is a full user of the app themselves
   from day one (that's the growth loop).

## Phase D — status sync on the inviter's phone

On app open (piggyback on `AppRouter`'s existing init, or HomeScreen
`initState`), if a local invite exists and isn't confirmed:
`getInviteStatus(code)` → if claimed, flip the card to confirmed and fire a
one-time celebration (reuse the badge-unlock celebration pattern from plan
008). No FCM, no polling timers — the 39-hour check-in loop guarantees the
user opens the app often enough for open-time sync to feel immediate.

Offline/failure behavior: status check is fire-and-forget with a short
timeout; **network failures** leave the pending state untouched. Never
block the home screen on the network — this app must keep working fully
offline.

Orphan detection: a successful response of `notFound` (code no longer
exists — TTL cleanup after an inviter reinstall, or a stale/invalidated
code) is NOT a failure: it resets the card to the empty state with a
gentle "invite expired — choose your contact again" note. Silent zombie
pending states are the one outcome this phase must never produce.
Distinguish carefully: timeout/offline → keep pending; authoritative
notFound → reset.

## Testing

- Unit: code generation (charset, length, uniqueness), `PairingService`
  against a mocked Supabase client, claim-is-one-shot semantics.
- Widget: the three card states; accept screen; "have a code?" entry.
- Manual: real WhatsApp round-trip between two devices; Play referrer only
  works via actual Play Store installs (internal testing track) — flag this
  as a release-checklist item, not CI-testable.

## Risks / open decisions

1. **Device identity survives reinstall only best-effort** — mitigated in
   three layers rather than solved: (a) iOS Keychain + Android Auto Backup
   for the UUID/pairing state (Phase A item 6); (b) orphaning made
   *detectable* via the `notFound` reset path (Phase D) so recovery is
   always a guided re-invite, never a silent zombie state; (c) server TTL
   on unclaimed rows (Phase B). Contact-side reinstall is invisible within
   this plan's scope and is deliberately deferred to the escalation phase,
   whose FCM token-refresh heartbeat is the natural re-binding point. Real
   accounts remain out of scope until then.
2. **wa.me prefill needs E.164** — reframed: normalization is an
   optimization for the deep-link path only. The share-sheet path needs no
   number at all, so a bad parse costs one extra tap, never correctness.
   `phone_numbers_parser` + device-region default + India-format unit tests
   (Phase A item 5).
3. **Play referrer reliability** — referrer is lost if the user installs by
   searching the store instead of tapping the link. Manual code entry is
   therefore not an iOS-only fallback; it's the primary universal path,
   referrer is the enhancement.
4. **Single contact by design** for now; schema doesn't prevent multiple
   invites later.
