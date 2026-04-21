# Rejected Alternatives

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-002: Go sidecar
- **Rejected:** 2026-04-20 (was ADR 0002; superseded by [D-005](architecture.md#d-005-dart-core-ptyc-peer))
- **Reason:** The ADR picked Go on two premises — (a) the heavy work belongs in a language separate from the UI layer, and (b) pql is Go so muscle memory transfers. Both broke on reassessment. The sidecar stripped of PTY is I/O-bound glue that `dart:io` covers cleanly (unix sockets, JSON-lines framing, process tables, shell-outs). The real axis was *separate process vs shared language*, not Go vs Rust, and separate-process is what matters (session persistence needs the daemon to outlive the app), not language. PTY is the one place Dart is genuinely weak — Dart's multi-threaded VM can't safely `fork()` — and that single constraint forces a native helper regardless, independent of whether the rest of the core is Dart. Once a small native helper is accepted, the question "does *everything else* need to be in that same native language" answers itself: no. Go sidecar directory dissolved; `ptyc` (C, PTY-only, pql-peer) is the surviving native supporter tool.
- **Cross-reference:** [D-005](architecture.md#d-005-dart-core-ptyc-peer)

### R-003: `MaterialApp` root
- **Rejected:** 2026-04-21
- **Reason:** Dragged in Material theming, default icons, and platform chrome that fought the custom three-tier theme pipeline ([D-009](architecture.md#d-009-three-tier-theme-pipeline)). Every bundled theme had to override Material defaults to look like clide; the overrides were visible in widget tests as "why is this `ElevatedButton` colored this way."
- **Cross-reference:** [D-007](architecture.md#d-007-app-root-is-bare-widgetsapp)

### R-004: Flutter `intl` + ARB codegen for i18n
- **Rejected:** 2026-04-21
- **Reason:** ARB codegen is inflexible for plugin-contributed catalogs — every catalogue needs a codegen pass, every extension ships with pre-generated Dart, and runtime merging is fighting the tool. The fframe text-driven pattern reads JSON at runtime with no codegen, which fits extension-shipped catalogs cleanly.
- **Cross-reference:** [D-021](accessibility.md#d-021-i18n-is-a-tier-0-contract)

### R-005: Patrol test runner
- **Rejected:** 2026-04-21
- **Reason:** Adds a dependency (violates [D-031](tooling.md#d-031-prefer-zero-deps-exact-pin)) for a capability we get from Playwright + Flutter's own semantics tree. Patrol's value proposition (native-gesture emulation) is less relevant on Linux desktop than on mobile.
- **Cross-reference:** [D-026](testing.md#d-026-web-driver-raw-playwright-plus-flutter-semantics)

### R-006: Nerd-font glyph icons
- **Rejected:** 2026-04-21
- **Reason:** TUI hangover from the Python-era clide under `legacy/`. Not desktop-native; forces a font dependency; doesn't theme consistently. Clide uses custom icon primitives (Tier 6 revisits with proper icon-set design).
- **Cross-reference:** [Q-017](questions-process.md#q-017-icon-set-growth)

### R-007: `CupertinoApp` root
- **Rejected:** 2026-04-21
- **Reason:** iOS-opinionated; wrong shell for a Linux-primary desktop IDE. Same theming-collision problem as [R-003](#r-003-materialapp-root).
- **Cross-reference:** [D-007](architecture.md#d-007-app-root-is-bare-widgetsapp)

### R-008: Riverpod / Provider / BLoC for state
- **Rejected:** 2026-04-21
- **Reason:** Violates [D-031](tooling.md#d-031-prefer-zero-deps-exact-pin). `ChangeNotifier` + `ListenableBuilder` ship in the SDK, fake trivially, and cover the state model we need. The ergonomic wins of Riverpod / Provider don't clear the "new dependency" bar at clide's scale.
- **Cross-reference:** [D-010](architecture.md#d-010-state-management-changenotifier)

### R-009: Port planning tooling into clide
- **Rejected:** 2026-04-21
- **Reason:** Earlier in the planning session the assumption was "clide owns Dart subcommands for decisions + tickets." That breaks the day a contributor works in a terminal or in VS Code / JetBrains — they have no `clide` binary to run. Reversing: pql owns planning long-term (see [D-039](process.md#d-039-planning-tooling-lives-in-pql)); clide consumes via shell-out.
- **Cross-reference:** [D-039](process.md#d-039-planning-tooling-lives-in-pql)

### R-010: Python-script stopgap under `tooling/db/`
- **Rejected:** 2026-04-21
- **Reason:** Location, not language. Settled-reach puts scripts at `tooling/db/` — copying that path here creates a script-pollution problem: every project using the pattern commits its own copy. The accepted Python port ([D-040](process.md#d-040-python-stopgap-under-toolsscriptsplan)) lives at `tools/scripts/plan`, clearly signalled as dev-tooling and time-limited.
- **Cross-reference:** [D-040](process.md#d-040-python-stopgap-under-toolsscriptsplan)

### R-011: Permanent stopgap
- **Rejected:** 2026-04-21
- **Reason:** If the Python port under `tools/scripts/plan` outlasts pql's feature parity, delete it. The deletion commit should be one changeset: remove `tools/scripts/plan`, remove its Makefile target (`decisions-validate` rewires to `pql decisions validate`), add a `CHANGELOG.md` entry under Removed, and verify `.pql/pql.db` still opens under the new `pql` binary.
- **Cross-reference:** [D-040](process.md#d-040-python-stopgap-under-toolsscriptsplan)

---
