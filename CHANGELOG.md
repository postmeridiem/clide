# Changelog

All notable changes to clide are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This changelog tracks the Flutter rebuild at the repo root. The Python
Textual implementation's changelog is preserved under
[`legacy/CHANGELOG.md`](legacy/CHANGELOG.md).

Versions are tracked in [`project.yaml`](project.yaml) under `version:`,
which is the single source of truth. Cutting a release means (a) moving
the entries below from `## [Unreleased]` under a new dated version
heading, and (b) bumping `project.yaml` `version:` in the same commit.

## [Unreleased]

### Changed

- `.gitignore` rewritten for the new toolchain: Flutter (build output under `app/`), Dart (`.dart_tool/`), Go sidecar (`sidecar/bin/`, `sidecar/dist/`, the legacy `/clide` binary), plus the usual test/OS/editor/secret rules. Python-specific rules narrow to `legacy/**` where they still apply.

### Added

- Architectural decision records carried forward from the short-lived
  `claudian` plugin project (discarded in favour of this Flutter
  rebuild):
  [ADR 0001](docs/ADRs/0001-cli-first-not-mcp.md) — CLI-first, not MCP.
  [ADR 0002](docs/ADRs/0002-sidecar-language-go.md) — Sidecar language: Go.
  [ADR 0003](docs/ADRs/0003-pql-as-supporter-tool.md) — pql as supporter tool; wrap, don't duplicate; pql is a Clide subsystem when present.
  [ADR 0004](docs/ADRs/0004-ignore-file-strategy.md) — Ignore file strategy (`ignore_files:` in `.pql/config.yaml`, layered).
- Root `Makefile` drives both the Go sidecar and the Flutter app under one toolchain. Version is read from `project.yaml` via awk and stamped into the sidecar via `-ldflags -X`. Flutter targets gracefully noop before the app is scaffolded so the Makefile is usable from day one. Pinned Go tooling (govulncheck, goimports, golangci-lint) installs via `make tools`.
- `ci/` entry scripts: `test.sh`, `lint.sh` (includes the supply-chain gate — no green lint without a green CVE scan), `security.sh`, `release.sh` (stub).
- Project identity files for the Flutter rebuild at the repo root: `project.yaml` (single source of truth for version + module path, version 2.0.0-dev), a fresh `README.md`, MIT `LICENSE`, and `.editorconfig`. The Python clide's manifest and README are preserved under `legacy/`.
- [`docs/initial-plan.md`](docs/initial-plan.md) — the north-star design document for the Flutter rebuild. Captures what we kept from Python Clide (pane model, git skills, Claude-always-visible), what we took from Obsidian (canvas and graph — no vault, no bases, no plugin inheritance), what Claudian's short experiment contributed (Go sidecar, CLI-first, pql-as-subsystem, ignore-file strategy), and the tier roadmap (Tier 0 app+sidecar handshake → Tier 5 canvas+graph).
- [`CLAUDE.md`](CLAUDE.md) orientation doc for future Claude Code instances: project identity, guardrails as one-liners, tier ordering, parent-project pointers, commands, dependencies & supply chain, open questions. Points at the design doc and ADRs rather than restating their content.
- Claude Code configuration under `.claude/`: project-level
  allow/deny permissions and two skills — `skill-create` (generic
  skill authoring guidance) and `git-commit` (this repo's commit
  conventions: no Conventional Commits, Keep a Changelog discipline,
  `project.yaml`-and-changelog-bumped-together rule, attribution
  trailer, safety reminders).
