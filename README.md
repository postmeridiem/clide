# clide

A Flutter desktop IDE for Claude Code. Markdown-first content, pql-powered queries, canvas and graph surfaces, a Go sidecar handling PTYs / subprocesses / git / pql. Claude drives the UI through a `clide` CLI.

Currently pre-v2.0, scaffolding. The north-star design lives in [`docs/initial-plan.md`](docs/initial-plan.md); architectural decisions are captured in [`docs/ADRs/`](docs/ADRs/). The Python Textual v1.2.0 implementation is archived under [`legacy/`](legacy/) for reference.

## Three surfaces, one tool

- **`app/`** — Flutter desktop application (Linux / macOS; Windows is a stretch).
- **`sidecar/`** — Go sidecar/CLI, single binary with two modes: `clide <subcommand>` (one-shot for Claude) and `clide --daemon` (long-running sidecar for the app). Owns PTYs, subprocesses, file watchers, git, pql invocations.
- **[`pql`](https://github.com/postmeridiem/pql)** — external supporter tool. clide wraps it for every query surface; never re-implements it.

## Why the rebuild?

The Python Textual implementation (`legacy/`) proved the pane model but capped at terminal-only rendering. A short-lived experiment (`claudian`, April 2026) explored an Obsidian-plugin approach and was abandoned because Obsidian is Electron, and the user's history with terminal-in-Electron ruled that host out.

Flutter desktop resolves both constraints: native Skia rendering avoids Electron's failure modes, `xterm.dart` gives us a solid terminal surface, and the pane model can be rebuilt natively. The Obsidian ideas worth keeping (canvas, graph) fold in; everything else (vault concept, inline query tables, plugin ecosystem inheritance) doesn't.

## Status

No build yet beyond the repo scaffold. Tier 0 acceptance: sidecar daemon runs, Flutter app connects, empty IDE shell appears with placeholders.

## License

MIT. See [`LICENSE`](LICENSE).
