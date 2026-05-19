#!/usr/bin/env bash
set -euo pipefail

i="${1:?instance index required}"
socks_port=$((40001 + i))
config="/etc/privoxy/warp-instances/warp-${socks_port}.config"

exec /usr/sbin/privoxy --no-daemon "$config"
