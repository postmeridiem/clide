# ADR 0005 — Dart core; sidecar directory dissolved; `ptyc` as pql-peer

**Status:** accepted
**Date:** 2026-04-20
**Supersedes:** [ADR 0002](0002-sidecar-language-go.md)

## Context

ADR 0002 picked Go for the sidecar/CLI on the reasoning that (a) the
heavy work (PTYs, subprocesses, file watchers, git, IPC) belongs in
a language separate from the UI layer, and (b) pql is Go so the
muscle memory transfers. The Flutter app would talk to a Go binary
over a unix socket.

On reassessment, two facts broke that reasoning:

1. **What the "heavy work" actually is.** Stripped of the PTY layer,
   the sidecar is I/O-bound glue around shell-outs (`git`, `claude`,
   `pql`), a unix-socket server, JSON-lines framing, and a process
   table. `dart:io` covers all of this cleanly. The Go-versus-Rust
   debate implicit in 0002 was the wrong axis — the real choice was
   **separate process vs shared language**, and separate-process is
   what matters (session persistence needs the daemon to outlive the
   app), not language.

2. **PTY is the one place Dart is genuinely weak** — and not because
   of ecosystem, but because Dart's multi-threaded VM can't safely
   `fork()`. That single constraint forces a native helper regardless
   of what language wraps it. Once you accept a small native helper,
   the question is whether *everything else* needs to be in that same
   native language. It doesn't.

So the "sidecar" directory stopped carrying weight. It existed to
justify the Go/Dart split. With the split gone, the directory is
ceremony.

## Decision

Three moves.

### 1. Dart is the core language.

Everything that used to live under `sidecar/` — IPC server, CLI
dispatch, process management, file watching, git shell-outs, pql
wrapper — is written in Dart. Two execution modes of one Dart AOT
binary:

- `clide <subcommand>` — one-shot, pql-style. Parses args, connects
  to the running daemon socket, sends a request, prints JSON on
  stdout, exits with the pql exit-code contract.
- `clide --daemon` — long-running. Owns PTYs, subscriptions, file
  watchers, subprocess lifecycles. Started by the app on load;
  survives app restarts so Claude sessions persist.

The Flutter app imports the Dart core as a library for in-process
state (views, widgets, models) *and* connects to the daemon over the
same IPC the CLI uses. One protocol, two clients.

### 2. The sidecar directory dissolves.

```
app/                # Flutter UI (Linux / macOS primary)
lib/                # Dart core shared by app + CLI + daemon:
                    #   ipc/, pty/, proc/, git/, pql/, events/, panes/
bin/clide.dart      # Dart AOT entry: subcommand dispatch + --daemon
tool/                # Dart scripts used by the Makefile
tests/              # integration tests that span app + daemon
```

No `sidecar/`. No Go module. `project.yaml` drops `module:`; the
Dart package name replaces it.

### 3. `ptyc` is a pql-peer supporter tool.

The PTY helper — a small C binary that does `posix_openpt` + `fork`
+ `exec` + fd-passing via `SCM_RIGHTS` — graduates to the same
status as pql: single-purpose, language-appropriate, standalone,
reusable outside Clide. It lives in its own directory (eventually
its own repo) and Clide wraps it the same way it wraps pql. Working
name: **`ptyc`**.

- Clide shells out to `ptyc` to spawn every PTY (terminal pane,
  tmux session, claude, LSP server, debug adapter — all one code
  path).
- `ptyc` writes only what it needs to write (a PTY + forked child)
  and does nothing else. No IPC protocol of its own, no long-running
  state. One-shot per pane.
- Consumers other than Clide (a Python script, another Dart app, a
  Go tool) can use `ptyc` standalone with no Clide dependency.

This mirrors ADR 0003's pql contract: **wrap, don't duplicate**;
supporter tools stay independent and reusable.

## Consequences

- **ADR 0002 is superseded.** Go sidecar removed. Existing
  `sidecar/` contents (Go skeleton — `cmd/clide/`, `internal/*`,
  `go.mod`) are deleted; the ideas it encoded (exit-code contract,
  ldflag-stamped version, JSON diagnostics) are reimplemented in
  Dart. The supersession note stays in 0002 so the history reads
  correctly.
- **One toolchain for the IDE proper.** Flutter + Dart. The C
  toolchain is needed only to build `ptyc` — a tiny, rarely-changing
  artifact.
- **`project.yaml` simplifies.** `module:` and `go_version:` go
  away. A `ptyc_version:` pin joins the existing `dart_sdk:` and
  `flutter_channel:` keys.
- **Supply-chain gates stay, shape changes.** The Go gate
  (`govulncheck`) is removed. The Dart gate stays (advisories review
  + exact-pin `pubspec.yaml`). `ptyc` gets its own tiny gate: it has
  no deps beyond libc, so the review is "read the 150 lines before
  every bump." `make security` becomes `make security` = Dart
  advisories + `ptyc` review checklist.
- **IPC stays.** The daemon / app / CLI split is unchanged — unix
  socket, token auth, JSON-lines. It was never about language.
- **Session persistence stays.** PTY master fds live in the Dart
  daemon process, not the app process. App restart does not kill
  Claude.
- **Pql continues as-is.** Wrapped via shell-out from
  `lib/src/pql/` (the Dart equivalent of the deleted
  `sidecar/internal/pql/`). No protocol change to pql.
- **CLAUDE.md and the Makefile need updates.** Commands, directory
  references, and the "sidecar language: Go" guardrail all shift.
- **Rust remains an escape hatch, not a plan.** If a Dart limit
  later forces a second native helper (file-watching at scale on
  macOS, a tree-sitter host, etc.), the precedent set here is: new
  native need → new supporter tool, peer of pql and `ptyc`. Never a
  second "core language."

## Notes

- **Name: `ptyc`** (pronounced "p-tic"). Three honest readings, all
  pointing at the same tool:
  1. **Project Terminal Controller** — parallel to pql's **Project
     Query Language**. Clide's supporter tools follow a `p*` pattern
     where `p` = *project*: pql handles project queries, ptyc
     handles project terminals. Future supporter tools that fit the
     "small single-purpose peer of pql" slot should follow the same
     pattern when the fit is natural.
  2. **PTY + child** — domain vocabulary (PTY parent/child pair).
     This is what a reader seeing the name on a command line will
     decode it as, and it's exactly what the tool does: run a child
     process under a PTY.
  3. **PTY + C** — the implementation language. Accurate and
     non-limiting; Unix has a long tradition of tools advertising
     their implementation (`gcc`, `libc`, `musl`). If we ever
     rewrote it in another language it would become a new tool with
     a new name, same as pql would if rewritten.

  Crucially, none of the readings tie the **caller** to any
  ecosystem — `ptyc` is usable from Dart, Python, Go, shell,
  anywhere a subprocess can be spawned and a fd can be received.
  Alternatives considered and rejected: `clide-pty-spawn` (too
  clide-specific for a peer tool), `dpty` (already taken on
  crates.io), `ptyspawn` (verbose), `dartmx` (falsely signals
  caller-ecosystem + implies multiplex), `ptyx` (arbitrary suffix,
  no domain reading), `ptyc` as read-only "PTY C" (works but sells
  the name short).
- The helper's wire contract (stdin JSON → stdout JSON + SCM_RIGHTS
  fd transfer) is intentionally small so wrapping it is trivial from
  any language.
- This ADR does not define the Clide CLI / event surface itself —
  that is [ADR 0006](0006-cli-and-event-surface.md).
