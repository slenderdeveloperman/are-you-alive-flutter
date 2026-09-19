import { alertMessage, type AlertKind } from './messages.js';

export type SendResult =
  | { ok: true; providerMessageId: string }
  | { ok: false; retryable: boolean; error: string };

export async function sendWitnessEmail(input: {
  outboxId: string;
  kind: AlertKind;
  email: string;
}): Promise<SendResult> {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.RESEND_FROM_EMAIL;
  if (!apiKey || !from) {
    return { ok: false, retryable: false, error: 'Resend configuration missing' };
  }

  const message = alertMessage(input.kind);
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `aya/witness-alert/${input.outboxId}`,
      },
      body: JSON.stringify({
        from,
        to: [input.email],
        subject: message.subject,
        text: message.text,
        html: message.html,
        tags: [
          { name: 'system', value: 'aya-witness' },
          { name: 'kind', value: input.kind },
        ],
      }),
    });

    const body = await response.text();
    let parsed: unknown;
    try {
      parsed = JSON.parse(body);
    } catch {
      parsed = null;
    }

    if (response.ok) {
      const id =
        parsed && typeof parsed === 'object' && 'id' in parsed
          ? String((parsed as { id: unknown }).id)
          : '';
      if (!id) {
        return { ok: false, retryable: true, error: 'Resend returned no message id' };
      }
      return { ok: true, providerMessageId: id };
    }

    const retryable = response.status === 429 || response.status >= 500;
    return {
      ok: false,
      retryable,
      error: `Resend ${response.status}: ${body.slice(0, 500)}`,
    };
  } catch (error) {
    return {
      ok: false,
      retryable: true,
      error: error instanceof Error ? error.message : 'Unknown Resend transport error',
    };
  }
}
