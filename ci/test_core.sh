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

# Hard timeout (seconds). The PTY tests should finish in <5s; IPC/daemon
# tests are faster still. 120s is generous for CI warmup, tiny for a
# hang.
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-120}

# failures-only: print failing tests + a final count, not one line per test.
# Override with TEST_REPORTER=expanded when debugging. (T-242)
REPORTER="${TEST_REPORTER:-failures-only}"

# Run dart test in its own process group so we can kill descendants on
# timeout. `setsid` starts a new session; `timeout --kill-after` SIGKILLs
# after SIGTERM if the test ignores it.
CORE_DIRS="test/ipc test/pty test/daemon test/git test/panes test/files test/editor test/pql"

# Run a `dart test` pass under the hard timeout + process-group kill.
run_pass() {
  if ! timeout --kill-after=5s "${TIMEOUT_SECONDS}s" \
       setsid --wait dart test -r "$REPORTER" "$@" ; then
    rc=$?
    if [[ $rc -eq 124 ]]; then
      echo "test-core: TIMEOUT — killing descendants" >&2
      pkill -9 -f "dart test" 2>/dev/null || true
      exit 1
    fi
    exit $rc
  fi
}

# Some core tests must not share the parallel pool:
#   - pty: spawn real PTYs (posix_openpt + posix_spawn) + a reader isolate;
#     in the parallel pool they contend for fds + CPU and the isolate starves,
#     flaking 'write sends keystrokes to child' (T-292).
#   - serial: spawn real `pql` processes against the shared on-disk
#     `.pql/pql.db`; concurrent invocations contend for the SQLite lock and
#     flake with PqlException(69) (db busy). (T-193, surfaced by the pql 1.10
#     record_id migration.)
# Run both in one --concurrency=1 pass (matching ci/test.sh's serial handling),
# then everything else in parallel.
echo "test-core: dart test (pty + serial; --concurrency=1)  (timeout ${TIMEOUT_SECONDS}s)"
run_pass --concurrency=1 --tags "pty || serial" $CORE_DIRS

echo "test-core: dart test (rest; parallel, excludes pty + serial)  (timeout ${TIMEOUT_SECONDS}s)"
run_pass --exclude-tags "pty || serial" $CORE_DIRS

echo "test-core: ok"
