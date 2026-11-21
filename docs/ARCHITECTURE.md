# Architecture

```
MacTouch/
  protocol/   PROTOCOL.md, test-vectors.json, tools/ (Node reference Mac + e2e tests, vector generator)
  desktop/    Swift package: MacTouchCore (no UI) + MacTouchDesktop (SwiftUI) + tests
  mobile/     Flutter app (Android), GetX
  docs/
```

## Desktop (Swift, macOS 13+)

| Piece | Responsibility |
|---|---|
| `MacTouchServer` | `NWListener` with `NWProtocolWebSocket`; per-connection session state machine; handshake; delegate callbacks on the main queue |
| `PairingTokenManager` | single-use, expiring, rate-limited token; injectable clock |
| `KeychainSecretStore` / `PairedDeviceStore` | secrets in Keychain, metadata in UserDefaults |
| `NetworkInfo` | private IPv4 discovery (`getifaddrs`, `en*` only) |
| `AppModel` | `ObservableObject` bridging server events to SwiftUI; `NWPathMonitor` refreshes the QR on Wi-Fi changes |
| `ContentView` | window, QR "trackpad slab", pairing dialog, Accessibility status |

Core Graphics input injection is Part 2; Part 1 reports and requests the Accessibility permission only.

## Mobile (Flutter, MVC + service/repository)

```
views/          widgets, no logic            (welcome, scanner, pairing, connected)
controllers/    GetX state + navigation      (Pairing, Connection, Theme)
data/repositories/  protocol logic           (ConnectionRepository, PairedMacRepository, IdentityRepository)
data/services/  platform edges               (Transport/WebSocket, SecureStore, Settings, NetworkMonitor)
core/           protocol constants, crypto, QR validation, errors, theme, logging
```

`ConnectionRepository` talks to an abstract `Transport`, so the handshake is unit-tested with a scripted fake Mac.

## Wi-Fi changes

- Phone: `connectivity_plus` events drop the socket and reconnect with the stored secret (backoff 1, 2, 4, 8, 15 s); Wi-Fi off shows a specific message instead of retrying. A heartbeat (10 s ping, 25 s deadline) catches silent drops, including moving between two Wi-Fi networks, which `connectivity_plus` reports as no change.
- Mac: `NWPathMonitor` refreshes the IP in the QR code. The listener binds all interfaces, so it keeps working. The phone stores the last address, so if the Mac gets a new DHCP lease the phone shows "couldn't reach your Mac" and the user rescans.
