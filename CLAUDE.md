# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What clide is

An IDE for Claude Code CLI. Single Flutter package at the repo root.

- **`lib/`** — all Dart code. Subsystem handlers (`lib/src/daemon/`, `lib/src/pty/`, `lib/src/ipc/`, `lib/src/git/`, `lib/src/pql/`), kernel services (`lib/kernel/`), UI widgets (`lib/widgets/`), built-in extensions (`lib/builtin/`), and the extension framework (`lib/extension/`). The Flutter app hosts the IPC server in-process (D-56). PTY spawning uses Dart FFI `posix_openpt()` + `posix_spawn()` directly.
- **[`pql`](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.

tmux owns Claude session persistence (D-41) — the app re-attaches on restart via `tmux new-session -A`. Native rendering — markdown, canvas, graph — is Dart/Flutter (`CustomPaint` + widgets), not third-party packages.

Design doc: [`docs/initial-plan.md`](docs/initial-plan.md). Decisions: [`governance/`](governance/) (`D-NNN` confirmed, `Q-NNN` open, `R-NNN` rejected — see [`governance/README.md`](governance/README.md)). Python Textual predecessor under [`legacy/`](legacy/).

## Guardrails

These are load-bearing. Violating any means the design is wrong, not the rule.

- **Flutter desktop is the host. No Electron, ever.** Web target may work as a happy accident — don't compromise desktop fidelity for it. If we ship a web build at all, prefer Flutter's **WebAssembly (CanvasKit/Skwasm) compile** over the JS/HTML renderer. `xterm.dart` is the terminal renderer; markdown, canvas, graph are custom `CustomPaint`/widget components.
- **Single process.** The Flutter app hosts everything in-process: IPC server, subsystem handlers (pane, files, editor, git, pql), extensions. No separate daemon binary (D-56 dissolved it).
- **CLI-first, not MCP.** Claude talks via Bash (`clide ...`), matching pql's contract. See [`D-1`](governance/decisions/architecture.md#d-1-cli-first-not-mcp).
- **Dart is the core; pql fills the query gap.** PTY spawning is native Dart FFI (`posix_openpt` + `posix_spawn`). `pql` (Go) handles vault queries. No second "core language." See [`D-5`](governance/decisions/architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer) (amended by D-56).
- **Own the rendering stack.** PTY (via Dart FFI), markdown renderer, graph, canvas — all clide-owned, not pulled from opinionated packages.
- **User/Claude parity.** Every CLI subcommand has a UI affordance, and every UI action has a CLI. See [`D-6`](governance/decisions/architecture.md#d-6-cli-and-event-surface-contract).
- **pql: wrap, don't duplicate.** Pql logic only lives in `lib/src/pql/` (pure shell-outs). Clide owns pql's `ignore_files:` config key; it never touches pql's `.pql/` index/cache data. See [`D-3`](governance/decisions/architecture.md#d-3-pql-as-supporter-tool-clide-wraps-never-duplicates).
- **Repo-is-the-workspace.** The git repo root is the workspace — no parallel "vault" concept.
- **Ignore discipline.** Single knob: `ignore_files:` in `.pql/config.yaml`, ordered layering. See [`D-4`](governance/decisions/architecture.md#d-4-ignore-file-strategy).
- **Decision discipline.** All architectural choices live in `governance/decisions/<domain>.md` as `D-NNN` records. Open questions as `Q-NNN` under `governance/questions/<domain>.md`. Rejected alternatives as `R-NNN` under `governance/rejected/<domain>.md`. Claim new IDs via `pql decisions claim D <domain> "title"`. See [`governance/README.md`](governance/README.md).
- **No pre-existing excuse.** Solo-dev repo — every failure encountered is yours to fix, regardless of who introduced it. If `make test` is red, a golden is broken, or `flutter analyze` shows a warning when you start working, the order is: **fix it first, then your work**. If you genuinely can't fix it in scope (separate ticket, large sweep, missing context), stop and surface it before continuing — don't push on top of broken state. "It was already broken" is not a reason to add more on top.

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
native/                  # Vendored native libs (libtree-sitter.so, dugite)
governance/              # D/Q/R records (decisions/, questions/, rejected/ subdirs)
docs/                    # Design docs, wireframes
legacy/                  # Python Textual clide v1.2 (frozen)
```

## Dependencies & supply chain

- **Prefer-zero-deps.** Flutter-SDK widgets first; third-party packages need justification. What stays is exact-pinned in `pubspec.yaml` (no caret ranges). Advisories reviewed before every bump; `pubspec.lock` committed.
- **Document every bundled dependency.** Listed in [`assets/licenses.yaml`](assets/licenses.yaml) with name, kind, version, homepage, license, and purpose. Adding a dep is a two-step commit: add the artefact **and** the `licenses.yaml` entry. See [`D-42`](governance/decisions/tooling.md#d-42-bundled-dependencies-documented-in-licensesyaml).
- **Native deps (dugite, libtree-sitter):** vendored in `native/`, pinned by SHA. Bumps follow the same advisory-review + `licenses.yaml` rule.

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
make push-check      # pre-push gate: decisions + core + fast tests + a11y
make hooks           # install the repo's git hooks (one-time setup)
make clean           # remove build artefacts
```

One-time setup on a fresh clone: `make hooks && flutter pub get` once Flutter is installed.

## Git workflow

Commit and push directly to `main` for routine work — this is a solo-dev repo and does not use a branch-first / feature-branch flow. Do **not** create a working branch just to land a change. (This overrides the generic "branch before committing on the default branch" assistant default.) The usual safety rules still hold: never `--no-verify`, never force-push `main`, and let the pre-push gate run.

## Changelog discipline

[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Every user-visible commit adds an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). Cutting a release means moving Unreleased entries under a new dated version heading **and** bumping `pubspec.yaml` `version:` in the same commit — see [`.claude/skills/git-commit/SKILL.md`](.claude/skills/git-commit/SKILL.md) for the full rule.

## Open questions

Open questions live under [`governance/questions/`](governance/questions/).
