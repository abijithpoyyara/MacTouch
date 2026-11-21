# Manual test plan, Part 4 (UI, settings, Mac companion)

Nothing in Part 4 has been run on a device by its author. Work through this once on the phone and the Mac mini and note any row that does not match.
Use a release build on the phone for realistic touch behavior: `flutter run --release`. Rebuild the Mac app first (`pkill -f MacTouchDesktop`, then `swift run MacTouchDesktop`).

## 1. Android: first run and pairing

| Step | Expected |
|---|---|
| Clear the app's data (or reinstall), open it | Introduction appears: four pages, Next, Skip, page dots |
| Finish it | Welcome screen; reopening the app goes straight to Welcome |
| Help > Replay the introduction | Introduction opens again |
| Scan QR code, pair | Same flow as before; ends on the connection hub |
| Hub | Shows Connected, Mac name, address, latency, Mac permission; "Open touchpad" works |
| Kill the Mac app | Hub changes to a reconnecting / not reachable state with a Reconnect button |

## 2. Touchpad

| Step | Expected |
|---|---|
| Portrait | Header is one line; quick shortcuts row; surface takes most of the height; Drag, Drag lock, Left, Right at the bottom |
| Rotate to landscape (orientation Automatic) | Surface on the left; shortcuts, toggles and buttons in a right-hand column; everything reachable |
| Touch the surface | Hints fade out; touch circles follow your fingers; lift: hints return |
| Settings > Gesture hints off | No hints |
| Star a shortcut in the Shortcut Center | It appears on the quick bar and runs when tapped |
| Settings > Quick shortcuts bar off | Bar disappears immediately |
| Settings > Haptic feedback off | No vibration on click, swipe, toggles |
| Settings > Orientation: Portrait / Landscape | Rotation locks; Automatic frees it |
| Header menu | Shortcuts, Gestures, Pointer and scrolling, Settings, Help each open the right screen |
| All earlier touchpad checks (`MANUAL_TESTING.md`, `MANUAL_TESTING_PART3.md`) | Still behave the same |

## 3. Settings apply immediately

With the touchpad open on another screen in the back stack, change each and return:

| Setting | Check |
|---|---|
| Pointer speed | pointer clearly faster / slower, no reconnect |
| Touch sensitivity | lowest: tiny finger movements are ignored, taps stay precise; highest: the pointer follows the smallest movement |
| Acceleration on/off and strength | fast swipes travel further when on |
| Smoothing | steadier, slightly delayed at high values |
| Scroll speed, Natural scrolling, Horizontal scrolling, Reverse horizontal | scrolling changes as described |
| Theme: System / Light / Dark | whole app switches; System follows the phone |
| Accent color | pick each of the 8 in light and in dark: buttons, switches' highlights, selected chips and the touchpad toggles change; text on them stays readable |
| Close and reopen the app | every setting is remembered |
| Reset appearance and behavior | theme, accent, haptics, hints, quick bar, orientation, pointer, scrolling return to defaults; shortcuts, gestures and the paired Mac stay |

## 4. Shortcuts, categories, presets

| Step | Expected |
|---|---|
| Menu > Manage categories > add "Design" | Appears as a filter chip |
| New shortcut > Category dropdown > Custom > Design | Saved under Design; the chip filters to it; the row shows "Design" |
| In the editor choose "New category..." | Creates it and selects it |
| Rename "Design" to "Graphics" | Chip and shortcuts update |
| Delete "Graphics" | Chip disappears; its shortcuts remain under Custom |
| Reorder inside a category | Order is kept after leaving and returning |
| Export: Settings > Import or export > Export > Copy | Snackbar confirms; paste into a note and read it: it is JSON with a `mactouch.shortcuts` format |
| Import: delete a custom shortcut, paste the text in Import > Check | Shows how many are ready; Import adds them back |
| Import the text of a random note | A clear "not a MacTouch shortcut pack" message; nothing changes |
| Import the same pack twice | Shortcuts are added again as new copies; nothing is overwritten |

## 5. Devices and help

| Step | Expected |
|---|---|
| Devices | Paired Mac with address, dates, status; history lists paired / connected / lost / disconnected with times |
| Turn the phone's Wi-Fi off and on | History records the loss and the reconnection |
| Clear history | Log is empty; the paired Mac is unaffected |
| Forget this Mac | Confirmation; afterwards the phone shows no paired Mac |
| Help > Check your connection | Rows for Wi-Fi, paired Mac, connection, latency, Mac permission match reality; Check again refreshes; Copy details puts text on the clipboard |
| Help > Mac settings some actions need | Lists each system action with its macOS requirement |

## 6. Accessibility

Turn on TalkBack and check: icon-only buttons are announced with their purpose; switches announce on/off; the accent swatches announce their color and selection;
the touchpad announces its purpose; the onboarding announces "Page n of 4". Set the system font size to largest: Settings, Help and Devices still scroll and nothing is cut off.

## 7. Mac app

| Step | Expected |
|---|---|
| Launch | Menu bar icon appears; main window opens; server starts (unless turned off in Settings) |
| Menu bar menu | Status text; Pair a Phone; Open MacTouch; Stop/Start Server; Disconnect while connected; Allow Accessibility while missing; Quit |
| Pair a Phone | Small window with only the QR code and a countdown; code changes every 2 minutes |
| Scan from the phone | The standard macOS alert appears over everything; Pair or Decline; the phone follows |
| Let the request time out (do nothing for a minute) | The alert closes by itself |
| Overview | Shows state and address; server Restart / Stop / Start |
| Stop the server | Overview shows "Server is stopped"; pairing window offers Start server |
| Start a second copy of MacTouch while the first runs | Second shows "could not start" with the reason and a Try again button |
| Turn Wi-Fi off on the Mac | "No local network" notice; pairing window says so |
| Remove Accessibility permission | Warning card with Open System Settings and Check again; menu bar icon changes; it clears within ~2 s when granted |
| Devices | Paired phones with last seen; Disconnect while connected; Forget asks first |
| History | Server started/stopped, paired, declined, connected, disconnected, server problems; Clear works |
| Settings > Mac name | The phone shows the new name after the next pairing |
| Settings > Menu bar icon / Dock icon | Each can be hidden, but not both (the other toggle is disabled) |
| Settings > Open at login | Works from /Applications/MacTouch.app; otherwise shows a plain explanation |
| Close the main window | Server and menu bar item keep running; Open MacTouch brings it back |
