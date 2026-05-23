#!/usr/bin/env bash
# Fast test layer — analyze + format + unit + widget + golden.
# Runs in <60s on a warm cache. Called from `make test` and the
# pre-push hook.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze"
flutter analyze

echo "==> dart format (whole tree)"
dart format --set-exit-if-changed .

echo "==> dart test (pty — unreliable under the flutter test runner)"
dart test --tags pty test/pty/session_test.dart test/panes/registry_test.dart

echo "==> flutter test --coverage (unit + widget + golden)"
flutter test --coverage --exclude-tags pty
