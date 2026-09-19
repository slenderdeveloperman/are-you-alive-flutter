-- AYA 0.3 / FLD-AYA-01
-- Minimal server-side watchdog state.
--
-- Applying this migration creates watchdog state and evaluation primitives,
-- but does not by itself deliver witness notifications. A scheduler/worker
-- must call evaluate_watchdogs() and consume witness_alert_outbox before the
-- product may claim automatic witness alerts are operational.

create table if not exists public.watchdogs (
  subject_id          uuid primary key,
  witness_id          uuid not null,
  last_check_in_at    timestamptz not null,
  deadline_at         timestamptz not null,
  status              text not null default 'active'
                       check (status in ('active','overdue','alerted','resolved')),
  overdue_at          timestamptz,
  last_alert_at       timestamptz,
  updated_at          timestamptz not null default now()
);

create table if not exists public.witness_alert_outbox (
  id                  bigserial primary key,
  subject_id          uuid not null,
  witness_id          uuid not null,
  kind                text not null check (kind in ('record_lapsed','record_restored')),
  created_at          timestamptz not null default now(),
  delivered_at        timestamptz
);

alter table public.watchdogs enable row level security;
alter table public.witness_alert_outbox enable row level security;

revoke all on table public.watchdogs from anonymous;
revoke all on table public.witness_alert_outbox from anonymous;
revoke all on table public.watchdogs from authenticated;
revoke all on table public.witness_alert_outbox from authenticated;

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
begin
  if p_deadline_at <= p_checked_in_at
     or p_deadline_at > p_checked_in_at + interval '40 hours' then
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

  select status into v_prior_status
  from watchdogs where subject_id = p_subject_id;

  insert into watchdogs (
    subject_id, witness_id, last_check_in_at, deadline_at, status, updated_at
  ) values (
    p_subject_id, v_witness_id, p_checked_in_at, p_deadline_at, 'active', now()
  )
  on conflict (subject_id) do update
  set witness_id = excluded.witness_id,
      last_check_in_at = excluded.last_check_in_at,
      deadline_at = excluded.deadline_at,
      status = 'active',
      overdue_at = null,
      updated_at = now();

  if v_prior_status in ('overdue','alerted') then
    insert into witness_alert_outbox(subject_id, witness_id, kind)
    values (p_subject_id, v_witness_id, 'record_restored');
  end if;

  return true;
end;
$$;

create or replace function public.evaluate_watchdogs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  update watchdogs
  set status = 'overdue',
      overdue_at = coalesce(overdue_at, now()),
      updated_at = now()
  where status = 'active'
    and deadline_at <= now();

  with due as (
    select subject_id, witness_id
    from watchdogs
    where status = 'overdue'
      and deadline_at + interval '2 hours' <= now()
      and last_alert_at is null
    for update
  ), queued as (
    insert into witness_alert_outbox(subject_id, witness_id, kind)
    select subject_id, witness_id, 'record_lapsed' from due
    returning subject_id
  )
  update watchdogs w
  set status = 'alerted',
      last_alert_at = now(),
      updated_at = now()
  where w.subject_id in (select subject_id from queued);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.refresh_watchdog(uuid, timestamptz, timestamptz) from public;
revoke all on function public.evaluate_watchdogs() from public;

grant execute on function public.refresh_watchdog(uuid, timestamptz, timestamptz) to anonymous;
-- evaluate_watchdogs is intentionally NOT granted to anonymous.
