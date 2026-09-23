#!/usr/bin/env bash
# Supply-chain gate — fails if a vendored native artefact under native/ no
# longer matches the SHA-256 recorded next to it (D-63, T-299).
#
# Each vendored directory carries a `SHA256SUMS` file in `sha256sum` format,
# written when the artefact was built/audited (see that dir's BUILD.md).
# This catches silent corruption or tampering of a binary that no lockfile
# covers — the osv gate (ci/osv_scan.sh) only sees pubspec.lock. A bump
# re-records the hash in the same commit as the new artefact.
set -euo pipefail
cd "$(dirname "$0")/.."

# sha256sum (GNU coreutils) on Linux; shasum ships with macOS instead.
if command -v sha256sum >/dev/null 2>&1; then
  SHACHECK=(sha256sum --check --strict)
elif command -v shasum >/dev/null 2>&1; then
  SHACHECK=(shasum -a 256 --check --strict)
else
  echo "==> native gate: neither sha256sum nor shasum found on PATH." >&2
  exit 2
fi

shopt -s nullglob
sums=(native/*/SHA256SUMS)
if [[ ${#sums[@]} -eq 0 ]]; then
  echo "==> native gate FAIL: no native/*/SHA256SUMS found — nothing verified." >&2
  exit 1
fi

fail=0
for sumfile in "${sums[@]}"; do
  dir="$(dirname "$sumfile")"
  echo "==> native gate: verifying $sumfile"
  if ! (cd "$dir" && "${SHACHECK[@]}" SHA256SUMS); then
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "==> native gate FAIL: a vendored artefact does not match its recorded SHA-256 (see above)." >&2
  echo "    If this is an intentional bump, rebuild per BUILD.md, re-record the hash" >&2
  echo "    in SHA256SUMS + BUILD.md, and update assets/licenses.yaml in the same commit." >&2
  exit 1
fi
echo "==> native gate OK: all vendored artefacts match their recorded SHA-256"
