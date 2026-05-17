# clide

An IDE for Claude Code CLI. Native rendering, terminal-first interaction, pql-powered queries, canvas and graph surfaces. Linux and macOS.

## Architecture

Single Flutter package at the repo root. The app hosts everything in-process: IPC server, subsystem handlers (pane, files, editor, git, pql), and the extension framework. tmux owns Claude session persistence (D-41).

- **`lib/`** — all Dart code. Core subsystems (`lib/src/`), kernel services (`lib/kernel/`), UI widgets (`lib/widgets/`), built-in extensions (`lib/builtin/`), the extension framework (`lib/extension/`).
- **PTY** — `lib/src/pty/` spawns child processes via Dart FFI `posix_openpt()` + `posix_spawn()` directly; no external helper binary.
- **`native/`** — vendored native libraries (`libtree-sitter.so` with wasmtime embedded). Linux only today.
- **[pql](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.

Claude drives the UI through a `clide` CLI surface (Bash, not MCP). Every CLI subcommand has a UI affordance and every UI action has a CLI equivalent (D-6).

## Built-in extensions

canvas, claude, claude_control, decisions, diff, editor, extensions_ui, files, git, graph, grammars_core, ipc_status, keybindings_ui, markdown, pql, problems, settings_ui, terminal, theme_picker, tickets, todos, welcome.

## Building

Requires Flutter (stable channel) on the host. One-time setup:

```
make hooks && flutter pub get
```

Then:

```
make run              # launch the desktop app
make test             # fast suite: analyze + format + unit + widget + golden
make test-core        # core subsystem tests (IPC, PTY, git, pane registry)
make test-a11y        # accessibility contract tests
make test-integration # real app boot integration tests
make build-linux      # flutter build linux
make build-macos      # flutter build macos
make push-check       # pre-push gate: decisions + core + fast + a11y + coverage + changelog
```

## Status

Pre-v2.0 (`2.0.0-dev`). Interaction model and panel system landed. The Python Textual v1.2.0 predecessor is archived under [`legacy/`](https://github.com/postmeridiem/clide/tree/main/legacy).

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — current architecture (read this first).
- [`docs/initial-plan.md`](docs/initial-plan.md) — historical design doc; preserved as a snapshot of the 2026-04 plan, much of it now superseded.
- [`governance/decisions/`](governance/decisions/) — confirmed decisions (`D-NNN`), open questions (`Q-NNN`), rejected alternatives (`R-NNN`).
- [`CLAUDE.md`](CLAUDE.md) — Claude-addressed working notes (guardrails, repo layout).

## License

MIT. See [`LICENSE`](LICENSE).
