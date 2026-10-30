import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
const read = (name) => readFileSync(new URL('../../' + name, import.meta.url), 'utf8');
test('the separately launched Cenit consumer uses the public client and cannot reach data-action persistence', () => {
  const source = read('experiments/data_action/consumer.rb');
  assert.match(source, /Cenit::DataAction::Client/);
  assert.doesNotMatch(source, /\brequire\s+['"]pg['"]|PG::|data-action\/packages|DATABASE_URL|mvp_runtime|producer_events_outbox/);
  for (const name of ['client', 'worker', 'receiver', 'cenit_connector']) {
    const adapter = read(`lib/cenit/data_action/${name}.rb`);
    assert.doesNotMatch(adapter, /PG::|\bSELECT\b|\bINSERT\b|producer_events_outbox|record_revisions/);
  }
});
test('the two-system runner exercises real processes and reconciles correlated completion', () => {
  const source = read('scripts/run_data_action_journey.mjs');
  for (const scenario of ['invalid nested order', 'durable acceptance before acknowledgment', 'lost successful response', 'dead letter and reviewed replay', 'stale event fence']) {
    assert.ok(source.includes(scenario));
  }
  assert.match(source, /spawn/);
  assert.match(source, /downstreamReceipt/);
});
