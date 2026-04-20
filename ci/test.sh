#!/usr/bin/env bash
# CI entry: run the full test matrix. Shells out to Makefile targets.
set -euo pipefail

cd "$(dirname "$0")/.."

make test
make test-race
make app-test
