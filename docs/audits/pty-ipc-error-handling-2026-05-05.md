# PTY + IPC error-handling audit

Date: 2026-05-05
Ticket: T-18
Decision ref: D-5

Punch list of error-handling issues in `lib/src/pty/`, `lib/src/ipc/`,
and `lib/src/daemon/`. Severity-ranked. Each item references the
follow-up ticket where the fix lands.

## Critical — silent failures, leaks, races

1. **`lib/src/pty/native_pty.dart:155-158`** — `forkpty()` failure
   throws `StateError('forkpty() failed')` with no errno. Caller
   can't distinguish ENOMEM/EAGAIN/ENOENT-of-/dev/ptmx. Capture
   errno before `_freeAll` (which may trample it) and surface via
   `PtyException`. → T-75

2. **`lib/src/pty/native_pty.dart:160-165`** — Child process: `chdir`
   and `execve` returns are ignored. If `execve` returns (i.e.
   fails), we fall through to `_exit(1)` with no diagnostic. Write
   a one-line error envelope to fd 1 before exiting so the parent's
   reader sees "exec failed: ENOENT" instead of immediate EOF. → T-75

3. **`lib/src/pty/native_pty.dart:244-251`** — `write()` ignores
   `_nativeWrite` return. Short writes silently drop bytes; -1/EPIPE
   reported as successful "wrote -1". Loop until full length is
   written or surface errno on negative returns. → T-75

4. **`lib/src/pty/native_pty.dart:259-262`** — `resize()` ignores
   `_ioctl` and `_nativeKill` return values. EBADF on a half-closed
   fd silently no-ops. Set `_dead = true` on EBADF. → T-75

5. **`lib/src/pty/native_pty.dart:198-210`** — Race: `_spawnReader`
   is `async` but `NativePty.start` returns immediately. `close()`
   racing with isolate spawn can leave the isolate orphaned. Make
   `start` await reader spawn or track the spawn-future. → T-76

6. **`lib/src/pty/native_pty.dart:280-290`** — `close()` sets
   `_dead = true` *before* `_nativeClose(_fd)`, but the reader
   isolate continues polling on `_fd`. If a new fd reuses that
   number, the reader's `poll` may briefly target the wrong file.
   Send shutdown signal via SendPort or self-pipe before closing. → T-76

7. **`lib/src/pty/session.dart:135-153`** — Resource leak: if
   `_recvFdAsync`, `setWinsize`, `proc.stdout.first.timeout`, or
   `_extractPid` throws, the spawned ptyc Process and (in some
   cases) the received `masterFd` leak. Only line 151 closes
   `masterFd`. Wrap post-spawn block in try/catch that kills `proc`,
   closes `masterFd`, and rethrows. → T-76

8. **`lib/src/pty/session.dart:240`** — `_recvFdAsync`: if
   `Isolate.spawn` itself throws, `port` is leaked. Wrap in
   try/catch. → T-76

9. **`lib/src/pty/session.dart:165-176`** — `write()` returns raw
   `libc.write` result without checking < 0 / errno or looping for
   short writes. Same as #3. → T-75

10. **`lib/src/pty/session.dart:271-275`** — `Isolate.spawn(...).then(...)`
    is fire-and-forget. If spawn fails, the error is silently
    swallowed and `_readerIsolate` remains null forever. Add
    `.catchError` or await it. → T-76

11. **`lib/src/ipc/server.dart:30-39`** — `broadcast()` `try/catch (_)`
    swallows write errors with no logging. At least log the kind. → T-77

12. **`lib/src/ipc/server.dart:107`** — `client.writeln(resp.encode())`
    is not awaited and not guarded. If client disconnected mid-dispatch,
    this throws asynchronously with no `onError` handler. Wrap in
    try/catch and remove the client from `_clients`. → T-77

13. **`lib/src/ipc/server.dart:83-108`** — `_handleLine` runs
    `await dispatch(msg)` with no per-request timeout. A misbehaving
    handler blocks the connection's read pipeline indefinitely. → T-77

14. **`lib/src/ipc/server.dart:46-50`** — Stale-socket retry deletes
    the socket file unconditionally on `SocketException`. If two
    daemon instances race to start, the second rips the first's live
    socket out from under it. Try `connect()` first; refuse if a
    live daemon answers. → T-77

## High — degraded UX / debugging

15. **`lib/src/daemon/pane_commands.dart:87-96`** — `_spawn`
    catch-all flattens every failure into `tool_error: pane.spawn
    failed: <toString>`. "binary not found", "permission denied",
    "out of pty fds" all look the same. Map `PtyException.errno`
    (ENOENT/EACCES/EMFILE) to distinct hints/codes. → T-79

16. **`lib/src/daemon/editor_commands.dart:67-76`** — Same pattern;
    `editor.open` catch-all loses FileSystemException distinctions
    (ENOENT vs EACCES vs EISDIR). → T-79

17. **`lib/src/daemon/files_commands.dart:78`** — `file.readAsStringSync()`
    is unguarded; UTF-8 errors, permission errors, races with deletion
    turn into a 500-style dispatch error instead of a clean
    `IpcResponse.err`. Wrap in try/catch. → T-81

18. **`lib/src/daemon/files_commands.dart:74`** — Path is concatenated
    with `/` and never validated. `path: "../../../etc/passwd"`
    traverses out of `files.root`. Resolve and verify the resulting
    path stays under `root.absolute.path`. → T-78 (security)

19. **`lib/src/pty/session.dart:201-234`** — `close()` distinguishes
    EOF/EBADF/EIO only in comments. The 500ms timeout is silent
    (`onTimeout: () {}`). Log the timeout so we know when SIGKILL
    was actually needed. → T-81

20. **`lib/src/pty/session.dart:390-394`** — Reader isolate treats
    any negative read return that isn't EINTR as EOF — including
    transient EAGAIN or recoverable EIO. Inspect errno and log
    non-EBADF/EIO/0 cases. → T-81

21. **`lib/src/pty/ffi/scm_rights.dart:115-116`** — Returned cmsg-data
    fd is read without sanity-checking against `msgControllen`. A
    malformed peer that sends only a partial cmsg could let us read
    garbage as an fd. Verify `dataOffset + 4 <= msgControllen`
    before deref. → T-81

22. **`lib/src/ipc/server.dart:41-56`** — `start()` logs to
    `stderr.writeln` but the rest of the daemon uses no logger. In
    the Flutter-host process stderr is often consumed by the engine.
    Standardize on a logger. → T-80

## Medium — cleanliness

23. **`lib/src/pty/session.dart:390`, `native_pty.dart:262, 285`** —
    Magic errno/signal numbers (`4=EINTR`, `9=SIGKILL`, `28=SIGWINCH`,
    `_kSighup=1`). Pull into named constants. → T-80

24. **`lib/src/pty/ffi/libc.dart:232-245`** — `errno` getter does a
    `lookupFunction` on every access (catching ArgumentError every
    call on macOS). Cache the resolved function pointer. → T-80

25. **`lib/src/daemon/git_commands.dart:283`** — `_gitError` always
    reports `tool_error`. A `git push` rejection or merge conflict is
    user-actionable, not a tool failure; could map to
    `IpcExitCode.conflict` when stderr matches known patterns. → T-81

26. **`lib/src/ipc/server.dart:97`** — Dispatch error shows
    `dispatch failed: $e` (full exception toString). Trim and add
    the request `cmd` for log correlation. → T-80

27. **`lib/src/daemon/pane_commands.dart:136`** — `registry.write(id, bytes)`
    return value `n` is shown to caller, but if `n == -1` (write failed)
    we still respond `ok`. Distinguish. → T-81

28. **`lib/src/ipc/envelope.dart:88-94`** — `IpcResponse.fromJson`
    throws `TypeError` if `ok=false` but `error` is missing. No
    graceful degradation for a malformed peer response. → T-81

29. **`lib/src/pty/native_pty.dart:111-119`** — PATH resolution
    silently uses the first existing match without checking `X_OK`.
    A non-executable file shadows a valid binary further along PATH. → T-81
