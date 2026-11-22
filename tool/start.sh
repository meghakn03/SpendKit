#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  printf '%s\n' 'Install Flutter 3.50.1 and add flutter to your PATH before starting SpendKit.' >&2
  exit 127
fi
if ! command -v node >/dev/null 2>&1 || ! node -e "require('node:sqlite')" >/dev/null 2>&1; then
  printf '%s\n' 'Install Node.js 24 LTS before starting the SpendKit backend.' >&2
  exit 127
fi

device="${1:-chrome}"
port="${SPENDKIT_PORT:-8787}"
loopback="http://127.0.0.1:$port"
host=127.0.0.1
if [[ "$device" == emulator-* ]]; then
  ./tool/setup-mobile.sh
  host=10.0.2.2
fi

api_ready() {
  curl --max-time 1 -fsS "$loopback/health" 2>/dev/null | grep -Fq '"service":"spendkit"'
}
if ! api_ready; then
  node backend/server.mjs &
  api_pid=$!
  trap 'kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true' EXIT
  for attempt in {1..30}; do
    if api_ready; then break; fi
    if ! kill -0 "$api_pid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  if ! api_ready; then
    printf '%s\n' 'The SpendKit API did not start. Check the server output above.' >&2
    exit 1
  fi
fi

flutter run -d "$device" --dart-define="SPENDKIT_API_URL=http://$host:$port"
