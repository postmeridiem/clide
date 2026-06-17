# clide

An IDE for Claude Code CLI. Native rendering, terminal-first interaction, pql-powered queries, canvas and graph surfaces. Linux and macOS.

## Architecture

Single Flutter package at the repo root. The app hosts everything in-process: IPC server, subsystem handlers (pane, files, editor, git, pql), and the extension framework. Claude session persistence is `--resume <session-id>` against Claude Code's transcript files (D-77, superseding the tmux-backed D-41).

- **`lib/`** — all Dart code. Core subsystems (`lib/src/`), kernel services (`lib/kernel/`), UI widgets (`lib/widgets/`), built-in extensions (`lib/builtin/`), the extension framework (`lib/extension/`).
- **PTY** — `lib/src/pty/` spawns child processes via Dart FFI `posix_openpt()` + `posix_spawn()` directly; no external helper binary.
- **`native/`** — vendored native libraries (`libtree-sitter.so` with wasmtime embedded). Linux only today.
- **[pql](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.

Claude drives the UI through a `clide` CLI surface (Bash, not MCP). Every CLI subcommand has a UI affordance and every UI action has a CLI equivalent (D-6).

## Built-in extensions

canvas, claude, claude_control, cli_install, decisions, deeplink, default_layout, diff, editor, extensions_ui, files, git, grammars_core, graph, ipc_status, keybindings_ui, markdown, menubar, output, pql, problems, search, settings_ui, terminal, theme_picker, tickets, todos, view, vim, welcome.

## Building

Requires Flutter (stable channel) and [pql](https://github.com/postmeridiem/pql)
on the host. pql is a hard dependency — the pre-push gate runs `pql decisions
validate` and the governance + ticket workflow is built on it (see its repo for
install). One-time setup:

```
make hooks && flutter pub get
pql init                 # once, in the repo root — wires up the pql skill + perms
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

Active development; the interaction model, panel system, and settings engine have landed. The Python Textual predecessor is archived under [`legacy/`](https://github.com/postmeridiem/clide/tree/main/legacy).

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — current architecture (read this first).
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to clone, build, test, file tickets, and write D-records.
- [`docs/initial-plan.md`](docs/initial-plan.md) — historical design doc; preserved as a snapshot of the 2026-04 plan, much of it now superseded.
- [`governance/decisions/`](governance/decisions/) — confirmed decisions (`D-NNN`), open questions (`Q-NNN`), rejected alternatives (`R-NNN`).
- [`CLAUDE.md`](CLAUDE.md) — Claude-addressed working notes (guardrails, repo layout).

## License

MIT. See [`LICENSE`](LICENSE).
