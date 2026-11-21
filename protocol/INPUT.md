# MacTouch input protocol (Part 2)

Adds signed input frames to protocol v1. Handshake, pairing and reconnect are unchanged except that
`pair_accepted` and `auth_ok` now also carry `"accessibility": true|false` (whether the Mac currently has
the macOS Accessibility permission).

## Session key

```
sessionKey = HMAC(secret, "session|" + clientNonce + "|" + serverNonce)     // derived on both sides, never sent
inputMac   = HMAC(sessionKey, "input|" + seq + "|" + body)                  // body = the exact UTF-8 string sent
```

`clientNonce` / `serverNonce` are the ones from the handshake that created the session, so every connection has its own key
and a recorded frame is useless on another connection. Vectors: `protocol/test-vectors.json`.

## Input frame (phone -> Mac)

```json
{"v":1,"type":"input","seq":42,"t":3180,
 "body":"{\"ev\":[{\"e\":\"move\",\"dx\":5,\"dy\":-3},{\"e\":\"btn\",\"b\":\"left\",\"s\":\"down\",\"n\":1}]}",
 "mac":"<base64url HMAC-SHA256>"}
```

| Field | Rule |
|---|---|
| `seq` | integer, starts at 1 for each session, must strictly increase (gaps allowed). Lower or equal = replay = session closed |
| `t` | integer >= 0, milliseconds since the session started on the phone (monotonic). Used for diagnostics and ordering checks |
| `body` | JSON *string* (so the MAC covers exact bytes, no canonicalisation), max 4096 bytes |
| `mac` | base64url, constant-time compared |

Order of checks on the Mac: authenticated session -> field types -> MAC -> sequence -> rate limit -> body parse. Nothing reaches the
input engine unless all pass.

## Events (`body.ev`, at most 64 per frame, applied in order)

| `e` | Fields | Meaning |
|---|---|---|
| `move` | `dx`,`dy` ints, each abs <= 2000 | relative pointer move (points). Clamped to the displays |
| `btn` | `b` `left`/`right`, `s` `down`/`up`, `n` 1-3 (default 1) | button state change. `n` is the click count for the down event (2 = double click). Duplicate downs and stray ups are ignored |
| `scroll` | `dx`,`dy` ints, each abs <= 1000 | pixel scroll. Positive `dy` = content moves down, positive `dx` = content moves right ("natural" when the fingers move that way). The phone applies the user's direction settings |
| `key` | `c` virtual key code 0-255, `s` `down`/`up`, `m` modifier bitmask 0-15 (shift 1, ctrl 2, option 4, cmd 8) | keyboard event (macOS virtual key codes) |
| `release` | – | release every pressed button and key |
| `shortcut` | `c` key code 0-255, `m` modifier bitmask 0-15 (default 0), `h` hold ms 0-5000 (default 0) | a full keyboard shortcut: modifiers down (control, option, shift, command), key down, [hold], key up, modifiers up in reverse. See `docs/GESTURES_AND_SHORTCUTS.md` |
| `sys` | `a` one of `mission_control`, `app_expose`, `desktop_left`, `desktop_right`, `show_desktop` | a macOS system action; the Mac decides how to run it and some need macOS settings |

Numbers must be integers; booleans, fractions and strings are rejected.

## Safety rules (Mac)

- All pressed buttons and keys are released when: the phone disconnects, the connection is lost or idle for 30 s, the server is stopped,
  the app quits, another phone replaces the session, or **any invalid frame** is received (bad MAC, bad sequence, malformed or out-of-range event).
- Invalid frame => `error` with `reason` (`bad_mac`, `bad_sequence`, `invalid_command`, `rate_limited`) and the socket is closed.
- Rate limit: token bucket, burst 400 frames, 250 frames/s sustained. Over-limit frames are dropped; ~400 consecutive drops closes the session.
- Without the Accessibility permission the engine ignores all events and holds no state.

## Other messages added

| Direction | Message |
|---|---|
| phone -> Mac | `ping` now carries `t` (phone clock, ms); `pong` echoes it so the phone can show latency |
| Mac -> phone | `status` `{accessibility: bool}` whenever the permission changes while connected |

## Limits

Frames are authenticated and replay-protected but **not encrypted**: anyone on the LAN can read pointer movements (not secrets).
They cannot inject, alter, replay or reorder frames without the session key.
