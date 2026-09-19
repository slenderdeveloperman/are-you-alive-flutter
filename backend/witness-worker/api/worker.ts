import type { VercelRequest, VercelResponse } from '@vercel/node';
import { evaluateAndLease, markRetry, markSubmitted, markTerminal } from '../src/db.js';
import { sendWitnessEmail } from '../src/resend.js';

function authorized(req: VercelRequest) {
  const secret = process.env.WORKER_SECRET;
  return Boolean(secret) && req.headers.authorization === `Bearer ${secret}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST' && req.method !== 'GET') {
    res.setHeader('Allow', 'GET, POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }
  if (!authorized(req)) return res.status(401).json({ error: 'unauthorized' });

  let jobs;
  try {
    jobs = await evaluateAndLease(25);
  } catch (error) {
    return res.status(503).json({
      error: 'database_unavailable',
      detail: error instanceof Error ? error.message : 'unknown',
    });
  }

  let submitted = 0;
  let retried = 0;
  let dead = 0;

  for (const job of jobs) {
    if (!job.delivery_email) {
      await markTerminal(job.id, 'Witness pairing has no delivery email');
      dead += 1;
      continue;
    }

    const result = await sendWitnessEmail({
      outboxId: job.id,
      kind: job.kind,
      email: job.delivery_email,
    });

    if (result.ok) {
      await markSubmitted(job.id, result.providerMessageId);
      submitted += 1;
    } else if (result.retryable) {
      await markRetry(job.id, job.attempt_count, result.error);
      retried += 1;
    } else {
      await markTerminal(job.id, result.error);
      dead += 1;
    }
  }

  // Deliberately return aggregate operational state only; never expose PII.
  return res.status(200).json({
    leased: jobs.length,
    submitted,
    retried,
    dead,
  });
}
