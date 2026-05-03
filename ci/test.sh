#!/usr/bin/env bash
# Fast test layer — analyze + format + unit + widget + golden.
# Runs in <60s on a warm cache. Called from `make test` and the
# pre-push hook.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze"
flutter analyze --no-fatal-infos

echo "==> dart format (whole tree)"
dart format --set-exit-if-changed .

echo "==> dart test (forkpty — incompatible with flutter test runner)"
dart test --tags forkpty test/pty/session_test.dart

echo "==> flutter test (unit + widget + golden)"
flutter test --exclude-tags forkpty
