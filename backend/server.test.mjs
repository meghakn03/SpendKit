import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

test('API protects financial data and preserves confirmed card state on restart', { timeout: 8000 }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'spendkit-api-'));
  let child;

  async function stop() {
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    const exited = once(child, 'exit');
    child.kill();
    await exited;
  }

  async function start() {
    child = spawn(process.execPath, [fileURLToPath(new URL('./server.mjs', import.meta.url))], {
      env: { ...process.env, SPENDKIT_PORT: '0', SPENDKIT_DB: join(dir, 'test.sqlite') },
      stdio: ['ignore', 'pipe', 'inherit'],
    });
    const [stdout] = await Promise.race([
      once(child.stdout, 'data'),
      once(child, 'exit').then(() => { throw new Error('API exited before startup'); }),
    ]);
    return stdout.toString().trim().split(' ').at(-1);
  }

  function call(base, path, { method = 'GET', token, body } = {}) {
    const headers = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body) headers['Content-Type'] = 'application/json';
    return fetch(`${base}${path}`, {
      method, headers, body: body ? JSON.stringify(body) : undefined,
    });
  }

  try {
    let base = await start();
    assert.equal((await call(base, '/transactions')).status, 401);
    assert.equal((await call(base, '/session', { method: 'POST', body: { code: '0000' } })).status, 401);

    const signIn = () => call(base, '/session', { method: 'POST', body: { code: '2048' } });
    const { token } = await (await signIn()).json();
    const rows = await (await call(base, '/transactions', { token })).json();
    assert.equal(rows.length, 48);
    assert.ok(rows.every(({ pence }) => Number.isInteger(pence)));
    const simulate = (pence, channel = 'purchase') => call(base, '/card/simulations', {
      method: 'POST', token, body: { pence, channel },
    });
    assert.equal((await simulate(0)).status, 400);
    assert.equal((await (await simulate(50000)).json()).reason, 'approved');
    assert.equal((await (await simulate(50001)).json()).reason, 'overLimit');
    const freeze = (code) => call(base, '/card', { method: 'PUT', token, body: { code, frozen: true } });
    assert.equal((await freeze('0000')).status, 403);
    assert.equal((await (await call(base, '/account', { token })).json()).frozen, false);
    assert.equal((await (await freeze('2048')).json()).frozen, true);
    assert.equal((await (await freeze('2048')).json()).frozen, true);
    const controls = (code, transactionLimitPence, atmBlocked) => call(base, '/card/controls', {
      method: 'PUT', token, body: { code, transactionLimitPence, atmBlocked },
    });
    assert.equal((await controls('0000', 25099, true)).status, 403);
    assert.equal((await controls('2048', 1200001, true)).status, 400);
    const updated = await (await controls('2048', 25099, true)).json();
    assert.equal(updated.transactionLimitPence, 25099);
    assert.equal(updated.atmBlocked, true);
    assert.equal(updated.frozen, true);
    assert.equal((await (await simulate(100, 'atm')).json()).reason, 'cardFrozen');
    await call(base, '/card', { method: 'PUT', token, body: { code: '2048', frozen: false } });
    assert.equal((await (await simulate(100, 'atm')).json()).reason, 'atmBlocked');
    assert.equal((await (await simulate(100)).json()).reason, 'approved');
    assert.equal((await (await call(base, '/account', { token })).json()).availablePence, 842560);
    await freeze('2048');
    assert.equal((await call(base, '/session', { method: 'DELETE', token })).status, 204);
    assert.equal((await call(base, '/account', { token })).status, 401);

    await stop();
    base = await start();
    const restored = (await (await signIn()).json()).account;
    assert.equal(restored.frozen, true);
    assert.equal(restored.transactionLimitPence, 25099);
    assert.equal(restored.atmBlocked, true);
  } finally {
    await stop();
    await rm(dir, { recursive: true, force: true });
  }
});
