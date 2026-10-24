#!/usr/bin/env bash
# Install the cleanyourtv launcher and the firetv-tvos home watcher (both built by you from source),
# then wire HOME to the new launcher.
# Usage: TV_HOST=<stick-ip> ./install-home.sh <launcher.apk> <home-watcher.apk> [config.json]
set -euo pipefail

: "${TV_HOST:?set TV_HOST to the IP address of the Fire TV stick}"
TV="$TV_HOST"
LAUNCHER_APK="${1:?path to the cleanyourtv launcher APK (com.gathin.tvhome)}"
WATCHER_APK="${2:?path to the firetv-tvos home-watcher APK (com.firetv.tvos)}"
CONFIG="${3:-}"
for f in "$LAUNCHER_APK" "$WATCHER_APK" ${CONFIG:+"$CONFIG"}; do
  [[ -r "$f" ]] || { echo "cannot read: $f" >&2; exit 1; }
done

SERVICE=com.firetv.tvos/com.firetv.tvos.HomeWatcherService
adb connect "$TV:5555" >/dev/null
a() { adb -s "$TV:5555" "$@"; }
tv() { adb -s "$TV:5555" shell "$@" </dev/null | tr -d '\r'; }

echo "installing launcher";      a install -r "$LAUNCHER_APK"
echo "installing home watcher";  a install -r "$WATCHER_APK"

# Add the watcher to the enabled accessibility services without dropping any that are already on.
current=$(tv settings get secure enabled_accessibility_services)
if [[ -z "$current" || "$current" == null ]]; then
  services="$SERVICE"
elif [[ ":$current:" == *":$SERVICE:"* ]]; then
  services="$current"
else
  services="$current:$SERVICE"
fi
tv settings put secure enabled_accessibility_services "$services"
tv settings put secure accessibility_enabled 1
tv appops set com.firetv.tvos SYSTEM_ALERT_WINDOW allow          # black cover overlay during the swap
tv settings put global alarm_manager_constants min_futurity=0     # lets the watcher's alarm fire at once
tv cmd package set-home-activity com.gathin.tvhome/.MainActivity

if [[ -n "$CONFIG" ]]; then
  echo "pushing theme config"
  a push "$CONFIG" /sdcard/Android/data/com.gathin.tvhome/files/config.json
fi

echo "accessibility services: $(tv settings get secure enabled_accessibility_services)"
tv input keyevent KEYCODE_HOME
echo "done. Press Home on the remote; you should land on the new launcher."
echo "Fire TV Settings: adb -s $TV:5555 shell am start -n com.amazon.tv.launcher/.ui.MainSettingsActivity"
