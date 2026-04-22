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

- Interaction model from Wireframe Flows v3: eight new D-records
  (D-047 through D-054) and five Q-records (Q-026 through Q-030)
  codifying layout invariants, chrome budget, editor mode, context
  auto-behavior, collapse spine, focus mode, state persistence, and
  the canonical keyboard map.

- Panel collapse spine — collapsed side panels render as a 12px
  vertical spine with rotated label, hover highlight, and badge dot
  for pending context (D-051, T-030).

- Focus mode — `Ctrl+.` takes the active panel full-window;
  `Escape` restores the prior layout with collapse states and
  divider positions intact (D-052, T-031).

- Canonical keyboard shortcuts from the interaction model: collapse
  toggles (`Ctrl+Shift+1/3`), panel focus (`Ctrl+1/2/3`), sidebar
  section switching (`Alt+1–5`), focus mode, and `Escape` dismiss
  (D-054, T-033).

- Right panel (context) icon rail — bottom section switcher matching
  the left sidebar rail pattern (D-047, T-034).

- Editor-above-Claude mode — `Ctrl+E` opens the editor as a split
  above Claude in the middle column with a draggable divider;
  `Ctrl+W` or `Escape` closes it. Prompt bar Y stays fixed
  (D-049, T-035).

- Layout state persists across sessions — collapse state, sidebar
  and context panel sizes, active sections, and editor split ratio
  saved to `.clide/settings.yaml` (D-053, T-032).

- Phosphor Icons font (v2.0.8, MIT) — regular, bold, and fill
  weights. Replaces hand-painted CustomPaint icons in sidebar and
  context panel icon rails.

### Changed

- Workspace renders Claude as the always-visible primary surface
  instead of showing a tab bar (D-047, D-048). The editor is a
  split overlay, not a tab.

- Syntax highlighting via tree-sitter (dart:ffi to vendored
  libtree-sitter.so with embedded wasmtime). 48 grammar WASM files,
  48 highlight queries. Colors map to theme syntax tokens.

- POLICY.md — project-wide rules for runtime behavior, dependency
  vetting, vendored binary management, telemetry, and licensing.

### Changed

- Line length set to 160 across .editorconfig and dart formatter.

- Core frame vs shipped extension boundary defined (D-046). Builtins
  are frame infrastructure only; content extensions are bundled but
  architecturally removable.

### Removed

- `builtin.jira` stub — Jira integration belongs as a third-party
  extension, not a frame builtin.
- `wasm_run` and `wasm_run_flutter` dependencies — replaced by
  vendored libtree-sitter.so via dart:ffi. Eliminates runtime network
  download that violated POLICY.md.

### Added

- pql skill installed via `pql init --with-skill=yes`
  (`.claude/skills/pql/SKILL.md`). Covers vault queries and the
  planning surface (decisions + tickets).

- `Bash(pql)` and `Bash(pql *)` permissions in
  `.claude/settings.json`.

- pql daemon subsystem (`lib/src/pql/`). `PqlClient` wraps the pql
  CLI per D-003. IPC verbs `pql.files | meta | backlinks | outlinks
  | tags | schema | query | doctor | decisions.sync | decisions.list
  | decisions.show | decisions.coverage | tickets.list | tickets.show
  | tickets.board | plan.status`. 15 new core tests.

- `builtin.pql` — sidebar panel with four views: Files (pql-indexed
  file listing), Query (PQL DSL input + results), Decisions (synced
  D/Q/R records colour-coded by type), Tickets (kanban board columns).
  Context panel tab showing backlinks + outlinks for the active file,
  auto-refreshing on `editor.active-changed` events.

- `builtin.problems` — sidebar panel aggregating diagnostics from
  `pql.doctor` and `pql.decisions.sync`. Surfaces missing index DB,
  stale skill installs, and broken decision cross-references with
  actionable hints.

- Git subsystem in the daemon (`lib/src/git/`). Status parser
  (`git status --porcelain`), unified-diff parser, and operations
  (stage, unstage, stage-hunk, discard, commit, stash, log, pull,
  push). IPC verbs `git.status | diff | stage | stage-all | unstage
  | stage-hunk | unstage-hunk | discard | commit | stash | stash-pop
  | log | pull | push` with `git.changed` events on mutations.
  42 new core tests cover parsing, operations, and dispatcher
  round-trips.

- `clide git …` CLI shortcuts: `git status`, `git diff [--staged]`,
  `git stage <paths>`, `git stage-all`, `git unstage`, `git discard`,
  `git commit "<msg>"`, `git log [--count N]`, `git stash`,
  `git stash-pop`, `git pull`, `git push`.

- `builtin.git` — sidebar panel showing staged, unstaged, untracked,
  and conflicted file groups. Per-file stage/unstage/discard on hover.
  Inline commit message input with Commit button. Branch + ahead/behind
  display with Pull/Push actions. Auto-refreshes on `git.changed`
  events.

- `builtin.diff` — workspace tab rendering unified diffs with
  old/new line numbers, addition/removal colouring, and binary/rename
  metadata. Staged/Unstaged toggle toolbar. Auto-refreshes on
  `git.changed` events.

- `builtin.editor` — Tier-2 editor tab wired up. Contributes a
  single `Editor` workspace tab that renders the daemon's active
  buffer via a new `EditorController`. Hydrates on mount
  (`editor.active` → `editor.read`), subscribes to
  `editor.opened | active-changed | edited | saved | closed`, and
  propagates user edits back through `editor.set-content`. Small
  echo-suppression guard avoids clobbering the caret when the
  daemon's authoritative edit echo comes back. Text surface is
  Flutter's `EditableText` primitive — no `TextField` / Material —
  so the D-007 "no Material root" stance carries into the editor;
  JetBrainsMono via the shared `clideMonoFamily` constants, cursor
  + selection colours bind to the theme.

- File-tree click in `builtin.files` now opens the clicked file in
  the editor via `ipc.request('editor.open', {path})`. No local
  command hop — the dispatch goes straight to the daemon and the
  UI reconciles through the `editor.active-changed` event.

- CLI shortcuts per CLAUDE.md's Tier-2 list: `clide open <path>`,
  `clide active`, `clide insert <text | ->`, `clide replace-selection
  <text | ->`, `clide save`, `clide tail --events [--filter
  SUBSYSTEM[:ID]]`. A lone `-` on insert / replace-selection reads
  text from stdin (pipe-friendly). `tail` reads the event-broadcast
  stream and prints JSON lines until SIGINT; `--filter` narrows by
  subsystem or subsystem+id. 5 new end-to-end CLI tests spin up real
  daemon subprocesses via a per-test `CLIDE_SOCKET_PATH` override (new
  env knob on `defaultSocketPath`) so tests run in parallel without
  colliding.

- Editor subsystem in the daemon (`lib/src/editor/`). `EditorBuffer`
  holds path + content + cursor/selection + dirty flag;
  `EditorRegistry` owns the open-buffer set, active-buffer tracking,
  and file I/O. IPC verbs land alongside (`editor.open | active |
  activate | list | read | insert | replace-selection | set-selection
  | set-content | save | close`) with matching events (`editor.opened
  | active-changed | selection-changed | edited | saved | closed`).
  Omitting `id` on mutating verbs targets the active buffer so the
  tier-2 CLI shortcuts (`clide insert "…"`, `clide replace-selection
  "…"`) read naturally. 16 new core tests cover the lifecycle +
  dispatcher round-trips.

- `builtin.claude` — Tier-1 stub upgraded to the real Claude pane per
  D-041. Contributes a primary `Claude` tab in the workspace slot that
  spawns `tmux new-session -A -s clide-claude-<hash> -- claude` via
  IPC `pane.spawn`, with `<hash>` derived from the git root path so
  reopening the app re-attaches to the running conversation. Primary
  has no close affordance; closing the tab doesn't kill the session.
  Command `claude.new-secondary` is registered for the palette wiring
  that's coming next. If tmux isn't on PATH, falls back to spawning
  `claude` directly and surfaces "no-tmux · fresh every launch" in
  the header subtitle. Accompanied by D-041 in
  [`decisions/architecture.md`](decisions/architecture.md#d-041-claude-panes-one-primary-per-repo-tmux-backed).

- `builtin.files` — workspace filesystem panel in the sidebar. Lazy
  tree rooted at the git root, expand/collapse, click-to-open plumbed
  to a future `editor.open` command. Backed by a new daemon-side
  `files.*` IPC subsystem (`files.root`, `files.ls`, `files.watch`)
  and a `FileWatcher` that wraps `Directory.watch(recursive: true)`
  with ignore-file filtering. Ignore set composes clide's built-in
  hide list (`.git/`, `.pql/`, `.clide/`, `.dart_tool/`, `build/`,
  `node_modules/`) with `.gitignore` / `.clideignore` at the root per
  D-004. `IgnoreSet` + `IgnorePattern` support line-per-pattern, `#`
  comments, anchored / directory-only / negated forms, and `**` across
  directories. 11 new unit tests on the matcher; 5 new dispatcher
  tests; 171 app tests still green.

- `builtin.terminal` — general-purpose terminal pane, Tier-1 stub
  upgraded to a working implementation. Contributes a `Terminal` tab
  in the workspace slot that spawns `$SHELL -l` via IPC
  `pane.spawn`, streams `pane.output` events into `xterm.dart`, and
  routes user input through `pane.write`. Resize propagates via
  `pane.resize` on viewport change. `initState` → spawn;
  `dispose` → `pane.close`. Error-state surface for "daemon not
  connected" / "shell exited." No Claude-specific behaviour — that
  lives in `builtin.claude` + D-041.

- Shared pane widgets under `app/lib/widgets/`: `ClidePtyView` wraps
  `xterm.dart` with clide-theme token bindings, JetBrains Mono as the
  face, and a Semantics live-region wrapper; `ClidePaneChrome` is the
  reusable title strip + optional close button. Consumers of the new
  widgets (`builtin.terminal`, `builtin.claude`) drive the xterm
  `Terminal` model and route bytes through IPC `pane.write` /
  `pane.output` events themselves — the widgets are rendering only,
  no IPC coupling.

- `xterm: 4.0.0` Dart dependency on the Flutter app — MIT, listed in
  `licenses.yaml` per D-042. Hand-rolling a VT100 / xterm / truecolour
  parser + renderer would be weeks for no fidelity win.

- `Q-023` — open question on SSH-remote development (run clide against
  a workspace on another host). Local-first stays the Tier-1 target;
  this records the constraint so the daemon / IPC / extension seams
  don't unknowingly accrete local-only assumptions.

- IPC `pane` subsystem in the daemon (per D-006). Commands:
  `pane.spawn | list | focus | close | write | resize | tail`. Events:
  `pane.spawned`, `pane.output` (base64-framed), `pane.exit`,
  `pane.resized`, `pane.focused`, `pane.closed`. `PaneRegistry` owns
  per-pane `PtySession` lifecycles + id generation (`p_N`); a
  `DaemonEventSink` seam lets handlers emit events without depending
  on the IPC server package. `DaemonServer.broadcast()` fans events
  out to every connected client (a later pass adds per-client
  `--filter` scoping). Panes carry a `kind:` field — `terminal` today,
  `claude` ready for step 7. Covered by 14 new Dart core tests
  exercising the real registry + dispatcher against the `ptyc` helper.

- `PtySession` in the Dart core (`lib/src/pty/`) — spawns a child
  under a PTY via the `ptyc` supporter tool, receives the master fd
  over `SCM_RIGHTS`, and exposes a byte stream, write, resize, and
  kill. A background isolate loops on blocking `read(fd)` and posts
  chunks to the main isolate. `close()` sends SIGTERM to the child
  so the PTY's EOF wakes the isolate cleanly, then falls through to
  SIGKILL + fd close + isolate kill as a safety net. Child env is
  built via `mergePtyEnv()` which stamps clide's true-colour defaults
  (`TERM=xterm-256color`, `COLORTERM=truecolor`, `CLICOLOR_FORCE=1`).
  Test coverage: echo round-trip, cat write/readback, env stamping
  verification, idempotent close.

- `ffi: 2.1.3` as a runtime dependency on the Dart core — justified
  in `pubspec.yaml` + documented in `licenses.yaml` per D-042. Used
  by `lib/src/pty/ffi/` for `socketpair`, `recvmsg` with `SCM_RIGHTS`,
  `read`/`write` on raw fds, and `ioctl(TIOCSWINSZ)`.

- `ci/test_core.sh` + `make test-core` — runs the Flutter-free core
  Dart tests (`test/`) under a 120s hard timeout with process-group
  cleanup. Wired into `push-check` ahead of the app test suite so a
  hung PTY test can't block the pre-push gate.

- Josefin Sans bundled as `app/assets/fonts/josefin_sans/` as the
  application UI face — variable-font pair (upright + italic, weight
  range 100-700), OFL-licensed. Declared as the `JosefinSans` family
  in `app/pubspec.yaml`. `_AppRoot` installs it as the ambient
  `DefaultTextStyle` at weight `w300` (Light) per the project's
  aesthetic direction; callers can still pass an explicit
  `fontWeight` on `ClideText` to get bolder emphasis.

- JetBrains Mono bundled as `app/assets/fonts/jetbrains_mono/` —
  Regular / Italic / Bold / BoldItalic weights (OFL-licensed,
  license file checked in alongside). Declared as the `JetBrainsMono`
  family in `app/pubspec.yaml`. `app/lib/widgets/src/typography.dart`
  exposes `clideUiFamily` + `clideMonoFamily` plus platform-ordered
  fallback chains for both faces, for web builds and harnesses that
  don't load asset fonts.

- `app/assets/licenses.yaml` — canonical manifest of every bundled
  third-party artefact (fonts today; Dart packages + native tools as
  they land). Schema has name, kind, version, homepage, license,
  `license_file` pointer, and a one-line purpose. Bundled alongside
  the per-dep license texts. The About screen (Tier 6) will render
  this file verbatim. Accompanied by
  [`D-042`](decisions/tooling.md#d-042-bundled-dependencies-documented-in-licensesyaml):
  adding a dep is a two-step commit (artefact + `licenses.yaml`
  entry in the same changeset).

### Changed

- CLAUDE.md "Dependencies & supply chain" section gains the
  "document every bundled dependency" rule, pointing at
  `app/assets/licenses.yaml` and `D-042`.

- `ptyc/` — the C PTY-spawn helper, peer of `pql` per
  [`D-005`](decisions/architecture.md#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer).
  One-shot, libc-only, ~400 LOC. Reads a JSON request on stdin
  (`argv`, optional `cwd`/`env`/`cols`/`rows`), does
  `posix_openpt` + `fork` + `execvp`, and hands the master fd back
  to the caller over a unix socket via `SCM_RIGHTS`. Socket fd
  defaults to 3; override via `PTYC_SOCK_FD` for language runtimes
  that shuffle pipe fds through the low numbers (Python's
  `subprocess` with `stdout=PIPE` does this). Exec-failure pipe
  (CLOEXEC) reports child-side errors to the parent without leaking
  zombies. Root Makefile gains `ptyc-test` target in addition to
  `ptyc-build` / `ptyc-clean`.

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

- `tools/scripts/plan` — Python stopgap entrypoint for `decisions`
  and `ticket` subcommands, writing to `.pql/pql.db` (gitignored).
  Supports `decisions sync | validate | claim | list | show | coverage`
  and `ticket new | list | show | status | assign | team | block |
  unblock | label | search | board`, plus `sqlite-query`. Verb shape
  and output format mirror the eventual `pql` subcommands so migration
  when pql ships feature parity is a call-site find-replace
  (`tools/scripts/plan ` → `pql `). Ported from settled-reach with
  the Scrum layer stripped; ticket IDs are `T-NNN` (TEXT PKs) and
  there's no `sprints` table. Time-limited per
  [`D-040`](decisions/process.md#d-040-python-stopgap-under-toolsscriptsplan)
  / [`R-011`](decisions/rejected.md#r-011-permanent-stopgap).

- `make decisions-validate` — cheap parser dry-run wired into
  `push-check`. Catches malformed records before push.

- Reserved extension slots — `builtin.decisions`, `builtin.tickets`,
  `builtin.claude-control`. Id-reserving stubs under
  `app/lib/builtin/` with no contributions yet. Implementations land
  once [`Q-021`](decisions/questions-architecture.md#q-021-pql-absorbs-planning-vs-keeps-separate)
  resolves (decisions + tickets) or when the claude-control tier
  arrives (`.claude/` first-class surface — distinct from the
  existing `builtin.claude` PTY-pane stub).

- `CLAUDE.md` — new "Decision discipline" guardrail pointing at
  `decisions/`.

### Changed

- `CLAUDE.md` — inline ADR links rewritten to point at the migrated
  `decisions/` records; bottom "Open questions" section collapsed to
  a pointer at `decisions/questions-*.md`; parent-project note
  updated to reference `decisions/architecture.md` instead of the
  deleted `docs/ADRs/`.

- `make decisions-validate` rewired from `tools/scripts/plan` to
  `pql decisions validate`.

- Decision discipline guardrail in CLAUDE.md now points at
  `pql decisions claim` instead of the Python stopgap.

### Removed

- `tools/scripts/plan` — Python stopgap planning scripts, superseded
  by `pql` 1.0 native `decisions` and `ticket` subcommands. Sunset
  condition from
  [`D-040`](decisions/process.md#d-040-python-stopgap-under-toolsscriptsplan)
  met; deletion per
  [`R-011`](decisions/rejected.md#r-011-permanent-stopgap).

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
