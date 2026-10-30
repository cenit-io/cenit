import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createInterface } from 'node:readline';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
const dataAction = process.env.CENIT_DATA_ACTION_ROOT;
test('Ctrl-C removes owned stores, processes and temporary credentials while preserving existing containers', {
  skip: !dataAction, timeout: 180_000,
}, async () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const dockerIds = () => execFileSync('docker', ['ps', '-q', '--no-trunc'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
  const before = dockerIds();
  const child = spawn(process.execPath, ['scripts/run_data_action_journey.mjs', '--data-action-root', dataAction], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let diagnostic = '', stores;
  child.stderr.on('data', (data) => { diagnostic = (diagnostic + data).slice(-2000); });
  const reader = createInterface({ input: child.stdout });
  reader.on('line', (line) => {
    try {
      const value = JSON.parse(line);
      if (value.status === 'local-stores-ready') { stores = value; child.kill('SIGINT'); }
    } catch {}
  });
  const timer = setTimeout(() => child.kill('SIGTERM'), 150_000);
  const code = await new Promise((resolve, reject) => { child.once('error', reject); child.once('close', resolve); });
  clearTimeout(timer);
  assert(stores, 'Runner never reached cancellable stores: ' + diagnostic);
  assert.notEqual(code, 0);
  assert.equal(existsSync(stores.temporaryDirectory), false);
  assert.equal(existsSync(stores.fixtureDirectory), false);
  const containers = dockerIds();
  assert(!containers.includes(stores.mongoContainer));
  for (const id of before) assert(containers.includes(id), 'An existing container disappeared');
  const fixtureContainers = execFileSync('docker', ['ps', '-aq', '--filter', `label=com.docker.compose.project=${stores.fixtureProject}`], { encoding: 'utf8' }).trim();
  assert.equal(fixtureContainers, '');
});
