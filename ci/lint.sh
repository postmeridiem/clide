#!/usr/bin/env bash
# CI entry: lint + supply-chain gates. Security runs here too so a
# merge-blocking lint failure and a merge-blocking CVE failure share
# one CI job — there is no version of "lint passed but we shipped a
# known-vulnerable dep" that is acceptable in this repo.
set -euo pipefail

cd "$(dirname "$0")/.."

make lint
make app-analyze
make security
