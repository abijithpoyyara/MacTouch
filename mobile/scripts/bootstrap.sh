#!/bin/sh
# Generates the Android platform folder with `flutter create`, then applies MacTouch's manifest settings.
# Run once after cloning:  cd mobile && ./scripts/bootstrap.sh
set -eu
cd "$(dirname "$0")/.."

flutter create --platforms=android --org app.mactouch --project-name mactouch_mobile .

MANIFEST=android/app/src/main/AndroidManifest.xml
python3 - "$MANIFEST" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
perms = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.ACCESS_WIFI_STATE",
]
add = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in text)
if add:
    text = text.replace("<application", add + "    <application", 1)
if "usesCleartextTraffic" not in text:
    # The Mac server speaks plain ws:// on the LAN; every message is authenticated with HMAC.
    text = text.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
if "android.hardware.camera" not in text:
    text = text.replace("<application", '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n    <application', 1)
open(path, "w", encoding="utf-8").write(text)
print("patched", path)
PY

# mobile_scanner needs minSdk 21+; pin to 23 for flutter_secure_storage's encrypted prefs.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i.bak -E 's/minSdk(Version)?[ =]+(flutter\.minSdkVersion|[0-9]+)/minSdk = 23/' "$f" && rm -f "$f.bak" && echo "set minSdk in $f"
done
flutter pub get
echo "Done. Run: flutter run"
