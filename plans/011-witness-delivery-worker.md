# AYA 0.3 — Witness Delivery Worker

Status: IMPLEMENTATION STARTED
Branch: `feat/aya-0.3`
Archive: `FLD-AYA-01`

## Goal

Turn `witness_alert_outbox` into a reliable external notification path that still
works when the subject phone is dead, offline, uninstalled, or otherwise unavailable.

The first production channel is email via Resend. Email is deliberately the first
channel because it proves the remote-watchdog property with minimal new client
infrastructure. FCM and WhatsApp can be layered on later.

## Architecture

```
external scheduler (5 min)
        |
        v
POST /api/worker
        |
        +--> evaluate_watchdogs()
        |
        +--> lease witness_alert_outbox rows
        |
        +--> resolve witness-owned delivery_email
        |
        +--> Resend POST /emails
        |      Idempotency-Key: aya/witness-alert/{outbox_id}
        |
        +--> submitted / retry / dead-letter state
                       |
                       v
              Resend delivery webhook
                       |
                       +--> delivered
                       +--> retryable failure
                       +--> terminal failure
```

## Why the scheduler is outside Neon

Neon `pg_cron` only runs while compute is active. A dead-man switch must not depend
on the database already being awake. Revision 0.3 therefore treats database-local
cron as an optional safety net, not the primary wake-up mechanism.

The worker endpoint is scheduler-agnostic. Any reliable external scheduler that can
send an authenticated HTTPS POST every ~5 minutes can wake it.

## Privacy / consent model

The inviter's address book is never uploaded to obtain an email address.

The designated witness enters their own delivery email when accepting the invite on
their device. The email is stored on the pairing row solely for operational witness
delivery and is deleted when the pairing is revoked.

## Delivery state

`witness_alert_outbox.status`:

- `pending` — ready to claim
- `leased` — temporarily owned by a worker invocation
- `submitted` — provider accepted the send; awaiting delivery webhook
- `delivered` — provider confirmed delivery
- `dead` — terminal failure / retry budget exhausted

Retry policy:
- attempts 1–4: 1m, 5m, 30m, 2h
- attempt 5 failure: `dead`
- expired leases return to pending eligibility
- every send uses a stable provider idempotency key based on outbox id

The worker is at-least-once by design. Duplicate worker invocation must be harmless.

## Message families

### record_lapsed

Subject:
`FLD-AYA-01 / RECORD LAPSED`

Body:
A subject who designated you as witness has not filed proof of continued existence
within the 39-hour window plus the witness grace period.

The message must state:
- this is an automated personal-network notice;
- it is not an emergency-services alert;
- the witness should use their own judgment about contacting the subject or someone
  who knows them.

### record_restored

Subject:
`FLD-AYA-01 / RECORD RESTORED`

Sent only after a prior overdue/alerted record returns active.

## Worker contract

Environment variables:
- `DATABASE_URL`
- `RESEND_API_KEY`
- `RESEND_FROM_EMAIL`
- `WORKER_SECRET`
- `RESEND_WEBHOOK_SECRET`

`POST /api/worker`
- requires `Authorization: Bearer <WORKER_SECRET>`
- calls `evaluate_watchdogs()`
- leases at most 25 eligible rows
- sends each row independently
- returns aggregate counts only, never witness PII

`POST /api/resend-webhook`
- verifies Svix signature using `RESEND_WEBHOOK_SECRET`
- deduplicates provider event id
- maps provider message id back to outbox row
- marks delivered / failed state

## Release gate

0.3.0 may claim automatic witness delivery only after all of the following are true:

- [ ] migration 005 applied to production Neon
- [ ] external scheduler configured
- [ ] Resend sending domain/from-address verified
- [ ] production secrets installed
- [ ] witness can provide delivery email while claiming invite
- [ ] subject files and watchdog refreshes
- [ ] subject phone is powered off
- [ ] watchdog evaluator creates lapse alert
- [ ] worker sends exactly one email
- [ ] delivery webhook marks it delivered
- [ ] duplicate worker invocation sends no duplicate
- [ ] simulated provider timeout retries without duplicate send
- [ ] revoked witness receives no later alert
- [ ] `record_restored` follows a previously alerted lapse
