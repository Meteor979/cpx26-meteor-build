#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PORT="${WEARWISE_DEMO_PORT:-4173}"
LOG="${TMPDIR:-/tmp}/wearwise-web-demo.log"

echo "Starting WearWise at http://127.0.0.1:${PORT}/"
python3 -m http.server "$PORT" --bind 127.0.0.1 > "$LOG" 2>&1 &
SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 1
open "http://127.0.0.1:${PORT}/"

echo "Press Control-C to stop the demo."
wait "$SERVER_PID"
