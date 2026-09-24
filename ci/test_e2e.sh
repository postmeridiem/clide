#!/usr/bin/env bash
# End-to-end layer: the web WASM build, driven by Playwright. Every spec in the
# `chromium` project runs against the dev server; the edge container's specs
# (`container-*`) have their own project (T-443).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> browser WASM e2e (Playwright)"
./tools/ui/build.sh
./tools/ui/serve.sh
trap './tools/ui/stop.sh >/dev/null 2>&1' EXIT
(cd tools/ui && npx playwright test --project=chromium)
