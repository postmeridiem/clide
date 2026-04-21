#!/usr/bin/env bash
# End-to-end layer: daemon subprocess + web WASM Playwright smoke.
# Neither fits in `make test`; together they're the "everything still
# works across process/runtime boundaries" gate.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> build bin/clide (required by daemon subprocess test)"
make build

echo "==> daemon subprocess test"
dart test test/daemon/

echo "==> browser WASM smoke (Playwright)"
./tools/ui/build.sh
./tools/ui/serve.sh
trap './tools/ui/stop.sh >/dev/null 2>&1' EXIT
(cd tools/ui && npx playwright test smoke.spec.ts)
