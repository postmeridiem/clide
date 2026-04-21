#!/usr/bin/env bash
# Serve the WASM bundle on http://localhost:$PORT (default 4280) in the
# background. Robust against orphaned servers: before starting, any
# existing listener on the port (from a previous run whose pidfile got
# lost or overwritten) is killed. The pidfile is advisory — `stop.sh`
# uses port-based kill as the source of truth.
set -euo pipefail

PORT=${CLIDE_UI_PORT:-4280}
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../../app/build/web"
PID_FILE="$HERE/.serve.pid"

if [[ ! -d "$DIR" ]]; then
  echo "serve: web build not found at $DIR — run tools/ui/build.sh first" >&2
  exit 2
fi

# Port-based orphan kill. Handles the case where the recorded pidfile
# was overwritten by an earlier failed call and the previous server
# is still bound to the port.
existing=""
if command -v lsof >/dev/null 2>&1; then
  existing=$(lsof -ti:"$PORT" 2>/dev/null || true)
elif command -v fuser >/dev/null 2>&1; then
  existing=$(fuser -n tcp "$PORT" 2>/dev/null | tr -d ' /tcp' || true)
fi
if [[ -n "$existing" ]]; then
  echo "serve: reclaiming port $PORT from stale listener(s) $existing"
  echo "$existing" | xargs -r kill 2>/dev/null || true
  sleep 0.2
fi

# Flutter web WASM requires Cross-Origin Opener/Embedder headers on the
# server for `SharedArrayBuffer`. A vanilla python http.server misses
# them, so CanvasKit still works but WasmGC-accelerated Skwasm may not.
# For Tier 0 driver-script automation this is fine; revisit when we
# need Skwasm performance parity.
cd "$DIR"
nohup python3 -m http.server "$PORT" >/tmp/clide-ui-serve.log 2>&1 &
echo $! > "$PID_FILE"
echo "serve: http://localhost:$PORT (pid $(cat "$PID_FILE"), log /tmp/clide-ui-serve.log)"
