// Part 3 protocol tests: shortcut and system-action events. `node --test protocol/tools/shortcut.test.mjs`
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { ReferenceDesktop, b64u, pairProof, deriveSecret, sessionKey, inputMac, parseInputBody } from './reference.mjs';

async function pairedPhone(desktop) {
  const ws = new WebSocket(`ws://127.0.0.1:${desktop.port}/`);
  const inbox = [], waiters = [];
  ws.onmessage = (e) => { const m = JSON.parse(e.data); const w = waiters.shift(); w ? w(m) : inbox.push(m); };
  ws.onclose = () => waiters.splice(0).forEach((w) => w({ type: '__closed' }));
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('connect failed')); });
  const next = () => new Promise((r) => (inbox.length ? r(inbox.shift()) : waiters.push(r)));
  const { serverNonce } = await next();
  const id = 'phone-' + b64u(crypto.randomBytes(9)), cn = b64u(crypto.randomBytes(16)), token = desktop.token.bytes;
  const send = (o) => ws.send(JSON.stringify({ v: 1, ...o }));
  send({ type: 'pair_request', deviceId: id, deviceName: 'Test phone', clientNonce: cn, proof: b64u(pairProof(token, id, cn, serverNonce)) });
  assert.equal((await next()).type, 'pair_pending');
  assert.equal((await next()).type, 'pair_accepted');
  const key = sessionKey(deriveSecret(token, id, cn, serverNonce), cn, serverNonce);
  let seq = 0;
  const frame = (events) => { seq += 1; const body = JSON.stringify({ ev: events }); return { type: 'input', seq, t: seq * 8, body, mac: b64u(inputMac(key, seq, body)) }; };
  return { next, send, frame };
}

test('valid shortcut and system events are accepted in order', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const p = await pairedPhone(d);
  p.send(p.frame([{ e: 'shortcut', c: 17, m: 8 }, { e: 'shortcut', c: 48, m: 8, h: 600 }, { e: 'sys', a: 'mission_control' }, { e: 'sys', a: 'desktop_left' }]));
  p.send({ type: 'ping', t: 1 });
  assert.equal((await p.next()).type, 'pong');
  assert.deepEqual(d.received.map((e) => e.e), ['shortcut', 'shortcut', 'sys', 'sys']);
  await d.stop();
});

test('invalid shortcut or system events end the session and nothing is applied', async () => {
  const bad = [
    { e: 'shortcut' }, { e: 'shortcut', c: 256 }, { e: 'shortcut', c: -1 }, { e: 'shortcut', c: 1, m: 16 },
    { e: 'shortcut', c: 1, h: 5001 }, { e: 'shortcut', c: 1, h: -5 }, { e: 'shortcut', c: 1.5 },
    { e: 'sys' }, { e: 'sys', a: 'reboot' }, { e: 'sys', a: 7 },
  ];
  for (const ev of bad) {
    const d = new ReferenceDesktop(); await d.start();
    const p = await pairedPhone(d);
    p.send(p.frame([ev]));
    const err = await p.next();
    assert.equal(err.type, 'error', JSON.stringify(ev));
    assert.equal(err.reason, 'invalid_command', JSON.stringify(ev));
    assert.equal((await p.next()).type, '__closed');
    assert.equal(d.received.length, 0, JSON.stringify(ev));
    await d.stop();
  }
});

test('parseInputBody accepts every documented system action and nothing else', () => {
  for (const a of ['mission_control', 'app_expose', 'desktop_left', 'desktop_right', 'show_desktop']) {
    assert.equal(parseInputBody(JSON.stringify({ ev: [{ e: 'sys', a }] })).length, 1);
  }
  assert.throws(() => parseInputBody(JSON.stringify({ ev: [{ e: 'sys', a: 'launchpad' }] })));
});
