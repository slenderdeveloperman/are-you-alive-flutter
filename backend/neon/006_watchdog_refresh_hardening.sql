-- AYA 0.3 / FLD-AYA-01
-- Harden watchdog refresh semantics without rewriting already-applied migrations.
--
-- This migration keeps the current device-id contract intact. The refresh RPC
-- still requires the caller to possess the opaque subject id, but a separately
-- authenticated RPC remains a release-gate item for the full trust model.

create or replace function public.refresh_watchdog(
  p_subject_id uuid,
  p_checked_in_at timestamptz,
  p_deadline_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_witness_id uuid;
  v_prior_status text;
  v_prior_check_in_at timestamptz;
begin
  -- The app's canonical record is exactly 39 hours. A small future tolerance
  -- absorbs device/server clock skew without allowing future-dated filings.
  if p_checked_in_at is null
     or p_deadline_at is null
     or p_checked_in_at > now() + interval '5 minutes'
     or p_deadline_at <> p_checked_in_at + interval '39 hours' then
    return false;
  end if;

  select claimer_id into v_witness_id
  from invites
  where inviter_id = p_subject_id
    and claimed_at is not null
    and claimer_id is not null
  order by claimed_at desc
  limit 1;

  if v_witness_id is null then
    return false;
  end if;

  -- Serialize refreshes for one subject. This prevents two concurrent retries
  -- from both observing an alerted row and enqueueing duplicate restorations.
  select status, last_check_in_at
    into v_prior_status, v_prior_check_in_at
  from watchdogs
  where subject_id = p_subject_id
  for update;

  -- An older retry is already represented by the newer server record. Treat it
  -- as an idempotent success and never move the server deadline backwards.
  if v_prior_check_in_at is not null
     and p_checked_in_at < v_prior_check_in_at then
    return true;
  end if;

  insert into watchdogs (
    subject_id, witness_id, last_check_in_at, deadline_at, status,
    overdue_at, last_alert_at, updated_at
  ) values (
    p_subject_id, v_witness_id, p_checked_in_at, p_deadline_at, 'active',
    null, null, now()
  )
  on conflict (subject_id) do update
  set witness_id = excluded.witness_id,
      last_check_in_at = excluded.last_check_in_at,
      deadline_at = excluded.deadline_at,
      status = 'active',
      overdue_at = null,
      -- A restored record must be eligible for a new alert after its next
      -- lapse. Leaving this marker populated suppresses all future alerts.
      last_alert_at = null,
      updated_at = now();

  if v_prior_status in ('overdue','alerted') then
    insert into witness_alert_outbox(subject_id, witness_id, kind)
    values (p_subject_id, v_witness_id, 'record_restored');
  end if;

  return true;
end;
$$;

revoke all on function public.refresh_watchdog(uuid, timestamptz, timestamptz) from public;
grant execute on function public.refresh_watchdog(uuid, timestamptz, timestamptz) to anonymous;

comment on function public.refresh_watchdog(uuid, timestamptz, timestamptz) is
  'Idempotent 39-hour watchdog refresh; rejects future/non-canonical deadlines and prevents stale retries from moving the record backwards.';
