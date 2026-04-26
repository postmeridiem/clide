#!/usr/bin/env bash
# Generate + summarize lcov coverage. No thresholds yet (see plan's
# "Open questions deferred" — we let the suite run for a week of real
# commits before setting hard gates that would just need tuning).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter test --coverage"
flutter test --coverage

if command -v lcov >/dev/null 2>&1; then
  echo "==> lcov summary"
  lcov --summary coverage/lcov.info
fi
