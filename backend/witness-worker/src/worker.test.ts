import assert from 'node:assert/strict';
import test from 'node:test';

import type { LeasedAlert } from './db.js';
import type { WorkerDependencies } from './worker.js';
import { processWitnessAlerts } from './worker.ts';

const job = (overrides: Partial<LeasedAlert> = {}): LeasedAlert => ({
  id: '42',
  kind: 'record_lapsed' as const,
  subject_id: 'subject',
  witness_id: 'witness',
  delivery_email: 'witness@example.com',
  attempt_count: 1,
  ...overrides,
});

function dependencies(jobs: LeasedAlert[]) {
  const calls: string[] = [];
  const sendWitnessEmail: WorkerDependencies['sendWitnessEmail'] = async (
    input,
  ) => {
    calls.push(`send:${input.outboxId}`);
    return { ok: true as const, providerMessageId: 'provider-1' };
  };
  const workerDependencies: WorkerDependencies = {
    evaluateAndLease: async (limit: number) => {
      calls.push(`lease:${limit}`);
      return jobs;
    },
    sendWitnessEmail,
    markSubmitted: async (id: string) => {
      calls.push(`submitted:${id}`);
    },
    markRetry: async (id: string) => {
      calls.push(`retry:${id}`);
    },
    markTerminal: async (id: string) => {
      calls.push(`dead:${id}`);
    },
  };
  return {
    calls,
    dependencies: workerDependencies,
  };
}

test('successful job is sent once and marked submitted', async () => {
  const harness = dependencies([job()]);
  const result = await processWitnessAlerts(harness.dependencies, 25);

  assert.deepEqual(result, { leased: 1, submitted: 1, retried: 0, dead: 0 });
  assert.deepEqual(harness.calls, ['lease:25', 'send:42', 'submitted:42']);
});

test('missing witness email is dead-lettered without provider delivery', async () => {
  const harness = dependencies([job({ delivery_email: null })]);
  const result = await processWitnessAlerts(harness.dependencies);

  assert.deepEqual(result, { leased: 1, submitted: 0, retried: 0, dead: 1 });
  assert.deepEqual(harness.calls, ['lease:25', 'dead:42']);
});

test('retryable provider failures return the job to retry handling', async () => {
  const harness = dependencies([job({ attempt_count: 3 })]);
  harness.dependencies.sendWitnessEmail = async (input) => {
    harness.calls.push(`send:${input.outboxId}`);
    return { ok: false as const, retryable: true, error: 'timeout' };
  };
  const result = await processWitnessAlerts(harness.dependencies);

  assert.deepEqual(result, { leased: 1, submitted: 0, retried: 1, dead: 0 });
  assert.deepEqual(harness.calls, ['lease:25', 'send:42', 'retry:42']);
});

test('terminal provider failures are dead-lettered', async () => {
  const harness = dependencies([job()]);
  harness.dependencies.sendWitnessEmail = async (input) => {
    harness.calls.push(`send:${input.outboxId}`);
    return { ok: false as const, retryable: false, error: 'suppressed' };
  };
  const result = await processWitnessAlerts(harness.dependencies);

  assert.deepEqual(result, { leased: 1, submitted: 0, retried: 0, dead: 1 });
  assert.deepEqual(harness.calls, ['lease:25', 'send:42', 'dead:42']);
});
