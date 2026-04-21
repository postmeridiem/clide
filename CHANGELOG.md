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

### Added

- Migrated the `docs/ADRs/` content into `decisions/` as D/R records:
  ADR 0001 → `D-001`, ADR 0002 → `R-002` (superseded by `D-005`), ADR
  0003 → `D-003`, ADR 0004 → `D-004`, ADR 0005 → `D-005`, ADR 0006 →
  `D-006`. Titles preserved; ADR 0006's trailing open questions moved
  to `questions-architecture.md` as `Q-001` / `Q-002` / `Q-003`. The
  originals are preserved in git history.

- `decisions/` at the repo root — Q&D record system ported from
  settled-reach and adapted for clide's domains. Confirmed decisions
  (`D-NNN`) live under domain files (`architecture.md`, `extensions.md`,
  `accessibility.md`, `testing.md`, `tooling.md`, `process.md`); open
  questions (`Q-NNN`) live under parallel `questions-<domain>.md`;
  rejected alternatives (`R-NNN`) live in `rejected.md`. Record shape,
  claiming rules, and the eventual pql-side tooling plan are documented
  in `decisions/README.md`. Migration of the existing `docs/ADRs/` into
  these files lands in a follow-up commit.
- `DECISIONS.md` one-line pointer at the repo root (matches
  settled-reach's convention).

### Removed

- `docs/ADRs/` directory — content lifted into `decisions/` as D/R
  records (see Added above). Originals preserved in git history.

- Go sidecar skeleton under `sidecar/` — `cmd/clide/main.go`, `go.mod`, and the `internal/*` packages (`cli`, `daemon`, `diag`, `git`, `ipc`, `pql`, `proc`, `pty`, `version`). Deleted wholesale per [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md): the "sidecar language: Go" premise no longer holds once the core is Dart. All functionality listed for those packages will be reimplemented under `lib/` as part of Tier 0.
- Go-specific Makefile targets (`lint`, `vuln`, `test-race`, `fmt`, `tidy`, `snapshot`, `tools`, `install` via Go), the `govulncheck`/`goimports`/`golangci-lint` version pins, and the pre-push hook's `GOBIN` PATH injection. Replaced with Dart/Flutter equivalents (`analyze`, `format`, `test`, `test-integration`, `build` via `dart compile exe`).
- `module:` and `go_version:` from `project.yaml` — single-language core means no Go module path to track.

### Changed

- [ADR 0002](docs/ADRs/0002-sidecar-language-go.md) marked **superseded** by [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md). The "sidecar language: Go" guardrail is retired. CLAUDE.md's guardrails, dependency notes, and command reference are updated to reflect the Dart-core direction.
- `.gitignore` retargeted: Flutter/Dart output at the repo root (`.dart_tool/`, `build/`, platform ephemeral dirs, `bin/clide`), plus a `ptyc/` section for the C helper's build artefacts. Go-specific rules removed.
- `ci/lint.sh`, `ci/test.sh`, `ci/security.sh`, and `.githooks/pre-push` rewritten for the Dart toolchain — no Go shell-outs, no `GOBIN` PATH dance.

### Added

- Testing docs under `docs/testing/`: `README.md` (what each layer covers, how to run, local vs CI flow), `a11y-manual.md` (15-minute Orca + VoiceOver checklist run at every tier cut), `claude-ui-workflow.md` (how Claude Code drives the app through the Playwright harness, including the `flt-semantics-placeholder` quirk).
- Makefile targets for every test layer and the UI harness: `test`, `test-a11y`, `test-integration`, `test-e2e`, `test-all`, `coverage`, `smoke-bundle`, `ui-dev`, `ui-stop`, `ui-smoke`. `push-check` now runs `test + test-a11y` (fast pre-push gate, <90s).
- Per-layer CI shell scripts under `ci/`: `test.sh` (analyze + format + unit + widget + golden, ~5s), `test_a11y.sh` (a11y contract), `test_integration.sh` (integration_test one file at a time — desktop can't batch them reliably), `test_e2e.sh` (daemon subprocess + browser WASM Playwright smoke), `smoke_bundle.sh` (xvfb-run the Linux release bundle for 5s; catches dynamic-linker / asset-bundle / plugin-init regressions that widget tests can't see), `coverage.sh` (flutter test --coverage + lcov summary).
- `.gitea/workflows/test.yml` — four-job pipeline (`unit`, `integration`, `startup-bundle`, `e2e`) that shells out to the `ci/*.sh` scripts. **Not activated yet** — Gitea Actions has to be enabled in the instance settings first. GitHub-Actions-syntax-compatible, so copying to `.github/workflows/` is a one-file move when the repo migrates.
- Web WASM harness under `tools/ui/` — Playwright driver so Claude Code (and humans) can drive the Flutter build in a real browser via the Semantics tree. `build.sh` / `serve.sh` / `stop.sh` manage a local `http.server` on `:4280` with port-based reclaim and kill (so orphaned listeners from earlier runs get swept). `driver.ts` exposes `ClideDriver` with `byLabel` / `click` / `type` / `readText` / `screenshot` / `dumpSemanticsTree` / `waitUntilReady` (auto-clicks the `flt-semantics-placeholder` to enable the semantics tree). First Playwright test `smoke.spec.ts` asserts welcome + disconnected labels render in the browser.
- Integration tests under `app/integration_test/`, run with the `integration_test` package against the real built app (not an in-memory widget pump). The load-bearing startup gate lives here: `app_starts_test.dart` boots `ClideApp`, waits for the root shell to settle, and asserts the three-column layout + welcome tab + statusbar connection indicator all render. Also covers theme-picker modal open/select/dismiss (`theme_picker_test.dart`) and extension enable/disable lifecycle with contributions mounting/unmounting (`extension_lifecycle_test.dart`).
- App-level test suite under `app/test/` — 168 tests across four layers:
  - **Unit** (`kernel/`, `extension/`) — events bus, settings (scope + YAML round-trip), log, i18n fallback chain matrix, theme resolver + loader + controller, panel registry + arrangement, command registry + keybinding parser + palette filter, extension-manager dep-order / cycle detection / enable-disable, manifest loader, extension scanner.
  - **Widget** (`widgets/`, `builtin/`) — every primitive's Semantics presence + token consumption + hover/press states; each Tier 0 built-in's contributions, view, and locale-switch re-render.
  - **Golden** (`goldens/`) — widget primitives only, Alchemist + Ahem font; PNG fixtures checked in under `_files/ci/` and `_files/linux/`.
  - **A11y** (`a11y/`) — `semantic_coverage_test.dart` (contract-level check that every built-in carries title + version + label-ready contributions), `contrast_test.dart` (WCAG-AA ratio gate on every bundled theme's canonical token pairs), `i18n_coverage_test.dart` (asserts every Tier-0-referenced key is present in its `en_US` catalog), `keyboard_traversal_test.dart` (focusability smoke).
- Test helpers under `app/test/helpers/` — `KernelFixture` (boots a KernelServices with in-memory defaults + a fake daemon for widget-level tests), `FakeDaemonClient` (subclasses the real client, no socket, drivable connected-state), `golden_harness` (Alchemist config with Ahem font for cross-platform pixel stability), `widget_harness` (wraps a widget in Directionality + ClideKernel + ClideTheme + MediaQuery).
- Flutter desktop app scaffold under `app/` with a bare `WidgetsApp` root (no Material, no Cupertino) and the Tier 0 three-column layout.
  - **Kernel** (`app/lib/kernel/`) — 18 services consumed by every extension: `settings` (scope-resolved get/set across `app.*`/`project.*`/`ext.*`), `project`, `extensions`, `theme`, `panels` (slot registry + arrangement), `events`, `ipc`, `commands` (+ palette + keybinding resolver), `clipboard`, `files`, `notify`, `dialog` (single-at-a-time modal router), `tray`, `secrets`, `os`, `net`, `focus`, and `log`. Unified in a `ClideKernel` `InheritedWidget`.
  - **i18n** (`app/lib/kernel/src/i18n/`) — text-driven lookup ported from [fframe](https://github.com/postmeridiem/fframe)'s `L10n`: namespaced JSON catalogs, `string()` / `interpolated()` calls with caller-supplied placeholders, and a proper locale fallback chain (exact → language → default-country → default-language → placeholder). Improves on fframe's design by adding the chain, which fframe lacks.
  - **A11y from Tier 0** — `Semantics(label:, hint:, button:)` on every interactive primitive; `SemanticsBinding.ensureSemantics()` at boot; a `theme/contrast.dart` helper exposes token pairs that the a11y suite walks for WCAG-AA compliance.
  - **Extension contract** (`app/lib/extension/`) — abstract `ClideExtension`, sealed `ContributionPoint` hierarchy (`TabContribution`, `StatusItemContribution`, `ToolbarButtonContribution`, `CommandContribution`, `TrayItemContribution`, `LayoutPresetContribution`). Each extension ships one manifest contributing N atoms into kernel slots. Priority-based ordering within a slot, dependency-aware activation, YAML manifest loader + scanner for `~/.clide/extensions/`.
  - **Three-tier theme pipeline** — palette (named colors) → semantic roles → ~60 VS-Code-style surface tokens, each layer with defaults so palette-only themes ship. Ported `summer-night` as the first bundled theme; muted value calibrated for WCAG-AA contrast.
  - **Widget primitives** (`app/lib/widgets/`) — `ClideSurface`, `ClideText`, `ClideButton`, `ClideTabBar`, `ClideDivider`, `ClideScrollbar`, `ClideTooltip`, `ClideIcon` + eight `CustomPainter`-rendered icons (folder, gear, x, chevron-left/right, dot, check, plug). All token-consuming, all Semantics-wrapped.
  - **Tier 0 built-in extensions** — `builtin.default-layout` (classic three-column preset + reset command), `builtin.welcome` (workspace placeholder), `builtin.ipc-status` (live-region statusbar indicator), `builtin.theme-picker` (command + modal, bound to `ctrl+k`). Plus 17 id-reserving stubs (`builtin.claude`, `builtin.terminal`, `builtin.files`, `builtin.editor`, `builtin.git`, ...) so later tiers can fill in without rename churn.
  - **Lua runtime boundary** — `app/lib/lua/` ships as typed stubs (`host`, `adapter`, `capability_api`, `render_intent`) so third-party Lua extensions can plug in at Tier 6 without retrofitting.
- `.gitignore` extended to cover `app/` sub-package artefacts (`app/.dart_tool`, `app/build`, per-platform ephemeral dirs, `app/*.iml`) and the Playwright harness under `tools/ui/` (`node_modules`, `out`, test-results).
- Dart core package at the repo root: `bin/clide.dart` (one binary, `--daemon` and one-shot subcommand modes), `lib/clide.dart` barrel exporting the shared IPC types, `lib/src/ipc/` (`envelope.dart`, `server.dart`, `paths.dart`, `schema_v1.dart`), and `lib/src/daemon/dispatcher.dart`. `clide --daemon` listens on a unix socket; `clide ping` / `clide version` round-trip through it with the ADR 0006 exit-code contract (`0/1/2/3/4`). Includes `test/ipc/` and `test/daemon/` suites covering envelope parsing, the in-process server, and a subprocess smoke that verifies signal-driven shutdown + socket unlink.
- `scripts/bazzite-flutter-setup.sh` — one-shot installer for the Flutter SDK + desktop build deps on Bazzite / Fedora Silverblue. Drops the SDK under `~/opt/flutter`, wires PATH in the user's shell rc files, and layers the Linux desktop build deps via `rpm-ostree install`.
- [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md) — Dart core; sidecar directory dissolved; `ptyc` as pql-peer. Establishes one Dart AOT binary for both CLI and daemon, `lib/` as the shared core, and promotes the C PTY helper to a standalone supporter tool on the same footing as pql.
- [ADR 0006](docs/ADRs/0006-cli-and-event-surface.md) — CLI and event surface contract. Defines the subsystem list (`pane`, `tab`, `editor`, `panel`, `tree`, `git`, `pql`, `canvas`, `graph`, `theme`, `settings`, `project`), the command shape, the versioned JSON event schema, the pql-style exit-code contract, and the command↔event duality rule that operationalises user/Claude parity.

- Architectural decision records carried forward from the short-lived
  `claudian` plugin project (discarded in favour of this Flutter
  rebuild):
  [ADR 0001](docs/ADRs/0001-cli-first-not-mcp.md) — CLI-first, not MCP.
  [ADR 0002](docs/ADRs/0002-sidecar-language-go.md) — Sidecar language: Go.
  [ADR 0003](docs/ADRs/0003-pql-as-supporter-tool.md) — pql as supporter tool; wrap, don't duplicate; pql is a Clide subsystem when present.
  [ADR 0004](docs/ADRs/0004-ignore-file-strategy.md) — Ignore file strategy (`ignore_files:` in `.pql/config.yaml`, layered).
- Pre-push quality gate: `.githooks/pre-push` runs `make push-check` (lint + test + test-race + test-integration + vuln + app-analyze + app-test) so bad pushes are caught locally before they hit Gitea. The app-side targets gracefully noop until Flutter is scaffolded. Install with `make hooks` (sets `git config core.hooksPath .githooks`); the hook prepends `$GOBIN`/`$HOME/go/bin` to PATH so govulncheck resolves without the user touching their shell profile.
- Go sidecar/CLI skeleton under `sidecar/` (module `git.schweitz.net/jpmschweitzer/clide/sidecar`): `cmd/clide/main.go`, `internal/cli` with a stdlib-flag dispatch, `internal/diag` mirroring pql's exit-code + stderr-JSON contract, `internal/version` with ldflag-stamped build info, and placeholder packages for `daemon`, `pty`, `proc`, `git`, `ipc`, `pql` awaiting their tier. `clide --version` emits JSON build-info today.
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
