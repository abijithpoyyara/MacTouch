# UI guide (Part 4)

## Design direction

Quiet, macOS-inspired: one accent color, rounded cards, system typography, short transitions. Each screen has one primary action.
Gradients are used once per screen at most (the hero card or the touchpad surface), and always at low opacity.

### Tokens (`mobile/lib/core/theme/tokens.dart`, `app_theme.dart`; `desktop/.../Theme.swift`)

| Token | Value |
|---|---|
| Spacing | 4, 8, 12, 16, 20, 24, 32 (`Tk.s1`..`Tk.s8`) |
| Radius | 12 (small), 16, 22 (cards), 28 (large surfaces) |
| Touch target | 48 dp minimum |
| Content width | 560 dp maximum, centered on tablets and in landscape |
| Motion | 120 ms for state changes, 220 ms for page transitions; no looping animation |
| Colors | one palette for light and dark (`MtColors`), with a user-chosen accent. Text on the accent is picked automatically for contrast |

Shared widgets live in `views/widgets/ui_kit.dart` (`ScreenFrame`, `Panel`, `RowGroup`, `NavRow`, `SwitchRow`, `SliderRow`, `ChoiceRow`, `StatusPill`).
Changing a token changes every screen built on it.

## Android screens

| # | Screen | Where you reach it | Notes |
|---|---|---|---|
| 1 | Onboarding | first launch; Help > Replay the introduction | four pages, Skip at any time |
| 2 | Device pairing | Welcome (Scan QR code / Reconnect), scanner, progress | scanner and progress screens keep their Part 1 layout |
| 3 | Connection status | after connecting (the hub) | state, address, latency, Mac permission, shortcuts to everything else |
| 4 | Touchpad | Open touchpad | portrait and landscape; see below |
| 5 | Gestures | Settings, hub, touchpad menu | cards with enable, sensitivity, distance, action, restore defaults |
| 6 | Shortcut Center | Settings, hub, touchpad quick bar | search, categories, favorites, reorder, import/export |
| 7 | Shortcut editor | New shortcut / Edit | name, icon, category (including your own), keys, hold, favorite |
| 8 | Devices | hub, Settings | paired Mac, reconnect, disconnect, forget, connection history |
| 9 | Settings | welcome, hub, touchpad menu | appearance, touchpad, pointer, scrolling, links, reset |
| 10 | Help | welcome, hub, Devices, touchpad menu | common problems, Mac settings table, live connection check |

### Touchpad

- Portrait: header, quick shortcuts (favorites), the touch surface (all remaining height), Drag / Drag lock, Left click / Right click.
- Landscape: surface on the left; quick shortcuts, toggles and click buttons in a column on the right.
- The header is one line: back, connection state with latency, and a menu (shortcuts, gestures, pointer and scrolling, settings, help).
- Gesture hints appear on the empty surface and fade out as soon as you touch it. Turn them off in Settings.
- Click buttons can be held while another finger drags.

## Settings

Everything is saved on the phone and applies immediately, with no reconnecting.

| Setting | Stored in | Effect |
|---|---|---|
| Theme (system / light / dark) | theme mode | whole app |
| Accent color (8) | app preferences | buttons, highlights, selected states, in both themes |
| Haptic feedback | app preferences | every vibration in the app goes through one switch |
| Gesture hints | app preferences | hints on the empty touchpad |
| Quick shortcuts bar | app preferences | favorites row on the touchpad |
| Screen orientation (auto / portrait / landscape) | app preferences | locks or releases rotation |
| Pointer speed | touchpad settings | distance the pointer moves per finger distance |
| Touch sensitivity | touchpad settings | how small a movement the pointer follows (dead zone 0-8 px) |
| Pointer acceleration and strength | touchpad settings | fast swipes travel further |
| Smoothing | touchpad settings | steadier movement with slight delay |
| Scroll speed, natural scrolling, horizontal scrolling, reverse horizontal | touchpad settings | two-finger scrolling |
| Gestures (enable, thresholds, actions) | gesture config | Gestures screen |
| Shortcuts, categories, key mapping | shortcut library | Shortcut Center |

"Reset appearance and behavior" restores the table above except gestures, shortcuts and your paired Mac.

### Shortcut presets (import and export)

Export copies your shortcuts and categories as plain text (a small JSON document). Import accepts that text, shows how many shortcuts are valid and
how many were skipped, then adds them as new shortcuts; existing ones are never replaced. It works through copy and paste, so it needs no storage or sharing permission.

## Accessibility

- Every icon-only control has a tooltip or semantic label; toggles report their state; custom buttons report as buttons.
- Touch targets are at least 48 dp. Text scales with the system font size; the settings and help screens scroll instead of clipping.
- State is never shown by color alone: status pills and rows carry text.
- Haptics can be turned off. Motion is short and there is no looping animation.
- The Mac app labels the QR code, sidebar selection, status dots and list rows for VoiceOver.

## Mac app

| Part | What it does |
|---|---|
| Menu bar item | state in the icon; menu with status, Pair a Phone, Open MacTouch, Start/Stop Server, Disconnect, Allow Accessibility, Quit |
| Pairing window | only the QR code, countdown, and clear states (stopped, starting, failed, no network, waiting for approval) |
| Pairing approval | the standard macOS alert; it closes by itself if the request times out |
| Main window | Overview (status, issues with fixes, server controls), Devices (paired phones, connection history), Settings |
| Settings | name shown on phones, start server on launch, menu bar icon, Dock icon, open at login |

The app stays small: no polling except a 2-second Accessibility check, no background animation, and closing the windows leaves the server and the menu bar item running.

## Not done / limits

- The scanner and pairing progress screens were not restyled; they still use the Part 1 layout.
- A phone remembers one Mac. The Devices screen says so.
- Settings are per phone and per Mac; there is no cloud sync.
- Open at login only works for MacTouch.app run from the Applications folder (a macOS requirement).
- Screenshots could not be produced in the build environment; see `SCREENSHOTS.md`.
