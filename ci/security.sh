#!/usr/bin/env bash
# CI entry: supply-chain + CVE gate. Shells out to Makefile targets so
# local dev and CI run the same commands.
#
# See ~/.claude/projects/-var-mnt-data-projects-clide/memory/ for the
# standing requirements: Go deps must be version-locked and CVE-checked;
# Dart deps prefer zero, with what remains pinned and audited.
set -euo pipefail

cd "$(dirname "$0")/.."

make security
