# Gestures and Shortcut Center (Part 3)

## Status: what is implemented, tested, and verified

"Verified on a Mac" means someone ran it on a real Mac and saw it work. **Nothing below is marked verified until you run
`docs/MANUAL_TESTING_PART3.md` and record the result.** Automated tests cover the logic (recognition, parsing, key sequences,
serialization); they cannot show that macOS reacts.

| Feature | Implemented | Automated tests | Verified on a Mac |
|---|---|---|---|
| One-finger move, tap, double-tap, two-finger tap, vertical and horizontal scroll | yes (Part 2) | yes | see Part 2 plan |
| Long press = drag | yes | yes (engine) | not yet |
| Three-finger swipes (4 directions), four-finger swipes (4 directions) | yes | yes (engine: direction, distance, duration, finger count, cancellation, conflicts) | not yet |
| Gesture mapping, enable/disable, distance, sensitivity, restore defaults | yes | yes (serialization, defaults, clamping) | n/a (phone only) |
| Shortcut library: search, add, edit, delete, reorder, favorites, restore | yes | yes (library logic) | n/a (phone only) |
| Shortcut execution (modifier down, key down/up, modifier up, optional hold) | yes | yes (exact event sequence, hold timers, release on disconnect) | not yet |
| Key mapping (per-key code override, raw key codes) | yes | yes | not yet |
| System action: Mission Control | yes (opens the Mission Control app, falls back to Control-Up) | yes (plan, fallback, no-permission path) | not yet |
| System actions: App Expos\u00e9, previous/next desktop, show desktop | yes (keyboard shortcuts) | yes (plan, exact key codes) | not yet, and they need macOS settings (below) |

## Gestures

| Gesture | Fingers | Default action | Settings |
|---|---|---|---|
| Move cursor | 1 | move | enable, pointer speed |
| Tap | 1 | left click | enable, tap tolerance |
| Double tap | 1 | double click, also enables tap-then-drag | enable, timing |
| Long press | 1 | hold left button (drag) | enable, hold time |
| Two-finger tap | 2 | right click | enable, tap tolerance |
| Vertical scroll | 2 | scroll | enable, scroll speed |
| Horizontal scroll | 2 | scroll sideways | enable, speed |
| Swipe up / down / left / right | 3 | Mission Control / App Expos\u00e9 / previous desktop / next desktop | enable, distance, action |
| Swipe up / down / left / right | 4 | show desktop / none / app switcher / none | enable, distance, action |

The three-finger defaults follow your specification (left = previous desktop, right = next desktop). macOS's own trackpad
does the opposite (swipe left goes to the next desktop); change the actions on the cards if you prefer that.

### Thresholds (all in `Tuning`, `gesture_engine.dart`)

| Name | Value | Meaning |
|---|---|---|
| tap slop / timeout | 10 px / 250 ms | a touch that moves more or lasts longer is not a tap |
| double-tap window / radius | 320 ms / 40 px | second tap must be this close in time and place |
| move deadzone | 3 px | no cursor movement below this, so taps stay accurate |
| two-finger tap slop / timeout | 14 px / 300 ms | |
| scroll slop | 6 px | centroid movement before a two-finger touch counts as scrolling |
| scroll start delay | 60 ms | scroll is held back this long (nothing is lost) so a third finger can claim the gesture |
| swipe direction decision | 14 px | direction is not decided earlier |
| swipe dominance | 1.5x | movement must be 1.5x larger on one axis, otherwise it is a diagonal and ignored |
| swipe max duration | 900 ms | from the first real movement to reaching the distance; slower is not a swipe |
| finger agreement | 40% | every finger must have moved at least 40% of the distance in the swipe direction |
| swipe distance | 80 px (3 fingers), 70 px (4 fingers) | configurable 30-300 px per gesture |
| long press hold | 450 ms | configurable 200-1200 ms; the finger must stay within the tap slop |

Per-gesture sensitivity is a multiplier (0.5-2.0) on the matching threshold: tap tolerance scales the tap slop, double-tap timing scales the window.

### Rules that prevent conflicts

1. **The number of fingers picks the gesture family and never goes back.** A swipe session stays a swipe session: lifting one finger does not turn it into a scroll or a click.
2. **Three or more fingers never move the cursor, click, scroll or right-click.**
3. **A third finger cancels a scroll that has not been sent yet.** Two-finger scroll waits 60 ms (only while a three-finger swipe is enabled), keeps the movement it saw, and releases it all if no third finger arrives. A quick flick is released when a finger lifts.
4. **A swipe fires at most once per touch session**, at the moment the distance is reached (not on lift).
5. **Finger-count validation:** the swipe must be made with exactly the counted fingers still down, and all of them must move the same way (a finger that stays put, or a pinch, is not a swipe).
6. **Diagonals and slow drags are ignored** rather than guessed.
7. **Long press is cancelled by movement, a second finger, or an early lift.** After it fires, other fingers are ignored until you lift; lifting releases the button and never also clicks.
8. A disabled swipe consumes the touch session silently; it never falls through to another gesture.
9. More than four fingers are ignored.

### Cancellation

If Android cancels a touch (palm rejection, a system gesture), the **whole session** is abandoned: no click, no swipe, any held button is released, and further movement is ignored until every finger has lifted. Leaving the screen, pausing the app, or losing the connection resets the engine and sends `release`.

## Shortcut Center

Categories: System, Window Management, Browser, Developer (terminal and IDE presets), and Custom. A shortcut has a name, icon, category, modifiers, key, optional hold time, favorite flag, and display order. You can search (every word must match the name, category, key combination or note), add, edit, delete, drag to reorder, and restore the defaults (your own shortcuts are kept).

Presets carry a note saying where they work ("Xcode", "Terminal, iTerm2", ...). **A shortcut works only where the target app defines it.** MacTouch sends the keys; it cannot know whether the front app reacts.

### How a shortcut is executed on the Mac

For Shift+Command+T the Mac posts, in this order, each event carrying the flags active at that moment:

```
Shift down -> Command down -> T down -> [hold] -> T up -> Command up -> Shift up
```

Modifiers are pressed control, option, shift, command and released in reverse. Modifier keys are posted as flagsChanged events, like a real keyboard; the primary key event also carries the flags, so applications that read flags and applications that watch modifier events both see a consistent keyboard. Everything pressed is tracked: if the phone disconnects, the connection drops, the server stops, the app quits or an invalid command arrives during a hold, all keys are released immediately and the pending timer does nothing.

**Hold time** (0-5000 ms, editable up to 3000 ms in the app): keeps the keys down for that long, for example Command-Tab with the switcher left open. At most 16 holds can be pending.

### Key mapping

macOS key codes are physical key positions, so the catalog uses the US layout. If a shortcut sends the wrong key on your layout, open Shortcuts > menu > Key mapping and change that key's code, or pick "Custom key code" in the editor to enter any code 0-255. Overrides are stored on the phone and applied when the shortcut is sent; the Mac receives only the final code.

## System actions

| Action | How it runs | Needs |
|---|---|---|
| Mission Control | opens `/System/Applications/Mission Control.app` (falls back to Control-Up) | nothing. Works even if the keyboard shortcut is turned off and without Accessibility |
| App Expos\u00e9 | Control-Down Arrow | Accessibility, and "Application windows" turned on in System Settings > Keyboard > Keyboard Shortcuts > Mission Control |
| Previous / next desktop | Control-Left / Control-Right Arrow | Accessibility, "Move left/right a space" turned on (same pane), at least two desktops |
| Show desktop | F11 | Accessibility, "Show Desktop" turned on (default F11) |
| Lock screen (preset shortcut) | Control-Command-Q | Accessibility; macOS 10.13 or later |
| Screenshots (preset shortcuts) | Shift-Command-3 / 4 / 5 | Accessibility; screenshot shortcuts left enabled |

Why keyboard shortcuts rather than private APIs: Spaces and Expos\u00e9 have no public API. The only supported route is the same keyboard shortcuts a user could press, which is why they depend on those macOS settings. If a shortcut was changed in System Settings, the action will not work until the default is restored or the action is remapped. The phone shows each action's requirement on its card.

## Protocol

Two new input events, both inside the signed frames from Part 2 (see `protocol/INPUT.md`): `{"e":"shortcut","c":17,"m":8,"h":0}` and `{"e":"sys","a":"mission_control"}`. Everything is validated before it reaches the engine: key code 0-255, modifiers 0-15, hold 0-5000, system action from a fixed list.
