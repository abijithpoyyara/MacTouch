# Screenshots

The screenshots in this folder could **not** be updated for Part 4: the code was written without an Android emulator or a Mac to run it on,
and a screenshot made from a mock-up would not show the real app. Capture them from the real apps with the steps below, then commit them to `docs/screenshots/`.

## Android

With the phone connected over USB (USB debugging on):

```sh
./docs/capture_screenshots.sh          # asks for a name, press Enter in the terminal when the screen is ready
```

Suggested set (light and dark, portrait; the touchpad also in landscape):

| File name | Screen |
|---|---|
| 01-onboarding | first page of the introduction |
| 02-welcome | Welcome / pairing entry |
| 03-hub | connection status hub |
| 04-touchpad-portrait, 04-touchpad-landscape | main touchpad |
| 05-gestures | Gestures |
| 06-shortcuts | Shortcut Center |
| 07-editor | Shortcut editor |
| 08-devices | Devices with history |
| 09-settings | Settings |
| 10-help | Help |

## macOS

`Shift-Command-4`, then Space, then click the window (this captures one window with its shadow). Capture: Overview, Devices, Settings, the pairing window, and the menu bar menu
(`Shift-Command-5` > Capture Selected Portion).
