#!/usr/bin/env bash
# Supply-chain gate — fails the push if any resolved dependency in
# pubspec.lock has a known advisory (OSV / GitHub Advisory Database).
#
# Complements `dart pub get`'s passive advisory print (informational,
# non-failing) with a hard, fail-closed gate. Native deps (dugite,
# tree-sitter, wasmtime) are vendored by SHA and not in a lockfile OSV
# reads — they're reviewed separately on bump (D-42, CLAUDE.md supply chain).
set -euo pipefail
cd "$(dirname "$0")/.."

# Resolve osv-scanner: PATH first, then a brew prefix (the git pre-push hook
# may run with a leaner PATH than the dev's interactive shell).
OSV="$(command -v osv-scanner || true)"
if [[ -z "$OSV" ]] && command -v brew >/dev/null 2>&1; then
  cand="$(brew --prefix 2>/dev/null)/bin/osv-scanner"
  [[ -x "$cand" ]] && OSV="$cand"
fi
if [[ -z "$OSV" ]]; then
  echo "==> osv gate: osv-scanner not found on PATH." >&2
  echo "    Install it:  brew install osv-scanner" >&2
  echo "    (or:         go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest)" >&2
  exit 2
fi

echo "==> osv gate: scanning pubspec.lock for known advisories"
if "$OSV" scan source --lockfile=pubspec.lock; then
  echo "==> osv gate OK: no known advisories"
else
  echo "==> osv gate FAIL: a dependency has a known advisory (see above)." >&2
  echo "    Bump the affected package (+ its assets/licenses.yaml entry), or" >&2
  echo "    document an explicit, justified exception before pushing." >&2
  exit 1
fi
