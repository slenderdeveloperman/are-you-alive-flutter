-- AYA 0.3 / FLD-AYA-01
-- Least-privilege grants for the server-side witness worker.
--
-- The aya_worker LOGIN role and its password are provisioned out-of-band.
-- This migration contains grants and RLS policies only; no credential is
-- committed to the repository.

do $$
begin
  if not exists (
    select 1 from pg_roles where rolname = 'aya_worker'
  ) then
    raise exception 'aya_worker role must be provisioned before migration 008';
  end if;

  execute format('grant connect on database %I to aya_worker', current_database());
  execute 'grant usage on schema public to aya_worker';
  execute 'grant execute on function public.evaluate_watchdogs() to aya_worker';
  execute 'grant execute on function public.claim_witness_alerts(integer) to aya_worker';
  execute 'grant execute on function public.purge_delivered_alerts() to aya_worker';
  execute 'grant select (id, provider_message_id, provider_event_ids) on public.witness_alert_outbox to aya_worker';
  execute 'grant update (status, provider_message_id, lease_until, last_error, next_attempt_at, delivered_at, provider_event_ids) on public.witness_alert_outbox to aya_worker';

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'witness_alert_outbox'
      and policyname = 'aya_worker_outbox_select'
  ) then
    execute 'create policy aya_worker_outbox_select on public.witness_alert_outbox for select to aya_worker using (true)';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'witness_alert_outbox'
      and policyname = 'aya_worker_outbox_update'
  ) then
    execute 'create policy aya_worker_outbox_update on public.witness_alert_outbox for update to aya_worker using (true) with check (true)';
  end if;
end;
$$;

comment on role aya_worker is
  'AYA witness delivery worker; limited to watchdog evaluation, leasing, and outbox state transitions.';
