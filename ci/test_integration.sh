#!/usr/bin/env bash
# integration_test suite — the load-bearing "tests pass but app doesn't
# start" regression gate. Flutter integration tests prefer one file at
# a time on desktop; we iterate to avoid the "Unable to start the app"
# error that hits when they run as a batch.
#
# -d linux pins the desktop device explicitly: the GitHub ubuntu-latest
# runner exposes BOTH a linux desktop AND a chrome web device, so a bare
# `flutter test integration_test/...` aborts with "More than one device
# connected" before it ever compiles (the dev box / old Gitea runner only
# had the one device, so this was latent until CI moved to GitHub).
set -euo pipefail
cd "$(dirname "$0")/.."

for f in integration_test/*_test.dart; do
  echo "==> integration_test: $f"
  flutter test -d linux "$f"
done
