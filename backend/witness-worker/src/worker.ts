import type { AlertKind, LeasedAlert } from './db.js';
import type { SendResult } from './resend.js';

export type WorkerRunResult = {
  leased: number;
  submitted: number;
  retried: number;
  dead: number;
};

export type WorkerDependencies = {
  evaluateAndLease: (limit: number) => Promise<LeasedAlert[]>;
  sendWitnessEmail: (input: {
    outboxId: string;
    kind: AlertKind;
    email: string;
  }) => Promise<SendResult>;
  markSubmitted: (id: string, providerMessageId: string) => Promise<void>;
  markRetry: (id: string, attemptCount: number, error: string) => Promise<void>;
  markTerminal: (id: string, error: string) => Promise<void>;
};

/**
 * Runs one bounded, stateless delivery pass. Database leasing provides the
 * cross-invocation idempotency boundary; this function keeps provider calls
 * isolated so one bad address/provider response cannot abort the batch.
 */
export async function processWitnessAlerts(
  dependencies: WorkerDependencies,
  limit = 25,
): Promise<WorkerRunResult> {
  const jobs = await dependencies.evaluateAndLease(limit);
  let submitted = 0;
  let retried = 0;
  let dead = 0;

  for (const job of jobs) {
    if (!job.delivery_email) {
      await dependencies.markTerminal(job.id, 'Witness pairing has no delivery email');
      dead += 1;
      continue;
    }

    const result = await dependencies.sendWitnessEmail({
      outboxId: job.id,
      kind: job.kind,
      email: job.delivery_email,
    });

    if (result.ok) {
      await dependencies.markSubmitted(job.id, result.providerMessageId);
      submitted += 1;
    } else if (result.retryable) {
      await dependencies.markRetry(job.id, job.attempt_count, result.error);
      retried += 1;
    } else {
      await dependencies.markTerminal(job.id, result.error);
      dead += 1;
    }
  }

  return { leased: jobs.length, submitted, retried, dead };
}
