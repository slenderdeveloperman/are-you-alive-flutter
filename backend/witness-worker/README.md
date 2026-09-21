# AYA witness worker

Stateless delivery worker for FLD-AYA-01.

## Local/deploy environment

- DATABASE_URL
- RESEND_API_KEY
- RESEND_EMAIL_DOMAIN
- RESEND_FROM_EMAIL
- WORKER_SECRET
- CRON_SECRET (used by the external scheduler)
- RESEND_WEBHOOK_SECRET

The production scheduler is the GitHub Actions workflow in
`.github/workflows/aya-watchdog.yml`. It calls `/api/worker` every five
minutes with:

`Authorization: Bearer $CRON_SECRET`

Set the GitHub Actions secrets `AYA_WORKER_URL` to the deployed worker base
URL and `AYA_WORKER_SECRET` to the value configured as `WORKER_SECRET` in
Vercel. GitHub schedules are best-effort, so the worker remains idempotent and
safe if a run is delayed or retried.

Configure Resend to send delivery webhooks to `/api/resend-webhook`.
The production Resend resource is `alerts.indica.slenderscape.com` in
`sa-east-1`; the Vercel integration exposes one resource region, so
`eu-west-1` is not an automatic failover without a separate provider resource
and worker failover implementation.

The worker must not be activated until `backend/neon/005_witness_delivery.sql`
has been applied.

Run the local contract checks with:

```bash
npm test
npm run typecheck
```

These checks cover the bounded delivery pass without contacting Neon or Resend.
The production gate remains the staging test that proves one lapse produces one
provider message, the signed webhook marks it delivered, retries are idempotent,
and revocation suppresses later delivery.
