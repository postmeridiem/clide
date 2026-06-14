# Decisions, Questions, Rejected

This directory holds structured planning records that pql parses
into pql.db. Each record is a `### [DQR]-N: Title` heading inside
a markdown file. Files live in three per-type subdirectories:

- `decisions/<domain>.md` — confirmed design decisions
- `questions/<domain>.md` — open questions that may resolve into
  decisions or rejected proposals
- `rejected/<domain>.md` — rejected proposals (kept for the audit
  trail)

The parser infers domain from the filename stem and record type
from the parent subdirectory.

D-records that propose implementation work link to `initiative`-type
tickets via `decision_ref`. Run `pql decisions show <id>
--with-tickets` to inspect implementation status.

## Recommended domains

Start with this canonical set; create files as records land in
each domain:

- **architecture** — structural commitments (storage, layering,
  languages, libraries)
- **process** — team workflow (commits, branches, releases, reviews)
- **design** — user-facing surface (UX, UI, public APIs)
- **coding-conventions** — team-internal code shape (style, lint,
  file layout)
- **testing** — quality strategy (coverage, layers, gates)

You might also want, project-permitting:

- `accessibility` — if you ship user-facing software
- `security` — if you handle user data or network surfaces
- `licensing` — if you release open-source or commercial
- `documentation` — if user-docs are non-trivial
- `deployment` — if shipping is non-trivial
- `performance` — if you have perf budgets / SLOs

<!-- pql:records (auto-generated; do not edit manually) -->

## Decisions

- [D-1: CLI-first, not MCP](decisions/architecture.md#d-1-cli-first-not-mcp) — _architecture_
- [D-3: pql as supporter tool; clide wraps, never duplicates](decisions/architecture.md#d-3-pql-as-supporter-tool-clide-wraps-never-duplicates) — _architecture_
- [D-4: Ignore file strategy](decisions/architecture.md#d-4-ignore-file-strategy) — _architecture_
- [D-5: Dart core; sidecar dissolved; `ptyc` as pql-peer](decisions/architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer) — _architecture_
- [D-6: CLI and event surface contract](decisions/architecture.md#d-6-cli-and-event-surface-contract) — _architecture_
- [D-7: App root is bare `WidgetsApp`](decisions/architecture.md#d-7-app-root-is-bare-widgetsapp) — _architecture_
- [D-8: Feature-first folder layout](decisions/architecture.md#d-8-feature-first-folder-layout) — _architecture_
- [D-9: Three-tier theme pipeline](decisions/architecture.md#d-9-three-tier-theme-pipeline) — _architecture_
- [D-10: State management — `ChangeNotifier` + `ListenableBuilder`](decisions/architecture.md#d-10-state-management--changenotifier--listenablebuilder) — _architecture_
- [D-11: Panel manager is kernel; layout is data; three-column is a preset](decisions/architecture.md#d-11-panel-manager-is-kernel-layout-is-data-three-column-is-a-preset) — _architecture_
- [D-12: Kernel admission rule — mandatory shared singletons only](decisions/architecture.md#d-12-kernel-admission-rule--mandatory-shared-singletons-only) — _architecture_
- [D-13: Git hardcoded in kernel project-loader](decisions/architecture.md#d-13-git-hardcoded-in-kernel-project-loader) — _architecture_
- [D-14: Two-tier disable — kernel locked, everything else extension-shaped](decisions/architecture.md#d-14-two-tier-disable--kernel-locked-everything-else-extension-shaped) — _architecture_
- [D-15: Extension grain — container-level, multi-contribution](decisions/extensions.md#d-15-extension-grain--container-level-multi-contribution) — _extensions_
- [D-16: Built-ins in Dart, third-party in sandboxed Lua](decisions/extensions.md#d-16-built-ins-in-dart-third-party-in-sandboxed-lua) — _extensions_
- [D-17: Panels are extension-shaped from day one](decisions/extensions.md#d-17-panels-are-extension-shaped-from-day-one) — _extensions_
- [D-18: YAML for themes + manifests; JSON for i18n catalogs](decisions/extensions.md#d-18-yaml-for-themes--manifests-json-for-i18n-catalogs) — _extensions_
- [D-19: Lua runtime as `ptyc`-peer supporter tool](decisions/extensions.md#d-19-lua-runtime-as-ptyc-peer-supporter-tool) — _extensions_
- [D-20: A11y is a Tier-0 contract](decisions/accessibility.md#d-20-a11y-is-a-tier-0-contract) — _accessibility_
- [D-21: i18n is a Tier-0 contract (fframe pattern + locale-fallback chain)](decisions/accessibility.md#d-21-i18n-is-a-tier-0-contract-fframe-pattern--locale-fallback-chain) — _accessibility_
- [D-22: WCAG-AA contrast gate on bundled themes](decisions/accessibility.md#d-22-wcag-aa-contrast-gate-on-bundled-themes) — _accessibility_
- [D-23: Test pyramid — seven layers](decisions/testing.md#d-23-test-pyramid--seven-layers) — _testing_
- [D-24: Golden tests — primitives only, Alchemist + Ahem](decisions/testing.md#d-24-golden-tests--primitives-only-alchemist--ahem) — _testing_
- [D-25: Mocks — hand-rolled fakes throughout; mocktail dropped](decisions/testing.md#d-25-mocks--hand-rolled-fakes-throughout-mocktail-dropped) — _testing_
- [D-26: Web driver — raw Playwright + Flutter semantics](decisions/testing.md#d-26-web-driver--raw-playwright--flutter-semantics) — _testing_
- [D-27: Startup regression gate](decisions/testing.md#d-27-startup-regression-gate) — _testing_
- [D-28: Test organisation — mirror `lib/` in `test/`](decisions/testing.md#d-28-test-organisation--mirror-lib-in-test) — _testing_
- [D-29: Pre-push gate — fast layer only](decisions/testing.md#d-29-pre-push-gate--fast-layer-only) — _testing_
- [D-30: Tests are client-side only](decisions/testing.md#d-30-tests-are-client-side-only) — _testing_
- [D-31: Prefer-zero-deps, exact-pin](decisions/tooling.md#d-31-prefer-zero-deps-exact-pin) — _tooling_
- [D-32: CI — Gitea primary, Linux-only runners, not yet activated](decisions/tooling.md#d-32-ci--gitea-primary-linux-only-runners-not-yet-activated) — _tooling_
- [D-33: Golden-output ignore pattern — `coverage.*` excludes output, not scripts](decisions/tooling.md#d-33-golden-output-ignore-pattern--coverage-excludes-output-not-scripts) — _tooling_
- [D-34: Q&D record system](decisions/process.md#d-34-qd-record-system) — _process_
- [D-35: Kanban / waterfall, not Scrum](decisions/process.md#d-35-kanban--waterfall-not-scrum) — _process_
- [D-36: `.claude/` is committed project surface, managed through the IDE](decisions/process.md#d-36-claude-is-committed-project-surface-managed-through-the-ide) — _process_
- [D-37: Commit conventions per git-commit skill](decisions/process.md#d-37-commit-conventions-per-git-commit-skill) — _process_
- [D-38: Changelog discipline — Keep a Changelog 1.1.0](decisions/process.md#d-38-changelog-discipline--keep-a-changelog-110) — _process_
- [D-39: Planning tooling lives in pql, not clide](decisions/process.md#d-39-planning-tooling-lives-in-pql-not-clide) — _process_
- [D-40: [SUPERSEDED] Python stopgap under `tools/scripts/plan`](decisions/process.md#d-40-superseded-python-stopgap-under-toolsscriptsplan) — _process_
- [D-41: Claude panes — one primary per repo, tmux-backed](decisions/architecture.md#d-41-claude-panes--one-primary-per-repo-tmux-backed) — _architecture_
- [D-42: Dependencies documented in `licenses.yaml`](decisions/tooling.md#d-42-dependencies-documented-in-licensesyaml) — _tooling_
- [D-43: Design handoff — adopt token palettes, reject Material wrapper](decisions/architecture.md#d-43-design-handoff--adopt-token-palettes-reject-material-wrapper) — _architecture_
- [D-44: Four bundled themes — clide, midnight, paper, terminal](decisions/architecture.md#d-44-four-bundled-themes--clide-midnight-paper-terminal) — _architecture_
- [D-45: Syntax highlighting tokens in the theme pipeline](decisions/architecture.md#d-45-syntax-highlighting-tokens-in-the-theme-pipeline) — _architecture_
- [D-46: Core frame builtins vs shipped extensions boundary](decisions/extensions.md#d-46-core-frame-builtins-vs-shipped-extensions-boundary) — _extensions_
- [D-47: Interaction model — Claude-is-home layout](decisions/architecture.md#d-47-interaction-model--claude-is-home-layout) — _architecture_
- [D-48: Chrome budget — no tabs, no breadcrumbs, keyboard-first](decisions/architecture.md#d-48-chrome-budget--no-tabs-no-breadcrumbs-keyboard-first) — _architecture_
- [D-49: Editor mode — inline above Claude, viewer swap](decisions/architecture.md#d-49-editor-mode--inline-above-claude-viewer-swap) — _architecture_
- [D-50: Context auto-behavior — right panel reacts to Claude](decisions/architecture.md#d-50-context-auto-behavior--right-panel-reacts-to-claude) — _architecture_
- [D-51: Panel collapse — 12px spine with badge](decisions/architecture.md#d-51-panel-collapse--12px-spine-with-badge) — _architecture_
- [D-52: Focus mode — full-window takeover](decisions/architecture.md#d-52-focus-mode--full-window-takeover) — _architecture_
- [D-53: State persistence across sessions](decisions/architecture.md#d-53-state-persistence-across-sessions) — _architecture_
- [D-54: Keyboard map — canonical shortcuts](decisions/architecture.md#d-54-keyboard-map--canonical-shortcuts) — _architecture_
- [D-55: Claude pane internal tabs for multi-session](decisions/architecture.md#d-55-claude-pane-internal-tabs-for-multi-session) — _architecture_
- [D-56: Dissolve daemon process; Flutter app hosts IPC server](decisions/architecture.md#d-56-dissolve-daemon-process-flutter-app-hosts-ipc-server) — _architecture_
- [D-57: Frameless custom chrome with per-column 24px hats](decisions/architecture.md#d-57-frameless-custom-chrome-with-per-column-24px-hats) — _architecture_
- [D-58: Format engines are adoptable dependencies](decisions/tooling.md#d-58-format-engines-are-adoptable-dependencies) — _tooling_
- [D-59: Bundled git via dugite-native](decisions/tooling.md#d-59-bundled-git-via-dugite-native) — _tooling_
- [D-60: No network on default launch path](decisions/tooling.md#d-60-no-network-on-default-launch-path) — _tooling_
- [D-61: Dependency vetting checklist](decisions/tooling.md#d-61-dependency-vetting-checklist) — _tooling_
- [D-62: Dependency removal process](decisions/tooling.md#d-62-dependency-removal-process) — _tooling_
- [D-63: Vendored binary rebuild process](decisions/tooling.md#d-63-vendored-binary-rebuild-process) — _tooling_
- [D-64: No telemetry — architectural commitment](decisions/architecture.md#d-64-no-telemetry--architectural-commitment) — _architecture_
- [D-65: License compatibility matrix](decisions/tooling.md#d-65-license-compatibility-matrix) — _tooling_
- [D-66: Line coverage gate at 95%, ratcheted from current](decisions/testing.md#d-66-line-coverage-gate-at-95-ratcheted-from-current) — _testing_
- [D-67: Pql changelog files are committed alongside code](decisions/process.md#d-67-pql-changelog-files-are-committed-alongside-code) — _process_
- [D-68: Dual integration surface — Bash CLI primary, MCP secondary](decisions/architecture.md#d-68-dual-integration-surface--bash-cli-primary-mcp-secondary) — _architecture_
- [D-69: published themes are user contracts; ship -hc variants for a11y](decisions/accessibility.md#d-69-published-themes-are-user-contracts-ship--hc-variants-for-a11y) — _accessibility_
- [D-70: IPC socket path is per-workspace, deterministic](decisions/architecture.md#d-70-ipc-socket-path-is-per-workspace-deterministic) — _architecture_
- [D-71: IPC socket access gated by chmod 0600 on socket + parent](decisions/architecture.md#d-71-ipc-socket-access-gated-by-chmod-0600-on-socket--parent) — _architecture_
- [D-72: IPC server is multi-connection with serial dispatch on the main isolate](decisions/architecture.md#d-72-ipc-server-is-multi-connection-with-serial-dispatch-on-the-main-isolate) — _architecture_
- [D-73: MCP transport for /ide is SSE over HTTP](decisions/architecture.md#d-73-mcp-transport-for-ide-is-sse-over-http) — _architecture_
- [D-74: IPC command schema is co-registered with the handler, validated at dispatch](decisions/architecture.md#d-74-ipc-command-schema-is-co-registered-with-the-handler-validated-at-dispatch) — _architecture_
- [D-75: Claude rendered natively from transcripts; terminal retained as general tool only](decisions/architecture.md#d-75-claude-rendered-natively-from-transcripts-terminal-retained-as-general-tool-only) — _architecture_
- [D-76: ClaudeConfig — Claude's config surface is clide's app settings (builtin-owned, watched, probe-cached per version)](decisions/architecture.md#d-76-claudeconfig--claudes-config-surface-is-clides-app-settings-builtin-owned-watched-probe-cached-per-version) — _architecture_
- [D-77: Drive Claude via the stream-json control protocol; teams become a clide-owned coordination layer](decisions/architecture.md#d-77-drive-claude-via-the-stream-json-control-protocol-teams-become-a-clide-owned-coordination-layer) — _architecture_
- [D-78: Claude permission/prompt transport is the stdio control channel](decisions/architecture.md#d-78-claude-permissionprompt-transport-is-the-stdio-control-channel) — _architecture_
- [D-79: Workspace content search is a pure-Dart in-process engine, outside pql](decisions/architecture.md#d-79-workspace-content-search-is-a-pure-dart-in-process-engine-outside-pql) — _architecture_
- [D-80: `files.read` allows trusted Claude config roots beyond the workspace](decisions/architecture.md#d-80-filesread-allows-trusted-claude-config-roots-beyond-the-workspace) — _architecture_
- [D-81: Right-pane reader load is driven by a retained `ReaderNav`, not per-view state or bus retention](decisions/architecture.md#d-81-right-pane-reader-load-is-driven-by-a-retained-readernav-not-per-view-state-or-bus-retention) — _architecture_
- [D-82: Keymap sequences are space-separated; matching is a reusable matcher consumed at the interception point](decisions/architecture.md#d-82-keymap-sequences-are-space-separated-matching-is-a-reusable-matcher-consumed-at-the-interception-point) — _architecture_
- [D-83: Dogfood agent model — hosted stream-json session primary, external CLI driver secondary](decisions/architecture.md#d-83-dogfood-agent-model--hosted-stream-json-session-primary-external-cli-driver-secondary) — _architecture_
- [D-84: Diff view placement — editor-mode inline above Claude, spawned from the git sidebar](decisions/architecture.md#d-84-diff-view-placement--editor-mode-inline-above-claude-spawned-from-the-git-sidebar) — _architecture_
- [D-85: Event bus delivery — bounded ring-buffer back-pressure; in-memory cursor retention, bus-owned if persisted](decisions/architecture.md#d-85-event-bus-delivery--bounded-ring-buffer-back-pressure-in-memory-cursor-retention-bus-owned-if-persisted) — _architecture_
- [D-86: MCP tool surface — full clide namespace generated from the co-registered command registry](decisions/architecture.md#d-86-mcp-tool-surface--full-clide-namespace-generated-from-the-co-registered-command-registry) — _architecture_
- [D-87: Output/log dock — bottom, toggled, read-only (logs + problems)](decisions/architecture.md#d-87-outputlog-dock--bottom-toggled-read-only-logs--problems) — _architecture_
- [D-88: clide-owned anchored popover + menu primitive](decisions/design.md#d-88-clide-owned-anchored-popover--menu-primitive) — _design_
- [D-89: inline pasted-image thumbnails that expand to the lightbox](decisions/design.md#d-89-inline-pasted-image-thumbnails-that-expand-to-the-lightbox) — _design_
- [D-90: clide:// deep links — paranoid allowlist + user confirmation](decisions/architecture.md#d-90-clide-deep-links--paranoid-allowlist--user-confirmation) — _architecture_
- [D-91: Unified conversation drawing card backed by a canvas renderer](decisions/architecture.md#d-91-unified-conversation-drawing-card-backed-by-a-canvas-renderer) — _architecture_
- [D-92: Ship pql bundled with clide](decisions/tooling.md#d-92-ship-pql-bundled-with-clide) — _tooling_
- [D-93: clide writes no directories of its own into the workspace](decisions/architecture.md#d-93-clide-writes-no-directories-of-its-own-into-the-workspace) — _architecture_
- [D-94: Workspace mode is a first-class, extensible declared capability](decisions/architecture.md#d-94-workspace-mode-is-a-first-class-extensible-declared-capability) — _architecture_
- [D-95: Workspace validity and onboarding flow](decisions/architecture.md#d-95-workspace-validity-and-onboarding-flow) — _architecture_
- [D-96: Remote-execution footprint — no-install ssh-exec](decisions/architecture.md#d-96-remote-execution-footprint--no-install-ssh-exec) — _architecture_
- [D-97: ssh:// workspace URI + system-ssh auth](decisions/architecture.md#d-97-ssh-workspace-uri--system-ssh-auth) — _architecture_
- [D-98: Remote-tool contract + connect preflight](decisions/architecture.md#d-98-remote-tool-contract--connect-preflight) — _architecture_
- [D-99: Remote session identity keyed on (host, workspace)](decisions/architecture.md#d-99-remote-session-identity-keyed-on-host-workspace) — _architecture_

## Open questions

- [Q-1: Authorisation granularity on the IPC socket](questions/architecture.md#q-1-authorisation-granularity-on-the-ipc-socket) — _architecture_
- [Q-4: `.canvas` schema compatibility with Obsidian](questions/architecture.md#q-4-canvas-schema-compatibility-with-obsidian) — _architecture_
- [Q-5: IPC wire-format stability + `schema_version:`](questions/architecture.md#q-5-ipc-wire-format-stability--schema-version) — _architecture_
- [Q-7: macOS app bundle signing / notarisation](questions/architecture.md#q-7-macos-app-bundle-signing--notarisation) — _architecture_
- [Q-8: Extension API shape — widgets, subcommands, both?](questions/extensions.md#q-8-extension-api-shape--widgets-subcommands-both) — _extensions_
- [Q-9: Lua runtime vendoring](questions/extensions.md#q-9-lua-runtime-vendoring) — _extensions_
- [Q-10: Extension manifest `schema_version:`](questions/extensions.md#q-10-extension-manifest-schema-version) — _extensions_
- [Q-11: Coverage gates — hard thresholds vs soft reporting](questions/testing.md#q-11-coverage-gates--hard-thresholds-vs-soft-reporting) — _testing_
- [Q-12: Screen-reader automation (axe-core via Playwright)](questions/testing.md#q-12-screen-reader-automation-axe-core-via-playwright) — _testing_
- [Q-13: Web production-mode a11y](questions/accessibility.md#q-13-web-production-mode-a11y) — _accessibility_
- [Q-14: i18n plurals / gender / date-format tooling](questions/accessibility.md#q-14-i18n-plurals--gender--date-format-tooling) — _accessibility_
- [Q-15: Editor tab — full LSP vs tree-sitter-only highlight](questions/process.md#q-15-editor-tab--full-lsp-vs-tree-sitter-only-highlight) — _process_
- [Q-16: `tree-sitter-dart` grammar maintenance](questions/process.md#q-16-tree-sitter-dart-grammar-maintenance) — _process_
- [Q-17: Icon set growth](questions/process.md#q-17-icon-set-growth) — _process_
- [Q-18: Theme hot-reload in release builds](questions/process.md#q-18-theme-hot-reload-in-release-builds) — _process_
- [Q-20: Kernel DB service — namespaced SQL access?](questions/process.md#q-20-kernel-db-service--namespaced-sql-access) — _process_
- [Q-25: Body text face — mono everywhere vs Josefin Sans UI + mono code](questions/architecture.md#q-25-body-text-face--mono-everywhere-vs-josefin-sans-ui--mono-code) — _architecture_
- [Q-26: Small screen layout (< 1000px)](questions/architecture.md#q-26-small-screen-layout--1000px) — _architecture_
- [Q-27: Two-editor split](questions/architecture.md#q-27-two-editor-split) — _architecture_
- [Q-29: Branch picker location](questions/architecture.md#q-29-branch-picker-location) — _architecture_
- [Q-30: Focus behavior when editor is dirty and viewer is peeked](questions/architecture.md#q-30-focus-behavior-when-editor-is-dirty-and-viewer-is-peeked) — _architecture_
- [Q-31: XWayland fallback for frameless — proper Wayland protocol needed](questions/architecture.md#q-31-xwayland-fallback-for-frameless--proper-wayland-protocol-needed) — _architecture_
- [Q-34: How + when to surface the account/team token budget given upstream doesn't expose it](questions/architecture.md#q-34-how--when-to-surface-the-accountteam-token-budget-given-upstream-doesnt-expose-it) — _architecture_
- [Q-35: Agent Blame + Session Flight Recorder — implement?](questions/design.md#q-35-agent-blame--session-flight-recorder--implement) — _design_
- [Q-36: Context X-ray — implement?](questions/design.md#q-36-context-x-ray--implement) — _design_
- [Q-37: Trust Ledger + decision-aware permission prompts — implement?](questions/design.md#q-37-trust-ledger--decision-aware-permission-prompts--implement) — _design_
- [Q-38: Agent Activity HUD — implement?](questions/design.md#q-38-agent-activity-hud--implement) — _design_
- [Q-39: Active Ticket Context — implement?](questions/design.md#q-39-active-ticket-context--implement) — _design_
- [Q-40: Twin-timeline rewind — implement?](questions/design.md#q-40-twin-timeline-rewind--implement) — _design_
- [Q-41: Visual Dialog — one bidirectional scene schema — implement?](questions/design.md#q-41-visual-dialog--one-bidirectional-scene-schema--implement) — _design_
- [Q-42: Immortal terminals — implement?](questions/design.md#q-42-immortal-terminals--implement) — _design_
- [Q-43: Local cost ledger — implement?](questions/design.md#q-43-local-cost-ledger--implement) — _design_
- [Q-44: Label-routed work queues / ticket dispatch — implement?](questions/design.md#q-44-label-routed-work-queues--ticket-dispatch--implement) — _design_
- [Q-45: Semantic terminal — implement?](questions/design.md#q-45-semantic-terminal--implement) — _design_
- [Q-46: Living codebase map — implement?](questions/design.md#q-46-living-codebase-map--implement) — _design_
- [Q-47: Live mixed documents — implement?](questions/design.md#q-47-live-mixed-documents--implement) — _design_
- [Q-48: Sealed-workspace mode — implement?](questions/design.md#q-48-sealed-workspace-mode--implement) — _design_
- [Q-49: Review honorable mentions — which, if any, get promoted?](questions/design.md#q-49-review-honorable-mentions--which-if-any-get-promoted) — _design_
- [Q-50: Web/WASM target after the dart:ffi pivot — fence, fix, or drop?](questions/architecture.md#q-50-webwasm-target-after-the-dartffi-pivot--fence-fix-or-drop) — _architecture_
- [Q-51: Unify workspace lifecycle on a single fenced open primitive](questions/architecture.md#q-51-unify-workspace-lifecycle-on-a-single-fenced-open-primitive) — _architecture_

## Resolved questions

- [Q-2: Back-pressure on event streams](questions/architecture.md#q-2-back-pressure-on-event-streams) — _architecture_
- [Q-3: Event persistence + audit/undo](questions/architecture.md#q-3-event-persistence--auditundo) — _architecture_
- [Q-6: Window chrome — native frame vs frameless custom](questions/architecture.md#q-6-window-chrome--native-frame-vs-frameless-custom) — _architecture_
- [Q-19: (withdrawn)](questions/process.md#q-19-withdrawn) — _process_
- [Q-21: Pql absorbs planning vs keeps separate](questions/architecture.md#q-21-pql-absorbs-planning-vs-keeps-separate) — _architecture_
- [Q-22: Ticket persistence strategy](questions/architecture.md#q-22-ticket-persistence-strategy) — _architecture_
- [Q-23: SSH-remote development — run clide against a remote workspace](questions/architecture.md#q-23-ssh-remote-development--run-clide-against-a-remote-workspace) — _architecture_
- [Q-28: Terminal strip scope — shell only or logs/errors/tests](questions/architecture.md#q-28-terminal-strip-scope--shell-only-or-logserrorstests) — _architecture_
- [Q-32: MCP tool surface — minimum slash-ide or extended clide tools?](questions/architecture.md#q-32-mcp-tool-surface--minimum-slash-ide-or-extended-clide-tools) — _architecture_
- [Q-33: MCP transport — SSE, WebSocket, stdio, or all?](questions/architecture.md#q-33-mcp-transport--sse-websocket-stdio-or-all) — _architecture_

## Rejected

- [R-2: Go sidecar](rejected/architecture.md#r-2-go-sidecar) — _architecture_
- [R-3: `MaterialApp` root](rejected/architecture.md#r-3-materialapp-root) — _architecture_
- [R-4: Flutter `intl` + ARB codegen for i18n](rejected/accessibility.md#r-4-flutter-intl--arb-codegen-for-i18n) — _accessibility_
- [R-5: Patrol test runner](rejected/testing.md#r-5-patrol-test-runner) — _testing_
- [R-6: Nerd-font glyph icons](rejected/process.md#r-6-nerd-font-glyph-icons) — _process_
- [R-7: `CupertinoApp` root](rejected/architecture.md#r-7-cupertinoapp-root) — _architecture_
- [R-8: Riverpod / Provider / BLoC for state](rejected/architecture.md#r-8-riverpod--provider--bloc-for-state) — _architecture_
- [R-9: Port planning tooling into clide](rejected/process.md#r-9-port-planning-tooling-into-clide) — _process_
- [R-10: Python-script stopgap under `tooling/db/`](rejected/process.md#r-10-python-script-stopgap-under-toolingdb) — _process_
- [R-11: Permanent stopgap](rejected/process.md#r-11-permanent-stopgap) — _process_
- [R-12: MaterialApp wrapper from design handoff](rejected/architecture.md#r-12-materialapp-wrapper-from-design-handoff) — _architecture_
