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

echo "==> dart test (pty — unreliable under the flutter test runner; serial)"
# --concurrency=1: these spawn real PTYs and compete for fds when run in
# parallel, which flaked them (registry/session). Serialize — the proper fix
# for resource-bound tests, vs. the old per-test `retry:` band-aid. (T-193)
dart test --concurrency=1 --tags pty test/pty/session_test.dart test/panes/registry_test.dart

# The parallel pool excludes both pty (runs under dart test, above) and
# serial-tagged tests (concurrency-vulnerable — run in their own --concurrency=1
# pass below). See dart_test.yaml + T-193.
if [[ "$coverage" == 1 ]]; then
  echo "==> flutter test --coverage (parallel pool; excludes pty + serial)"
  flutter test --coverage --exclude-tags "pty || serial" --timeout 60s
  cp coverage/lcov.info coverage/lcov.parallel.info
  echo "==> flutter test --coverage (serial-tagged; --concurrency=1)"
  flutter test --coverage --tags serial --concurrency=1 --timeout 60s
  echo "==> merge coverage (parallel + serial passes → coverage/lcov.info)"
  python3 ci/merge_lcov.py coverage/lcov.parallel.info coverage/lcov.info > coverage/lcov.merged.info
  mv coverage/lcov.merged.info coverage/lcov.info
  rm -f coverage/lcov.parallel.info
else
  echo "==> flutter test (dev; parallel pool, excludes pty + serial)"
  flutter test --exclude-tags "pty || serial" --concurrency=12 --timeout 60s
  echo "==> flutter test (dev; serial-tagged, --concurrency=1)"
  flutter test --tags serial --concurrency=1 --timeout 60s
fi
