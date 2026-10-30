// Reproducible two-checkout acceptance. Only the fixture owner sees PostgreSQL.
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline';
const execute = promisify(execFile);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const option = process.argv.indexOf('--data-action-root');
assert(option >= 0 && process.argv[option + 1], 'Pass --data-action-root /absolute/path/to/data-action');
const dataAction = path.resolve(process.argv[option + 1]);
const scratch = mkdtempSync(path.join(tmpdir(), 'cenit-data-action-journey-'));
const owned = new Set();
let fixture, mongoId, manifest, configFile, mongoEndpoint;
let stopping = false;
const envBase = { PATH: process.env.PATH, HOME: process.env.HOME, TMPDIR: process.env.TMPDIR };
const docker = (...args) => execFileSync('docker', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const jsonFile = (name, value) => { const file = path.join(scratch, name); writeFileSync(file, JSON.stringify(value), { mode: 0o600 }); return file; };
const report = (scenario, evidence = {}) => console.log(JSON.stringify({ ...evidence, scenario, status: 'passed' }));
function stop() { stopping = true; for (const child of owned) child.kill('SIGTERM'); fixture?.kill('SIGTERM'); }
process.on('SIGINT', stop); process.on('SIGTERM', stop);
async function consumer(mode, args = [], expectedCode = 0) {
  assert(!stopping, 'Journey interrupted');
  const child = spawn('rbenv', ['exec', 'bundle', 'exec', 'ruby', 'experiments/data_action/consumer.rb', configFile, mode, ...args], {
    cwd: root, env: { ...envBase, RAILS_ENV: 'test', DB_TEST_HOST: mongoEndpoint, DB_TEST: `cenit_data_action_journey_${process.pid}`,
      UNICORN_CENIT_SERVER: 'true', SKIP_DB_INITIALIZATION: 'true', CENIT_LOCAL_FAULTS: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  owned.add(child);
  let output = '', errors = '';
  child.stdout.on('data', (data) => { output += data; });
  child.stderr.on('data', (data) => { errors += data; });
  const timer = setTimeout(() => child.kill('SIGTERM'), 90_000);
  const code = await new Promise((resolve, reject) => { child.once('error', reject); child.once('close', resolve); });
  clearTimeout(timer); owned.delete(child);
  assert.equal(code, expectedCode, `Cenit ${mode} failed: ${errors.slice(-1600)} ${output.slice(-1600)}`);
  const line = output.split('\n').filter((item) => item.startsWith('CENIT_RESULT ')).at(-1);
  assert(line, `Cenit ${mode} returned no correlated result: ${output.slice(-1200)}`);
  return JSON.parse(line.slice('CENIT_RESULT '.length));
}
async function control(route, body) {
  const response = await fetch(manifest.fixtureControlOrigin + route, { method: body === undefined ? 'GET' : 'POST',
    headers: { authorization: `Bearer ${manifest.fixtureControlToken}`, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(15_000) });
  assert.equal(response.status, 200, `Fixture ${route} failed`); return response.json();
}
async function source(route, body, expected = 200) {
  const response = await fetch(manifest.origin + '/api/integration/v1' + route, { method: body === undefined ? 'GET' : 'POST',
    headers: { authorization: `Bearer ${readFileSync(manifest.serviceTokenFile, 'utf8').trim()}`, 'x-data-action-workspace-id': manifest.workspaceId,
      'x-data-action-integration-id': manifest.profileId, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(15_000) });
  assert.equal(response.status, expected, `Public ${route} failed`); return response.json();
}
const status = () => consumer('status');
const deliveryStatus = () => source(`/subscriptions/${manifest.subscriptionId}/status`);
const jobFor = async (recordId) => (await status()).jobs.find((job) => job.recordId === recordId);
const baseOrder = { source: 'synthetic', externalOrderId: 'cenit-order-1', customer: { name: 'Synthetic buyer', address: { city: 'Miami' } },
  items: [{ sku: 'SKU-1', quantity: 2, unitPriceMinor: 1250 }, { sku: 'SKU-2', quantity: 1, unitPriceMinor: 50 }] };
try {
  fixture = spawn(process.execPath, ['scripts/run-business-foundation-local.mjs', '--cenit-fixture'], { cwd: dataAction, env: envBase, stdio: ['ignore', 'pipe', 'pipe'] });
  let fixtureTail = '';
  fixture.stderr.on('data', (chunk) => { fixtureTail = (fixtureTail + chunk).slice(-4000); });
  console.log(JSON.stringify({ status: 'starting', fixtureProject: `data-action-foundation-${fixture.pid}` }));
  const reader = createInterface({ input: fixture.stdout });
  const ready = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Fixture startup timed out: ' + fixtureTail)), 180_000);
    reader.on('line', (line) => { try { const value = JSON.parse(line); if (value.status === 'cenit-fixture-ready') { clearTimeout(timer); resolve(value); } } catch {} });
    fixture.once('error', (error) => { clearTimeout(timer); reject(error); });
    fixture.once('exit', (code) => { clearTimeout(timer); reject(new Error(`Fixture exited ${code}: ${fixtureTail}`)); });
  });
  manifest = JSON.parse(readFileSync(ready.manifestFile, 'utf8'));
  const consumerConfig = Object.fromEntries(['origin', 'workspaceId', 'environmentId', 'profileId', 'subscriptionId',
    'objectTypeVersionId', 'queryDefinitionVersionId', 'operationVersionIds', 'serviceTokenFile', 'sinkOrigin']
    .map((key) => [key, manifest[key]]));
  assert(!JSON.stringify(consumerConfig).includes('postgresql://'));
  configFile = jsonFile('consumer.json', consumerConfig);
  mongoId = docker('run', '-d', '--rm', '-p', '127.0.0.1::27017', 'mongo@sha256:8bb4442761a63a8dda452744082cdac9644b429807eb977b42324a63cef59ca4', '--quiet');
  mongoEndpoint = docker('port', mongoId, '27017/tcp');
  assert.match(mongoEndpoint, /^127\.0\.0\.1:\d+$/);
  for (let attempt = 0; ; attempt++) {
    try { docker('exec', mongoId, 'mongosh', '--quiet', '--eval', 'db.adminCommand({ping:1}).ok'); break; }
    catch { assert(attempt < 30, 'MongoDB did not become ready'); await new Promise((resolve) => setTimeout(resolve, 500)); }
  }
  console.log(JSON.stringify({ status: 'local-stores-ready', fixtureProject: `data-action-foundation-${fixture.pid}`,
    mongoContainer: mongoId, temporaryDirectory: scratch, fixtureDirectory: path.dirname(ready.manifestFile) }));
  await consumer('bootstrap');
  const invalid = jsonFile('invalid.json', { ...baseOrder, items: [{ sku: 'SKU-1', quantity: 1.5, unitPriceMinor: 1250 }] });
  const denied = await consumer('intake', [invalid, path.join(scratch, 'invalid-intent.json')], 2);
  assert(denied.fields.some((field) => field.path === 'items[0].quantity'));
  assert.equal((await control('/status')).records, 0);
  report('invalid nested order');
  const input = jsonFile('order-1.json', baseOrder), intent = path.join(scratch, 'intent-1.json');
  const [first, retry] = await Promise.all([consumer('intake', [input, intent]), consumer('intake', [input, intent])]);
  assert.deepEqual(first, retry); assert.equal(first.revision, 1);
  assert.equal((await control('/status')).records, 1);
  assert.equal((await control('/status')).facts.length, 1);
  assert.equal((await deliveryStatus()).deliveries.length, 1);
  assert.equal((await consumer('command', [first.commandId])).status, 'completed');
  report('concurrent authenticated intake commits one Command and record', first);
  const accepted = await consumer('receive', ['crash-after-accept'], 75);
  assert.equal((await jobFor(first.recordId)).state, 'pending');
  const initialDelivery = (await deliveryStatus()).deliveries[0];
  assert.equal(initialDelivery.state, 'leased');
  // The fixture owner advances expired test leases; the consumer never receives SQL credentials.
  await control('/expire-deliveries', {});
  await consumer('receive');
  assert.equal((await status()).jobs.length, 1);
  assert.equal((await deliveryStatus()).deliveries[0].state, 'acknowledged');
  assert.equal(accepted.eventId, initialDelivery.eventId);
  report('durable acceptance before acknowledgment', { eventId: accepted.eventId, jobId: accepted.jobId });
  const changed = jsonFile('updated.json', { ...baseOrder, customer: { name: 'Synthetic buyer', address: { city: 'Barcelona' } },
    items: [{ sku: 'SKU-1', quantity: 99, unitPriceMinor: 1250 }] });
  const edited = await consumer('update', [changed, path.join(scratch, 'edit-intent.json'), first.recordId, '1']);
  assert.equal(edited.revision, 2);
  await control('/fault', { mode: 'transient-once' }); await consumer('work');
  assert.equal((await jobFor(first.recordId)).state, 'pending'); assert.equal((await control('/status')).effects.length, 0);
  await consumer('advance-work'); await control('/fault', { mode: 'lost-once' }); await consumer('work');
  assert.equal((await control('/status')).effects.length, 1); assert.equal((await jobFor(first.recordId)).state, 'pending');
  await consumer('advance-work'); await consumer('work');
  const completed = await jobFor(first.recordId), downstream = (await control('/status')).effects;
  assert.equal(completed.state, 'completed'); assert.equal(completed.revision, 1); assert.equal(completed.attempts, 3);
  assert.equal(downstream.length, 1); assert.equal(downstream[0].body.shipTo, 'Miami');
  assert.equal(downstream[0].body.lines[0].units, 2); assert.equal(downstream[0].body.lines[0].amountMinor, 2500);
  assert.equal(completed.downstreamReceipt.effectKey, completed.effectKey);
  report('lost successful response reconciles the immutable original revision', { ...first, eventId: completed.eventId,
    jobId: completed.jobId, delivery: 'acknowledged', downstreamReceipt: completed.downstreamReceipt });
  const createOrder = async (number) => {
    const file = jsonFile(`order-${number}.json`, { ...baseOrder, externalOrderId: `cenit-order-${number}` });
    return consumer('intake', [file, path.join(scratch, `intent-${number}.json`)]);
  };
  const second = await createOrder(2); await consumer('receive');
  await consumer('work', ['crash-after-effect'], 76);
  assert.equal((await jobFor(second.recordId)).state, 'leased');
  await consumer('advance-work'); await consumer('work');
  assert.equal((await jobFor(second.recordId)).state, 'completed'); assert.equal((await control('/status')).effects.length, 2);
  report('process restart after a committed external effect');
  const third = await createOrder(3); await consumer('receive'); await control('/fault', { mode: 'unavailable' });
  for (let attempt = 0; attempt < 8; attempt++) { await consumer('work'); if (attempt < 7) await consumer('advance-work'); }
  const dead = await jobFor(third.recordId); assert.equal(dead.state, 'dead_lettered'); assert.equal(dead.attempts, 8);
  assert.equal(dead.attemptHistory.length, 8); assert.equal((await control('/status')).effects.length, 2);
  await control('/fault', { mode: 'normal' });
  await consumer('replay', [dead.jobId, 'Reviewed synthetic outage; simulator recovered']); await consumer('work');
  const replayed = await jobFor(third.recordId);
  assert.equal(replayed.state, 'completed'); assert.equal(replayed.effectKey, dead.effectKey); assert.equal(replayed.eventId, dead.eventId);
  assert.equal(replayed.replays.length, 1); assert.equal(replayed.attemptHistory.length, 9);
  report('dead letter and reviewed replay preserve effect identity');
  const fourth = await createOrder(4);
  const claims = await Promise.all([source(`/subscriptions/${manifest.subscriptionId}/claim`, { limit: 1 }), source(`/subscriptions/${manifest.subscriptionId}/claim`, { limit: 1 })]);
  const events = claims.flatMap((value) => value.events); assert.equal(events.length, 1);
  const oldClaim = events[0]; await control('/expire-deliveries', {});
  const fresh = (await source(`/subscriptions/${manifest.subscriptionId}/claim`, { limit: 1 })).events[0];
  assert.notEqual(oldClaim.fence, fresh.fence);
  const stale = await source(`/subscriptions/${manifest.subscriptionId}/ack`, { eventId: oldClaim.eventId, fence: oldClaim.fence }, 409);
  assert.equal(stale.error.code, 'STALE_LEASE');
  await control('/expire-deliveries', {}); await consumer('receive'); await consumer('work');
  assert.equal((await jobFor(fourth.recordId)).state, 'completed');
  report('stale event fence and concurrent pull claims');
  const fifth = await createOrder(5);
  let exhaustedEvent;
  for (let attempt = 0; attempt < 8; attempt++) {
    const claim = (await source(`/subscriptions/${manifest.subscriptionId}/claim`, { limit: 1 })).events[0];
    assert(claim);
    exhaustedEvent ??= claim.eventId;
    assert.equal(claim.eventId, exhaustedEvent);
    await source(`/subscriptions/${manifest.subscriptionId}/fail`, { eventId: claim.eventId, fence: claim.fence,
      code: 'SYNTHETIC_CONSUMER_UNAVAILABLE', retryable: true });
    await control('/ready-deliveries', {});
  }
  assert.equal((await deliveryStatus()).deliveries.find((delivery) => delivery.eventId === exhaustedEvent).state, 'dead_lettered');
  const sourceReplay = await source(`/subscriptions/${manifest.subscriptionId}/replay`, {
    eventId: exhaustedEvent, reason: 'Reviewed synthetic consumer outage; Cenit can accept durably again' });
  assert.equal(sourceReplay.replayed, true);
  await consumer('receive'); await consumer('work');
  const sourceRecovered = (await deliveryStatus()).deliveries.find((delivery) => delivery.eventId === exhaustedEvent);
  assert.equal(sourceRecovered.state, 'acknowledged'); assert.equal(sourceRecovered.attemptHistory.length, 9);
  assert.equal((await jobFor(fifth.recordId)).eventId, exhaustedEvent);
  assert.equal((await control('/status')).replayAudits, 1);
  report('public reviewed event replay retains event identity and audit evidence');
  const deliveries = (await deliveryStatus()).deliveries, jobs = (await status()).jobs, final = await control('/status');
  assert.equal(deliveries.length, 5); assert(deliveries.every((event) => event.state === 'acknowledged'));
  assert.equal(jobs.length, 5); assert(jobs.every((job) => job.state === 'completed'));
  assert.equal(final.records, 5); assert.equal(final.effects.length, 5);
  assert.equal(final.facts.length, 6);
  for (const job of jobs) {
    const event = deliveries.find((delivery) => delivery.eventId === job.eventId);
    assert.equal(event.commandId, job.commandId); assert.equal(event.correlationId, job.correlationId);
    assert.equal(event.recordId, job.recordId); assert.equal(event.revision, job.revision);
  }
  console.log(JSON.stringify({ status: 'passed', businessRecords: final.records, eventDeliveries: deliveries.length,
    consumerJobs: jobs.length, downstreamEffects: final.effects.length, correlated: jobs.map((job) => ({
      commandId: job.commandId, correlationId: job.correlationId, recordId: job.recordId, revision: job.revision,
      eventId: job.eventId, eventDelivery: 'acknowledged', consumerJob: job.jobId, downstreamReceipt: job.downstreamReceipt })) }));
} finally {
  const activeChildren = [...owned];
  for (const child of activeChildren) child.kill('SIGTERM');
  await Promise.all(activeChildren.map((child) => new Promise((resolve) => {
    if (child.exitCode !== null || child.signalCode !== null) return resolve();
    const timer = setTimeout(() => { child.kill('SIGKILL'); resolve(); }, 10_000);
    child.once('close', () => { clearTimeout(timer); resolve(); });
  })));
  if (fixture && fixture.exitCode === null && fixture.signalCode === null) {
    fixture.kill('SIGTERM');
    await new Promise((resolve) => { const timer = setTimeout(resolve, 30_000); fixture.once('exit', () => { clearTimeout(timer); resolve(); }); });
    assert(fixture.exitCode !== null || fixture.signalCode !== null, 'Fixture cleanup did not finish; inspect the owned process.');
  }
  if (mongoId) docker('rm', '-f', mongoId);
  rmSync(scratch, { recursive: true, force: true });
  process.removeListener('SIGINT', stop); process.removeListener('SIGTERM', stop);
}
