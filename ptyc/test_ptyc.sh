#!/usr/bin/env bash
# Smoke test for ptyc. Uses python3 for the SCM_RIGHTS fd receive dance.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/bin/ptyc"

if [[ ! -x "$BIN" ]]; then
  echo "test: bin/ptyc not built — run 'make' first" >&2
  exit 2
fi

python3 - "$BIN" <<'PY'
import errno
import json
import os
import socket
import subprocess
import sys
import time

ptyc = sys.argv[1]


def spawn(req):
    """Launch ptyc, pipe the request in, receive fd + response."""
    sock_parent, sock_child = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
    child_fd = sock_child.fileno()
    env = {**os.environ, "PTYC_SOCK_FD": str(child_fd)}
    try:
        p = subprocess.Popen(
            [ptyc],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            pass_fds=(child_fd,),
            env=env,
        )
    finally:
        sock_child.close()

    p.stdin.write(json.dumps(req).encode())
    p.stdin.close()

    fd = None
    try:
        msg, ancdata, _flags, _addr = sock_parent.recvmsg(1, socket.CMSG_SPACE(4))
        for cmsg_level, cmsg_type, cmsg_data in ancdata:
            if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                fd = int.from_bytes(cmsg_data[:4], "little")
                break
    except OSError:
        pass
    sock_parent.close()

    stdout = p.stdout.read().decode()
    stderr = p.stderr.read().decode()
    code = p.wait()
    return code, stdout, stderr, fd


def expect_ok(req, reads_substr=None):
    code, out, err, fd = spawn(req)
    assert code == 0, f"exit={code}, stderr={err!r}"
    j = json.loads(out)
    assert j["ok"] is True, out
    assert j["pid"] > 0, out
    assert fd is not None and fd >= 0, "no fd received"
    pid = j["pid"]
    try:
        if reads_substr is not None:
            chunks = []
            deadline = time.time() + 5.0
            while time.time() < deadline:
                try:
                    data = os.read(fd, 4096)
                except OSError as e:
                    if e.errno in (errno.EIO,):  # child exited, PTY EOF on Linux
                        break
                    raise
                if not data:
                    break
                chunks.append(data.decode(errors="replace"))
                if reads_substr in "".join(chunks):
                    break
            got = "".join(chunks)
            assert reads_substr in got, f"expected {reads_substr!r} in {got!r}"
    finally:
        os.close(fd)
        # Child should exit on its own after producing its output for an
        # `echo`; give it a moment, then reap.
        try:
            for _ in range(20):
                rpid, _ = os.waitpid(pid, os.WNOHANG)
                if rpid == pid:
                    break
                time.sleep(0.05)
            else:
                os.kill(pid, 9)
                os.waitpid(pid, 0)
        except ChildProcessError:
            pass


def expect_err(req, match_fragment):
    code, out, err, fd = spawn(req)
    assert code != 0, f"expected failure, got ok: {out!r}"
    assert fd is None, "error path must not send an fd"
    j = json.loads(err)
    assert j["ok"] is False, err
    assert match_fragment in j["error"], f"{match_fragment!r} not in {j['error']!r}"


# 1. Happy path: echo prints and exits cleanly.
expect_ok({"argv": ["/bin/echo", "hello-ptyc"]}, reads_substr="hello-ptyc")

# 2. env replacement works — child sees exactly the keys we pass.
expect_ok(
    {"argv": ["/usr/bin/env"], "env": {"FOO": "bar", "PATH": "/usr/bin:/bin"}},
    reads_substr="FOO=bar",
)

# 3. cwd respected.
expect_ok({"argv": ["/bin/sh", "-c", "pwd"], "cwd": "/tmp"}, reads_substr="/tmp")

# 4. window size propagates (stty reports it).
expect_ok(
    {"argv": ["/bin/sh", "-c", "stty size"], "cols": 132, "rows": 42},
    reads_substr="42 132",
)

# 5. Bad request: missing argv.
expect_err({}, "argv is required")

# 6. Bad request: argv not an array.
expect_err({"argv": "bash"}, "argv must be an array")

# 7. exec failure reported on error channel.
expect_err({"argv": ["/does/not/exist/nope"]}, "execvp")

# 8. Unknown key rejected.
expect_err({"argv": ["true"], "wat": 1}, "unknown key")

print("ptyc: all smoke tests passed")
PY
