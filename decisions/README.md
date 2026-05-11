# Decisions

Confirmed decisions, open questions, and rejected alternatives for clide.

Decisions are split by domain. When unsure where a record belongs: if
it constrains **how we build**, it's architecture. If it defines **what
ships to users**, it's extensions / accessibility. If it defines **how
we verify**, it's testing. If it defines **what the toolchain looks
like**, it's tooling. If it defines **how the team works**, it's
process.

Cross-domain records live in one file with `[D-NNN]`-shaped cross-
references in related files. Split threshold: when any file exceeds
~350 lines, review whether it should split (see settled-reach's
`questions-*.md` split pattern for precedent).

## Domain files

| File | Domain |
|------|--------|
| [architecture.md](architecture.md) | Core, rendering, IPC, kernel, panel manager |
| [extensions.md](extensions.md) | Extension contract, Lua runtime, grain, contribution points |
| [accessibility.md](accessibility.md) | A11y + i18n policy, WCAG gates |
| [testing.md](testing.md) | Test pyramid, drivers, client-side constraint |
| [tooling.md](tooling.md) | Toolchain, supply chain, CI, ignore strategy |
| [process.md](process.md) | Q&D system, kanban, commit conventions, changelog |
| [rejected.md](rejected.md) | Rejected alternatives across all domains |
| [questions.md](questions.md) | Master index of open questions |
| [questions-architecture.md](questions-architecture.md) | Architecture Qs |
| [questions-extensions.md](questions-extensions.md) | Extension Qs |
| [questions-accessibility.md](questions-accessibility.md) | A11y / i18n Qs |
| [questions-testing.md](questions-testing.md) | Testing Qs |
| [questions-process.md](questions-process.md) | Process + tooling Qs |

## Record shape

Confirmed decisions (`D-NNN`):

```markdown
### D-NNN: Short title
- **Date:** YYYY-MM-DD
- **Decision:** one-sentence summary, then details.
- **Rationale:** why this over alternatives.
- **Cost:** known downsides / what we're accepting.
- **Raised by:** who proposed / endorsed.
```

Domain-specific fields (`Kill switch:`, `Evaluation reports:`,
`Amendment:`, `Cross-reference:`) are additive. Amendments are inline
and dated: `**Amendment (YYYY-MM-DD):** …`. Cross-references use
markdown anchor links with the full slug:
`[D-5](architecture.md#d-5-dart-core-ptyc-peer)`.

Open questions (`Q-NNN`):

```markdown
### Q-NNN: Short question-form title
- **Status:** Open | Partially resolved → [D-NNN] | Resolved → [D-NNN]
- **Question:** ...
- **Context:** ...
- **Assigned to:** (optional)
- **Source:** (optional)
```

Rejected alternatives (`R-NNN`):

```markdown
### R-NNN: Short rejected-option title
- **Rejected:** YYYY-MM-DD
- **Reason:** ...
- **Cross-reference:** [D-NNN] (what was picked instead)
```

## Claiming an ID

Until the pql planning subcommands land ([`Q-21`](questions-process.md)),
claim IDs by inspecting the highest existing `D-NNN` / `Q-NNN` /
`R-NNN` in the target file and incrementing.

Once `pql decisions claim D <domain> "title"` exists, use that —
same semantics, no race on concurrent sessions.

## Querying

`pql decisions …` reads `decisions/*.md` and writes `.pql/pql.db`
(gitignored; markdown is the source of truth).

Common queries:

```bash
pql decisions list --type confirmed --domain architecture
pql decisions show D-5 --with-refs
pql decisions coverage     # D-records without tickets
pql decisions validate     # pre-push parser gate
pql ticket board           # kanban view of tickets
```

## Adding a decision

1. Edit the appropriate domain file.
2. Follow the record shape above.
3. Run `pql decisions validate` (also runs in `make push-check`).
4. Commit. The SQLite index rebuilds from markdown on any
   `pql decisions sync`.

<!-- pql:records (auto-generated; do not edit manually) -->

## Decisions

- [D-1: CLI-first, not MCP](architecture.md#d-1-cli-first-not-mcp) — _architecture_
- [D-3: pql as supporter tool; clide wraps, never duplicates](architecture.md#d-3-pql-as-supporter-tool-clide-wraps-never-duplicates) — _architecture_
- [D-4: Ignore file strategy](architecture.md#d-4-ignore-file-strategy) — _architecture_
- [D-5: Dart core; sidecar dissolved; `ptyc` as pql-peer](architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer) — _architecture_
- [D-6: CLI and event surface contract](architecture.md#d-6-cli-and-event-surface-contract) — _architecture_
- [D-7: App root is bare `WidgetsApp`](architecture.md#d-7-app-root-is-bare-widgetsapp) — _architecture_
- [D-8: Feature-first folder layout](architecture.md#d-8-feature-first-folder-layout) — _architecture_
- [D-9: Three-tier theme pipeline](architecture.md#d-9-three-tier-theme-pipeline) — _architecture_
- [D-10: State management — `ChangeNotifier` + `ListenableBuilder`](architecture.md#d-10-state-management--changenotifier--listenablebuilder) — _architecture_
- [D-11: Panel manager is kernel; layout is data; three-column is a preset](architecture.md#d-11-panel-manager-is-kernel-layout-is-data-three-column-is-a-preset) — _architecture_
- [D-12: Kernel admission rule — mandatory shared singletons only](architecture.md#d-12-kernel-admission-rule--mandatory-shared-singletons-only) — _architecture_
- [D-13: Git hardcoded in kernel project-loader](architecture.md#d-13-git-hardcoded-in-kernel-project-loader) — _architecture_
- [D-14: Two-tier disable — kernel locked, everything else extension-shaped](architecture.md#d-14-two-tier-disable--kernel-locked-everything-else-extension-shaped) — _architecture_
- [D-15: Extension grain — container-level, multi-contribution](extensions.md#d-15-extension-grain--container-level-multi-contribution) — _extensions_
- [D-16: Built-ins in Dart, third-party in sandboxed Lua](extensions.md#d-16-built-ins-in-dart-third-party-in-sandboxed-lua) — _extensions_
- [D-17: Panels are extension-shaped from day one](extensions.md#d-17-panels-are-extension-shaped-from-day-one) — _extensions_
- [D-18: YAML for themes + manifests; JSON for i18n catalogs](extensions.md#d-18-yaml-for-themes--manifests-json-for-i18n-catalogs) — _extensions_
- [D-19: Lua runtime as `ptyc`-peer supporter tool](extensions.md#d-19-lua-runtime-as-ptyc-peer-supporter-tool) — _extensions_
- [D-20: A11y is a Tier-0 contract](accessibility.md#d-20-a11y-is-a-tier-0-contract) — _accessibility_
- [D-21: i18n is a Tier-0 contract (fframe pattern + locale-fallback chain)](accessibility.md#d-21-i18n-is-a-tier-0-contract-fframe-pattern--locale-fallback-chain) — _accessibility_
- [D-22: WCAG-AA contrast gate on bundled themes](accessibility.md#d-22-wcag-aa-contrast-gate-on-bundled-themes) — _accessibility_
- [D-23: Test pyramid — seven layers](testing.md#d-23-test-pyramid--seven-layers) — _testing_
- [D-24: Golden tests — primitives only, Alchemist + Ahem](testing.md#d-24-golden-tests--primitives-only-alchemist--ahem) — _testing_
- [D-25: Mocks — mocktail at IO, hand-rolled fakes for ChangeNotifiers](testing.md#d-25-mocks--mocktail-at-io-hand-rolled-fakes-for-changenotifiers) — _testing_
- [D-26: Web driver — raw Playwright + Flutter semantics](testing.md#d-26-web-driver--raw-playwright--flutter-semantics) — _testing_
- [D-27: Startup regression gate](testing.md#d-27-startup-regression-gate) — _testing_
- [D-28: Test organisation — mirror `lib/` in `test/`](testing.md#d-28-test-organisation--mirror-lib-in-test) — _testing_
- [D-29: Pre-push gate — fast layer only](testing.md#d-29-pre-push-gate--fast-layer-only) — _testing_
- [D-30: Tests are client-side only](testing.md#d-30-tests-are-client-side-only) — _testing_
- [D-31: Prefer-zero-deps, exact-pin](tooling.md#d-31-prefer-zero-deps-exact-pin) — _tooling_
- [D-32: CI — Gitea primary, Linux-only runners, not yet activated](tooling.md#d-32-ci--gitea-primary-linux-only-runners-not-yet-activated) — _tooling_
- [D-33: Golden-output ignore pattern — `coverage.*` excludes output, not scripts](tooling.md#d-33-golden-output-ignore-pattern--coverage-excludes-output-not-scripts) — _tooling_
- [D-34: Q&D record system](process.md#d-34-qd-record-system) — _process_
- [D-35: Kanban / waterfall, not Scrum](process.md#d-35-kanban--waterfall-not-scrum) — _process_
- [D-36: `.claude/` is committed project surface, managed through the IDE](process.md#d-36-claude-is-committed-project-surface-managed-through-the-ide) — _process_
- [D-37: Commit conventions per git-commit skill](process.md#d-37-commit-conventions-per-git-commit-skill) — _process_
- [D-38: Changelog discipline — Keep a Changelog 1.1.0](process.md#d-38-changelog-discipline--keep-a-changelog-110) — _process_
- [D-39: Planning tooling lives in pql, not clide](process.md#d-39-planning-tooling-lives-in-pql-not-clide) — _process_
- [D-40: [SUPERSEDED] Python stopgap under `tools/scripts/plan`](process.md#d-40-superseded-python-stopgap-under-toolsscriptsplan) — _process_
- [D-41: Claude panes — one primary per repo, tmux-backed](architecture.md#d-41-claude-panes--one-primary-per-repo-tmux-backed) — _architecture_
- [D-42: Dependencies documented in `licenses.yaml`](tooling.md#d-42-dependencies-documented-in-licensesyaml) — _tooling_
- [D-43: Design handoff — adopt token palettes, reject Material wrapper](architecture.md#d-43-design-handoff--adopt-token-palettes-reject-material-wrapper) — _architecture_
- [D-44: Four bundled themes — clide, midnight, paper, terminal](architecture.md#d-44-four-bundled-themes--clide-midnight-paper-terminal) — _architecture_
- [D-45: Syntax highlighting tokens in the theme pipeline](architecture.md#d-45-syntax-highlighting-tokens-in-the-theme-pipeline) — _architecture_
- [D-46: Core frame builtins vs shipped extensions boundary](extensions.md#d-46-core-frame-builtins-vs-shipped-extensions-boundary) — _extensions_
- [D-47: Interaction model — Claude-is-home layout](architecture.md#d-47-interaction-model--claude-is-home-layout) — _architecture_
- [D-48: Chrome budget — no tabs, no breadcrumbs, keyboard-first](architecture.md#d-48-chrome-budget--no-tabs-no-breadcrumbs-keyboard-first) — _architecture_
- [D-49: Editor mode — inline above Claude, viewer swap](architecture.md#d-49-editor-mode--inline-above-claude-viewer-swap) — _architecture_
- [D-50: Context auto-behavior — right panel reacts to Claude](architecture.md#d-50-context-auto-behavior--right-panel-reacts-to-claude) — _architecture_
- [D-51: Panel collapse — 12px spine with badge](architecture.md#d-51-panel-collapse--12px-spine-with-badge) — _architecture_
- [D-52: Focus mode — full-window takeover](architecture.md#d-52-focus-mode--full-window-takeover) — _architecture_
- [D-53: State persistence across sessions](architecture.md#d-53-state-persistence-across-sessions) — _architecture_
- [D-54: Keyboard map — canonical shortcuts](architecture.md#d-54-keyboard-map--canonical-shortcuts) — _architecture_
- [D-55: Claude pane internal tabs for multi-session](architecture.md#d-55-claude-pane-internal-tabs-for-multi-session) — _architecture_
- [D-56: Dissolve daemon process; Flutter app hosts IPC server](architecture.md#d-56-dissolve-daemon-process-flutter-app-hosts-ipc-server) — _architecture_
- [D-57: Frameless custom chrome with per-column 24px hats](architecture.md#d-57-frameless-custom-chrome-with-per-column-24px-hats) — _architecture_
- [D-58: Format engines are adoptable dependencies](tooling.md#d-58-format-engines-are-adoptable-dependencies) — _tooling_
- [D-59: Bundled git via dugite-native](tooling.md#d-59-bundled-git-via-dugite-native) — _tooling_
- [D-60: No network on default launch path](tooling.md#d-60-no-network-on-default-launch-path) — _tooling_
- [D-61: Dependency vetting checklist](tooling.md#d-61-dependency-vetting-checklist) — _tooling_
- [D-62: Dependency removal process](tooling.md#d-62-dependency-removal-process) — _tooling_
- [D-63: Vendored binary rebuild process](tooling.md#d-63-vendored-binary-rebuild-process) — _tooling_
- [D-64: No telemetry — architectural commitment](architecture.md#d-64-no-telemetry--architectural-commitment) — _architecture_
- [D-65: License compatibility matrix](tooling.md#d-65-license-compatibility-matrix) — _tooling_
- [D-66: Line coverage gate at 95%, ratcheted from current](testing.md#d-66-line-coverage-gate-at-95-ratcheted-from-current) — _testing_

## Open questions

- [Q-1: Authorisation granularity on the IPC socket](questions-architecture.md#q-1-authorisation-granularity-on-the-ipc-socket) — _architecture_
- [Q-2: Back-pressure on event streams](questions-architecture.md#q-2-back-pressure-on-event-streams) — _architecture_
- [Q-3: Event persistence + audit/undo](questions-architecture.md#q-3-event-persistence--auditundo) — _architecture_
- [Q-4: `.canvas` schema compatibility with Obsidian](questions-architecture.md#q-4-canvas-schema-compatibility-with-obsidian) — _architecture_
- [Q-5: IPC wire-format stability + `schema_version:`](questions-architecture.md#q-5-ipc-wire-format-stability--schema-version) — _architecture_
- [Q-6: Window chrome — native frame vs frameless custom](questions-architecture.md#q-6-window-chrome--native-frame-vs-frameless-custom) — _architecture_
- [Q-7: macOS app bundle signing / notarisation](questions-architecture.md#q-7-macos-app-bundle-signing--notarisation) — _architecture_
- [Q-8: Extension API shape — widgets, subcommands, both?](questions-extensions.md#q-8-extension-api-shape--widgets-subcommands-both) — _extensions_
- [Q-9: Lua runtime vendoring](questions-extensions.md#q-9-lua-runtime-vendoring) — _extensions_
- [Q-10: Extension manifest `schema_version:`](questions-extensions.md#q-10-extension-manifest-schema-version) — _extensions_
- [Q-11: Coverage gates — hard thresholds vs soft reporting](questions-testing.md#q-11-coverage-gates--hard-thresholds-vs-soft-reporting) — _testing_
- [Q-12: Screen-reader automation (axe-core via Playwright)](questions-testing.md#q-12-screen-reader-automation-axe-core-via-playwright) — _testing_
- [Q-13: Web production-mode a11y](questions-accessibility.md#q-13-web-production-mode-a11y) — _accessibility_
- [Q-14: i18n plurals / gender / date-format tooling](questions-accessibility.md#q-14-i18n-plurals--gender--date-format-tooling) — _accessibility_
- [Q-15: Editor tab — full LSP vs tree-sitter-only highlight](questions-process.md#q-15-editor-tab--full-lsp-vs-tree-sitter-only-highlight) — _process_
- [Q-16: `tree-sitter-dart` grammar maintenance](questions-process.md#q-16-tree-sitter-dart-grammar-maintenance) — _process_
- [Q-17: Icon set growth](questions-process.md#q-17-icon-set-growth) — _process_
- [Q-18: Theme hot-reload in release builds](questions-process.md#q-18-theme-hot-reload-in-release-builds) — _process_
- [Q-19: (withdrawn)](questions-process.md#q-19-withdrawn) — _process_
- [Q-20: Kernel DB service — namespaced SQL access?](questions-process.md#q-20-kernel-db-service--namespaced-sql-access) — _process_
- [Q-21: Pql absorbs planning vs keeps separate](questions-architecture.md#q-21-pql-absorbs-planning-vs-keeps-separate) — _architecture_
- [Q-22: Ticket persistence strategy](questions-architecture.md#q-22-ticket-persistence-strategy) — _architecture_
- [Q-23: SSH-remote development — run clide against a remote workspace](questions-architecture.md#q-23-ssh-remote-development--run-clide-against-a-remote-workspace) — _architecture_
- [Q-25: Body text face — mono everywhere vs Josefin Sans UI + mono code](questions-architecture.md#q-25-body-text-face--mono-everywhere-vs-josefin-sans-ui--mono-code) — _architecture_
- [Q-26: Small screen layout (< 1000px)](questions-architecture.md#q-26-small-screen-layout--1000px) — _architecture_
- [Q-27: Two-editor split](questions-architecture.md#q-27-two-editor-split) — _architecture_
- [Q-28: Terminal strip scope — shell only or logs/errors/tests](questions-architecture.md#q-28-terminal-strip-scope--shell-only-or-logserrorstests) — _architecture_
- [Q-29: Branch picker location](questions-architecture.md#q-29-branch-picker-location) — _architecture_
- [Q-30: Focus behavior when editor is dirty and viewer is peeked](questions-architecture.md#q-30-focus-behavior-when-editor-is-dirty-and-viewer-is-peeked) — _architecture_
- [Q-31: XWayland fallback for frameless — proper Wayland protocol needed](questions-architecture.md#q-31-xwayland-fallback-for-frameless--proper-wayland-protocol-needed) — _architecture_

## Rejected

- [R-2: Go sidecar](rejected.md#r-2-go-sidecar) — _rejected_
- [R-3: `MaterialApp` root](rejected.md#r-3-materialapp-root) — _rejected_
- [R-4: Flutter `intl` + ARB codegen for i18n](rejected.md#r-4-flutter-intl--arb-codegen-for-i18n) — _rejected_
- [R-5: Patrol test runner](rejected.md#r-5-patrol-test-runner) — _rejected_
- [R-6: Nerd-font glyph icons](rejected.md#r-6-nerd-font-glyph-icons) — _rejected_
- [R-7: `CupertinoApp` root](rejected.md#r-7-cupertinoapp-root) — _rejected_
- [R-8: Riverpod / Provider / BLoC for state](rejected.md#r-8-riverpod--provider--bloc-for-state) — _rejected_
- [R-9: Port planning tooling into clide](rejected.md#r-9-port-planning-tooling-into-clide) — _rejected_
- [R-10: Python-script stopgap under `tooling/db/`](rejected.md#r-10-python-script-stopgap-under-toolingdb) — _rejected_
- [R-11: Permanent stopgap](rejected.md#r-11-permanent-stopgap) — _rejected_
- [R-12: MaterialApp wrapper from design handoff](rejected.md#r-12-materialapp-wrapper-from-design-handoff) — _rejected_
