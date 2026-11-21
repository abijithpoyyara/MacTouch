# MacTouch

Use an Android phone as a wireless trackpad for a Mac mini or MacBook.

**Part 1 (this commit): foundation and QR pairing.** The Mac runs a WebSocket server and shows a QR code; the phone scans it, the Mac asks you to approve, and both sides end up with an authenticated connection that is saved for reconnecting. Pointer/click/scroll input arrives in Part 2.

| | |
|---|---|
| `desktop/` | macOS app, Swift + SwiftUI, Network.framework (macOS 13+) |
| `mobile/` | Android app, Flutter + GetX |
| `protocol/` | wire protocol spec, shared test vectors, Node reference implementation |
| `docs/` | architecture notes |

Protocol and security model: [`protocol/PROTOCOL.md`](protocol/PROTOCOL.md). Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Requirements

- Mac: macOS 13+, Xcode 15+ (or the Swift 5.9+ command-line tools)
- Phone build machine: Flutter 3.27+ (Dart 3.6+), Android SDK, a phone with Android 6+ (API 23)
- Mac and phone on the **same local network** (no guest-Wi-Fi client isolation, no VPN routing LAN traffic away)

## Run the Mac app

```sh
cd desktop
swift run MacTouchDesktop          # quickest: runs from the terminal
# or build a double-clickable, ad-hoc signed app bundle:
./scripts/make_app.sh && open build/MacTouch.app
```

First launch:
1. macOS may ask to allow incoming network connections. Choose **Allow**.
2. Click **Allow** on the Accessibility card (System Settings > Privacy & Security > Accessibility). Not needed for pairing; needed for pointer control in Part 2.

Open `Package.swift` in Xcode if you prefer an IDE.

## Run the Android app

```sh
cd mobile
./scripts/bootstrap.sh     # once: flutter create (android/), adds camera/network permissions, minSdk 23, flutter pub get
flutter run                # phone connected over USB with debugging on
```

Release APK: `flutter build apk --release` (output in `build/app/outputs/flutter-apk/`).
`bootstrap.sh` exists because the generated `android/` folder is not checked in; it patches the manifest with `INTERNET`, `CAMERA`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` and allows cleartext `ws://` (the LAN protocol authenticates with HMAC instead of TLS).

## Pair

1. Mac: MacTouch is running; a QR code is shown (it refreshes every 2 minutes).
2. Phone: **Scan QR code**, point at the Mac screen.
3. Mac: a dialog asks to pair "<phone name>". Click **Pair**.
4. Phone: shows the connected screen. Next time, open the app and tap **Reconnect** (it also tries automatically).

## Tests

```sh
# Protocol (runs anywhere with Node 22+; no dependencies)
python3 protocol/tools/gen_vectors.py          # only if you change the protocol
node --test protocol/tools/e2e.test.mjs protocol/tools/input.test.mjs protocol/tools/shortcut.test.mjs

# Mac (on a Mac)
cd desktop && swift test

# Phone (needs the Flutter SDK)
cd mobile && flutter test && flutter analyze
```

### Developing the phone app without a Mac

```sh
node protocol/tools/reference.mjs 48500
```
prints a QR payload JSON; replace `host` with your computer's LAN IP, render it as a QR code with any generator, and scan it. The reference server auto-approves pairing.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Couldn't reach your Mac" | different networks; guest Wi-Fi with client isolation; VPN; macOS firewall blocking incoming connections for MacTouch |
| "Port 48500 is already in use" | another MacTouch instance; quit it |
| QR shows "No local network" | Mac isn't on Wi-Fi/Ethernet with a private IPv4 address |
| "This code has expired" | codes last 2 minutes; scan the current one |
| Camera black / "Camera isn't available" | grant camera permission in Android Settings |

## Current limitations (Part 1)

- Input frames are signed (HMAC with a per-session key) and replay-protected, but not encrypted: anyone on your LAN can see pointer movement. See `protocol/INPUT.md`.
- Keyboard events are supported by the Mac engine and protocol but the phone has no keyboard UI yet.
- Manual test plan for the Mac mini: `docs/MANUAL_TESTING.md`.
- Gestures (3 and 4 fingers, long press) and the Shortcut Center: `docs/GESTURES_AND_SHORTCUTS.md`. Test plan: `docs/MANUAL_TESTING_PART3.md`. System actions have macOS requirements and are listed there with their verification status.
- UI guide (screens, design tokens, settings, accessibility, Mac app): `docs/UI_GUIDE.md`. Test plan: `docs/MANUAL_TESTING_PART4.md`. Screenshots must be captured from the real apps: `docs/SCREENSHOTS.md`.
- One phone connected at a time. The Mac's address is stored on the phone; if the Mac's IP changes, rescan.
