# Architecture Decisions

Core, rendering, IPC, kernel, panel manager.

---

### D-007: App root is bare `WidgetsApp`
- **Date:** 2026-04-21
- **Decision:** The Flutter app root is `WidgetsApp`, not `MaterialApp` or `CupertinoApp`. Clide's look is fully custom; the Material/Cupertino shells would drag in opinionated theming, default icons, and platform chrome we'd then have to fight.
- **Rationale:** Clide is a Linux-primary desktop IDE with a custom theme pipeline and custom primitives (panels, tabs, panes, canvas). Material's implicit theming collides with [D-009](#d-009-three-tier-theme-pipeline); Cupertino is iOS-flavoured. `WidgetsApp` gives us routing, locale, focus traversal, semantics, and Directionality without aesthetic baggage.
- **Cost:** We build and own every primitive; no `ElevatedButton` fallback. See [R-003](rejected.md#r-003-materialapp-root) and [R-007](rejected.md#r-007-cupertinoapp-root).
- **Raised by:** 2026-04-21 planning.

### D-008: Feature-first folder layout
- **Date:** 2026-04-21
- **Decision:** Under `app/lib/`, organise by feature (`kernel/`, `extension/`, `widgets/`, `builtin/<name>/`) rather than by layer (`models/`, `views/`, `controllers/`). Private implementation lives under each feature's `src/`; the feature's public surface is a barrel file at the feature root (e.g. `app/lib/kernel/kernel.dart`).
- **Rationale:** Features grow and get deleted as units; layer-first layouts fragment a feature across three directories and make deletions risky. Matches extensions-as-features (every extension already has its own folder).
- **Cost:** Imports cross features only via the barrel — enforce by review, no automated check yet.
- **Raised by:** 2026-04-21 planning.

### D-009: Three-tier theme pipeline
- **Date:** 2026-04-21
- **Decision:** Themes resolve through three layers: (1) palette — raw named colours per theme YAML; (2) semantic — roles like `surface.background`, `text.primary`, `accent.focus`; (3) surface — component-scoped tokens derived from semantic roles (button bg/fg/border hover/pressed/disabled states).
- **Rationale:** Direct palette-to-component binding collapses under multi-theme work; VS Code's 600-token surface map is the proof. The semantic layer is where a11y contrast gates apply; the surface layer is where components bind.
- **Cost:** Three layers to keep coherent per theme. Contrast gate ([D-022](accessibility.md#d-022-wcag-aa-contrast-gate-on-bundled-themes)) enforces the semantic layer on every bundled theme.
- **Raised by:** 2026-04-21 planning.

### D-010: State management — `ChangeNotifier` + `ListenableBuilder`
- **Date:** 2026-04-21
- **Decision:** Per-feature state uses `ChangeNotifier` exposed through a feature facade (singleton-per-kernel); widgets subscribe via `ListenableBuilder`. No Riverpod, Provider, BLoC, or Redux.
- **Rationale:** SDK-shipped, zero deps, trivial to fake in tests (hand-rolled fakes in [D-025](testing.md#d-025-mocks-mocktail-at-io-plus-hand-rolled-fakes)). Violates [D-031 prefer-zero-deps](tooling.md#d-031-prefer-zero-deps-exact-pin) otherwise. See [R-008](rejected.md#r-008-riverpod-provider-bloc-for-state).
- **Cost:** No codegen ergonomics; manual `notifyListeners()` discipline. The `ListenableBuilder.listenable` contract rejects rebuilds outside the subscribed notifier — intentional.
- **Raised by:** 2026-04-21 planning.

### D-011: Panel manager is kernel; layout is data; three-column is a preset
- **Date:** 2026-04-21
- **Decision:** The kernel owns a panel manager that treats layout as declarative data (tree of splits + leaves). The default "three-column IDE" (sidebar / editor / assistant) is one preset; alternative presets (writer-focus single-column, debugger four-pane) ship as data, not code forks.
- **Rationale:** Hard-coded three-column layouts paint us into corners when future tiers add canvas, graph, terminal-grid. Data-driven layout also lets extensions contribute presets without patching the panel manager.
- **Cost:** More kernel surface up-front; pays back at Tier 5 (canvas) and Tier 6 (extension-contributed layouts).
- **Raised by:** 2026-04-21 planning.

### D-012: Kernel admission rule — mandatory shared singletons only
- **Date:** 2026-04-21
- **Decision:** A service joins the kernel only if it is (a) mandatory for app boot and (b) a shared singleton across features. Everything else is an extension or a feature-local service.
- **Rationale:** Keeps the kernel auditable. Previous drafts piled "useful globals" into the kernel; result was a 40-service god-object. The admission rule forced 18 services out of 31 candidates.
- **Cost:** Some legitimate cross-cutting concerns (telemetry, crash reporter when they land) must pass the test; we expect a few more admissions as Tiers 3-6 land.
- **Raised by:** 2026-04-21 planning.

### D-013: Git hardcoded in kernel project-loader
- **Date:** 2026-04-21
- **Decision:** The kernel's project loader treats "repo root" as a `git` concept — runs `git rev-parse --show-toplevel` to find workspace root, subscribes to filesystem events, and shells out to `git` for status/diff/stage. No VCS abstraction layer.
- **Rationale:** Option B (VCS abstraction) is premature generalisation — we have one VCS today, Mercurial/Fossil/Sapling users are a rounding error on the Linux desktop IDE market, and the abstraction adds a seam that has to be tested against nothing. When a second VCS shows up we refactor.
- **Cost:** Adding Mercurial support later costs a real refactor, not just a plugin. Acceptable.
- **Raised by:** 2026-04-21 planning.

### D-014: Two-tier disable — kernel locked, everything else extension-shaped
- **Date:** 2026-04-21
- **Decision:** Kernel services cannot be disabled at runtime. Extensions (including every bundled built-in) can be toggled via the extension manager. This creates exactly two disable tiers: kernel (always on) and extension (toggleable).
- **Rationale:** A three-tier system (kernel / bundled-cannot-disable / user-can-disable) is dishonest — if a "bundled built-in" can't be disabled, it's kernel and belongs in kernel admission review. Forcing every bundled feature to pass the extension contract is also the best test we have that the contract is actually usable.
- **Cost:** Disabling `builtin.default_layout` by mistake produces an empty window. Mitigated by the kernel's first-boot defaults and a "reset extensions" action.
- **Raised by:** 2026-04-21 planning.

---

### D-041: Claude panes — one primary per repo, tmux-backed
- **Date:** 2026-04-22
- **Decision:** Every repo (keyed on the git root) hosts **exactly one primary Claude pane** plus zero or more **secondary** Claude panes. The primary persists across clide restarts; secondaries are ephemeral. Persistence layer is **tmux**: the daemon spawns the primary as `tmux new-session -A -s clide-claude-<repohash> -- claude`, which re-attaches to the running session if the app restarts. Secondaries spawn as `tmux new-session -A -s clide-claude-<repohash>-N -- claude` with `N` incrementing. Close semantics: closing a secondary kills that tmux session and focus collapses back to the primary (or to the next-most-recent secondary); the primary has **no close affordance** — close-gestures on it hide it / minimise to a dock, they don't kill the session. Daemon is the owner; the UI doesn't track tmux session state directly, it just asks the pane subsystem to spawn/close and observes events. General-purpose terminal panes (`builtin.terminal`) do **not** get tmux wrapping or persistence — they're per-app-lifetime.
- **Context:** 2026-04-22 planning. The user workflow is "open repo → Claude is already there, with my last conversation intact." A cold session-restart every time clide re-launches defeats the premise. tmux already solves "reattach to a shell-like session across disconnects"; layering our own persistence protocol on top of ptyc would duplicate it.
- **Rationale:** (1) tmux is battle-tested — no new persistence code to review. (2) The pane subsystem stays neutral; Claude-specific behaviour lives in `builtin.claude`. (3) Keying by git root means the user doesn't manage session names manually — opening a repo is enough. (4) "Always one primary" removes a failure mode: there's never "no Claude to talk to." (5) Secondaries stay frictionless — the user spawns and closes them at will without breaking the primary.
- **Cost:** Requires tmux on the PATH of the daemon's runtime environment (reasonable for Linux + macOS; Windows support via WSL or a separate approach). Killing a primary (via the daemon on shutdown) still leaves the detached tmux session around until the next clide start re-attaches; acceptable but worth documenting for support. Secondary numbering (`-1`, `-2`, …) resets between clide runs since ephemeral state is lost — also acceptable.
- **Raised by:** 2026-04-22 planning, Tier 1 implementation.
- **Cross-reference:** [`D-005`](#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer) (ptyc as the spawn primitive tmux runs under), [`D-006`](#d-006-cli-and-event-surface-contract) (pane.\* IPC surface), [`R-009`](rejected.md#r-009-port-planning-tooling-into-clide) (why per-repo scoping via git root matches the wrap-don't-duplicate theme).

### D-001: CLI-first, not MCP
- **Date:** 2026-04-20 (was ADR 0001; ported from the claudian lineage)
- **Decision:** Claude talks to clide exclusively via Bash (`clide …`). No MCP server. No protocol layer in Claude's face. The CLI uses the same exit-code + stderr-JSON contract as pql.
- **Context:** The two mainstream options for the agent-facing surface were an MCP server or a plain Bash CLI matching pql's contract.
- **Rationale:** Same mental model as pql for the agent — one tool-use pattern covers both. No MCP runtime to host, authenticate, or keep in sync with client versions. User/Claude parity is easier to enforce: every CLI subcommand must have a UI affordance in the Flutter app and vice versa ([D-006](#d-006-cli-and-event-surface-contract)). Claude Code's `Bash(clide *)` allow rule is the only configuration clide needs on the agent side.
- **Cost:** If an MCP-only integration becomes compelling later (e.g. a multi-agent scenario), nothing here precludes adding one that shells out to the same CLI.
- **Raised by:** Ported from the claudian lineage.

### D-003: pql as supporter tool; clide wraps, never duplicates
- **Date:** 2026-04-20 (was ADR 0003; ported from the claudian lineage)
- **Decision:** Two complementary rules. **(1) Wrap, don't duplicate.** Clide never re-implements backlinks, ranking, frontmatter parsing, or wikilink resolution for query purposes. If a capability is missing in pql, it is added upstream in pql's repo and clide bumps the dependency. The only place clide contains pql logic is `lib/src/pql/` — pure shell-outs to the `pql` binary. **(2) pql is a clide subsystem when clide is present in the repo.** On load, clide writes its current state into `.pql/config.yaml` — no conditional sync. Clide only stomps keys it manages (starting with `ignore_files:` — see [D-004](#d-004-ignore-file-strategy)). Other pql config keys are left alone. Clide does **not** touch pql's index/cache data under `<repo>/.pql/` — that stays pql's private store.
- **Context:** [`pql`](https://github.com/postmeridiem/pql) is a pre-existing Go CLI that indexes a markdown-bearing directory tree into SQLite and exposes frontmatter, wikilinks, tags, headings, and bases through a query surface. Clide needs those capabilities for its Query panel, canvas drivers, graph view, and any feature that needs to know structure.
- **Rationale:** One source of truth for markdown semantics. Any new query capability the UI wants goes through a pql upstream PR, not a local workaround. Users never have to learn pql's config file to get consistent behaviour — clide manages it. The arrow clide → pql is never inverted: pql stays ignorant of its wrapper.
- **Cost:** Clide's `lib/src/pql/` package is deliberately thin. pql is also the **only** query engine — Obsidian-style inline "bases" are explicitly not supported; queries live at the repo level. In repos without clide, pql works standalone unaffected.
- **Raised by:** Ported from the claudian lineage. Load-bearing for [D-039](process.md#d-039-planning-tooling-lives-in-pql).

### D-004: Ignore file strategy
- **Date:** 2026-04-20 (was ADR 0004; ported from the claudian lineage)
- **Decision:** One mechanism everywhere: the `ignore_files:` list in `.pql/config.yaml`. Ordered list of gitignore-shaped files; later entries win on per-pattern conflicts. pql defaults to `ignore_files: [.gitignore]`. Per [D-003](#d-003-pql-as-supporter-tool), clide writes the list on load — `[.gitignore, .clideignore]` if `.clideignore` exists, else `[.gitignore]`. `.clideignore` carries **only** the clide-specific deviations from `.gitignore` (supports `!pattern` negations); never duplicate gitignore's contents. Walker magic: none except `.git/` — every other tool-owned dir (`.pql/`, `.clide/`) is added to `.gitignore` at install time; exclusion flows through the normal `ignore_files:` chain.
- **Context:** Every file-enumerating surface in clide (pql query panels, canvas drivers, graph view, file watchers, pane lists, file tree) needs to skip the obvious junk — `vendor/`, `node_modules/`, `dist/`, build artifacts — or results drown in noise. Clide's working assumption is that the git repo *is* the workspace — no separate "vault" concept.
- **Rationale:** Users get one config knob, in a file they might already know (pql users) or never need to touch (clide-only users). `.clideignore` is short by design — it's deltas, not a full list. Sidecar consumers read the same key and apply identical precedence, so Claude and the user always see the same filtered surface.
- **Cost:** Removing clide from a repo leaves pql working with vanilla defaults (clide's last-written `ignore_files:` stays until pql or the user rewrites it; worth reconsidering during uninstall design).
- **Raised by:** Ported from the claudian lineage.

### D-005: Dart core; sidecar dissolved; `ptyc` as pql-peer
- **Date:** 2026-04-20 (was ADR 0005; supersedes [R-002](rejected.md#r-002-go-sidecar))
- **Decision:** Three moves. **(1) Dart is the core language.** Everything that used to live under `sidecar/` — IPC server, CLI dispatch, process management, file watching, git shell-outs, pql wrapper — is written in Dart. Two execution modes of one Dart AOT binary: `clide <subcommand>` (one-shot, pql-style) and `clide --daemon` (long-running, owns PTYs and subprocesses, survives app restarts). The Flutter app imports the Dart core as a library *and* connects to the daemon over IPC. **(2) The sidecar directory dissolves.** Layout is `app/` (Flutter UI), `lib/` (Dart core), `bin/clide.dart` (AOT entry), `ptyc/` (C helper), no `sidecar/`, no Go module. **(3) `ptyc` is a pql-peer supporter tool.** Small C binary that does `posix_openpt` + `fork` + `exec` + fd-passing via `SCM_RIGHTS`; clide wraps it the same way it wraps pql. Shells out for every PTY (terminal pane, tmux session, Claude, LSP server, debug adapter — one code path). Consumers other than clide can use `ptyc` standalone.
- **Context:** [R-002](rejected.md#r-002-go-sidecar) picked Go for the sidecar/CLI on two premises: (a) the heavy work belongs in a language separate from the UI layer, and (b) pql is Go so the muscle memory transfers. On reassessment, both premises broke: the "heavy work" is I/O-bound glue that `dart:io` covers cleanly — the real choice was **separate process vs shared language**, and separate-process is what matters. PTY is the one place Dart is genuinely weak (multi-threaded VM can't safely `fork()`), and once you accept a small native helper, *nothing else* needs to be in the same language.
- **Rationale:** One toolchain for the IDE proper (Flutter + Dart). C toolchain needed only to build `ptyc` — tiny, rarely-changing. Session persistence stays because PTY master fds live in the Dart daemon process, not the app. `ptyc` naming: **p** for *project* (parallel to pql's *project query language*), **ptyc** reads as both "PTY + child" (domain vocabulary) and "PTY + C" (implementation language). Usable from Dart, Python, Go, shell — anywhere a subprocess can be spawned and a fd received.
- **Cost:** Rust remains an escape hatch, not a plan. If a Dart limit later forces a second native helper (file-watching at scale on macOS, a tree-sitter host, etc.), the precedent is: new native need → new supporter tool, peer of pql and `ptyc`. Never a second "core language." Supply-chain gates stay, shape changes — Go `govulncheck` removed, Dart advisories review + exact-pin stays, `ptyc` gets a "read the 150 lines" review checklist (see `make security`).
- **Raised by:** 2026-04-20 reassessment. See also the `ptyc` naming note in the original ADR (read as Project Terminal Controller / PTY+C / PTY+child).

### D-006: CLI and event surface contract
- **Date:** 2026-04-20 (was ADR 0006)
- **Decision:** The CLI is organised into **subsystems**. Each subsystem owns a noun, a set of verbs, and a set of events. The set is closed at any point in time (documented); growth is additive (new verbs, new events — never renaming existing ones without a version bump). Initial subsystems (by tier): `pane`, `tab`, `open`, `editor`, `panel`, `tree`, `git`, `pql`, `canvas`, `graph`, `theme`, `settings`, `project`. Two umbrella entry points sit outside any subsystem: `clide tail --events [--filter <subsystem>[:<id>]]` and `clide status`. Command shape: `clide <subsystem> <verb> [<positional>...] [--flag ...] [-- argv...]`. Exit codes parity with pql (`0/1/2/3/4` + `64-78` sysexits reserved); diagnostic JSON on **stderr** on non-zero exit; stdout stays machine-parseable on success. Events are JSON objects, one per line, with `v`, `ts`, `type` (`<subsystem>.<verb_past|noun_changed>`), `subsystem`, `id`, and `payload`; binary payloads base64. Every state-changing command emits at least one event; read-only commands emit nothing. Replay buffer per subsystem (default depth 16) so late subscribers still see recent effects. Parity rule: every UI affordance has a matching CLI verb (or a follow-up task naming the verb); every CLI verb surfaces in the UI (or documents why it's Claude-only).
- **Context:** [D-001](#d-001-cli-first-not-mcp) established that Claude drives clide via a Bash CLI. That decided the *channel* — it did not define the *surface*. CLAUDE.md stated the rule colloquially ("every CLI subcommand has a UI affordance … if you add one side without the other, the feature is incomplete"); this record restates it as an implementable contract that satisfies user/Claude parity, daemon-as-authoritative-state, and pql-style ergonomics at once.
- **Rationale:** Surface is enumerable — adding a subsystem means adding a row and specifying verbs + events. Wire schema is versioned (`v: 1` starting point; compatibility breaks bump the major and land alongside a `project.yaml` `schema_version:` bump — see [Q-005](questions-architecture.md#q-005-ipc-wire-format-stability)). Events are the only UI→app state channel; the Flutter app does not poll. Extensions inherit this — a Dart extension publishes a subsystem; the same registration pipeline exposes it to Claude via the CLI.
- **Cost:** Replay-buffer memory per subsystem (cheap — most emit seldom). Back-pressure on firehose streams ([Q-002](questions-architecture.md#q-002-back-pressure-on-event-streams)), authorisation granularity ([Q-001](questions-architecture.md#q-001-authorisation-granularity)), and event persistence ([Q-003](questions-architecture.md#q-003-event-persistence-audit-undo)) are all deferred until Tier 1 is in real use.
- **Raised by:** 2026-04-20 planning.

---
