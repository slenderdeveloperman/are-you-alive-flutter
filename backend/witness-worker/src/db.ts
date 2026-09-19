import { neon } from '@neondatabase/serverless';

export type AlertKind = 'record_lapsed' | 'record_restored';

export type LeasedAlert = {
  id: string;
  kind: AlertKind;
  subject_id: string;
  witness_id: string;
  delivery_email: string;
  attempt_count: number;
};

function sql() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is required');
  return neon(url);
}

export async function evaluateAndLease(limit = 25): Promise<LeasedAlert[]> {
  const query = sql();
  await query`select public.evaluate_watchdogs()`;
  const rows = await query`select * from public.claim_witness_alerts(${limit})`;
  return rows as unknown as LeasedAlert[];
}

export async function markSubmitted(id: string, providerMessageId: string) {
  const query = sql();
  await query`
    update public.witness_alert_outbox
    set status = 'submitted',
        provider_message_id = ${providerMessageId},
        lease_until = null,
        last_error = null
    where id = ${id}::bigint
  `;
}

export async function markRetry(
  id: string,
  attemptCount: number,
  error: string,
) {
  const query = sql();
  const delays = [60, 300, 1800, 7200];
  if (attemptCount >= 5) {
    await query`
      update public.witness_alert_outbox
      set status = 'dead',
          lease_until = null,
          last_error = left(${error}, 1000)
      where id = ${id}::bigint
    `;
    return;
  }
  const seconds = delays[Math.max(0, Math.min(attemptCount - 1, delays.length - 1))];
  await query`
    update public.witness_alert_outbox
    set status = 'pending',
        lease_until = null,
        next_attempt_at = now() + make_interval(secs => ${seconds}),
        last_error = left(${error}, 1000)
    where id = ${id}::bigint
  `;
}

export async function markTerminal(id: string, error: string) {
  const query = sql();
  await query`
    update public.witness_alert_outbox
    set status = 'dead',
        lease_until = null,
        last_error = left(${error}, 1000)
    where id = ${id}::bigint
  `;
}

export async function applyProviderEvent(
  providerMessageId: string,
  providerEventId: string,
  eventType: string,
) {
  const query = sql();

  // Dedup is performed atomically by appending the provider event id only if
  // it has not been seen on this outbox row before.
  const rows = await query`
    update public.witness_alert_outbox
    set provider_event_ids = array_append(provider_event_ids, ${providerEventId}),
        status = case
          when ${eventType} = 'email.delivered' then 'delivered'
          when ${eventType} in ('email.bounced','email.failed','email.suppressed') then 'dead'
          else status
        end,
        delivered_at = case
          when ${eventType} = 'email.delivered' then now()
          else delivered_at
        end,
        last_error = case
          when ${eventType} in ('email.bounced','email.failed','email.suppressed')
            then left(${eventType}, 1000)
          else last_error
        end
    where provider_message_id = ${providerMessageId}
      and not (${providerEventId} = any(provider_event_ids))
    returning id
  `;
  return rows.length > 0;
}
