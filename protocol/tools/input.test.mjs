// Part 2 protocol tests: `node --test protocol/tools/input.test.mjs`
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { ReferenceDesktop, b64u, unb64u, pairProof, deriveSecret, sessionKey, inputMac } from './reference.mjs';

const vectors = JSON.parse(fs.readFileSync(new URL('../test-vectors.json', import.meta.url)));

test('session key and input MAC match the shared vectors (Python-generated)', () => {
  const key = sessionKey(unb64u(vectors.secret), vectors.clientNonce, vectors.serverNonce);
  assert.equal(b64u(key), vectors.sessionKey);
  assert.equal(b64u(inputMac(key, vectors.inputSeq, vectors.inputBody)), vectors.inputMac);
});

async function pairedPhone(desktop) {
  const ws = new WebSocket(`ws://127.0.0.1:${desktop.port}/`);
  const inbox = [], waiters = [];
  ws.onmessage = (e) => { const m = JSON.parse(e.data); const w = waiters.shift(); w ? w(m) : inbox.push(m); };
  ws.onclose = () => waiters.splice(0).forEach((w) => w({ type: '__closed' }));
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('connect failed')); });
  const next = () => new Promise((r) => (inbox.length ? r(inbox.shift()) : waiters.push(r)));
  const { serverNonce } = await next();
  const id = 'phone-' + b64u(crypto.randomBytes(9)), cn = b64u(crypto.randomBytes(16));
  const token = desktop.token.bytes;
  const send = (o) => ws.send(JSON.stringify({ v: 1, ...o }));
  send({ type: 'pair_request', deviceId: id, deviceName: 'Test phone', clientNonce: cn, proof: b64u(pairProof(token, id, cn, serverNonce)) });
  assert.equal((await next()).type, 'pair_pending');
  const accepted = await next();
  assert.equal(accepted.type, 'pair_accepted');
  assert.equal(accepted.accessibility, true);
  const key = sessionKey(deriveSecret(token, id, cn, serverNonce), cn, serverNonce);
  let seq = 0;
  const frame = (events, over = {}) => {
    seq += 1;
    const body = JSON.stringify({ ev: events });
    return { type: 'input', seq, t: seq * 8, body, mac: b64u(inputMac(key, seq, body)), ...over };
  };
  return { ws, next, send, frame };
}

test('signed input frames reach the engine, in order', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const p = await pairedPhone(d);
  p.send(p.frame([{ e: 'move', dx: 5, dy: 3 }, { e: 'btn', b: 'left', s: 'down', n: 1 }]));
  p.send(p.frame([{ e: 'scroll', dx: 0, dy: 9 }]));
  p.send({ type: 'ping', t: 42 });
  const pong = await p.next();
  assert.equal(pong.type, 'pong');
  assert.equal(pong.t, 42, 'pong echoes the ping timestamp');
  assert.deepEqual(d.received.map((e) => e.e), ['move', 'btn', 'scroll']);
  await d.stop();
});

test('bad MAC, replayed sequence, and invalid events end the session', async () => {
  const cases = [
    ['bad mac', (p) => p.frame([{ e: 'move', dx: 1, dy: 1 }], { mac: 'AAAA' }), 'bad_mac'],
    ['unsigned', (p) => { const f = p.frame([{ e: 'move', dx: 1, dy: 1 }]); delete f.mac; return f; }, 'invalid_command'],
    ['replay', (p) => ({ ...p.frame([{ e: 'move', dx: 1, dy: 1 }]), seq: 1 }), 'bad_mac'],   // seq changed after signing
    ['out of range', (p) => p.frame([{ e: 'move', dx: 99999, dy: 0 }]), 'invalid_command'],
    ['unknown event', (p) => p.frame([{ e: 'format_disk' }]), 'invalid_command'],
  ];
  for (const [name, make, reason] of cases) {
    const d = new ReferenceDesktop(); await d.start();
    const p = await pairedPhone(d);
    p.send(p.frame([{ e: 'move', dx: 2, dy: 2 }]));        // seq 1 accepted
    p.send(make(p));
    const err = await p.next();
    assert.equal(err.type, 'error', name);
    assert.equal(err.reason, reason, name);
    assert.equal((await p.next()).type, '__closed', name);
    assert.deepEqual(d.received.map((e) => e.e), ['move'], `${name}: nothing from the bad frame may be applied`);
    await d.stop();
  }
});

test('a replayed frame (same seq, valid MAC) is rejected', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const p = await pairedPhone(d);
  const f = p.frame([{ e: 'move', dx: 2, dy: 2 }]);
  p.send(f); p.send(f);
  const err = await p.next();
  assert.equal(err.reason, 'bad_sequence');
  assert.equal(d.received.length, 1);
  await d.stop();
});

test('unsigned input from an unauthenticated socket is refused', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const ws = new WebSocket(`ws://127.0.0.1:${d.port}/`);
  const got = [];
  ws.onmessage = (e) => got.push(JSON.parse(e.data));
  await new Promise((r) => (ws.onopen = r));
  await new Promise((r) => setTimeout(r, 50));
  ws.send(JSON.stringify({ v: 1, type: 'input', seq: 1, t: 0, body: '{"ev":[{"e":"move","dx":9,"dy":9}]}', mac: 'AAAA' }));
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(got.at(-1).reason, 'unauthenticated');
  assert.equal(d.received.length, 0);
  await d.stop();
});
