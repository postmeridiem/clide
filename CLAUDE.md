# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What clide is

A Flutter desktop IDE for Claude Code. One language (Dart) across the stack, plus small native supporter tools where Dart can't reach.

- **`app/`** — Flutter desktop application (Linux / macOS primary; Windows stretch).
- **`lib/` + `bin/clide.dart`** — Dart core, shared by the app and by one AOT-compiled binary that has two modes: `clide <subcommand>` (one-shot for Claude) and `clide --daemon` (long-running for the app). Owns IPC, PTYs (via `ptyc`), subprocesses, file watchers, git shell-outs, pql invocations.
- **[`pql`](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.
- **`ptyc`** — small C supporter tool, peer of pql. Spawns a PTY + child and hands the master fd back over `SCM_RIGHTS`. Clide shells out to it for every pane (shell, tmux, claude, LSP, debug adapter).

App ↔ daemon ↔ CLI speak a single JSON-lines unix socket protocol. The daemon outlives app restarts so Claude sessions survive reopens. Native rendering — markdown, canvas, graph — is Dart/Flutter (`CustomPaint` + widgets), not third-party packages.

Design doc: [`docs/initial-plan.md`](docs/initial-plan.md). Decisions: [`decisions/`](decisions/) (`D-NNN` confirmed, `Q-NNN` open, `R-NNN` rejected — see [`decisions/README.md`](decisions/README.md)). Python Textual predecessor under [`legacy/`](legacy/).

## Guardrails

These are load-bearing. Violating any means the design is wrong, not the rule.

- **Flutter desktop is the host. No Electron, ever.** Web target may work as a happy accident — don't compromise desktop fidelity for it. If we ship a web build at all, prefer Flutter's **WebAssembly (CanvasKit/Skwasm) compile** over the JS/HTML renderer: it matches the desktop rendering pipeline, keeps our custom `CustomPaint` components pixel-identical, and avoids the DOM-renderer quirks around input handling and terminal-style content. `xterm.dart` is the terminal renderer (Tier 1); markdown, canvas, graph are custom `CustomPaint`/widget components (Tiers 2+, 5).
- **No heavy lifting in the UI layer.** The app renders and handles input; process/PTY/IO lifecycles live in the daemon. The daemon is Dart too — the split is *process boundary*, not language boundary.
- **CLI-first, not MCP.** Claude talks via Bash (`clide ...`), matching pql's contract. See [`D-001`](decisions/architecture.md#d-001-cli-first-not-mcp).
- **Dart is the core; native supporter tools fill specific gaps.** One Dart AOT binary for CLI + daemon. `ptyc` (C) for PTY spawning. `pql` (Go) for queries. No second "core language." See [`D-005`](decisions/architecture.md#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer) (supersedes [`R-002`](decisions/rejected.md#r-002-go-sidecar)).
- **Own the rendering stack.** PTY (via `ptyc`), markdown renderer, graph, canvas — all clide-owned, not pulled from opinionated packages. Third-party rendering is where we'd hit ceilings first; we'd rather pay the cost up front.
- **User/Claude parity.** Every CLI subcommand has a UI affordance in the app, and every UI action has a CLI. Events are symmetric: every UI state change is a subscribable event. See [`D-006`](decisions/architecture.md#d-006-cli-and-event-surface-contract).
- **pql: wrap, don't duplicate, and treat it as a clide subsystem when present.** Pql logic only lives in `lib/src/pql/` (pure shell-outs). Clide owns pql's `ignore_files:` config key; it never touches pql's `.pql/` index/cache data. See [`D-003`](decisions/architecture.md#d-003-pql-as-supporter-tool-clide-wraps-never-duplicates).
- **Repo-is-the-workspace.** The git repo root is the workspace — no parallel "vault" concept. Clide dogfoods against its own repo.
- **Ignore discipline.** Single knob: `ignore_files:` in `.pql/config.yaml`, ordered layering. Default `[.gitignore]`; clide writes `[.gitignore, .clideignore]` when `.clideignore` exists. See [`D-004`](decisions/architecture.md#d-004-ignore-file-strategy).
- **Decision discipline.** All architectural choices live in `decisions/<domain>.md` as `D-NNN` records. Open questions live in `decisions/questions-<domain>.md` as `Q-NNN`. Rejected alternatives live in `decisions/rejected.md` as `R-NNN`. Before an architectural change, read the relevant domain file; before disagreeing with a guardrail, propose an amendment to the underlying `D-NNN` rather than a one-off. Claim new IDs via `pql decisions claim D <domain> "title"`. See [`decisions/README.md`](decisions/README.md).

## Tier ordering (don't skip ahead)

1. **Tier 0** — Flutter app + Dart daemon handshake, empty IDE shell.
2. **Tier 1** — Claude in an `xterm.dart` pane backed by `ptyc`-spawned PTYs; session persists across app restarts.
3. **Tier 2** — Pane model + active-file awareness + `clide open/active/insert/replace-selection/tail`.
4. **Tier 3** — Git panel (staged/unstaged, hunk stage, conflict UI) + diff tab + `clide git …`.
5. **Tier 4** — pql integration: Query panel, file tree, backlinks, problems — all drawing from pql.
6. **Tier 5** — Canvas (`CustomPaint` + `InteractiveViewer`) and graph view.
7. **Tier 6** — Dart extension API, settings, theming, distributable builds.

See `docs/initial-plan.md` for the full tier definitions and acceptance criteria.

## Parent projects

- **`legacy/`** — Python Textual clide v1.2.0. Feature-frozen. Reference for the pane model, panel set, git skills (`/commit`, `/stash`, `/pull`, `/push` — rewire to `clide git …`), TODO.md parsing format.
- **`projects/claudian`** (April 2026, discarded) — 2-day experiment with an Obsidian-plugin approach. Its architectural patterns (CLI-first, pql-as-subsystem, ignore-file strategy, supply-chain gate, changelog discipline, commit conventions) are the records you see under `decisions/` and the skills under `.claude/skills/`. It first proposed a Go sidecar; [`D-005`](decisions/architecture.md#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer) reversed that in favour of a Dart core.
- **[`projects/pql`](https://github.com/postmeridiem/pql)** — active supporter tool. Clide depends on it; never duplicates it.

## Dependencies & supply chain

- **Dart (core + app):** prefer-zero-deps. Flutter-SDK widgets first; third-party packages need justification. What stays is exact-pinned in `pubspec.yaml` (no caret ranges). Advisories reviewed before every bump; `pubspec.lock` committed.
- **Document every bundled dependency.** Every third-party artefact that ships in the clide binary — Dart packages, fonts, bundled assets, native supporter tools — is listed in [`app/assets/licenses.yaml`](app/assets/licenses.yaml) with name, kind, version, homepage, license, relative path to the bundled license text, and a one-line purpose. Adding a dep is a two-step commit: add the artefact **and** the `licenses.yaml` entry in the same changeset. The About screen (Tier 6) renders the file verbatim; until then, the list being accurate is the contract. See [`D-042`](decisions/tooling.md#d-042-bundled-dependencies-documented-in-licensesyaml).
- **`ptyc` and any future native supporter tool:** no dep graph by design (libc-only for `ptyc`). "Audit" is reading the source before each bump.
- `pubspec.lock` is always committed.
- `make security` runs the Dart advisory review; `ci/security.sh` is the CI entry.

## Commands

(Placeholder until Tier 0 commits land these targets in real form.)

```
make build           # dart compile exe bin/clide.dart -o bin/clide
make test            # flutter test
make test-integration# daemon + CLI + fixture-repo suite
make analyze         # flutter analyze
make format          # dart format --set-exit-if-changed
make build-linux     # flutter build linux
make build-macos     # flutter build macos
make ptyc-build      # build the ptyc PTY-spawn helper
make security        # Dart advisory review + ptyc source review
make push-check      # pre-push gate: analyze + format + test
make hooks           # install the repo's git hooks (one-time setup)
make clean           # remove build artefacts
```

One-time setup on a fresh clone: `make hooks && flutter pub get` once Flutter is installed.

## Changelog discipline

[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Every user-visible commit adds an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). Cutting a release means moving Unreleased entries under a new dated version heading **and** bumping `project.yaml` `version:` in the same commit — see [`.claude/skills/git-commit/SKILL.md`](.claude/skills/git-commit/SKILL.md) for the full rule.

## Open questions

Open questions live under [`decisions/questions-*.md`](decisions/questions.md).
