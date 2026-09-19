-- AYA 0.3 / FLD-AYA-01
-- Witness-owned email delivery + durable worker state.

alter table public.invites
  add column if not exists delivery_email text;

alter table public.witness_alert_outbox
  add column if not exists status text not null default 'pending'
    check (status in ('pending','leased','submitted','delivered','dead')),
  add column if not exists attempt_count integer not null default 0,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists lease_until timestamptz,
  add column if not exists provider_message_id text,
  add column if not exists last_error text,
  add column if not exists provider_event_ids text[] not null default '{}';

create unique index if not exists witness_alert_provider_message_uq
  on public.witness_alert_outbox(provider_message_id)
  where provider_message_id is not null;

create index if not exists witness_alert_ready_idx
  on public.witness_alert_outbox(status, next_attempt_at, id)
  where status in ('pending','leased');

-- Replace the old claim signature. The witness supplies their own delivery
-- address; the inviter's address-book data is never uploaded for this purpose.
drop function if exists public.claim_invite(text, uuid, text);

create or replace function public.claim_invite(
  p_code text,
  p_claimer_id uuid,
  p_claimer_name text default null,
  p_delivery_email text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int;
  v_email text;
begin
  v_email := lower(trim(coalesce(p_delivery_email, '')));
  if v_email = ''
     or length(v_email) > 254
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    return 'invalid_email';
  end if;

  update invites
  set claimed_at = now(),
      claimer_id = p_claimer_id,
      claimer_name = left(coalesce(p_claimer_name, ''), 60),
      delivery_email = v_email
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

revoke all on function public.claim_invite(text, uuid, text, text) from public;
grant execute on function public.claim_invite(text, uuid, text, text) to anonymous;

-- Existing rows created before migration 005 may have delivered_at populated.
update public.witness_alert_outbox
set status = 'delivered'
where delivered_at is not null
  and status <> 'delivered';

comment on column public.invites.delivery_email is
  'Witness-supplied operational address for AYA lapse/restoration notices.';
