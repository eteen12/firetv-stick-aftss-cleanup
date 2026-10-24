#!/usr/bin/env bash
# Re-enable every package in a list (undoes debloat.sh).
# Usage: TV_HOST=<stick-ip> ./restore.sh [list]     (list defaults to debloat.txt)
set -euo pipefail

: "${TV_HOST:?set TV_HOST to the IP address of the Fire TV stick}"
TV="$TV_HOST"
LIST="${1:-$(dirname "$0")/debloat.txt}"
[[ -r "$LIST" ]] || { echo "cannot read list: $LIST" >&2; exit 1; }

adb connect "$TV:5555" >/dev/null
tv() { adb -s "$TV:5555" shell "$@" </dev/null | tr -d '\r'; }

ok=0 fail=0 skip=0
while IFS= read -r line || [[ -n "$line" ]]; do
  pkg="${line%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -z "$pkg" ]] && continue
  if [[ ! "$pkg" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$ ]]; then
    echo "SKIP  $pkg (not a bare package name)"; skip=$((skip + 1)); continue
  fi
  out=$(tv pm enable --user 0 "$pkg" 2>&1 || true)
  if [[ "$out" == *"new state: enabled"* ]]; then
    echo "OK    $pkg"; ok=$((ok + 1))
  else
    echo "FAIL  $pkg: ${out:-no output}"; fail=$((fail + 1))
  fi
done < "$LIST"

echo "enabled: $ok   failed: $fail   skipped: $skip"
echo "reboot the stick to finish: adb -s $TV:5555 reboot"
