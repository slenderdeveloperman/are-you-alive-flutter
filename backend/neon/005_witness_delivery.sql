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


-- Atomically lease a small batch for a stateless worker. The worker performs
-- network I/O only after this transaction has committed.
create or replace function public.claim_witness_alerts(p_limit integer default 25)
returns table (
  id bigint,
  kind text,
  subject_id uuid,
  witness_id uuid,
  delivery_email text,
  attempt_count integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select o.id
    from witness_alert_outbox o
    where (
      (o.status = 'pending' and o.next_attempt_at <= now())
      or
      (o.status = 'leased' and o.lease_until <= now())
    )
    order by o.id
    limit greatest(1, least(coalesce(p_limit, 25), 25))
    for update skip locked
  ),
  leased as (
    update witness_alert_outbox o
    set status = 'leased',
        lease_until = now() + interval '10 minutes',
        attempt_count = o.attempt_count + 1,
        last_error = null
    from candidates c
    where o.id = c.id
    returning o.id, o.kind, o.subject_id, o.witness_id, o.attempt_count
  )
  select l.id, l.kind, l.subject_id, l.witness_id, i.delivery_email, l.attempt_count
  from leased l
  join invites i
    on i.inviter_id = l.subject_id
   and i.claimer_id = l.witness_id
   and i.claimed_at is not null
   and i.delivery_email is not null;
end;
$$;

-- Direct table access stays denied to app roles. The delivery worker connects
-- with a server-side DATABASE_URL, not the app's anonymous Data API role.
revoke all on function public.claim_witness_alerts(integer) from public;

comment on function public.claim_witness_alerts(integer) is
  'AYA worker-only atomic lease of pending witness notifications.';
