#!/usr/bin/env bash
# End-to-end layer: web WASM Playwright smoke.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> browser WASM smoke (Playwright)"
./tools/ui/build.sh
./tools/ui/serve.sh
trap './tools/ui/stop.sh >/dev/null 2>&1' EXIT
(cd tools/ui && npx playwright test smoke.spec.ts)
