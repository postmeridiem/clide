# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What clide is

A Flutter desktop IDE for Claude Code. Three surfaces, one coherent tool:

- **`app/`** — Flutter desktop application (Linux / macOS primary; Windows stretch).
- **`sidecar/`** — Go sidecar/CLI, single binary with two modes: `clide <subcommand>` (one-shot for Claude) and `clide --daemon` (long-running for the app). Owns PTYs, subprocesses, file watchers, git, pql invocations.
- **[`pql`](https://github.com/postmeridiem/pql)** — external supporter tool. Clide wraps it for every query surface; never re-implements it.

App ↔ sidecar ↔ CLI speak a single JSON-lines unix socket protocol. The sidecar outlives app restarts so Claude sessions survive reopens.

Design doc: [`docs/initial-plan.md`](docs/initial-plan.md). Decisions: [`docs/ADRs/`](docs/ADRs/). Python Textual predecessor under [`legacy/`](legacy/).

## Guardrails

These are load-bearing. Violating any means the design is wrong, not the rule.

- **Flutter desktop is the host. No Electron, ever.** Web target may work as a happy accident — don't compromise desktop fidelity for it. `xterm.dart` is the terminal renderer.
- **No heavy lifting in the UI layer.** Flutter app renders and handles input. PTYs/subprocesses/filesystem/git all live in the sidecar.
- **CLI-first, not MCP.** Claude talks via Bash (`clide ...`), matching pql's contract. See [ADR 0001](docs/ADRs/0001-cli-first-not-mcp.md).
- **Sidecar language: Go.** Module `git.schweitz.net/jpmschweitzer/clide/sidecar`. See [ADR 0002](docs/ADRs/0002-sidecar-language-go.md).
- **User/Claude parity.** Every CLI subcommand has a UI affordance in the app, and every UI action has a CLI. If you add one side without the other, the feature is incomplete.
- **pql: wrap, don't duplicate, and treat it as a clide subsystem when present.** Pql logic only lives in `sidecar/internal/pql/` (pure shell-outs). Clide owns pql's `ignore_files:` config key; it never touches pql's `.pql/` index/cache data. See [ADR 0003](docs/ADRs/0003-pql-as-supporter-tool.md).
- **Repo-is-the-workspace.** The git repo root is the workspace — no parallel "vault" concept. Clide dogfoods against its own repo.
- **Ignore discipline.** Single knob: `ignore_files:` in `.pql/config.yaml`, ordered layering. Default `[.gitignore]`; clide writes `[.gitignore, .clideignore]` when `.clideignore` exists. See [ADR 0004](docs/ADRs/0004-ignore-file-strategy.md).

## Tier ordering (don't skip ahead)

1. **Tier 0** — Flutter app + sidecar daemon handshake, empty IDE shell.
2. **Tier 1** — Claude in an `xterm.dart` pane; session persists across app restarts.
3. **Tier 2** — Pane model + active-file awareness + `clide open/active/insert/replace-selection/tail`.
4. **Tier 3** — Git panel (staged/unstaged, hunk stage, conflict UI) + diff tab + `clide git …`.
5. **Tier 4** — pql integration: Query panel, file tree, backlinks, problems — all drawing from pql.
6. **Tier 5** — Canvas (`CustomPaint` + `InteractiveViewer`) and graph view.
7. **Tier 6** — Dart extension API, settings, theming, distributable builds.

See `docs/initial-plan.md` for the full tier definitions and acceptance criteria.

## Parent projects

- **`legacy/`** — Python Textual clide v1.2.0. Feature-frozen. Reference for the pane model, panel set, git skills (`/commit`, `/stash`, `/pull`, `/push` — rewire to `clide git …`), TODO.md parsing format.
- **`projects/claudian`** (April 2026, discarded) — 2-day experiment with an Obsidian-plugin approach. Its architectural patterns (Go sidecar, CLI-first, pql-as-subsystem, ignore-file strategy, supply-chain gate, changelog discipline, commit conventions) are the ADRs and skills you see here.
- **[`projects/pql`](https://github.com/postmeridiem/pql)** — active supporter tool. Clide depends on it; never duplicates it.

## Dependencies & supply chain

- **Go (sidecar):** exact-pin versions (never `@latest`). `make vuln` (`govulncheck ./...`) runs after every dep add/bump and gates CI.
- **Dart (app):** prefer-zero-deps. Flutter-SDK widgets first; third-party packages need justification. What stays is exact-pinned in `pubspec.yaml` (no caret ranges). Advisories reviewed before every bump; `pubspec.lock` committed.
- `go.sum` and `pubspec.lock` are always committed.
- `make security` aggregates the Go and Dart CVE gates; `ci/security.sh` is the CI entry.

## Commands

(Placeholder until Phase 3 commits land these targets.)

```
make build           # build sidecar/bin/clide
make test            # go test ./...
make test-race       # with race detector
make lint            # golangci-lint
make vuln            # govulncheck (sidecar CVE gate)
make app-build       # flutter build linux / macos
make app-test        # flutter test
make app-analyze     # dart analyze
make security        # run all CVE gates (go + dart)
make push-check      # full pre-push gate: lint + test + test-race + vuln + app-analyze + app-test
make hooks           # install the repo's git hooks (one-time setup)
make tools           # install Go tooling at pinned versions (govulncheck, goimports, golangci-lint)
make clean           # remove build artefacts
```

One-time setup on a fresh clone: `make tools && make hooks`, plus `cd app && flutter pub get` once Flutter is installed.

## Changelog discipline

[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Every user-visible commit adds an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). Cutting a release means moving Unreleased entries under a new dated version heading **and** bumping `project.yaml` `version:` in the same commit — see [`.claude/skills/git-commit/SKILL.md`](.claude/skills/git-commit/SKILL.md) for the full rule.

## Open questions

- `.canvas` schema compatibility with Obsidian — decide during Tier 5 spike.
- Extension API shape (widgets, subcommands, both) — decide during Tier 6.
- IPC wire-format stability + `schema_version:` in `project.yaml` — decide when the first real subcommand lands.
- Editor tab: full LSP integration via sidecar vs tree-sitter-only highlight — decide during Tier 2.
