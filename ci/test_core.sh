#!/usr/bin/env bash
# ci/test_core.sh — run the Flutter-free core Dart tests.
#
# Covers `test/` at the repo root (IPC, daemon, PTY). Wraps `dart test`
# in a hard timeout + process-group kill so a hanging test (typically
# one holding a native fd open) can't wedge CI or pre-push.
#
# Rationale: D-030 makes tests client-side only; a hang here is always
# local — either a real bug or a bad test. Either way we'd rather fail
# loudly at 120s than block a pre-push indefinitely.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

if ! command -v dart >/dev/null; then
  echo "test-core: dart not on PATH; is Flutter installed?" >&2
  exit 2
fi

if ! command -v ptyc >/dev/null && [[ ! -x "ptyc/bin/ptyc" ]]; then
  echo "test-core: building ptyc (required by PTY tests)"
  make -C ptyc >/dev/null
fi

# Hard timeout (seconds). The PTY tests should finish in <5s; IPC/daemon
# tests are faster still. 120s is generous for CI warmup, tiny for a
# hang.
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-120}

# Run dart test in its own process group so we can kill descendants on
# timeout. `setsid` starts a new session; `timeout --kill-after` SIGKILLs
# after SIGTERM if the test ignores it.
echo "test-core: dart test test/  (timeout ${TIMEOUT_SECONDS}s)"
if ! timeout --kill-after=5s "${TIMEOUT_SECONDS}s" \
     setsid --wait dart test test/ ; then
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "test-core: TIMEOUT — killing descendants" >&2
    pkill -9 -f "dart test test/" 2>/dev/null || true
    pkill -9 -f "ptyc" 2>/dev/null || true
    exit 1
  fi
  exit $rc
fi

echo "test-core: ok"
