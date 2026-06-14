#!/usr/bin/env bash
# Build the Flutter web WASM bundle that the Playwright harness drives.
# The Flutter package lives at the repo root since the app/ flattening
# (T-384 fixed the stale `cd app` that broke this target).
set -euo pipefail
cd "$(dirname "$0")/../.."
flutter build web --wasm "$@"
echo "built build/web ($(du -sh build/web | cut -f1))"
