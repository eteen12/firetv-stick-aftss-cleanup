#!/usr/bin/env bash
# Undo install-home.sh: remove the home watcher from accessibility, uninstall both apps,
# and put the alarm manager setting back. Amazon's launcher takes Home again.
# Usage: TV_HOST=<stick-ip> ./uninstall-home.sh
set -euo pipefail

: "${TV_HOST:?set TV_HOST to the IP address of the Fire TV stick}"
TV="$TV_HOST"
SERVICE=com.firetv.tvos/com.firetv.tvos.HomeWatcherService
adb connect "$TV:5555" >/dev/null
tv() { adb -s "$TV:5555" shell "$@" </dev/null | tr -d '\r'; }

current=$(tv settings get secure enabled_accessibility_services)
[[ "$current" == null ]] && current=""
remaining=$(tr ':' '\n' <<<"$current" | grep -vxF "$SERVICE" | grep -v '^$' | paste -sd: - || true)
if [[ -n "$remaining" ]]; then
  tv settings put secure enabled_accessibility_services "$remaining"
else
  tv settings delete secure enabled_accessibility_services >/dev/null || true
  tv settings put secure accessibility_enabled 0
fi
tv settings delete global alarm_manager_constants >/dev/null || true

for pkg in com.firetv.tvos com.gathin.tvhome; do
  echo "uninstall $pkg: $(adb -s "$TV:5555" uninstall "$pkg" 2>&1 | tr -d '\r')"
done
tv input keyevent KEYCODE_HOME
echo "done. Home is Amazon's launcher again."
