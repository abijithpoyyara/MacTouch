# Manual test plan: Mac mini + Android phone

Do this once after installing Part 2. About 20 minutes.

## 0. Setup

1. Mac: `cd desktop && swift run MacTouchDesktop` (or build the app bundle with `./scripts/make_app.sh`).
2. Phone: `cd mobile && flutter run`.
3. Same Wi-Fi. Pair as in the README.

### Accessibility permission (the usual reason "nothing moves")

macOS grants the permission to a *specific app*:

| How you started the Mac app | Allow this in System Settings > Privacy & Security > Accessibility |
|---|---|
| `swift run` in Terminal | **Terminal** (or iTerm / your IDE), because it is the parent process |
| `build/MacTouch.app` | **MacTouch** |

If you rebuild the `.app` the ad-hoc signature changes and macOS may ignore the old entry: select it, press `-` to remove it, then add it again.
After allowing, the MacTouch window turns green within 2 seconds (or click **Check again**).

## 1. Permission guidance

| Step | Expected |
|---|---|
| Start with MacTouch **not** allowed. Pair, open the touchpad on the phone | Orange banner on the phone explaining what to enable. Mac window shows "Accessibility needed" with **Open System Settings** / **Check again** |
| Touch the pad | Cursor does not move (macOS security is not bypassed) |
| Turn the permission on | Banner disappears on the phone within ~2 s, cursor now moves |
| Turn it off again while connected | Banner returns within ~2 s; nothing moves; no button is stuck |

## 2. Cursor

| Step | Expected |
|---|---|
| Slide one finger slowly | Cursor follows 1:1 times the speed setting, no jitter |
| Slide fast, then slow over the same distance (acceleration on) | Fast swipe travels clearly further |
| Settings > acceleration off | Same distance both times |
| Push the cursor to every screen edge and corner | Stops at the edge, no wrap, no jump |
| Rest a finger and tap | Cursor does not drift before the click |

## 3. Clicks

| Step | Expected |
|---|---|
| Tap | Left click (try a Finder icon: it selects) |
| Two quick taps on a Finder file | Double click: opens it (checks click count 2) |
| Tap two fingers together | Right-click context menu appears |
| Left click button | Click. Hold it and slide a finger on the pad: drags (Finder icon moves) |
| Right click button | Context menu |

## 4. Scroll

Open a long web page or document.

| Step | Expected |
|---|---|
| Two fingers up/down | Page scrolls; with natural scrolling on, content follows your fingers |
| Settings > natural scrolling off | Direction reverses |
| Two fingers left/right on a wide page | Scrolls sideways; "Reverse horizontal" flips it; switching horizontal off disables it |
| Scroll speed slider | Visibly scales distance |
| **If vertical or horizontal feels backwards on your Mac** | Flip the matching setting and tell me; the sign convention is in `protocol/INPUT.md` |

## 5. Drag, drag lock

| Step | Expected |
|---|---|
| Tap, then immediately touch and drag | Drags (move a Finder icon / select text) and drops on release |
| **Drag** toggle on, slide one finger | Left button held for the whole slide, released on lift |
| **Drag** + **Drag lock**, slide, lift | Button stays down (icon stays picked up); move again with new touches; **tap** once to drop |
| Turn **Drag** off while locked | Button released |

## 6. Nothing may stay pressed (most important)

Hold the left click button (or start a locked drag) and then:

| Action | Expected on the Mac |
|---|---|
| Switch the phone to airplane mode / turn Wi-Fi off | Button released within ~1 s of the disconnect (or 30 s idle at worst); Finder icon drops |
| Press the phone's home button | Button released immediately |
| Press back on the phone | Button released |
| Kill the phone app | Button released |
| Click **Disconnect** in the MacTouch window | Button released |
| Click **Stop server** | Button released |
| Quit MacTouch (Cmd-Q) | Button released |

Check by watching a held Finder icon or by selecting text in TextEdit: the selection must not keep extending.

## 7. Reconnect, heartbeat, rate limits

| Step | Expected |
|---|---|
| Turn phone Wi-Fi off and on | Header shows "No Wi-Fi", then reconnects by itself; touchpad works again without re-pairing |
| Header latency | Shows a plausible value (usually under 30 ms) |
| Stop and start the Mac server | Phone shows reconnecting, then connected once the Mac is back |
| Scribble wildly with two hands | No lag build-up, no crash; cursor stops promptly when you stop |

## 8. Automated checks

```sh
node --test protocol/tools/e2e.test.mjs protocol/tools/input.test.mjs
cd desktop && swift test          # needs full Xcode
cd mobile && flutter test && flutter analyze
```
