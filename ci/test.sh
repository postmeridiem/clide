#!/usr/bin/env bash
# Fast test layer — analyze + format + unit + widget + golden.
#
# Two modes (T-192):
#   ci/test.sh              dev inner loop — NO coverage, parallel. ~20s warm.
#   ci/test.sh --coverage   gate run — instrumented; writes coverage/lcov.info
#                           for coverage-gate. ~36s (coverage is the floor and
#                           is concurrency-insensitive, measured — so no
#                           --concurrency here; it buys nothing).
#
# Both pass `--timeout 60s` so a hung test (a stray pumpAndSettle, or a
# real-time deadlock) fails fast instead of wedging the runner for ~10 min and
# stalling the pre-push gate. (Use the pumpAsync helper in tests; never
# pumpAndSettle / Future.delayed(Duration.zero) inside testWidgets.)
set -euo pipefail
cd "$(dirname "$0")/.."

coverage=0
[[ "${1:-}" == "--coverage" ]] && coverage=1

echo "==> flutter analyze"
flutter analyze

echo "==> dart format (whole tree)"
dart format --set-exit-if-changed .

echo "==> dart test (pty — unreliable under the flutter test runner)"
dart test --tags pty test/pty/session_test.dart test/panes/registry_test.dart

if [[ "$coverage" == 1 ]]; then
  echo "==> flutter test --coverage (gate; unit + widget + golden + a11y)"
  flutter test --coverage --exclude-tags pty --timeout 60s
else
  echo "==> flutter test (dev; no coverage, parallel)"
  flutter test --exclude-tags pty --concurrency=12 --timeout 60s
fi
