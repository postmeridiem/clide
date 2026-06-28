#!/usr/bin/env bash
# T-88 — track dugite-native (bundled git) upstream releases for security
# updates (D-59). Compares the pinned DUGITE_VERSION against the latest
# desktop/dugite-native release and flags CVE / security mentions.
#
# WHY THIS SCRIPT IS THE MAINTENANCE HOME: dugite's binary is FETCHED at build
# time (`make dugite-fetch`), not built, and native/dugite/ is gitignored — so
# there is no `native/dugite/BUILD.md` (D-63) to record it. The pin lives in the
# Makefile (DUGITE_VERSION / DUGITE_COMMIT); this script + its `make dugite-check`
# target are the version-tracking calendar D-59 requires.
#
# CADENCE: run quarterly during normal operation. Run IMMEDIATELY on a git or
# dugite-native security advisory — subscribe to:
#   https://github.com/git/git/security/advisories
#   https://github.com/desktop/dugite-native/security/advisories
#
# This check is INFORMATIONAL (not a push gate): it reports drift and flags CVE
# mentions. The bump itself is manual per D-63 (reproducibility record) and is
# automated by T-25 (CI). A bump updates: Makefile DUGITE_VERSION/COMMIT, the
# fetched binary in native/dugite/, and assets/licenses.yaml if the bundled git
# or dugite version changed.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="desktop/dugite-native"
CURRENT="$(grep -E '^DUGITE_VERSION[[:space:]]*:=' Makefile | head -1 | sed -E 's/.*:=[[:space:]]*//')"

# Public read — no auth needed for a quarterly check. gh would raise the rate
# limit but isn't required; curl keeps this dependency-free.
json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)"
LATEST="$(printf '%s' "$json" | sed -nE 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -1)"

if [[ -z "$LATEST" ]]; then
  echo "==> dugite-check: couldn't reach the dugite-native releases API." >&2
  echo "    Check manually: https://github.com/$REPO/releases" >&2
  exit 2
fi

echo "==> dugite-check (T-88): bundled '$CURRENT' vs latest release '$LATEST'"
if [[ "$CURRENT" == "$LATEST" ]]; then
  echo "    OK — up to date."
else
  echo "    DRIFT — a newer dugite-native release exists:  $CURRENT -> $LATEST"
  echo "    Bump (D-63 record; machine: T-25): update Makefile DUGITE_VERSION/COMMIT,"
  echo "    refresh native/dugite/, and assets/licenses.yaml if the git/dugite version changed."
fi

# Loud flag when the latest release notes mention a CVE / security fix — those
# jump the queue regardless of the quarterly cadence.
if printf '%s' "$json" | grep -qiE 'cve-[0-9]{4}|security (fix|advisory|release|update)|vulnerab'; then
  echo "    !! SECURITY: the latest release notes mention a CVE / security fix — schedule a bump NOW." >&2
fi
