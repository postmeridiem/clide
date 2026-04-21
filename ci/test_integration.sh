#!/usr/bin/env bash
# integration_test suite — the load-bearing "tests pass but app doesn't
# start" regression gate. Flutter integration tests prefer one file at
# a time on desktop; we iterate to avoid the "Unable to start the app"
# error that hits when they run as a batch.
set -euo pipefail
cd "$(dirname "$0")/.."

cd app
for f in integration_test/*_test.dart; do
  echo "==> integration_test: $f"
  flutter test "$f"
done
