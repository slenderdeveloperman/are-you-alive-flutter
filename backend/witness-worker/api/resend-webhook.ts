import type { VercelRequest, VercelResponse } from '@vercel/node';
import { Webhook } from 'svix';
import { applyProviderEvent } from '../src/db.js';

async function readRawBody(req: VercelRequest): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString('utf8');
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  const secret = process.env.RESEND_WEBHOOK_SECRET;
  if (!secret) return res.status(503).json({ error: 'webhook_not_configured' });

  const rawBody = await readRawBody(req);
  const id = String(req.headers['svix-id'] ?? '');
  const timestamp = String(req.headers['svix-timestamp'] ?? '');
  const signature = String(req.headers['svix-signature'] ?? '');

  let event: {
    type?: string;
    data?: { email_id?: string };
  };
  try {
    event = new Webhook(secret).verify(rawBody, {
      'svix-id': id,
      'svix-timestamp': timestamp,
      'svix-signature': signature,
    }) as typeof event;
  } catch {
    return res.status(400).json({ error: 'invalid_signature' });
  }

  const type = event.type ?? '';
  const providerMessageId = event.data?.email_id ?? '';
  if (!providerMessageId || !id) {
    return res.status(200).json({ ignored: true });
  }

  const relevant = new Set([
    'email.delivered',
    'email.delivery_delayed',
    'email.bounced',
    'email.failed',
    'email.suppressed',
  ]);
  if (!relevant.has(type)) return res.status(200).json({ ignored: true });

  const changed = await applyProviderEvent(providerMessageId, id, type);
  return res.status(200).json({ accepted: true, changed });
}
