#!/usr/bin/env bash
# CI entry: supply-chain + CVE gate. Shells out to Makefile targets so
# local dev and CI run the same commands.
#
# See ~/.claude/projects/-var-mnt-data-projects-clide/memory/ for the
# standing requirement: Dart deps prefer zero; what remains is pinned
# and advisory-audited before bumping. Native supporter tools (ptyc, any
# future peer) are reviewed by reading them — they have no dep graph.
set -euo pipefail

cd "$(dirname "$0")/.."

make security
