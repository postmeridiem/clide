# ptyc

Small POSIX helper that spawns a child process under a PTY and hands
the master fd back to its caller. Language-agnostic; usable from any
program that can fork a subprocess and receive a file descriptor over a
unix socket.

Clide uses it for every PTY it owns (terminal panes, Claude sessions,
tmux wrappers, LSP servers, debug adapters). See
[`D-005`](../decisions/architecture.md#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer)
for the architectural rationale; ptyc is a peer of
[`pql`](https://github.com/postmeridiem/pql), not a clide subsystem.

## Build

```sh
make           # produces bin/ptyc
make test      # runs test_ptyc.sh against the built binary
make clean
```

No third-party dependencies. `CC`, `CFLAGS`, and `LDFLAGS` are
overrideable in the usual way.

## Wire contract

ptyc is a one-shot helper. The caller:

1. Creates a `socketpair(AF_UNIX, SOCK_STREAM, 0)`.
2. Launches `ptyc` as a subprocess, passing one end of the socket to
   the child as **file descriptor 3** (the default) or whatever fd is
   given in the `PTYC_SOCK_FD` environment variable. The other end of
   the socket stays with the caller. The env-var override exists
   because some language runtimes (Python's `subprocess` with
   `stdout=PIPE`, for example) shuffle their own pipe fds through the
   low numbers and it's cheaper for the caller to pick a higher fd
   than to dup2 it down.
3. Writes the request as **JSON on stdin** and closes stdin (EOF
   signals end of request).
4. Receives the master PTY fd over the socket via **`SCM_RIGHTS`**
   ancillary data (with a single-byte `'x'` payload so the receiver
   knows when to `recvmsg`).
5. Reads the success response from stdout (single line of JSON) and
   reaps the exited `ptyc` process.

### Request

JSON object on stdin. All fields optional except `argv`.

```json
{
  "argv": ["bash", "-l"],
  "cwd": "/home/me/work",
  "env": {"TERM": "xterm-256color", "LANG": "en_US.UTF-8"},
  "cols": 80,
  "rows": 24
}
```

- `argv` — required, non-empty array of strings. `argv[0]` is resolved
  via `PATH`.
- `cwd` — optional. If omitted, the child inherits ptyc's cwd.
- `env` — optional object. If present, the child's environment is
  **replaced** with exactly the keys given (ptyc does `clearenv()` and
  then `putenv` per entry). If absent, the child inherits ptyc's
  environment. This is a deliberate choice: the daemon is expected to
  build the env it wants, not rely on a merge.
- `cols`, `rows` — optional. Default `80` × `24`. Applied via
  `TIOCSWINSZ` before fork.

### Success response (stdout)

```json
{"ok":true,"pid":12345}
```

One line, trailing newline. The master PTY fd is already on the socket
by the time stdout is written. `pid` is the spawned child's PID — the
caller is responsible for `waitpid`'ing it when appropriate.

### Error response (stderr)

```json
{"ok":false,"error":"exec: No such file or directory","errno":2}
```

Written on stderr. No fd is sent. ptyc exits with a non-zero code.

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success — fd sent, success response on stdout. |
| `1`  | Bad request — JSON parse error, missing `argv`, bad field values. |
| `2`  | Syscall failed — fork, exec, PTY open, `sendmsg`, etc. Check `errno` in the response. |

## Limits

Compile-time caps, deliberately small:

- `MAX_ARGV`    = 64 entries
- `MAX_ENV`     = 256 entries
- `MAX_INPUT`   = 64 KiB request size

These are far above what any reasonable pane invocation needs; if you
hit them you're holding ptyc wrong. Edit the `#define`s in `ptyc.c` and
rebuild.

## Security notes

- The JSON parser is scoped to the shape above. It rejects anything
  else. Strings support the standard `\"` `\\` `\/` `\b` `\f` `\n`
  `\r` `\t` escapes and ASCII-range `\uXXXX`. Non-ASCII Unicode escapes
  (and surrogate pairs) are rejected — the daemon is expected to emit
  raw UTF-8 bytes.
- Input is trusted (daemon is local, same user). ptyc does not sanitise
  argv or env beyond format-level checks — if the daemon asks ptyc to
  exec `rm`, ptyc execs `rm`.
- ptyc does not `setuid` or `setgid`. It runs as the invoking user.

## Session persistence

ptyc is stateless and one-shot. Session persistence (survive app
restart) is the **caller's** concern. Clide achieves it by spawning
ptyc with `tmux new-session -A -s <name> -- <cmd>` for Claude panes;
tmux handles the persistence layer and ptyc just spawns tmux. See
`D-041` (Claude panes — one primary per repo, tmux-backed).
