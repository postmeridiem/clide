# Rejected — Architecture

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-2: Go sidecar
- **Rejected:** 2026-04-20 (was ADR 0002; superseded by [D-5](../decisions/architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer))
- **Reason:** The ADR picked Go on two premises — (a) the heavy work belongs in a language separate from the UI layer, and (b) pql is Go so muscle memory transfers. Both broke on reassessment. The sidecar stripped of PTY is I/O-bound glue that `dart:io` covers cleanly (unix sockets, JSON-lines framing, process tables, shell-outs). The real axis was *separate process vs shared language*, not Go vs Rust, and separate-process is what matters (session persistence needs the daemon to outlive the app), not language. PTY is the one place Dart is genuinely weak — Dart's multi-threaded VM can't safely `fork()` — and that single constraint forces a native helper regardless, independent of whether the rest of the core is Dart. Once a small native helper is accepted, the question "does *everything else* need to be in that same native language" answers itself: no. Go sidecar directory dissolved; `ptyc` (C, PTY-only, pql-peer) is the surviving native supporter tool.
- **Cross-reference:** [D-5](../decisions/architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer)

### R-3: `MaterialApp` root
- **Rejected:** 2026-04-21
- **Reason:** Dragged in Material theming, default icons, and platform chrome that fought the custom three-tier theme pipeline ([D-9](../decisions/architecture.md#d-9-three-tier-theme-pipeline)). Every bundled theme had to override Material defaults to look like clide; the overrides were visible in widget tests as "why is this `ElevatedButton` colored this way."
- **Cross-reference:** [D-7](../decisions/architecture.md#d-7-app-root-is-bare-widgetsapp)

### R-7: `CupertinoApp` root
- **Rejected:** 2026-04-21
- **Reason:** iOS-opinionated; wrong shell for a Linux-primary desktop IDE. Same theming-collision problem as [R-3](#r-3-materialapp-root).
- **Cross-reference:** [D-7](../decisions/architecture.md#d-7-app-root-is-bare-widgetsapp)

### R-8: Riverpod / Provider / BLoC for state
- **Rejected:** 2026-04-21
- **Reason:** Violates [D-31](../decisions/tooling.md#d-31-prefer-zero-deps-exact-pin). `ChangeNotifier` + `ListenableBuilder` ship in the SDK, fake trivially, and cover the state model we need. The ergonomic wins of Riverpod / Provider don't clear the "new dependency" bar at clide's scale.
- **Cross-reference:** [D-10](../decisions/architecture.md#d-10-state-management--changenotifier--listenablebuilder)

### R-12: MaterialApp wrapper from design handoff
- **Rejected:** 2026-04-22
- **Reason:** The design handoff delivers theme files as `MaterialApp`/`ThemeData` Dart classes. This is the delivery format of claude.ai/design, not a design intent. Adopting Material's widget system would contradict [D-7](../decisions/architecture.md#d-7-app-root-is-bare-widgetsapp) (bare WidgetsApp, no Material/Cupertino). We translate the palette tokens and syntax roles into our existing YAML + `SurfaceTokens` pipeline.
- **Cross-reference:** [D-43](../decisions/architecture.md#d-43-design-handoff--adopt-token-palettes-reject-material-wrapper)

---
