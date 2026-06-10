#!/usr/bin/env bash
# ci/test_core.sh — run the Flutter-free core Dart tests.
#
# Covers `test/` at the repo root (IPC, daemon, PTY, git, panes, files,
# editor, pql). Each pass runs under `dart test --timeout` so a hanging
# test (typically one holding a native fd open) fails fast instead of
# wedging CI or the pre-push gate — the same portable mechanism ci/test.sh
# uses for the Flutter suite. No external `timeout`/`setsid` wrapper: those
# are GNU coreutils and absent on macOS, where their failure silently
# skipped the whole suite.
#
# Rationale: D-030 makes tests client-side only; a hang here is always
# local — either a real bug or a bad test. Either way we'd rather fail
# loudly at the per-test timeout than block a pre-push indefinitely.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

if ! command -v dart >/dev/null; then
  echo "test-core: dart not on PATH; is Flutter installed?" >&2
  exit 2
fi

# Per-test hard timeout. The PTY tests should finish in <5s; IPC/daemon
# tests are faster still. 60s is generous for CI warmup, tiny for a hang.
# Matches ci/test.sh's --timeout 60s.
TEST_TIMEOUT="${TEST_TIMEOUT:-60s}"

# failures-only: print failing tests + a final count, not one line per test.
# Override with TEST_REPORTER=expanded when debugging. (T-242)
REPORTER="${TEST_REPORTER:-failures-only}"

CORE_DIRS="test/ipc test/pty test/daemon test/git test/panes test/files test/editor test/pql"

# Run a `dart test` pass under the per-test timeout. set -e propagates a
# failing pass (including a --timeout-induced failure) with dart's exit code.
run_pass() {
  dart test -r "$REPORTER" --timeout "$TEST_TIMEOUT" "$@"
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
echo "test-core: dart test (pty + serial; --concurrency=1)  (timeout ${TEST_TIMEOUT})"
run_pass --concurrency=1 --tags "pty || serial" $CORE_DIRS

echo "test-core: dart test (rest; parallel, excludes pty + serial)  (timeout ${TEST_TIMEOUT})"
run_pass --exclude-tags "pty || serial" $CORE_DIRS

echo "test-core: ok"
