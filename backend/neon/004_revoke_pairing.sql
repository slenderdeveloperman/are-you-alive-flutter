-- AYA 0.3 / FLD-AYA-01
-- Explicit relationship revocation.
--
-- A subject removing/changing a designated witness must remove the server-side
-- pairing and watchdog state too. The caller proves possession of both the
-- subject's opaque device UUID and the current invite code; neither value is
-- sufficient alone.

create or replace function public.revoke_pairing(
  p_code text,
  p_inviter_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_found boolean;
begin
  select exists(
    select 1 from invites
    where code = p_code
      and inviter_id = p_inviter_id
  ) into v_found;

  if not v_found then
    return false;
  end if;

  -- Remove queued/delivered operational envelopes for this relationship before
  -- removing the watchdog. There are no foreign keys by design, so make the
  -- deletion order explicit.
  delete from witness_alert_outbox
  where subject_id = p_inviter_id;

  delete from watchdogs
  where subject_id = p_inviter_id;

  delete from invites
  where code = p_code
    and inviter_id = p_inviter_id;

  return true;
end;
$$;

revoke all on function public.revoke_pairing(text, uuid) from public;
grant execute on function public.revoke_pairing(text, uuid) to anonymous;
