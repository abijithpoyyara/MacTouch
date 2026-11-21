#!/bin/sh
# Captures Android screenshots through adb into docs/screenshots/. Requires adb and a connected phone.
set -eu
cd "$(dirname "$0")"
mkdir -p screenshots
command -v adb >/dev/null || { echo "adb not found. Install Android platform-tools."; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "No phone found. Connect it over USB and allow USB debugging."; exit 1; }
while :; do
  printf "Screenshot name (empty to finish): "
  read -r name
  [ -z "$name" ] && break
  printf "Show the screen on the phone, then press Enter... "
  read -r _
  adb exec-out screencap -p > "screenshots/$name.png"
  echo "saved docs/screenshots/$name.png"
done
