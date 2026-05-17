# clide — Architecture

Current as of 2026-05-17. Tracks the code on `main`. For the original
design plan (much of it now superseded), see
[`docs/initial-plan.md`](initial-plan.md). For decisions, see
[`governance/decisions/`](../governance/decisions/).

## Shape

clide is a **single Flutter package at the repo root**. There is no
sidecar process, no separate daemon, no Go binary. One `flutter run`
boots the whole IDE.

```
flutter desktop app  (lib/main.dart)
  ├── kernel services (lib/kernel/)        — theme, i18n, settings, panels,
  │                                          commands, focus, scheduler, …
  ├── core subsystems (lib/src/)           — ipc, daemon dispatch, panes,
  │   │                                      pty, editor, files, git, pql
  │   └── PTY via Dart FFI                  posix_openpt + posix_spawn (T-96)
  ├── widget primitives (lib/widgets/)     — ClideButton, ClideText, … no
  │                                          Material/Cupertino
  ├── built-in extensions (lib/builtin/)   — claude, editor, files, git, terminal,
  │                                          welcome, … each a ClideExtension
  └── extension framework (lib/extension/) — contract + dependency-gated activation
```

### Process model

One OS process. The Flutter app hosts:

- the IPC dispatcher (`DaemonDispatcher` in `lib/src/daemon/`),
- every subsystem handler (pane/files/editor/git/pql),
- the extension manager and all built-in extensions.

`tmux` is the only external long-lived process — it owns Claude
session persistence so panes survive app restarts (D-41). The app
re-attaches via `tmux new-session -A` on boot.

PTYs are spawned natively from Dart. `lib/src/pty/native_pty.dart`
calls `posix_openpt()` + `posix_spawn()` via FFI; the child inherits
the slave PTY as stdin/stdout/stderr. No C helper binary.

### Native dependencies

Vendored under [`native/`](../native/) with per-platform subdirectories
(`linux-x64/` today). Currently:

- `libtree-sitter.so` — wasmtime-embedded tree-sitter for syntax
  highlighting. Loaded via `dart:ffi`. See
  `lib/kernel/src/syntax/tree_sitter_ffi.dart`.

Each entry is listed in [`assets/licenses.yaml`](../assets/licenses.yaml)
with version + SHA expectation (D-42).

### External tools

clide shells out to two binaries at runtime:

- **`git`** — vendored as `dugite-native` if present at the install
  directory; otherwise `PATH` `git`. Resolution happens at
  `lib/kernel/src/toolchain_paths.dart`. **Never resolves against the
  open workspace** (T-98).
- **`pql`** — the [pql](https://github.com/postmeridiem/pql) project
  query language; supporter tool, wrapped in `lib/src/pql/`. Clide
  never re-implements pql features (D-3).

## Surfaces

### Claude-facing — `clide` CLI

Per D-1 and D-6, Claude talks to clide exclusively via Bash. Every
state-changing command emits one or more events on a long-lived
event stream; every UI affordance has a matching CLI verb. See D-6
for the subsystem/verb/event contract.

> **Caveat (2026-05):** the Unix-socket server that exposes the
> dispatcher to a thin `clide` C client is currently unimplemented.
> Today's working path is in-process direct dispatch. See **T-99**
> (IPC server implementation) and **D-68** (dual integration surface
> — Bash CLI primary, MCP secondary).

### User-facing — Flutter desktop

Three-column layout (sidebar / workspace / context) with collapsible
panels, a custom title bar, and per-panel "hats" for branding +
window controls. The interaction model is documented in D-47 and
neighboring decisions.

## Subsystems at a glance

| Subsystem | Location | Owns |
|---|---|---|
| IPC envelope + dispatcher | `lib/src/ipc/`, `lib/src/daemon/` | request/response framing, command registration, broadcast events |
| Pane registry | `lib/src/panes/` | spawn/list/write/resize/close, event emission |
| PTY | `lib/src/pty/` | `posix_openpt` + `posix_spawn`, reader isolate, signal forwarding |
| Editor | `lib/src/editor/` | buffer registry, open/save/setContent |
| Files | `lib/src/files/` | ls / read / watch, path-safety containment check |
| Git | `lib/src/git/` | client (no shell), status/diff/operations parsing |
| Pql wrapper | `lib/src/pql/` | shell-out only; never re-implements pql |
| Kernel services | `lib/kernel/src/` | theme, i18n, settings, panels, commands, focus, syntax |
| Extensions | `lib/extension/`, `lib/builtin/` | dependency-gated activation, contribution points |

## Build + test

```
make hooks && flutter pub get   # one-time setup
make run                        # launch app
make test                       # analyze + format + unit + widget + golden
make test-core                  # IPC / PTY / git / pane registry
make test-a11y                  # accessibility contract
make test-integration           # real-app boot tests
make push-check                 # the full pre-push gate
```

The pre-push gate enforces a 95% line-coverage floor (D-66), a
40-word soft / 60-word hard CHANGELOG bullet cap, all unit/widget
tests, and the a11y contract.

## Governance

All architectural choices live in
[`governance/decisions/<domain>.md`](../governance/decisions/) as
`D-NNN` records, open questions as `Q-NNN`, rejected alternatives as
`R-NNN`. Claim new IDs via `pql decisions claim D <domain> "title"`.
The governance index lists everything: [`governance/README.md`](../governance/README.md).

The pql ticket backlog tracks in-flight work; `pql ticket board
--pretty` for the live view.
