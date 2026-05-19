#!/usr/bin/env bash
set -euo pipefail

i="${1:?instance index required}"
BASE_PORT=40001
BASE_IP_OCTET=2
SOCKS_BIND="0.0.0.0"
iface="wgcf${i}"
port=$((BASE_PORT + i))
warp_ip="172.16.0.$((BASE_IP_OCTET + i))"

for _ in $(seq 1 10); do
  if ip -4 addr show "$iface" 2>/dev/null | grep -q "inet ${warp_ip}/32"; then
    exec /usr/local/bin/microsocks -i "$SOCKS_BIND" -p "$port" -b "$warp_ip"
  fi
  sleep 1
done

echo "Expected $iface to have ${warp_ip}/32 before starting microsocks on port ${port}" >&2
exit 1
