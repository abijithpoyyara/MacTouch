// MacTouch protocol v1 - reference implementation (Node >= 22, no dependencies).
// Doubles as a stand-in "Mac" for developing the Flutter app without a Mac.
import http from 'node:http';
import crypto from 'node:crypto';

export const PROTOCOL_VERSION = 1;
export const b64u = (buf) => Buffer.from(buf).toString('base64url');
export const unb64u = (s) => Buffer.from(s, 'base64url');
const hmac = (key, msg) => crypto.createHmac('sha256', key).update(msg, 'utf8').digest();
export const pairProof = (token, id, cn, sn) => hmac(token, `pair|${id}|${cn}|${sn}`);
export const deriveSecret = (token, id, cn, sn) => hmac(token, `secret|${id}|${cn}|${sn}`);
export const authProof = (secret, id, cn, sn) => hmac(secret, `auth|${id}|${cn}|${sn}`);
export const serverProof = (secret, cn, sn) => hmac(secret, `server|${sn}|${cn}`);
// Part 2: signed input frames (see protocol/INPUT.md)
export const sessionKey = (secret, cn, sn) => hmac(secret, `session|${cn}|${sn}`);
export const inputMac = (key, seq, body) => hmac(key, `input|${seq}|${body}`);

export function parseInputBody(body) {
  const root = JSON.parse(body);
  if (!root || !Array.isArray(root.ev) || root.ev.length > 64) throw new Error('bad body');
  const int = Number.isInteger;
  return root.ev.map((e) => {
    if (!e || typeof e.e !== 'string') throw new Error('bad event');
    switch (e.e) {
      case 'move':
        if (!int(e.dx) || !int(e.dy) || Math.abs(e.dx) > 2000 || Math.abs(e.dy) > 2000) throw new Error('move');
        return e;
      case 'scroll':
        if (!int(e.dx) || !int(e.dy) || Math.abs(e.dx) > 1000 || Math.abs(e.dy) > 1000) throw new Error('scroll');
        return e;
      case 'btn':
        if (!['left', 'right'].includes(e.b) || !['down', 'up'].includes(e.s) || (e.n !== undefined && ![1, 2, 3].includes(e.n))) throw new Error('btn');
        return e;
      case 'key':
        if (!int(e.c) || e.c < 0 || e.c > 255 || !['down', 'up'].includes(e.s) || (e.m !== undefined && (!int(e.m) || e.m < 0 || e.m > 15))) throw new Error('key');
        return e;
      case 'shortcut':
        if (!int(e.c) || e.c < 0 || e.c > 255 || (e.m !== undefined && (!int(e.m) || e.m < 0 || e.m > 15))
            || (e.h !== undefined && (!int(e.h) || e.h < 0 || e.h > 5000))) throw new Error('shortcut');
        return e;
      case 'sys':
        if (!['mission_control', 'app_expose', 'desktop_left', 'desktop_right', 'show_desktop'].includes(e.a)) throw new Error('sys');
        return e;
      case 'release':
        return e;
      default:
        throw new Error('unknown event');
    }
  });
}
const equal = (a, b) => a.length === b.length && crypto.timingSafeEqual(a, b);
const ID_RE = /^[A-Za-z0-9_-]{8,64}$/;
const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

function encodeFrame(opcode, payload) {
  const len = payload.length;
  const head = len < 126 ? Buffer.from([0x80 | opcode, len])
    : Buffer.from([0x80 | opcode, 126, len >> 8, len & 255]);
  return Buffer.concat([head, payload]);
}

function* decodeFrames(state) {
  for (;;) {
    const b = state.buf;
    if (b.length < 2) return;
    let len = b[1] & 0x7f, off = 2;
    if (len === 126) { if (b.length < 4) return; len = b.readUInt16BE(2); off = 4; }
    else if (len === 127) throw new Error('frame too large');
    const masked = (b[1] & 0x80) !== 0;
    if (b.length < off + (masked ? 4 : 0) + len) return;
    const mask = masked ? b.subarray(off, off + 4) : null;
    if (masked) off += 4;
    const payload = Buffer.from(b.subarray(off, off + len));
    if (mask) for (let i = 0; i < len; i++) payload[i] ^= mask[i % 4];
    state.buf = b.subarray(off + len);
    yield { opcode: b[0] & 0x0f, payload };
  }
}

export class ReferenceDesktop {
  constructor({ port = 0, name = 'Reference Mac', tokenTtlMs = 120000, approve = () => true } = {}) {
    Object.assign(this, { port, name, tokenTtlMs, approve });
    this.serverId = b64u(crypto.randomBytes(12));
    this.paired = new Map();   // deviceId -> secret Buffer
    this.active = null;
    this.sessions = new Set();
    this.received = [];   // input events that passed every check, in order
    this.failures = 0;
    this.rotate();
    this.server = http.createServer((_, res) => { res.writeHead(426); res.end(); });
    this.server.on('upgrade', (req, socket) => this.#upgrade(req, socket));
  }
  rotate() {
    this.token = { bytes: crypto.randomBytes(32), expires: Date.now() + this.tokenTtlMs, used: false };
    this.failures = 0;
  }
  async start() {
    await new Promise((r) => this.server.listen(this.port, '127.0.0.1', r));
    this.port = this.server.address().port;
  }
  async stop() {
    for (const s of this.sessions) s.socket.destroy();
    await new Promise((r) => this.server.close(r));
  }
  qrPayload(host = '192.168.1.20') {
    return { app: 'mactouch', v: PROTOCOL_VERSION, host, port: this.port, token: b64u(this.token.bytes),
      exp: Math.floor(this.token.expires / 1000), name: this.name, id: this.serverId };
  }
  #upgrade(req, socket) {
    const key = req.headers['sec-websocket-key'];
    if (!key) return socket.destroy();
    const accept = crypto.createHash('sha1').update(key + GUID).digest('base64');
    socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
    const s = { socket, stage: 'handshake', serverNonce: b64u(crypto.randomBytes(16)), state: { buf: Buffer.alloc(0) } };
    this.sessions.add(s);
    socket.on('data', (d) => {
      s.state.buf = Buffer.concat([s.state.buf, d]);
      try {
        for (const f of decodeFrames(s.state)) {
          if (f.opcode === 8) return this.#close(s);
          if (f.opcode === 9) socket.write(encodeFrame(10, f.payload));
          if (f.opcode === 1) this.#message(s, f.payload.toString('utf8'));
        }
      } catch { this.#close(s); }
    });
    socket.on('close', () => this.#close(s, true));
    socket.on('error', () => {});
    this.#send(s, { type: 'challenge', serverNonce: s.serverNonce, serverId: this.serverId, serverName: this.name });
  }
  #send(s, o) { if (!s.socket.destroyed) s.socket.write(encodeFrame(1, Buffer.from(JSON.stringify({ v: 1, ...o })))); }
  #close(s, fromSocket = false) {
    if (s.stage === 'closed') return;
    s.stage = 'closed';
    this.sessions.delete(s);
    if (this.active === s) this.active = null;
    if (!fromSocket) { s.socket.write(encodeFrame(8, Buffer.alloc(0))); s.socket.end(); }
  }
  #reject(s, type, reason) { this.#send(s, { type, reason }); this.#close(s); }
  async #message(s, text) {
    let m; try { m = JSON.parse(text); } catch { return this.#reject(s, 'error', 'bad_message'); }
    if (s.stage === 'authenticated') {
      if (m.type === 'ping') return this.#send(s, { type: 'pong', ...(Number.isInteger(m.t) ? { t: m.t } : {}) });
      if (m.type === 'disconnect') return this.#close(s);
      if (m.type === 'input') return this.#input(s, m);
      return this.#send(s, { type: 'error', code: 'unsupported' });
    }
    if (s.stage !== 'handshake') return;
    const okIds = ID_RE.test(m.deviceId ?? '') && ID_RE.test(m.clientNonce ?? '') && typeof m.proof === 'string';
    if (m.type === 'pair_request' && okIds) return this.#pair(s, m);
    if (m.type === 'auth' && okIds) return this.#auth(s, m);
    return this.#reject(s, 'error', 'unauthenticated');
  }
  async #pair(s, m) {
    if (this.active || [...this.sessions].some((x) => x.stage === 'pairing')) return this.#reject(s, 'pair_rejected', 'busy');
    const t = this.token;
    if (t.used) return this.#reject(s, 'pair_rejected', 'busy');
    if (Date.now() > t.expires) { this.rotate(); return this.#reject(s, 'pair_rejected', 'token_expired'); }
    const expected = pairProof(t.bytes, m.deviceId, m.clientNonce, s.serverNonce);
    if (!equal(expected, unb64u(m.proof))) {
      if (++this.failures >= 5) this.rotate();
      return this.#reject(s, 'pair_rejected', 'invalid_proof');
    }
    t.used = true; s.stage = 'pairing';
    this.#send(s, { type: 'pair_pending' });
    const ok = await this.approve({ deviceId: m.deviceId, deviceName: String(m.deviceName ?? '').slice(0, 64) });
    this.rotate();
    if (s.stage !== 'pairing') return;
    if (!ok) return this.#reject(s, 'pair_rejected', 'declined');
    const secret = deriveSecret(t.bytes, m.deviceId, m.clientNonce, s.serverNonce);
    this.paired.set(m.deviceId, secret);
    s.sessionKey = sessionKey(secret, m.clientNonce, s.serverNonce);
    this.#send(s, { type: 'pair_accepted', serverProof: b64u(serverProof(secret, m.clientNonce, s.serverNonce)), accessibility: true });
    s.stage = 'authenticated'; this.active = s; s.deviceId = m.deviceId;
  }
  #input(s, m) {
    const ok = s.sessionKey && Number.isInteger(m.seq) && m.seq >= 1 && Number.isInteger(m.t) && m.t >= 0
      && typeof m.body === 'string' && Buffer.byteLength(m.body) <= 4096 && typeof m.mac === 'string';
    if (!ok) return this.#reject(s, 'error', 'invalid_command');
    if (!equal(inputMac(s.sessionKey, m.seq, m.body), unb64u(m.mac))) return this.#reject(s, 'error', 'bad_mac');
    if (m.seq <= (s.lastSeq ?? 0)) return this.#reject(s, 'error', 'bad_sequence');
    s.lastSeq = m.seq;
    let events;
    try { events = parseInputBody(m.body); } catch { return this.#reject(s, 'error', 'invalid_command'); }
    this.received.push(...events);
  }
  #auth(s, m) {
    const secret = this.paired.get(m.deviceId);
    if (!secret) return this.#reject(s, 'auth_failed', 'unknown_device');
    if (!equal(authProof(secret, m.deviceId, m.clientNonce, s.serverNonce), unb64u(m.proof))) return this.#reject(s, 'auth_failed', 'invalid_proof');
    if (this.active && this.active.deviceId !== m.deviceId) return this.#reject(s, 'auth_failed', 'busy');
    if (this.active) this.#close(this.active);
    s.sessionKey = sessionKey(secret, m.clientNonce, s.serverNonce);
    this.#send(s, { type: 'auth_ok', serverProof: b64u(serverProof(secret, m.clientNonce, s.serverNonce)), accessibility: true });
    s.stage = 'authenticated'; this.active = s; s.deviceId = m.deviceId;
  }
}

// `node reference.mjs [port]` runs a stand-in Mac that prints its QR payload and auto-approves pairing.
if (import.meta.url === `file://${process.argv[1]}`) {
  const d = new ReferenceDesktop({ port: Number(process.argv[2] ?? 48500) });
  await d.start();
  console.log('Reference desktop listening. QR payload (host must be your LAN IP, not 192.168.1.20):');
  console.log(JSON.stringify(d.qrPayload()));
}
