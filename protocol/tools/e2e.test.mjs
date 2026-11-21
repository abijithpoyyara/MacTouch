// End-to-end protocol tests: `node --test protocol/tools/`
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { ReferenceDesktop, b64u, unb64u, pairProof, deriveSecret, authProof, serverProof } from './reference.mjs';

const vectors = JSON.parse(fs.readFileSync(new URL('../test-vectors.json', import.meta.url)));

test('crypto matches the shared test vectors (Python-generated)', () => {
  const v = vectors, token = unb64u(v.token);
  assert.equal(b64u(pairProof(token, v.deviceId, v.clientNonce, v.serverNonce)), v.pairProof);
  const secret = deriveSecret(token, v.deviceId, v.clientNonce, v.serverNonce);
  assert.equal(b64u(secret), v.secret);
  assert.equal(b64u(authProof(secret, v.deviceId, v.clientNonce, v.serverNonce)), v.authProof);
  assert.equal(b64u(serverProof(secret, v.clientNonce, v.serverNonce)), v.serverProof);
});

async function connect(d) {
  const ws = new WebSocket(`ws://127.0.0.1:${d.port}/`);
  const inbox = [], waiters = []; let closed = false;
  ws.onmessage = (e) => { const m = JSON.parse(e.data); const w = waiters.shift(); w ? w(m) : inbox.push(m); };
  ws.onclose = () => { closed = true; waiters.splice(0).forEach((w) => w({ type: '__closed' })); };
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('connect failed')); });
  const next = () => new Promise((r) => (inbox.length ? r(inbox.shift()) : waiters.push(r)));
  const challenge = await next();
  assert.equal(challenge.type, 'challenge');
  return { ws, next, challenge, isClosed: () => closed, send: (o) => ws.send(JSON.stringify({ v: 1, ...o })) };
}
const newClient = () => ({ id: 'phone-' + b64u(crypto.randomBytes(9)), nonce: () => b64u(crypto.randomBytes(16)) });

async function pairOnce(d, c, token = d.token.bytes) {
  const link = await connect(d), cn = c.nonce(), sn = link.challenge.serverNonce;
  link.send({ type: 'pair_request', deviceId: c.id, deviceName: 'Test phone', clientNonce: cn,
    proof: b64u(pairProof(token, c.id, cn, sn)) });
  return { link, cn, sn, token };
}

test('pairing, mutual proof, then reconnect with the derived secret', async () => {
  const d = new ReferenceDesktop({ name: 'Test Mac' }); await d.start();
  const c = newClient(); const token = d.token.bytes;
  const { link, cn, sn } = await pairOnce(d, c);
  assert.equal((await link.next()).type, 'pair_pending');
  const acc = await link.next();
  assert.equal(acc.type, 'pair_accepted');
  const secret = deriveSecret(token, c.id, cn, sn);          // never sent over the wire
  assert.equal(acc.serverProof, b64u(serverProof(secret, cn, sn)));
  link.send({ type: 'ping' }); assert.equal((await link.next()).type, 'pong');
  link.send({ type: 'pointer_move', dx: 1, dy: 1 }); assert.equal((await link.next()).code, 'unsupported');

  const l2 = await connect(d), cn2 = c.nonce();               // same device reconnects, replacing session
  l2.send({ type: 'auth', deviceId: c.id, clientNonce: cn2, proof: b64u(authProof(secret, c.id, cn2, l2.challenge.serverNonce)) });
  const ok = await l2.next();
  assert.equal(ok.type, 'auth_ok');
  assert.equal(ok.serverProof, b64u(serverProof(secret, cn2, l2.challenge.serverNonce)));
  assert.equal((await link.next()).type, '__closed');         // old session dropped
  await d.stop();
});

test('wrong token proof is rejected; 5 failures rotate the token', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const before = b64u(d.token.bytes);
  for (let i = 0; i < 5; i++) {
    const { link } = await pairOnce(d, newClient(), crypto.randomBytes(32));
    assert.deepEqual((await link.next()).reason, 'invalid_proof');
  }
  assert.notEqual(b64u(d.token.bytes), before);
  await d.stop();
});

test('expired token is rejected', async () => {
  const d = new ReferenceDesktop({ tokenTtlMs: 30 }); await d.start();
  const token = d.token.bytes;
  await new Promise((r) => setTimeout(r, 60));
  const { link } = await pairOnce(d, newClient(), token);
  assert.equal((await link.next()).reason, 'token_expired');
  await d.stop();
});

test('token is single-use and a decline leaves nobody paired', async () => {
  const d = new ReferenceDesktop({ approve: () => false }); await d.start();
  const token = d.token.bytes;
  const first = await pairOnce(d, newClient(), token);
  assert.equal((await first.link.next()).type, 'pair_pending');
  assert.equal((await first.link.next()).reason, 'declined');
  const replay = await pairOnce(d, newClient(), token);        // old token after rotation
  assert.equal((await replay.link.next()).reason, 'invalid_proof');
  assert.equal(d.paired.size, 0);
  await d.stop();
});

test('control messages before authentication are refused and the socket closed', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const link = await connect(d);
  link.send({ type: 'pointer_move', dx: 5, dy: 5 });
  const err = await link.next();
  assert.equal(err.type, 'error'); assert.equal(err.reason, 'unauthenticated');
  assert.equal((await link.next()).type, '__closed');
  await d.stop();
});

test('auth with unknown device or wrong secret fails', async () => {
  const d = new ReferenceDesktop(); await d.start();
  const c = newClient();
  const l1 = await connect(d), cn = c.nonce();
  l1.send({ type: 'auth', deviceId: c.id, clientNonce: cn, proof: b64u(crypto.randomBytes(32)) });
  assert.equal((await l1.next()).reason, 'unknown_device');
  d.paired.set(c.id, crypto.randomBytes(32));
  const l2 = await connect(d);
  l2.send({ type: 'auth', deviceId: c.id, clientNonce: cn, proof: b64u(crypto.randomBytes(32)) });
  assert.equal((await l2.next()).reason, 'invalid_proof');
  await d.stop();
});
