# Rejected Alternatives

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-2: Go sidecar
- **Rejected:** 2026-04-20 (was ADR 0002; superseded by [D-5](architecture.md#d-5-dart-core-ptyc-peer))
- **Reason:** The ADR picked Go on two premises — (a) the heavy work belongs in a language separate from the UI layer, and (b) pql is Go so muscle memory transfers. Both broke on reassessment. The sidecar stripped of PTY is I/O-bound glue that `dart:io` covers cleanly (unix sockets, JSON-lines framing, process tables, shell-outs). The real axis was *separate process vs shared language*, not Go vs Rust, and separate-process is what matters (session persistence needs the daemon to outlive the app), not language. PTY is the one place Dart is genuinely weak — Dart's multi-threaded VM can't safely `fork()` — and that single constraint forces a native helper regardless, independent of whether the rest of the core is Dart. Once a small native helper is accepted, the question "does *everything else* need to be in that same native language" answers itself: no. Go sidecar directory dissolved; `ptyc` (C, PTY-only, pql-peer) is the surviving native supporter tool.
- **Cross-reference:** [D-5](architecture.md#d-5-dart-core-ptyc-peer)

### R-3: `MaterialApp` root
- **Rejected:** 2026-04-21
- **Reason:** Dragged in Material theming, default icons, and platform chrome that fought the custom three-tier theme pipeline ([D-9](architecture.md#d-9-three-tier-theme-pipeline)). Every bundled theme had to override Material defaults to look like clide; the overrides were visible in widget tests as "why is this `ElevatedButton` colored this way."
- **Cross-reference:** [D-7](architecture.md#d-7-app-root-is-bare-widgetsapp)

### R-4: Flutter `intl` + ARB codegen for i18n
- **Rejected:** 2026-04-21
- **Reason:** ARB codegen is inflexible for plugin-contributed catalogs — every catalogue needs a codegen pass, every extension ships with pre-generated Dart, and runtime merging is fighting the tool. The fframe text-driven pattern reads JSON at runtime with no codegen, which fits extension-shipped catalogs cleanly.
- **Cross-reference:** [D-21](accessibility.md#d-21-i18n-is-a-tier-0-contract)

### R-5: Patrol test runner
- **Rejected:** 2026-04-21
- **Reason:** Adds a dependency (violates [D-31](tooling.md#d-31-prefer-zero-deps-exact-pin)) for a capability we get from Playwright + Flutter's own semantics tree. Patrol's value proposition (native-gesture emulation) is less relevant on Linux desktop than on mobile.
- **Cross-reference:** [D-26](testing.md#d-26-web-driver-raw-playwright-plus-flutter-semantics)

### R-6: Nerd-font glyph icons
- **Rejected:** 2026-04-21
- **Reason:** TUI hangover from the Python-era clide under `legacy/`. Not desktop-native; forces a font dependency; doesn't theme consistently. Clide uses custom icon primitives (Tier 6 revisits with proper icon-set design).
- **Cross-reference:** [Q-17](questions-process.md#q-17-icon-set-growth)

### R-7: `CupertinoApp` root
- **Rejected:** 2026-04-21
- **Reason:** iOS-opinionated; wrong shell for a Linux-primary desktop IDE. Same theming-collision problem as [R-3](#r-3-materialapp-root).
- **Cross-reference:** [D-7](architecture.md#d-7-app-root-is-bare-widgetsapp)

### R-8: Riverpod / Provider / BLoC for state
- **Rejected:** 2026-04-21
- **Reason:** Violates [D-31](tooling.md#d-31-prefer-zero-deps-exact-pin). `ChangeNotifier` + `ListenableBuilder` ship in the SDK, fake trivially, and cover the state model we need. The ergonomic wins of Riverpod / Provider don't clear the "new dependency" bar at clide's scale.
- **Cross-reference:** [D-10](architecture.md#d-10-state-management-changenotifier)

### R-9: Port planning tooling into clide
- **Rejected:** 2026-04-21
- **Reason:** Earlier in the planning session the assumption was "clide owns Dart subcommands for decisions + tickets." That breaks the day a contributor works in a terminal or in VS Code / JetBrains — they have no `clide` binary to run. Reversing: pql owns planning long-term (see [D-39](process.md#d-39-planning-tooling-lives-in-pql)); clide consumes via shell-out.
- **Cross-reference:** [D-39](process.md#d-39-planning-tooling-lives-in-pql)

### R-10: Python-script stopgap under `tooling/db/`
- **Rejected:** 2026-04-21
- **Reason:** Location, not language. Settled-reach puts scripts at `tooling/db/` — copying that path here creates a script-pollution problem: every project using the pattern commits its own copy. The accepted Python port ([D-40](process.md#d-40-python-stopgap-under-toolsscriptsplan)) lives at `tools/scripts/plan`, clearly signalled as dev-tooling and time-limited.
- **Cross-reference:** [D-40](process.md#d-40-python-stopgap-under-toolsscriptsplan)

### R-11: Permanent stopgap
- **Rejected:** 2026-04-21
- **Reason:** If the Python port under `tools/scripts/plan` outlasts pql's feature parity, delete it. The deletion commit should be one changeset: remove `tools/scripts/plan`, remove its Makefile target (`decisions-validate` rewires to `pql decisions validate`), add a `CHANGELOG.md` entry under Removed, and verify `.pql/pql.db` still opens under the new `pql` binary.
- **Cross-reference:** [D-40](process.md#d-40-python-stopgap-under-toolsscriptsplan)

### R-12: MaterialApp wrapper from design handoff
- **Rejected:** 2026-04-22
- **Reason:** The design handoff delivers theme files as `MaterialApp`/`ThemeData` Dart classes. This is the delivery format of claude.ai/design, not a design intent. Adopting Material's widget system would contradict [D-7](architecture.md#d-7-app-root-is-bare-widgetsapp) (bare WidgetsApp, no Material/Cupertino). We translate the palette tokens and syntax roles into our existing YAML + `SurfaceTokens` pipeline.
- **Cross-reference:** [D-43](architecture.md#d-43-design-handoff-adopt-token-palettes-reject-material-wrapper)

---
