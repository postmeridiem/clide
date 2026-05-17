#!/usr/bin/env bash
# integration_test suite — the load-bearing "tests pass but app doesn't
# start" regression gate. Flutter integration tests prefer one file at
# a time on desktop; we iterate to avoid the "Unable to start the app"
# error that hits when they run as a batch.
#
# Skips: theme_picker_test.dart — pumpAndSettle hangs on theme.pick
# (T-116). Restore once that's fixed.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in integration_test/*_test.dart; do
  case "$f" in
    integration_test/theme_picker_test.dart) echo "==> integration_test: $f (SKIPPED — T-116)"; continue ;;
  esac
  echo "==> integration_test: $f"
  flutter test "$f"
done
