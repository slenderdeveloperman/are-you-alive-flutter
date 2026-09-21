-- AYA 0.3 / FLD-AYA-01
-- Complete the least-privilege read set used by the signed webhook update.
-- The UPDATE expression references these existing values in CASE branches.

do $$
begin
  if not exists (
    select 1 from pg_roles where rolname = 'aya_worker'
  ) then
    raise exception 'aya_worker role must be provisioned before migration 009';
  end if;

  execute 'grant select (status, delivered_at, last_error) on public.witness_alert_outbox to aya_worker';
end;
$$;

comment on role aya_worker is
  'AYA witness delivery worker; limited to watchdog evaluation, leasing, delivery, and webhook state transitions.';
