# Testing Decisions

Test pyramid, drivers, client-side constraint.

---

### D-23: Test pyramid — seven layers
- **Date:** 2026-04-21
- **Decision:** The pyramid has seven layers: unit (pure Dart) → widget (pumped + find) → golden (visual primitives) → a11y (semantics coverage + keyboard + contrast + i18n) → integration (`flutter test integration_test/`) → E2E (Playwright driving the WASM build + `clide --daemon` subprocess) → startup-smoke (`ci/smoke_bundle.sh`: build Linux release, run under xvfb for 5 s).
- **Rationale:** Each layer catches a distinct regression class. Skipping any layer means that class ships unprotected. Pushed back when earlier rounds proposed "just widget + E2E"; widget can't catch paint regressions (that's golden), E2E can't catch a11y tree drift (that's semantics).
- **Cost:** Seven CI jobs; total wall time budgeted at < 15 min. Pre-push runs layers 1-4 (< 90 s — see [D-29](#d-29-pre-push-gate-fast-layer-only)).
- **Raised by:** 2026-04-21 planning.

### D-24: Golden tests — primitives only, Alchemist + Ahem
- **Date:** 2026-04-21
- **Decision:** Goldens cover primitive widgets only (button, tab, panel header, token-bound surfaces). Composed layouts are tested via widget-find assertions, not pixel goldens. Golden rendering uses Alchemist with the Ahem font to get deterministic text metrics across platforms.
- **Rationale:** Pixel goldens of composed layouts churn constantly (one tweak → fifty golden diffs) without catching more than primitive goldens would. Alchemist + Ahem sidesteps the "font rendering differs between Linux CI and macOS dev" trap.
- **Cost:** Goldens have zero real text; layouts rely on widget tests. Acceptable.
- **Raised by:** 2026-04-21 planning.

### D-25: Mocks — mocktail at IO, hand-rolled fakes for ChangeNotifiers
- **Date:** 2026-04-21
- **Decision:** `mocktail 1.0.4` mocks IO boundaries (sockets, processes, `dart:io` File/Directory). `ChangeNotifier` facades get hand-rolled fakes — tiny classes that extend `ChangeNotifier` with test-controlled setters. No `mocktail` for notifiers.
- **Rationale:** Mocking a `ChangeNotifier` with a generated mock hides subscription bugs — `notifyListeners` becomes a mock call instead of actually firing. Hand-rolled fakes exercise the real subscription machinery.
- **Cost:** Roughly 20 lines per fake. Rounds out to less code than configuring a mocktail whenCall chain.
- **Raised by:** 2026-04-21 planning.

### D-26: Web driver — raw Playwright + Flutter semantics
- **Date:** 2026-04-21
- **Decision:** The browser-side E2E driver uses Playwright directly against Flutter's semantics tree (`flt-semantics[aria-label]`). No Patrol, no flutter_driver for web. The driver (`tools/ui/driver.ts`) clicks `flt-semantics-placeholder` on load to activate semantics, then queries by substring aria-label (Flutter merges sibling labels).
- **Rationale:** Patrol adds a dependency for a capability we get from semantics + Playwright directly. Labels are the a11y tree we already contract to maintain ([D-20](accessibility.md#d-20-a11y-is-a-tier-0-contract)); reusing them for E2E is a win.
- **Cost:** Driver has to know Flutter's sibling-merging behaviour — documented in `docs/testing/claude-ui-workflow.md`.
- **Raised by:** 2026-04-21 planning.

### D-27: Startup regression gate
- **Date:** 2026-04-21
- **Decision:** Two gates guard boot regressions: `integration_test/app_starts_test.dart` (fast — boots the app under `flutter test`) and `ci/smoke_bundle.sh` (slow — `flutter build linux`, run the bundle under `xvfb` for 5 s, assert no exit code). Both run in CI as `startup-bundle` job.
- **Rationale:** The fast integration test catches "boot hangs in Dart land"; the bundle smoke catches "boot breaks under release compile + production xvfb" — different regression classes.
- **Cost:** One extra CI job + `xvfb` on the runner. Five seconds of boot is enough; we've already caught one regression at this gate.
- **Raised by:** 2026-04-21 planning.

### D-28: Test organisation — mirror `lib/` in `test/`
- **Date:** 2026-04-21
- **Decision:** Every test file lives at the same relative path as its subject. `app/lib/kernel/src/i18n/catalog_loader.dart` pairs with `app/test/kernel/i18n/catalog_loader_test.dart`. No separate `unit/` vs `widget/` directories; test type is detected by what the test imports.
- **Rationale:** Matching paths makes "jump to test" predictable in any editor. Type-by-imports matches how `flutter test` already works.
- **Cost:** Large feature folders mirror into large test folders. Acceptable.
- **Raised by:** 2026-04-21 planning.

### D-29: Pre-push gate — fast layer only
- **Date:** 2026-04-21
- **Decision:** `make push-check` runs analyze + format + unit + widget + golden + a11y, target < 90 s. Integration, E2E, and startup-bundle run in CI but not on pre-push.
- **Rationale:** Pre-push gates that exceed ~90 s get disabled by muscle memory ("just push, it'll catch in CI"). Keeping the gate fast keeps it respected. Integration + E2E + bundle still gate merge via CI.
- **Cost:** Some regressions land on `main` that CI catches. Rollback or hotfix — acceptable for a solo-or-small-team cadence.
- **Raised by:** 2026-04-21 planning.

### D-30: Tests are client-side only
- **Date:** 2026-04-21
- **Decision:** No test hits the network. No test depends on remote fixtures, shared DBs, or state outside the test process. Fakes and fixtures live in-tree.
- **Rationale:** Network-dependent tests flake; flaky tests get quarantined; quarantined tests get deleted. Client-side-only makes CI deterministic offline.
- **Cost:** pql / daemon / extension tests stand up real subprocesses and real sockets locally — no mocked network convenience.
- **Raised by:** 2026-04-21 planning.

---
