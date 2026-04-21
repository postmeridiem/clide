#!/usr/bin/env bash
# Kill the dev web server on $CLIDE_UI_PORT (default 4280). Port-based
# kill so any orphan from a previous `serve.sh` that lost its pidfile
# dies too.
set -euo pipefail

PORT=${CLIDE_UI_PORT:-4280}
HERE="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$HERE/.serve.pid"

pids=""
if command -v lsof >/dev/null 2>&1; then
  pids=$(lsof -ti:"$PORT" 2>/dev/null || true)
elif command -v fuser >/dev/null 2>&1; then
  pids=$(fuser -n tcp "$PORT" 2>/dev/null | tr -d ' /tcp' || true)
fi

if [[ -n "$pids" ]]; then
  echo "stop: killing $pids (port $PORT)"
  echo "$pids" | xargs -r kill 2>/dev/null || true
  # Give SIGTERM 300ms to land; escalate to SIGKILL for stragglers.
  sleep 0.3
  remaining=""
  if command -v lsof >/dev/null 2>&1; then
    remaining=$(lsof -ti:"$PORT" 2>/dev/null || true)
  fi
  if [[ -n "$remaining" ]]; then
    echo "stop: escalating to SIGKILL for $remaining"
    echo "$remaining" | xargs -r kill -9 2>/dev/null || true
  fi
else
  echo "stop: no server on port $PORT"
fi

rm -f "$PID_FILE"
