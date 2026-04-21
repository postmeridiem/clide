#!/usr/bin/env bash
# Build the Flutter web WASM bundle that the Playwright harness drives.
set -euo pipefail
cd "$(dirname "$0")/../../app"
flutter build web --wasm "$@"
echo "built app/build/web ($(du -sh build/web | cut -f1))"
