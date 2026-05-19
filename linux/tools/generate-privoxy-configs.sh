#!/usr/bin/env bash
set -euo pipefail

HOST_IP=""
INSTANCE_COUNT=9
SOCKS_BASE_PORT=40001
HTTP_BASE_PORT=41001
BASE_CONFIG="/etc/privoxy/config"
OUTPUT_DIR="/etc/privoxy/warp-instances"

usage() {
  cat <<'EOF'
Usage:
  generate-privoxy-configs.sh --host-ip <LAN_IP> [options]

Options:
  --host-ip <ip>            LAN IP for the HTTP bridge listener (required)
  --instance-count <n>      Number of WARP instances to render (default: 9)
  --socks-base-port <port>  First SOCKS port (default: 40001)
  --http-base-port <port>   First HTTP port (default: 41001)
  --base-config <path>      Base Privoxy config to copy from (default: /etc/privoxy/config)
  --output-dir <path>       Output directory (default: /etc/privoxy/warp-instances)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-ip)
      HOST_IP="${2:?missing value for --host-ip}"
      shift 2
      ;;
    --instance-count)
      INSTANCE_COUNT="${2:?missing value for --instance-count}"
      shift 2
      ;;
    --socks-base-port)
      SOCKS_BASE_PORT="${2:?missing value for --socks-base-port}"
      shift 2
      ;;
    --http-base-port)
      HTTP_BASE_PORT="${2:?missing value for --http-base-port}"
      shift 2
      ;;
    --base-config)
      BASE_CONFIG="${2:?missing value for --base-config}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?missing value for --output-dir}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$HOST_IP" ]]; then
  echo "--host-ip is required" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$BASE_CONFIG" ]]; then
  echo "Base Privoxy config not found: $BASE_CONFIG" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

tmp_filtered="$(mktemp)"
trap 'rm -f "$tmp_filtered"' EXIT

python3 - "$BASE_CONFIG" "$tmp_filtered" <<'PY'
from pathlib import Path
import re
import sys

src = Path(sys.argv[1]).read_text()
out = []
for line in src.splitlines():
    if re.match(r'^\s*(listen-address|forward-socks5|logfile)\b', line):
        continue
    out.append(line)

Path(sys.argv[2]).write_text("\n".join(out).rstrip() + "\n")
PY

for ((i = 0; i < INSTANCE_COUNT; i++)); do
  socks_port=$((SOCKS_BASE_PORT + i))
  http_port=$((HTTP_BASE_PORT + i))
  output_file="${OUTPUT_DIR}/warp-${socks_port}.config"

  cat "$tmp_filtered" > "$output_file"
  cat <<EOF >> "$output_file"

# 9router -> WARP via local SOCKS
# laptop 9router access on LAN

logfile warp-${socks_port}.log
listen-address  ${HOST_IP}:${http_port}
forward-socks5 / 127.0.0.1:${socks_port} .
EOF

  chmod 644 "$output_file"
  echo "Rendered $output_file"
done
