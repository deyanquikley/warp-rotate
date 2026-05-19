#!/usr/bin/env bash
set -euo pipefail

i="${1:?instance index required}"
iface="wgcf${i}"

if ip link show "$iface" >/dev/null 2>&1; then
  exit 0
fi

exec wg-quick up "$iface"
