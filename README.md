# clide

An IDE for Claude Code CLI. Native rendering, terminal-first interaction, pql-powered queries, canvas and graph surfaces. Linux and macOS.

## Architecture

Single Flutter package at the repo root. The app hosts everything in-process: IPC server, subsystem handlers (pane, files, editor, git, pql), and the extension framework. tmux owns Claude session persistence.

- **`lib/`** — all Dart code. Kernel services (theme, i18n, settings, panels, commands, focus), UI widgets, built-in extensions, and the extension contract.
- **`ptyc/`** — small C helper. Spawns a PTY + child and hands the master fd back over `SCM_RIGHTS`. Every pane (shell, tmux, claude, LSP, debug adapter) goes through it.
- **[pql](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.

Claude drives the UI through a `clide` CLI surface (Bash, not MCP). Every CLI subcommand has a UI affordance and every UI action has a CLI equivalent.

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
make test-integration # real app boot integration tests
make build-linux      # flutter build linux
make build-macos      # flutter build macos
make ptyc-build       # build the ptyc PTY-spawn helper
make push-check       # pre-push gate: decisions + core + fast tests
```

## Status

Pre-v2.0 (`2.0.0-dev`). Interaction model and panel system landed. The Python Textual v1.2.0 predecessor is archived under [`legacy/`](legacy/).

Design doc: [`docs/initial-plan.md`](docs/initial-plan.md). Architectural decisions: [`decisions/`](decisions/).

## License

MIT. See [`LICENSE`](LICENSE).
