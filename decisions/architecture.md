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

*Architectural backlog from the claudian lineage lives below; ADR
migrations (D-001, D-003, D-004, D-005, D-006) follow when commit #2
runs.*
