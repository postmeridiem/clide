#!/usr/bin/env bash
# A11y contract gate — semantic coverage + keyboard traversal + WCAG
# contrast + i18n key coverage. Runs in <5s and is part of push-check.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> a11y suite"
# failures-only: failing tests + a final count, not one line per test.
# Override with TEST_REPORTER=expanded when debugging. (T-242)
flutter test -r "${TEST_REPORTER:-failures-only}" test/a11y/
