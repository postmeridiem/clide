#!/usr/bin/env bash
# Startup regression gate: build the Linux release bundle and run it
# under xvfb for 5 seconds. Non-zero exit = the app crashed on boot.
#
# Catches: dynamic-linker errors, plugin-init failures, asset-not-bundled
# regressions, main-isolate unhandled errors surfacing pre-first-frame.
# These are exactly the class of regressions `make test` / widget tests
# cannot see because they never pump the real bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE="app/build/linux/x64/release/bundle/clide_app"

echo "==> build linux release bundle"
(cd app && flutter build linux --release)

if [[ ! -x "$BUNDLE" ]]; then
  echo "smoke: bundle not found at $BUNDLE" >&2
  exit 2
fi

echo "==> launching under xvfb for 5s"
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "smoke: xvfb-run is required (install via: apt-get install xvfb)" >&2
  exit 2
fi

# Wrap with `timeout` so a healthy daemon-less app gets SIGTERM cleanly.
# Expected: SIGTERM (exit 143) — the app stayed up the whole time.
# Anything else: crash.
set +e
xvfb-run -a -s "-screen 0 1280x720x24" timeout --signal=TERM 5 "$BUNDLE"
exit_code=$?
set -e

# `timeout` exits 124 when it sends SIGTERM + the process terminates
# gracefully, 143 when terminated without graceful cleanup, or the
# app's own exit code if it self-exited first.
case $exit_code in
  124|143)
    echo "==> smoke: app stayed up for 5s, killed by timeout (healthy)"
    exit 0
    ;;
  0)
    echo "==> smoke: app exited cleanly before timeout (unusual; check main.dart)" >&2
    exit 0
    ;;
  *)
    echo "==> smoke: app exited with $exit_code before timeout (CRASH)" >&2
    exit 1
    ;;
esac
