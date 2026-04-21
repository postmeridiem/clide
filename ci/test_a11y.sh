#!/usr/bin/env bash
# A11y contract gate — semantic coverage + keyboard traversal + WCAG
# contrast + i18n key coverage. Runs in <5s and is part of push-check.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> a11y suite"
(cd app && flutter test test/a11y/)
