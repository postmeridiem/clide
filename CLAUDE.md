# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What clide is

A Flutter desktop IDE for Claude Code. Single Flutter package at the repo root, plus small native supporter tools where Dart can't reach.

- **`lib/`** — all Dart code. Subsystem handlers (`lib/src/daemon/`, `lib/src/pty/`, `lib/src/ipc/`, `lib/src/git/`, `lib/src/pql/`), kernel services (`lib/kernel/`), UI widgets (`lib/widgets/`), built-in extensions (`lib/builtin/`), and the extension framework (`lib/extension/`). The Flutter app hosts the IPC server in-process (D-056).
- **[`pql`](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.
- **`ptyc/`** — small C supporter tool, peer of pql. Spawns a PTY + child and hands the master fd back over `SCM_RIGHTS`. Clide shells out to it for every pane (shell, tmux, claude, LSP, debug adapter).

tmux owns Claude session persistence (D-041) — the app re-attaches on restart via `tmux new-session -A`. Native rendering — markdown, canvas, graph — is Dart/Flutter (`CustomPaint` + widgets), not third-party packages.

Design doc: [`docs/initial-plan.md`](docs/initial-plan.md). Decisions: [`decisions/`](decisions/) (`D-NNN` confirmed, `Q-NNN` open, `R-NNN` rejected — see [`decisions/README.md`](decisions/README.md)). Python Textual predecessor under [`legacy/`](legacy/).

## Guardrails

These are load-bearing. Violating any means the design is wrong, not the rule.

- **Flutter desktop is the host. No Electron, ever.** Web target may work as a happy accident — don't compromise desktop fidelity for it. If we ship a web build at all, prefer Flutter's **WebAssembly (CanvasKit/Skwasm) compile** over the JS/HTML renderer. `xterm.dart` is the terminal renderer; markdown, canvas, graph are custom `CustomPaint`/widget components.
- **Single process.** The Flutter app hosts everything in-process: IPC server, subsystem handlers (pane, files, editor, git, pql), extensions. No separate daemon binary (D-056 dissolved it). The CLI surface for Claude is a thin C client (ptyc peer).
- **CLI-first, not MCP.** Claude talks via Bash (`clide ...`), matching pql's contract. See [`D-001`](decisions/architecture.md#d-001-cli-first-not-mcp).
- **Dart is the core; native supporter tools fill specific gaps.** `ptyc` (C) for PTY spawning. `pql` (Go) for queries. No second "core language." See [`D-005`](decisions/architecture.md#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer) (amended by D-056).
- **Own the rendering stack.** PTY (via `ptyc`), markdown renderer, graph, canvas — all clide-owned, not pulled from opinionated packages.
- **User/Claude parity.** Every CLI subcommand has a UI affordance, and every UI action has a CLI. See [`D-006`](decisions/architecture.md#d-006-cli-and-event-surface-contract).
- **pql: wrap, don't duplicate.** Pql logic only lives in `lib/src/pql/` (pure shell-outs). Clide owns pql's `ignore_files:` config key; it never touches pql's `.pql/` index/cache data. See [`D-003`](decisions/architecture.md#d-003-pql-as-supporter-tool-clide-wraps-never-duplicates).
- **Repo-is-the-workspace.** The git repo root is the workspace — no parallel "vault" concept.
- **Ignore discipline.** Single knob: `ignore_files:` in `.pql/config.yaml`, ordered layering. See [`D-004`](decisions/architecture.md#d-004-ignore-file-strategy).
- **Decision discipline.** All architectural choices live in `decisions/<domain>.md` as `D-NNN` records. Open questions as `Q-NNN`. Rejected alternatives as `R-NNN`. Claim new IDs via `pql decisions claim D <domain> "title"`. See [`decisions/README.md`](decisions/README.md).

## Repo layout

```
lib/
  main.dart              # Flutter app entry point
  app.dart               # Root layout, workspace, panels
  clide.dart             # Barrel: shared types (IPC envelope, pane kinds, etc.)
  src/                   # Core subsystems (IPC server, PTY, git, files, pql, panes, editor)
  kernel/                # Kernel services (theme, i18n, settings, panels, commands, focus)
  builtin/               # Built-in extensions (claude, editor, files, git, terminal, etc.)
  widgets/               # Custom widget primitives (no Material/Cupertino)
  extension/             # Extension contract and registration
  lua/                   # Lua runtime support (Tier 6)
test/                    # All tests (core subsystems + widgets + goldens + a11y)
assets/                  # Fonts, themes, grammars, licenses, logo
linux/, macos/, web/     # Flutter platform directories
ptyc/                    # C PTY helper
native/                  # Vendored native libs (libtree-sitter.so)
decisions/               # D/Q/R records
docs/                    # Design docs, wireframes
legacy/                  # Python Textual clide v1.2 (frozen)
```

## Dependencies & supply chain

- **Prefer-zero-deps.** Flutter-SDK widgets first; third-party packages need justification. What stays is exact-pinned in `pubspec.yaml` (no caret ranges). Advisories reviewed before every bump; `pubspec.lock` committed.
- **Document every bundled dependency.** Listed in [`assets/licenses.yaml`](assets/licenses.yaml) with name, kind, version, homepage, license, and purpose. Adding a dep is a two-step commit: add the artefact **and** the `licenses.yaml` entry. See [`D-042`](decisions/tooling.md#d-042-bundled-dependencies-documented-in-licensesyaml).
- **`ptyc` and any future native supporter tool:** no dep graph by design (libc-only for `ptyc`). "Audit" is reading the source before each bump.

## Commands

```
make run             # launch Flutter desktop app
make analyze         # flutter analyze
make format          # dart format --set-exit-if-changed
make test            # fast test suite (analyze + format + unit + widget + golden)
make test-core       # core subsystem tests (IPC, PTY, git, pane registry)
make test-a11y       # accessibility contract tests
make test-integration# real app boot integration tests
make build-linux     # flutter build linux
make build-macos     # flutter build macos
make ptyc-build      # build the ptyc PTY-spawn helper
make push-check      # pre-push gate: decisions + core + fast tests + a11y
make hooks           # install the repo's git hooks (one-time setup)
make clean           # remove build artefacts
```

One-time setup on a fresh clone: `make hooks && flutter pub get` once Flutter is installed.

## Changelog discipline

[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Every user-visible commit adds an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). Cutting a release means moving Unreleased entries under a new dated version heading **and** bumping `project.yaml` `version:` in the same commit — see [`.claude/skills/git-commit/SKILL.md`](.claude/skills/git-commit/SKILL.md) for the full rule.

## Open questions

Open questions live under [`decisions/questions-*.md`](decisions/questions.md).
