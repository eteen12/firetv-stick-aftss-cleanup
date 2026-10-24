#!/usr/bin/env bash
# Disable every package in a list for user 0 (reversible with restore.sh).
# Usage: TV_HOST=<stick-ip> ./debloat.sh [list]     (list defaults to debloat.txt)
# Set FORCE=1 to run on a model or Fire OS build other than AFTSS / PS7717.
set -euo pipefail

: "${TV_HOST:?set TV_HOST to the IP address of the Fire TV stick}"
TV="$TV_HOST"
LIST="${1:-$(dirname "$0")/debloat.txt}"
[[ -r "$LIST" ]] || { echo "cannot read list: $LIST" >&2; exit 1; }

adb connect "$TV:5555" >/dev/null
tv() { adb -s "$TV:5555" shell "$@" </dev/null | tr -d '\r'; }

model=$(tv getprop ro.product.model)
build=$(tv getprop ro.build.version.name)
echo "device: $model / $build"
if [[ "$model" != "AFTSS" || "$build" != *PS7717* ]] && [[ "${FORCE:-0}" != 1 ]]; then
  echo "this list was tested on AFTSS with Fire OS 7.7.1.7 (PS7717); rerun with FORCE=1 to continue anyway" >&2
  exit 1
fi

ok=0 fail=0 skip=0
while IFS= read -r line || [[ -n "$line" ]]; do
  pkg="${line%%#*}"                     # strip comments
  pkg="${pkg//[[:space:]]/}"            # strip whitespace
  [[ -z "$pkg" ]] && continue
  if [[ ! "$pkg" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$ ]]; then
    echo "SKIP  $pkg (not a bare package name)"; skip=$((skip + 1)); continue
  fi
  out=""
  for _ in 1 2; do                      # some packages (com.amazon.tv.livetv) need a second attempt
    out=$(tv pm disable-user --user 0 "$pkg" 2>&1 || true)
    [[ "$out" == *"new state: disabled-user"* ]] && break
  done
  if [[ "$out" == *"new state: disabled-user"* ]]; then
    echo "OK    $pkg"; ok=$((ok + 1))
  else
    echo "FAIL  $pkg: ${out:-no output}"; fail=$((fail + 1))
  fi
done < "$LIST"

echo "disabled: $ok   failed: $fail   skipped: $skip"
echo "packages that are not on your stick fail with 'Unknown package'; that is harmless."
