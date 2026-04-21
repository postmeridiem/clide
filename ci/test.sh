#!/usr/bin/env bash
# Fast test layer — unit + widget + golden. Runs in <60s on a warm
# cache. Called from `make test` and the pre-push hook.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> dart analyze (root package)"
dart analyze

echo "==> dart format (whole tree)"
dart format --set-exit-if-changed .

echo "==> dart test (root package)"
dart test

echo "==> flutter analyze (app)"
(cd app && flutter analyze)

echo "==> flutter test (app unit + widget + golden)"
(cd app && flutter test)
