#!/usr/bin/env bash
# Point Android Private DNS at a blocking resolver so the protected Amazon loggers cannot report home.
# Usage: TV_HOST=<stick-ip> ./privacy-dns.sh [on|off]          (default: on)
#        DNS_HOST=other.dns.example ./privacy-dns.sh on           (default: dns.adguard-dns.com)
set -euo pipefail

: "${TV_HOST:?set TV_HOST to the IP address of the Fire TV stick}"
TV="$TV_HOST"
DNS_HOST="${DNS_HOST:-dns.adguard-dns.com}"
MODE="${1:-on}"

adb connect "$TV:5555" >/dev/null
tv() { adb -s "$TV:5555" shell "$@" </dev/null | tr -d '\r'; }

case "$MODE" in
  on)
    [[ "$DNS_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "bad DNS_HOST: $DNS_HOST" >&2; exit 1; }
    tv settings put global private_dns_specifier "$DNS_HOST"
    tv settings put global private_dns_mode hostname
    ;;
  off)
    tv settings put global private_dns_mode off
    ;;
  *) echo "usage: $0 [on|off]" >&2; exit 1 ;;
esac

echo "private_dns_mode:      $(tv settings get global private_dns_mode)"
echo "private_dns_specifier: $(tv settings get global private_dns_specifier)"
sleep 3
for host in device-metrics-us.amazon.com www.netflix.com; do
  echo "$host -> $(tv ping -c 1 -W 2 "$host" 2>&1 | head -n 1)"
done
echo "with DNS on, device-metrics-us.amazon.com should resolve to 127.0.0.1 or 0.0.0.0 and netflix normally."
