import type { VercelRequest, VercelResponse } from '@vercel/node';
import { evaluateAndLease, markRetry, markSubmitted, markTerminal } from '../src/db.js';
import { sendWitnessEmail } from '../src/resend.js';
import { processWitnessAlerts } from '../src/worker.js';

function authorized(req: VercelRequest) {
  // Vercel Cron sends `Authorization: Bearer $CRON_SECRET`. WORKER_SECRET
  // remains available for manual/external scheduler invocations.
  const secret = process.env.WORKER_SECRET ?? process.env.CRON_SECRET;
  return Boolean(secret) && req.headers.authorization === `Bearer ${secret}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST' && req.method !== 'GET') {
    res.setHeader('Allow', 'GET, POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }
  if (!authorized(req)) return res.status(401).json({ error: 'unauthorized' });

  try {
    const result = await processWitnessAlerts({
      evaluateAndLease,
      sendWitnessEmail,
      markRetry,
      markSubmitted,
      markTerminal,
    });
    // Deliberately return aggregate operational state only; never expose PII.
    return res.status(200).json(result);
  } catch (error) {
    return res.status(503).json({
      error: 'database_unavailable',
      detail: error instanceof Error ? error.message : 'unknown',
    });
  }
}
