# Manual test plan, Part 3 (Mac mini + Android phone)

Prerequisites: Part 2 works (cursor moves and clicks). The Mac app was rebuilt after applying Part 3 (an older build rejects the new
`shortcut` and `sys` events and closes the connection). Accessibility is allowed (see `docs/MANUAL_TESTING.md`, step 0).
Use `flutter run --release` on the phone for realistic touch behaviour.

Record the result next to each row. Anything that fails: note the exact steps and what happened.

## 1. Gestures

Use the touchpad screen.

| Step | Expected |
|---|---|
| Rest one finger on the pad for about half a second without moving, then slide | Phone buzzes; the Mac starts dragging (move a Finder icon). Lift: it drops |
| Rest a finger, but wiggle it a little before half a second | No drag starts |
| Three fingers up (about 1 cm / 80 px) | Mission Control opens |
| Three fingers down | App Expos\u00e9 shows the front app's windows (needs the setting, see section 3) |
| Three fingers left / right | Previous / next desktop (needs two desktops and the setting) |
| Three fingers up slowly (more than a second) | Nothing |
| Three fingers diagonally | Nothing |
| Three fingers moving, one finger staying still | Nothing |
| Two-finger scroll, then add a third finger and swipe | Swipe fires; the page does not scroll first |
| Normal two-finger scroll | Starts without noticeable delay; the whole distance is scrolled |
| Four fingers up / left | Show desktop / app switcher (defaults) |
| Gestures screen: turn "Swipe up" (3 fingers) off | Three fingers up does nothing, and does not move the cursor or scroll |
| Gestures screen: change its distance to 200 px | Needs a much longer swipe |
| Gestures screen: change its action to a shortcut (for example "New tab" in Safari) | Swipe now runs that shortcut |
| Gestures screen: Restore default gestures | Everything back to the defaults above |
| Start a gesture and pull down the Android notification shade mid-gesture | Gesture is abandoned; nothing stays pressed |

## 2. Shortcuts

Open Shortcuts (lightning icon on the touchpad screen). Tap a shortcut to run it. Test in the right app.

| Category | Shortcut | App | Expected |
|---|---|---|---|
| System | Lock screen | any | Mac locks (run this last) |
| System | Screenshot: selection | any | Crosshair appears |
| System | Show desktop | any | Windows slide away (needs the setting) |
| Window | App switcher | two apps open | Switches to the previous app |
| Window | App switcher with hold 600 ms (edit it) | two apps open | Switcher stays visible about 0.6 s, then switches |
| Window | Minimize window / Close window | TextEdit | Window minimizes / closes |
| Window | Mission Control | any | Opens (no setup needed) |
| Browser | New tab, Reopen closed tab, Find, Close tab | Safari or Chrome | Each does what it says |
| Developer | Terminal: clear screen, new tab, interrupt | Terminal | Each does what it says |
| Developer | Build / Run | Xcode with a project | Builds / runs |
| Custom | Create one: name "Test", pick an icon, Custom category, Command+Shift, key N, favorite on | Finder | Appears under Favorites and Custom; Command-Shift-N makes a new folder |

Library features: search for "tab" and "xcode"; filter by category and Favorites; edit a shortcut and save; delete one and bring it back with Restore default shortcuts; reorder (reorder button, drag a row, leave and come back: the order is kept).

Also check: a shortcut that does nothing in the front app (for example Xcode Build while in Safari) simply does nothing; MacTouch does not claim success it cannot see.

## 3. System-action prerequisites

System Settings > Keyboard > Keyboard Shortcuts > Mission Control. Tick these, then re-test section 1:

| Action | Setting to turn on |
|---|---|
| App Expos\u00e9 | "Application windows" (Control-Down Arrow) |
| Previous / next desktop | "Move left a space" / "Move right a space" (Control-Left / Right Arrow); create a second desktop in Mission Control |
| Show desktop | "Show Desktop" (F11) |
| Mission Control | none |

If one still fails with its setting on: some keyboards or macOS versions report arrow keys with the Fn flag, which the shortcut lookup may expect. Tell me which action failed and your macOS version.

## 4. Nothing may stay pressed

Run an app switcher shortcut with a 3000 ms hold (edit the shortcut), and while the switcher is open:

| Action | Expected |
|---|---|
| Turn phone Wi-Fi off | Command is released within about a second; switcher closes (or selects) |
| Click Disconnect in the MacTouch window | Same |
| Click Stop server / quit MacTouch | Same |

Then test with a held long press: start a drag with a long press and turn Wi-Fi off. The button must release.

## 5. Key mapping

| Step | Expected |
|---|---|
| Menu > Key mapping, change "T" to code 17 (its own default) | Shows no "changed" mark after reset; no effect |
| Change "T" to 11 (B), run New tab | Sends Command-B instead (proves the mapping is applied), then Reset all |
| Editor > Choose key > Custom key code 114, save, run | Mac receives key code 114 (Help/Insert key position) |
