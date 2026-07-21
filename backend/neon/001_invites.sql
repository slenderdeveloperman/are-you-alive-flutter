-- Plan 009 Phase B: emergency-contact pairing backend (Neon).
-- Access model: the Data API's `anonymous` role gets EXECUTE on three
-- SECURITY DEFINER functions and nothing else. No direct table access,
-- so rows can never be listed or dumped through the API.

create table if not exists public.invites (
  code         text primary key,
  inviter_id   uuid not null,
  created_at   timestamptz not null default now(),
  claimed_at   timestamptz,
  claimer_id   uuid,
  claimer_name text
);

alter table public.invites enable row level security;

revoke all on table public.invites from anonymous;
revoke all on table public.invites from authenticated;

-- Creates (or replaces the caller's own unclaimed) invite. Also performs
-- opportunistic TTL cleanup of stale unclaimed invites: Neon free tier
-- scales compute to zero, so pg_cron can't be relied on to fire.
create or replace function public.create_invite(p_code text, p_inviter_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_code !~ '^AYA-[0-9A-HJKMNP-TV-Z]{6}$' then
    return false;
  end if;

  delete from invites
  where claimed_at is null
    and created_at < now() - interval '30 days';

  -- One active invite per inviter: replace any previous unclaimed one.
  delete from invites
  where inviter_id = p_inviter_id
    and claimed_at is null;

  begin
    insert into invites (code, inviter_id) values (p_code, p_inviter_id);
  exception when unique_violation then
    return false; -- Caller regenerates and retries.
  end;

  return true;
end;
$$;

-- One-shot claim. Returns 'claimed', 'already_claimed', or 'not_found'.
create or replace function public.claim_invite(
  p_code text,
  p_claimer_id uuid,
  p_claimer_name text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int;
begin
  update invites
  set claimed_at = now(),
      claimer_id = p_claimer_id,
      claimer_name = left(coalesce(p_claimer_name, ''), 60)
  where code = p_code
    and claimed_at is null;
  get diagnostics v_updated = row_count;

  if v_updated = 1 then
    return 'claimed';
  end if;

  if exists (select 1 from invites where code = p_code) then
    return 'already_claimed';
  end if;

  return 'not_found';
end;
$$;

-- Status probe for the inviter (plan 009 Phase D): 'pending', 'claimed',
-- or the load-bearing authoritative 'not_found'.
create or replace function public.get_invite_status(p_code text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select case when claimed_at is null then 'pending' else 'claimed' end
     from invites where code = p_code),
    'not_found'
  );
$$;

revoke all on function public.create_invite(text, uuid) from public;
revoke all on function public.claim_invite(text, uuid, text) from public;
revoke all on function public.get_invite_status(text) from public;

grant execute on function public.create_invite(text, uuid) to anonymous;
grant execute on function public.claim_invite(text, uuid, text) to anonymous;
grant execute on function public.get_invite_status(text) to anonymous;
