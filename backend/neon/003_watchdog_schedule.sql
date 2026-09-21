-- AYA 0.3 / FLD-AYA-01
-- External watchdog scheduling and retention.
--
-- Neon projects may expose pg_cron but only from the database configured as
-- cron.database_name. The AYA database is `neondb`, and production scheduling
-- is therefore owned by Vercel Cron (`backend/witness-worker/vercel.json`).
-- Keep the retention operation as a SECURITY DEFINER function so the worker
-- can perform it without direct table ownership.

create or replace function public.purge_delivered_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  delete from witness_alert_outbox
  where delivered_at is not null
    and delivered_at < now() - interval '30 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.purge_delivered_alerts() from public;

comment on function public.purge_delivered_alerts() is
  'AYA worker-only retention of delivered witness-alert envelopes older than 30 days.';
