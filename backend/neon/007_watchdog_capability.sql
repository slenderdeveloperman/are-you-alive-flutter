-- AYA 0.3 / FLD-AYA-01
-- Bind subject-owned watchdog operations to a per-install capability.
--
-- The Data API still uses Neon anonymous JWTs for transport, but an anonymous
-- JWT is not proof that the caller owns a particular subject record. The app
-- therefore generates a random capability, stores it in secure storage, and
-- sends it only to these subject-owned RPCs. Neon stores only its SHA-256
-- digest. Losing the capability means re-pairing; it is never recoverable
-- from the database.

create extension if not exists pgcrypto;

alter table public.invites
  add column if not exists inviter_capability_hash text;

create or replace function public.aya_capability_hash(p_capability text)
returns text
language sql
immutable
strict
as $$
  select encode(digest(p_capability, 'sha256'), 'hex');
$$;

revoke all on function public.aya_capability_hash(text) from public;

-- Replace the old two-argument create RPC. A matching claimed row can be
-- upgraded in place so existing pairings survive the capability rollout.
drop function if exists public.create_invite(text, uuid);

create or replace function public.create_invite(
  p_code text,
  p_inviter_id uuid,
  p_inviter_capability text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_updated integer;
begin
  if p_code is null
     or p_inviter_capability is null
     or p_code !~ '^AYA-[0-9A-HJKMNP-TV-Z]{6}$'
     or p_inviter_capability !~ '^[0-9a-fA-F]{64}$' then
    return false;
  end if;

  v_hash := public.aya_capability_hash(p_inviter_capability);

  -- Upgrade a row created before this migration, or refresh the capability
  -- on the subject's own still-unclaimed invite.
  update invites
  set inviter_capability_hash = v_hash
  where code = p_code
    and inviter_id = p_inviter_id
    and (
      inviter_capability_hash is null
      or inviter_capability_hash = v_hash
      or claimed_at is null
    );
  get diagnostics v_updated = row_count;
  if v_updated = 1 then
    return true;
  end if;

  delete from invites
  where claimed_at is null
    and created_at < now() - interval '30 days';

  -- One active invite per inviter: replace any previous unclaimed one.
  delete from invites
  where inviter_id = p_inviter_id
    and claimed_at is null;

  begin
    insert into invites (code, inviter_id, inviter_capability_hash)
    values (p_code, p_inviter_id, v_hash);
  exception when unique_violation then
    return false; -- Caller regenerates and retries.
  end;

  return true;
end;
$$;

revoke all on function public.create_invite(text, uuid, text) from public;
grant execute on function public.create_invite(text, uuid, text) to anonymous;

-- Remove the anonymous, UUID-only refresh path. A caller must possess both
-- the opaque subject id and the secure-storage capability for its pairing.
drop function if exists public.refresh_watchdog(uuid, timestamptz, timestamptz);

create or replace function public.refresh_watchdog(
  p_subject_id uuid,
  p_checked_in_at timestamptz,
  p_deadline_at timestamptz,
  p_subject_capability text
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
  if p_subject_capability is null
     or p_subject_capability !~ '^[0-9a-fA-F]{64}$'
     or p_checked_in_at is null
     or p_deadline_at is null
     or p_checked_in_at > now() + interval '5 minutes'
     or p_deadline_at <> p_checked_in_at + interval '39 hours' then
    return false;
  end if;

  select claimer_id into v_witness_id
  from invites
  where inviter_id = p_subject_id
    and inviter_capability_hash = public.aya_capability_hash(p_subject_capability)
    and claimed_at is not null
    and claimer_id is not null
  order by claimed_at desc
  limit 1;

  if v_witness_id is null then
    return false;
  end if;

  select status, last_check_in_at
    into v_prior_status, v_prior_check_in_at
  from watchdogs
  where subject_id = p_subject_id
  for update;

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
      last_alert_at = null,
      updated_at = now();

  if v_prior_status in ('overdue','alerted') then
    insert into witness_alert_outbox(subject_id, witness_id, kind)
    values (p_subject_id, v_witness_id, 'record_restored');
  end if;

  return true;
end;
$$;

revoke all on function public.refresh_watchdog(uuid, timestamptz, timestamptz, text) from public;
grant execute on function public.refresh_watchdog(uuid, timestamptz, timestamptz, text) to anonymous;

-- Replace revocation with the same subject capability check. The old function
-- is removed so stale clients cannot continue using the UUID-only contract.
drop function if exists public.revoke_pairing(text, uuid);

create or replace function public.revoke_pairing(
  p_code text,
  p_inviter_id uuid,
  p_inviter_capability text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_found boolean;
begin
  if p_inviter_capability is null
     or p_inviter_capability !~ '^[0-9a-fA-F]{64}$' then
    return false;
  end if;

  select exists(
    select 1 from invites
    where code = p_code
      and inviter_id = p_inviter_id
      and inviter_capability_hash = public.aya_capability_hash(p_inviter_capability)
  ) into v_found;

  if not v_found then
    return false;
  end if;

  delete from witness_alert_outbox
  where subject_id = p_inviter_id;

  delete from watchdogs
  where subject_id = p_inviter_id;

  delete from invites
  where code = p_code
    and inviter_id = p_inviter_id
    and inviter_capability_hash = public.aya_capability_hash(p_inviter_capability);

  return true;
end;
$$;

revoke all on function public.revoke_pairing(text, uuid, text) from public;
grant execute on function public.revoke_pairing(text, uuid, text) to anonymous;

comment on column public.invites.inviter_capability_hash is
  'SHA-256 digest of the subject-owned secure-storage capability used by watchdog RPCs.';
