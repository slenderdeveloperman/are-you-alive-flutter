# AYA witness worker

Stateless delivery worker for FLD-AYA-01.

## Local/deploy environment

- DATABASE_URL
- RESEND_API_KEY
- RESEND_FROM_EMAIL
- WORKER_SECRET
- RESEND_WEBHOOK_SECRET

The scheduler calls `/api/worker` every ~5 minutes with:

`Authorization: Bearer $WORKER_SECRET`

Configure Resend to send delivery webhooks to `/api/resend-webhook`.

The worker must not be activated until `backend/neon/005_witness_delivery.sql`
has been applied.
