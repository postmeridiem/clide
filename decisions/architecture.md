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
- **Amendment (2026-04-23):** The separate daemon process and two-package layout are dissolved per [D-056](#d-056-dissolve-daemon-process-flutter-app-hosts-ipc-server). Dart-core and ptyc-as-peer principles survive; the daemon binary does not.
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

### D-043: Design handoff — adopt token palettes, reject Material wrapper
- **Date:** 2026-04-22
- **Decision:** The claude.ai/design handoff (`docs/claude-design/`) delivers hi-fi mockups, interaction flows, a design system, and four theme palettes (clide, midnight, paper, terminal) as Dart files using `MaterialApp`/`ThemeData`. We adopt the colour tokens, layout annotations, typography direction, and syntax highlighting palettes. We reject the `MaterialApp` wrapper — tokens are translated into our existing YAML theme pipeline and `SurfaceTokens` (per [D-007](#d-007-app-root-is-bare-widgetsapp)). The design files stay in `docs/claude-design/` as reference; they are not runtime assets.
- **Rationale:** The design's value is in the palette + layout + component vocabulary, not in the delivery format. Material's `ThemeData` fights our bare-`WidgetsApp` + `CustomPaint` stance. Translating tokens preserves design intent without absorbing Material's widget opinions.
- **Cost:** Manual translation of four theme files into YAML. Ongoing: any design refresh needs the same translation pass.
- **Cross-reference:** [D-007](#d-007-app-root-is-bare-widgetsapp), [D-009](#d-009-three-tier-theme-pipeline), [R-012](rejected.md#r-012-materialapp-wrapper-from-design-handoff).
- **Raised by:** 2026-04-22 design handoff review.

### D-044: Four bundled themes — clide, midnight, paper, terminal
- **Date:** 2026-04-22
- **Decision:** Ship four bundled themes replacing the single summer-night preset. `clide` (cool near-black + periwinkle, default), `midnight` (VS Code-adjacent muted dark), `paper` (drafting-sheet light), `terminal` (near-black + amber). All share the same semantic token names. Source palettes in `docs/claude-design/themes/`; runtime YAML under `lib/kernel/src/theme/themes/`.
- **Rationale:** Summer-night was a placeholder carried from the legacy TUI. The design system delivers a coherent set of four that covers dark, muted-dark, light, and monochrome workflows.
- **Cost:** Summer-night users lose their theme (acceptable — it was dev-only). Four YAML files to maintain.
- **Cross-reference:** [D-043](#d-043-design-handoff-adopt-token-palettes-reject-material-wrapper), [D-022](accessibility.md#d-022-wcag-aa-contrast-gate-on-bundled-themes).
- **Raised by:** 2026-04-22 design handoff review.

### D-045: Syntax highlighting tokens in the theme pipeline
- **Date:** 2026-04-22
- **Decision:** Add syntax-role colour tokens to `SurfaceTokens`: keyword, type, string, number, comment, method, punctuation. Each bundled theme defines these. The editor and diff views consume them; tree-sitter (when it lands per [Q-015](questions-architecture.md#q-015-editor-tab-full-lsp-vs-tree-sitter-only)) maps grammar scopes to these tokens.
- **Rationale:** The design system ships syntax palettes per theme. Adding them now means the token surface is ready when syntax highlighting lands.
- **Cost:** Seven new fields on `SurfaceTokens`. Default resolution falls back to semantic roles (keyword → accent, comment → textMuted, etc.) so themes that don't declare syntax tokens still compile.
- **Raised by:** 2026-04-22 design handoff review.

### D-047: Interaction model — Claude-is-home layout
- **Date:** 2026-04-22
- **Decision:** The prompt bar is pinned to a fixed Y-position in the middle column; every other surface makes room *around* Claude — never on top, never pushing the prompt off-Y. Three hard rules: (1) prompt bar Y-position is invariant across all states (open, collapsed, focus, editor, viewer); (2) the three bottom strips (left icon rail, app strip, right icon rail) align to one continuous horizontal line; (3) Claude is always the largest surface when present. The three-column layout from [D-011](#d-011-panel-manager-is-kernel-layout-is-data-three-column-is-a-preset) is refined: left = overview (tickets, decisions, files, git, PRs), middle = Claude (+ optional editor above), right = context (viewer, pql graph, links, images). Both side panels have a bottom icon rail for section switching; keyboard: `⌥1–5` (left), context-type switcher (right).
- **Rationale:** "Claude is home" means the prompt never moves, regardless of what opens or closes around it. Every layout mutation respects this invariant. The three-column refinement assigns purpose to columns rather than leaving them generic.
- **Cost:** The prompt bar invariant constrains future layout presets — any preset that repositions Claude must explicitly break this rule. Editor mode (see [D-049](#d-049-editor-mode-inline-above-claude-viewer-swap)) is the only case where another surface shares the middle column, and it opens *above* Claude rather than displacing it.
- **Cross-reference:** [D-011](#d-011-panel-manager-is-kernel-layout-is-data-three-column-is-a-preset), [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first), [D-049](#d-049-editor-mode-inline-above-claude-viewer-swap).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-048: Chrome budget — no tabs, no breadcrumbs, keyboard-first
- **Date:** 2026-04-22
- **Decision:** Clide deletes classic IDE chrome: no buffer tabs, no breadcrumbs, no VS Code-style activity bar, no separate status bar row (merged into app strip). Total persistent chrome: 2 edge arrows (collapse toggles), 1 hover-only `⛶` glyph per panel (focus mode), 0 always-visible buttons beyond icon rails. `⌘P` overlay is the fuzzy finder — no layout shift. Keyboard is the primary interaction surface; icons are escape hatches. Files open individually; opening a second file closes the first (split on explicit command — deferred, see [Q-027](questions-architecture.md#q-027-two-editor-split)).
- **Rationale:** Every pixel of chrome that isn't Claude is a tax on the "Claude is home" principle. Tabs and breadcrumbs are navigation affordances for a multi-buffer editor; clide's editor is a secondary surface (viewer ↔ editor swap per [D-049](#d-049-editor-mode-inline-above-claude-viewer-swap)), not a primary one. The fuzzy finder (`⌘P`) replaces all navigation chrome.
- **Cost:** Users accustomed to VS Code/IntelliJ tab workflows have no tabs to fall back on. Mitigated by `⌘P` fuzzy find being the universal navigation path. Resolves T-022 (multi-buffer editor tabs) as rejected in favour of this approach.
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-049](#d-049-editor-mode-inline-above-claude-viewer-swap).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-049: Editor mode — inline above Claude, viewer swap
- **Date:** 2026-04-22
- **Decision:** Editor invoked via `⌘E` on a file or `✎` icon in a viewer. Editor lifts *above* Claude in the middle column, occupying 30–40% of vertical space; Claude keeps the remainder; prompt bar Y unchanged. Close with `⌘W`. Draggable divider between editor and Claude. The viewer (`👁`) and editor (`✎`) are mutually exclusive for the same file — a `✎` click on a viewer promotes the file to editor in the middle column and snaps the right panel back to nav; a `👁` click on an editor demotes the file to viewer in the right panel and closes the editor. Different files can coexist (editor on `main.dart` + viewer on `README.md`). When editor is open on `.md`, the viewer auto-opens with live sync to editor content; no auto-viewer for non-renderable files (`.dart`, `.yaml`, etc.).
- **Rationale:** The editor is not a primary surface — it's a temporary intervention. Claude's prompt bar must never move ([D-047](#d-047-interaction-model-claude-is-home-layout)), so the editor opens above, not replacing. The viewer ↔ editor swap prevents two surfaces showing the same file simultaneously, which simplifies state management and avoids confusion about which surface is authoritative.
- **Cost:** Only one file in the editor at a time (no tabs per [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first)). Power users wanting two files side-by-side must wait for split (see [Q-027](questions-architecture.md#q-027-two-editor-split)).
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-050: Context auto-behavior — right panel reacts to Claude
- **Date:** 2026-04-22
- **Decision:** The right panel responds to Claude's content references automatically: (1) right open + empty → panel holds footprint, stays empty; (2) right open + viewer loaded + Claude links `foo.md` → swap in, replaces current viewer; (3) right collapsed + Claude links `foo.md` → badge on spine ("2"), no layout shift; (4) editor open on `.md` → viewer auto-opens with live sync; (5) editor on non-renderable file → no auto-viewer.
- **Rationale:** Claude is the driver; the context panel is reactive. Auto-swapping when the panel is open reduces user clicks. Badging when collapsed respects the user's decision to collapse — no involuntary layout shifts.
- **Cost:** The auto-swap requires the daemon (or Claude integration) to emit structured content references, not just terminal text. This implies a lightweight parser or event that identifies file references in Claude's output — deferred to implementation.
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-051](#d-051-panel-collapse-12px-spine-with-badge).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-051: Panel collapse — 12px spine with badge
- **Date:** 2026-04-22
- **Decision:** When collapsed, a panel becomes a 12px spine: vertically rotated label ("tickets" / "context"), no icon rail, `paper-2` background (slightly darker than main paper), border on inner edge only. Click anywhere on spine to expand. If a context badge is pending (e.g. Claude linked a file while collapsed): small filled dot with count at top of spine. Edge arrow on outer boundary toggles collapse; keyboard: `⌘⇧1` (left) / `⌘⇧3` (right). Expand restores prior size and section state.
- **Rationale:** Collapsed panels must not consume significant horizontal space (12px = 1 icon-width) but must remain discoverable and able to signal pending content. The badge-on-spine avoids involuntary expand while still communicating that something arrived.
- **Cost:** The spine replaces the current simple `setVisible(false)` toggle with a real collapsed-state widget. Collapse state must be persisted across sessions (see [D-053](#d-053-state-persistence-across-sessions)).
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-050](#d-050-context-auto-behavior-right-panel-reacts-to-claude).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-052: Focus mode — full-window takeover
- **Date:** 2026-04-22
- **Decision:** Focus mode entered via double-click on panel header, hover-visible `⛶` glyph in header, or `⌘.`. Active panel takes the full window; all others hidden. Header shows "Esc" hint. `Esc` restores the exact prior layout (collapse state, divider positions, active sections). Focus mode is per-panel, not per-tab.
- **Rationale:** When the user wants to concentrate on a single surface — Claude conversation, file tree, diff view — they shouldn't have to manually collapse both side panels. Focus mode is a single-action "maximise and restore" with no state loss.
- **Cost:** Must snapshot and restore full `LayoutArrangement` state on enter/exit. Interacts with responsive behaviour — focus mode at narrow widths should work identically.
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-053](#d-053-state-persistence-across-sessions).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-053: State persistence across sessions
- **Date:** 2026-04-22
- **Decision:** The following layout state is persisted across app restarts: collapse state of left and right panels, active left section (tickets/decisions/files/git/pr), active right context type, pql pane expanded/collapsed, editor split ratio when open, fuzzy find recent picks. Stored via `SettingsStore` in project-scoped settings (`.clide/settings.yaml`).
- **Rationale:** Users expect their workspace layout to survive restarts. Without persistence, every launch starts at the default layout preset, which is disorienting when the user has customised their column widths and panel states.
- **Cost:** Adds write-on-change to several layout operations. Must handle migration if the setting keys evolve. `.clide/settings.yaml` is already gitignored, so personal layout state stays personal.
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-051](#d-051-panel-collapse-12px-spine-with-badge), [D-052](#d-052-focus-mode-full-window-takeover).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-054: Keyboard map — canonical shortcuts
- **Date:** 2026-04-22
- **Decision:** Canonical keyboard shortcuts (cross-platform, `⌘` = `Ctrl` on Linux): `⌘P` fuzzy find overlay; `⌘⇧1` / `⌘⇧3` collapse/expand left / right panel; `⌘1` / `⌘2` / `⌘3` focus left / middle / right panel; `⌘.` toggle focus mode on focused panel; `⌥1–⌥5` left-panel section switch (tickets, decisions, files, git, pr); `⌘E` open current file in editor; `⌘W` close editor / dismiss viewer; `Esc` exit focus mode / close fuzzy finder / dismiss viewer. Responsive breakpoints: ≥ 1600px splits relax toward 30%; 1200–1600px default (L 200px, R 220px, middle flex); < 1200px splits toward 40%, consider auto-collapse right; < 1000px deferred (see [Q-026](questions-architecture.md#q-026-small-screen-layout)).
- **Rationale:** These shortcuts follow the "keyboard is the primary surface" principle from [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first). The set is minimal and covers all layout operations. `⌘.` for focus mode follows VS Code precedent (quick-fix → general "do the thing").
- **Cost:** Some shortcuts may conflict with OS-level bindings on specific Linux desktops; the keybinding resolver ([D-017](extensions.md#d-017-panels-are-extension-shaped-from-day-one)) allows user override.
- **Cross-reference:** [D-047](#d-047-interaction-model-claude-is-home-layout), [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first), [D-052](#d-052-focus-mode-full-window-takeover).
- **Raised by:** 2026-04-22 interaction model spec (Wireframe — Flows v3).

### D-055: Claude pane internal tabs for multi-session
- **Date:** 2026-04-23
- **Decision:** Multiple Claude sessions share the workspace as internal tabs inside the Claude pane header — not as workspace-level tabs (which would violate [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first)). The primary session tab has no close affordance (per [D-041](#d-041-claude-panes-one-primary-per-repo-tmux-backed)). Secondary session tabs show a close `×`. A small `+` button sits at the right end of the tab row to spawn a new secondary. Double-clicking empty space in the tab row also spawns a new secondary. When a secondary is closed, focus collapses to the most-recently-active remaining tab (primary or another secondary). The tab row is hidden when only the primary exists — it appears on first secondary spawn and disappears when the last secondary closes. Session names in the tab row use the tmux session name slug (readable path, per the session naming convention).
- **Amendment to [D-041](#d-041-claude-panes-one-primary-per-repo-tmux-backed):** D-041 defined the lifecycle (primary persists, secondaries are ephemeral, close semantics) but left the multi-session UI unspecified. This record fills that gap. The `claude.new-secondary` command (already registered but not wired) is the spawn mechanism; the tab row is the UI surface.
- **Rationale:** The workspace is Claude's space ([D-047](#d-047-interaction-model-claude-is-home-layout)). Multiple Claude sessions are a Claude concern, not a workspace concern. Internal tabs keep the multiplicity contained — the workspace slot doesn't know how many sessions exist, it just renders the Claude pane. The hide-when-one rule keeps the common case (single primary) chrome-free.
- **Cost:** The Claude pane grows its own tab model (lightweight — just a list of session IDs + which is active). The `builtin.claude` extension owns this; no kernel changes needed.
- **Cross-reference:** [D-041](#d-041-claude-panes-one-primary-per-repo-tmux-backed), [D-047](#d-047-interaction-model-claude-is-home-layout), [D-048](#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first).
- **Raised by:** 2026-04-23 interaction model refinement.

### D-056: Dissolve daemon process; Flutter app hosts IPC server
- **Date:** 2026-04-23
- **Decision:** The separate Dart daemon process (`clide --daemon`) and the two-package repo layout (`lib/` core + `app/` Flutter) are dissolved. The Flutter app moves to the repo root (one `pubspec.yaml`) and hosts the IPC server in-process. All subsystem handlers (pane, files, editor, git, pql) run inside the Flutter process. The `bin/clide.dart` AOT binary is removed. The CLI surface for Claude (`clide <command>`) becomes a thin C client — either a new peer of `ptyc` or a mode within `ptyc` itself — that connects to the app's unix socket, sends a JSON-lines request, prints the response, and exits. tmux owns session persistence (it already did per [D-041](#d-041-claude-panes-one-primary-per-repo-tmux-backed)); the daemon's PTY ownership was redundant.
- **Amendment to [D-005](#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer):** D-005's "two execution modes of one Dart AOT binary" premise assumed the daemon needed to outlive the app to preserve PTY sessions. tmux already solves this — `tmux new-session -A` re-attaches regardless of which process originally spawned it. The daemon process added complexity (two packages, two build targets, IPC client/server split, process lifecycle management) without a benefit tmux doesn't already provide. D-005's other principles survive: Dart is the core language, `ptyc` is a C peer of pql, one language for the IDE proper.
- **Repo layout after dissolution:**
  - `/pubspec.yaml` — single Flutter package (was `app/pubspec.yaml`)
  - `/lib/` — all Dart code: kernel, extensions, widgets, subsystem handlers
  - `/bin/` — empty or removed (CLI is a C binary now)
  - `/test/` — all tests
  - `/assets/` — fonts, themes, grammars, licenses
  - `/ptyc/` — C PTY helper (unchanged)
  - `/native/` — vendored native libs (libtree-sitter.so)
  - `/decisions/`, `/docs/`, `/legacy/` — unchanged
- **Rationale:** One package means one `pubspec.yaml`, one `flutter analyze`, one `flutter test`, no `cd` gymnastics, no cross-package import barriers. The IPC server running in-process eliminates the daemon lifecycle (start, stop, reconnect, pid file). If the app crashes, tmux sessions survive; the app re-attaches on restart. The CLI client in C is ~100 lines (socket connect + JSON exchange) with the same contract as pql.
- **Cost:** If the Flutter app is not running, Claude's `clide` commands fail. In practice this is acceptable — the IDE being closed means the user isn't working. A future "headless mode" could start the Flutter engine without a window if needed.
- **Cross-reference:** [D-005](#d-005-dart-core-sidecar-dissolved-ptyc-as-pql-peer) (amended), [D-041](#d-041-claude-panes-one-primary-per-repo-tmux-backed) (tmux persistence), [D-001](#d-001-cli-first-not-mcp) (CLI-first surface preserved via C client).
- **Raised by:** 2026-04-23 architectural simplification.

---
