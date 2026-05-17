# clide — External Consultant Review

**Date:** 2026-05-14
**Scope:** Full-repository assessment of clide at `main` (commit `9030e56`).
**Method:** Six independent specialist reviewers, each given read-only access and a
brief covering best practice, clean code, architecture, usability, stability,
expandability, style, consistency, and general quality. Reviewers did not see each
other's findings; cross-cutting themes below are genuine independent agreement.

**Panel:**
| Lens | Reviewer |
|---|---|
| Architecture | Software Architect |
| Tests & quality gates | Test / QA Analyst |
| UX & accessibility | UX & Accessibility Expert |
| Code quality & craft | Senior Dart/Flutter Engineer |
| Security & supply chain | Security Engineer |
| Docs, governance & DX | TPM / Developer-Experience Consultant |

---

## Overall verdict

clide is, for a solo-dev pre-v2.0 project, **unusually disciplined** — every reviewer
said so independently. The governance system is alive, the core subsystems are small
and well-typed, the FFI/PTY layer shows real systems-programming care, and the quality
gates are genuine rather than ornamental. The codebase is in good shape.

The weaknesses cluster into a handful of themes, and several are **load-bearing**: a
central guardrail (CLI-first IPC) has no runtime implementation, keyboard operability —
the core requirement of a power-user dev tool — is largely unbuilt, an untrusted
workspace can achieve code execution, and the two primary onboarding documents describe
an architecture that no longer exists.

None of these are fatal; all are fixable; most have quick-win first steps. But they
should be addressed before a public v2.0.

---

## Cross-cutting themes (independent agreement)

These were each flagged by **two or more** reviewers who did not coordinate:

1. **The IPC layer is mid-migration and contradicts itself.** The Architect found no
   Unix-socket *server* anywhere in `lib/` — D-56's "app hosts an in-process IPC server"
   and D-1's "CLI-first, not MCP" have no runtime path; three IPC clients
   (`DaemonClient`, `InProcessClient`, `IsolateClient`) coexist with two duplicated
   service-wiring sites. The Security reviewer independently noted `DaemonClient`'s
   socket code is still live as an unvalidated attack surface. **Pick one IPC model,
   implement or amend D-56, delete the other two.**

2. **The "no pre-existing excuse / clean board" guardrail is being violated right now.**
   `flutter analyze` reports 9 `unnecessary_import` issues in `test/`; `ci/test.sh` runs
   analyze with `--no-fatal-infos`, which silently tolerates them. Flagged by the
   Architect, Code Quality, and Test reviewers. The repo's own rules say fix-first.

3. **`lib/src/terminal/` is in an undeclared middle state.** ~7k LOC forked from
   xterm.dart, carrying commented-out `print`s, dangling TODOs, a 1137-line `parser.dart`,
   and the only `invalid_use_of_protected_member` suppression in the repo. MEMORY says
   "code under `lib/` is owned, not vendored" — so it must either be formally vendored
   (frozen, documented, decision-recorded) or cleaned to the project bar. Flagged by
   Code Quality; the Architect's "consistency" deduction points at the same seam.

4. **Documentation describes a dissolved architecture.** `README.md` and
   `docs/initial-plan.md` still describe a Go sidecar, `ptyc/` C helper, `app/`
   subdirectory, and a separate `clide --daemon` process — all removed by D-5, D-56, and
   the FFI pivot. A new contributor's first read builds a wrong mental model.

---

## Consolidated scorecard

Scores are each reviewer's, 1–5, on their own dimensions.

| Domain | Dimension | Score |
|---|---|---|
| **Architecture** | Layering & dependency direction | 4 |
| | Separation of concerns | 4 |
| | Expandability | 5 |
| | Consistency | 4 |
| | Guardrail adherence | 3 |
| **Tests** | Coverage quality | 4 |
| | Test reliability / flakiness | 3 |
| | Gate trustworthiness | 3 |
| | Test maintainability | 5 |
| | Regression-catching power | 4 |
| **UX / a11y** | Interaction model | 2 |
| | Accessibility | 3 |
| | Visual consistency | 4 |
| | Discoverability | 2 |
| | State coverage (loading/error/empty) | 3 |
| **Code quality** | Idiomatic Dart | 4 |
| | Error handling | 4 |
| | Naming & readability | 4 |
| | Consistency across subsystems | 3 |
| | Resource / lifecycle safety | 4 |
| **Security** | Subprocess safety | 2 |
| | IPC input validation | 3 |
| | Path / filesystem safety | 3 |
| | Dependency / supply-chain hygiene | 3 |
| | Secrets & sandboxing | 3 |
| **Docs / governance** | Governance discipline | 4 |
| | Documentation accuracy | 2 |
| | Changelog hygiene | 3 |
| | Contributor onboarding | 2 |
| | Convention adherence | 4 |

**Highest marks:** expandability (5), test maintainability (5). The extension contract
and test-helper design are genuine standouts.
**Lowest marks:** interaction model (2), discoverability (2), subprocess safety (2),
documentation accuracy (2), contributor onboarding (2).

---

## Prioritized action list

Synthesized across all six reviews. Severity is the highest any reviewer assigned.

### Critical — address before public v2.0

1. **Fix untrusted-workspace code execution.** `toolchain_paths.dart:79` resolves
   `native/dugite/bin/git` relative to the *workspace root*; a malicious repo can plant
   an executable there that clide runs on the first auto-fired `git.status`. Resolve
   `native/dugite` against `Platform.resolvedExecutable`'s directory, never the
   workspace. *(Security)*
2. **Resolve the IPC story.** Either implement the in-process Unix-socket server per
   D-56 so the `clide` CLI / C client actually works, or amend D-56 to make in-process
   direct dispatch the design and delete `DaemonClient`'s socket code, `IsolateClient`,
   `Backend`, and `backend_entry.dart`. Today the code claims three models and runs one,
   and a load-bearing guardrail (D-1/D-6) is unmet. *(Architecture, Security)*
3. **Make the tool keyboard-operable.** `ClideTappable` (base of nearly every
   interactive widget) is mouse-only — no `Focus`, no Enter/Space. The command palette
   has no arrow-key navigation and no Escape. For a keyboard-first dev tool this is a
   functional gap, not a polish item. *(UX)*
4. **Fix the onboarding docs.** Rewrite `README.md`'s `ptyc/` / `make ptyc-build`
   sections, fix its dead `decisions/` link, and banner `docs/initial-plan.md` as
   historical (or split out a current `docs/architecture.md`). *(Docs)*

### Major — should land soon

5. Add symlink re-resolution + containment re-check in `files.read` / `files.ls` — a
   repo symlink `config -> /etc/shadow` currently passes path-safety. *(Security)*
6. Add `test-integration` (and ideally `smoke-bundle`) to `make push-check` — the gate
   that catches "app won't boot" is currently omitted from the pre-push gate. *(Tests)*
7. Schema-validate the IPC argument surface; reject `-`-prefixed `branch`/`remote`/`path`
   values; add size/count bounds. *(Security)*
8. Establish a real focus-traversal model (`FocusTraversalGroup` per slot, a documented
   "focus next panel" keybinding) and integrate `FocusTracker` with Flutter's focus
   system instead of paralleling it. *(UX)*
9. Fix the `SchedulerService._startTicker` isolate-spawn race — a `_stopTicker()` before
   the spawn future resolves leaks a forever-ticking isolate. Mirror `NativePty`'s
   `_readerReady` pattern. *(Code quality)*
10. Decide the status of `lib/src/terminal/` — formally vendor (and decision-record) it,
    or do the cleanup sweep. *(Code quality)*
11. Replace fixed wall-clock `Future.delayed` sleeps in `watcher_test.dart` /
    `session_test.dart` with event-driven waits; make swallowed `onTimeout` callbacks
    `fail()` loudly. *(Tests)*
12. Write a human-facing `CONTRIBUTING.md`; cut an interim release to drain the ~80-commit
    `[Unreleased]` backlog; merge duplicate changelog subsection headings. *(Docs)*
13. Single global `KeyboardListener` → scoped `Shortcuts`/`Actions`; move
    `KeybindingResolver` off layout-dependent `keyLabel`. *(UX)*

### Quick wins — hours each

- Clear the 9 `unnecessary_import` analyzer issues; drop `--no-fatal-infos` from
  `ci/test.sh`. *(Architecture, Tests, Code quality)*
- Run the `forkpty` PTY tests with `--coverage` so `native_pty.dart` — the riskiest file
  — is honestly measured. *(Tests)*
- Add a `Focus` + Enter/Space wrapper and a focus-ring inside `ClideTappable`; this fixes
  the keyboard gap for every button and list item at once. *(UX)*
- Add arrow-key + Escape + selected-index to `ClidePalette` (copy the existing
  `_ProjectSwitcherDropdown` `onKeyEvent` pattern). *(UX)*
- Amend D-66 to reflect the coverage floor's real location (`pubspec.yaml`), mechanism,
  and value (90%) — it currently disagrees with the changelog and the code. *(Docs)*
- Reconcile `licenses.yaml` with `pubspec.yaml` (`test` version drift, phantom `lints`
  entry); add a `native/SHA256SUMS` manifest. *(Security, Docs)*
- Replace silent `catch (_)` in `tree_sitter_ffi.dart` with a logged last-error.
  *(Code quality)*
- Fix the `clide.dart` barrel leak in `file_tree_view.dart:8`; narrow the barrel (drop
  the `dispatcher.dart` export); move `test_app.dart` out of the production `main.dart`
  import graph. *(Architecture)*
- Expand the contrast gate's `canonicalPairs` to cover `globalTextMuted`, the `status*`
  colors, and `panelActiveBorder`. *(UX)*
- Triage stale governance Q-records (Q-1/2/3/25 overtaken by shipped Tier-1 work).
  *(Docs)*

---

# Full reviews

## 1. Architecture — Software Architect

### Executive summary

clide is an unusually disciplined solo-dev codebase. The governance system (67
D-records, tracked Q/R) is real and largely honored in code, the kernel/extension split
is coherent, and the feature-first layout with barrel files is consistently applied. The
single biggest strength is the **extension contract**: every built-in — including layout
itself — passes the same `ClideExtension` + `ContributionPoint` contract, which is the
best possible proof the contract is usable. The single biggest risk is **architectural
drift in the IPC layer**: D-56 mandates the Flutter app host an in-process IPC server
reachable by a thin C client over a unix socket, but no socket server exists anywhere in
`lib/` — the "CLI-first, not MCP" guardrail (D-1) has no runtime path today. Compounding
this, three parallel IPC client implementations (`DaemonClient` socket,
`InProcessClient`, `IsolateClient` + `Backend`) coexist with two competing
service-wiring sites (`main.dart` and `backend_entry.dart`), suggesting an unfinished
migration.

### Strengths

- **Extension contract is clean and scales** — `lib/extension/src/extension.dart` +
  `contribution.dart`: sealed `ContributionPoint` hierarchy, `ClideExtensionContext`
  lists services explicitly (deliberately avoiding a `KernelServices` import cycle —
  `extension.dart:50-52`). `ExtensionManager` does dependency topo-sort,
  dependency-gated activation, and contribution apply/remove symmetrically
  (`extensions_manager.dart:164-202`). Adding a pane = new extension file + one
  `register()` line in `main.dart`.
- **Kernel admission rule is enforced, not aspirational** — D-12's "mandatory shared
  singleton" test visibly shaped `KernelServices` (`facade.dart:38-93`); ~25 services,
  each defensibly cross-cutting. The two-tier disable model (D-14) is honored:
  `default_layout` is itself an extension.
- **Feature-first layout with barrel discipline** (D-8) is consistent — every
  `builtin/<name>/` and `kernel/` has a barrel; builtins import
  `package:clide/kernel/kernel.dart`, not deep paths. Only one leak found.
- **Governance-to-code traceability is genuine** — `WidgetsApp` root (D-7) at
  `app.dart:38`, `ChangeNotifier`/`ListenableBuilder` state (D-10) everywhere, git
  hardcoded in toolchain/project loader (D-13), terminal correctly tagged
  `inlined-source` in `licenses.yaml` with modifications documented.
- **Git subsystem cohesion** — `lib/src/git/` cleanly split into `client` / `status` /
  `diff` / `operations` (~250 lines each), each a single responsibility.

### Findings

- **[Critical] No IPC socket server exists** — D-56 specifies the app hosts an
  in-process IPC server with a C client connecting over a unix socket. `grep` for
  `ServerSocket`/unix-domain `bind` in `lib/` returns nothing. `DaemonClient._connect`
  (`client.dart:72-94`) *connects* to a socket, but nothing *serves* one. Today the only
  working path is `InProcessClient` (`in_process.dart`), which calls the dispatcher
  directly in-process. **Claude cannot drive clide via `clide ...` — the CLI-first
  guardrail (D-1, D-6) has no implementation.** This is the load-bearing contract of the
  whole project and it is absent.
- **[Major] Three IPC clients + two wiring sites = unfinished migration** —
  `DaemonClient` (socket), `InProcessClient`, and `IsolateClient`+`Backend`/
  `backend_entry.dart` all coexist. `main.dart:76-113` wires subsystems via
  `buildDispatcher`; `backend_entry.dart:40-110` wires the *same* five subsystems again
  inside an isolate. `Backend.spawn` is referenced only by `facade.dart` but `main.dart`
  uses `autoStartDaemonClient: false` + `daemonClientFactory` (the in-process path).
  Dead-or-dormant isolate infrastructure with duplicated registration logic — pick one
  and delete the others.
- **[Major] `main.dart` (production entry) imports `test_app.dart`** — `main.dart:2` and
  `:51-55`. The production binary carries the test harness and branches on
  `CLIDE_TESTMODE`. Test scaffolding should not be reachable from the shipping entry
  point; gate it behind a separate entrypoint or `kDebugMode`.
- **[Minor] `flutter analyze` reports 9 issues** — all `unnecessary_import` in `test/`,
  but CLAUDE.md's "no pre-existing excuse" / "clean board" guardrail makes this a
  fix-first item.
- **[Minor] Barrel leak** — `lib/builtin/files/src/file_tree_view.dart:8` imports
  `package:clide/src/files/listing.dart` directly instead of via
  `package:clide/clide.dart` (which already re-exports `FileEntry`).
- **[Minor] `clide.dart` barrel exports the daemon dispatcher** — `clide.dart:15`
  exports `src/daemon/dispatcher.dart`. The barrel is described as "shared types"; the
  dispatcher is server-side machinery.
- **[Minor] `ExtensionManager.activate` swallows exceptions** (`extensions_manager.dart:
  141-143`) — a failed `activate()` logs and continues, leaving the extension
  un-activated but `_known`, with no surfaced "degraded" state for the UI.

### Recommendations

**Quick wins:** clear the 9 analyzer issues; fix the `file_tree_view.dart` barrel leak
(consider a CI grep gate for `package:clide/src/` imports outside their feature); move
`test_app.dart` out of the production import graph; drop the `dispatcher.dart` export
from `clide.dart`.

**Larger efforts:** resolve the IPC story (implement the socket server per D-56, or
amend D-56 and delete `DaemonClient`/`IsolateClient`/`Backend`/`backend_entry.dart`);
collapse subsystem wiring into one `registerAllSubsystems(...)` function; give
`ExtensionManager` a surfaced failure state so the UI can show degraded built-ins.

### Scorecard

| Dimension | Score | Justification |
|---|---|---|
| Layering & dependency direction | 4/5 | Kernel→extension direction clean, context-vs-aggregate split avoids cycles; docked for the `src/`↔`kernel/src/` barrel leak and the dispatcher export. |
| Separation of concerns | 4/5 | Feature-first layout, single-responsibility subsystems; duplicated subsystem registration is the blemish. |
| Expandability | 5/5 | New pane = one extension file + one `register()` line; sealed contribution hierarchy; layout itself is data and extension-shaped. |
| Consistency | 4/5 | Barrels, naming, D-record back-references uniform; three coexisting IPC clients and 9 analyzer issues break the bar. |
| Guardrail adherence | 3/5 | `WidgetsApp`, single-process, no-Material, governance, zero-deps all honored — but D-1/D-6/D-56 (CLI-first via socket server) have no runtime implementation. |

---

## 2. Tests & quality gates — Test / QA Analyst

### Executive summary

The clide test suite is, for a solo-dev pre-2.0 project, in genuinely good shape. ~104
test files against 276 lib files, ~92.75% line coverage, and — critically — the coverage
was *not* bought with assertion-free filler. Even the alarmingly-named files
(`coverage_trivials_test.dart`, `zero_coverage_widgets_test.dart`,
`services_stubs_test.dart`, `mop_up_test.dart`) contain real behavioral assertions. The
biggest strength is a sensibly layered pyramid with a real boot-path integration gate
and a startup smoke test that catches the "tests pass but app won't launch" class. The
biggest risk is **flakiness from wall-clock-dependent tests** — fixed `Future.delayed`
sleeps in file-watcher and PTY tests will eventually produce intermittent CI failures,
and the PTY tests are run via `dart test` so they are **excluded from the coverage
measurement entirely**.

### Strengths

- **Test pyramid is sound.** Pure-Dart unit, widget tests with a shared harness, golden
  tests (Alchemist), an a11y contract layer, and 3 real-boot `integration_test/` files —
  correctly separated by runner (`ci/test.sh` vs `ci/test_core.sh` vs
  `ci/test_integration.sh`).
- **Helpers are well-designed.** `test/helpers/kernel_fixture.dart` boots a real
  `KernelServices` with in-memory themes/i18n and `autoStartDaemonClient: false` — no
  real socket, temp-dir scoped, proper `dispose()`. `FakeDaemonClient` is a clean stub.
- **Error-branch discipline.** `pql_commands_errors_test.dart` /
  `git_commands_errors_test.dart` deliberately point the toolchain at a non-existent
  binary to drive catch-branches the happy path can't reach — table-driven, with
  `reason:` tags.
- **OS-dialog avoidance is handled correctly.** `welcome/dialog_test.dart` mocks the
  `clide/window` MethodChannel to throw `MissingPluginException`, exercising the fallback
  path *without* spawning a native file picker.
- **Startup gate.** `ci/smoke_bundle.sh` builds the real release bundle and runs it
  under xvfb for 5s, correctly interpreting `timeout` exit codes (124/143 = healthy).
- **Coverage gate is honest.** `ci/coverage_gate.sh` is a self-contained awk parser (no
  `lcov` dependency), ratchets only upward, and `exit 2` distinguishes "missing data"
  from "below floor."

### Findings

- **[Major] PTY tests are excluded from coverage.** `ci/test.sh:13` runs
  `flutter test --coverage --exclude-tags forkpty`; the `forkpty` tests run separately
  via `dart test` with no `--coverage`. So `lib/src/pty/native_pty.dart` — the
  highest-risk native code in the repo — is barely in the measured denominator. The
  92.75% number overstates coverage of the riskiest file.
- **[Major] Wall-clock sleeps will flake.** `test/files/watcher_test.dart:67-82` uses
  fixed `Future.delayed`; `test/pty/session_test.dart:71` polls 50×100ms and `:65` uses a
  bare `500ms` settle. `session_test.dart`'s `timeout(5s, onTimeout: () {})` (`:48`)
  *swallows* the timeout — a never-producing PTY proceeds to a confusing assertion
  failure rather than a clear timeout.
- **[Major] `make push-check` does not run integration tests.** `push-check:
  decisions-validate test-core test test-a11y coverage-gate` — `test-integration` and
  `smoke-bundle` are omitted. A boot-order regression sails through.
- **[Minor] `flutter analyze --no-fatal-infos` in `ci/test.sh:9`** contradicts the
  stated "fail-on-warning, clean board" discipline.
- **[Minor] Integration tests run one-file-at-a-time** to dodge a batch "Unable to start
  the app" error — each invocation re-boots the engine (slow), and the workaround masks
  whether the batch failure is environmental or a real teardown leak.
- **[Minor] Golden CI config disabled.** Only platform goldens run; a Linux-only CI
  never validates the macOS goldens, and stale `test/goldens/failures/*.png` artifacts
  are committed to the repo.
- **[Minor] `test_core.sh` timeout kill is best-effort** — the `pkill -9 -f` pattern
  match is redundant noise next to the real `setsid` + `timeout --kill-after` safety net.
- **[Minor] `git/client_test.dart` depends on the ambient `git` binary**, not the
  vendored dugite — the suite passes/fails on the host git version.

### Recommendations

**Quick wins:** add `test-integration` (and `smoke-bundle`) to `push-check` — the single
highest-value change; run the `forkpty` tests with `--coverage`; drop `--no-fatal-infos`;
gitignore `test/goldens/failures/`; make `onTimeout` callbacks `fail()`.

**Larger efforts:** replace fixed sleeps with event-driven waits
(`expectLater(stream, emits(...))`); add a macOS golden CI matrix entry or document
goldens as advisory; consider a coverage-exclusion allowlist for genuinely-unreachable
defensive branches rather than chasing the last lines with filler tests.

### Scorecard

| Dimension | Score | Justification |
|---|---|---|
| Coverage quality | 4/5 | Tests are meaningful even in "mop-up" files; docked because PTY/FFI is outside the measured number. |
| Test reliability / flakiness | 3/5 | Fixed wall-clock sleeps and a swallowed timeout are latent intermittent failures. |
| Gate trustworthiness | 3/5 | Coverage gate and smoke bundle are well-built, but `push-check` omits integration tests. |
| Test maintainability | 5/5 | Shared fixtures, consistent structure, table-driven error suites, clear doc comments. |
| Regression-catching power | 4/5 | Real boot-path integration + smoke + a11y + goldens; weakened by single-OS goldens and PTY coverage gaps. |

---

## 3. UX & accessibility — UX & Accessibility Expert

### Executive summary

clide has an unusually disciplined *foundation* for a solo pre-v2.0 project: a coherent
semantic design-token system, a WCAG-AA contrast gate wired into CI, and i18n/semantic
contract tests. That foundation is the biggest strength. The biggest risk is that
**keyboard operability is largely unimplemented below the foundation** — the project's
own core interaction primitive (`ClideTappable`) is mouse-only, the command palette has
no arrow-key navigation or Escape, and there is no focus-traversal wiring across panels.
For a keyboard-first power-user dev tool, this is a critical gap that the a11y test suite
does not catch because the tests assert *structural* presence (Semantics nodes exist)
rather than *operability* (can you actually drive it from the keyboard).

### Strengths

- **Semantic token system is real and enforced.** `lib/kernel/src/theme/tokens.dart`
  defines ~65 named surface tokens; widgets consume `ClideTheme.of(context).surface`
  rather than raw colors. The resolver provides defaults so partial themes still produce
  a complete `SurfaceTokens`.
- **Contrast gate is genuine WCAG math, run per-theme.** `lib/kernel/src/theme/
  contrast.dart` implements real relative-luminance ratio with alpha pre-compositing
  against neutral grey (`contrast.dart:31-37`) — semi-transparent tokens can't spuriously
  pass.
- **Semantics are present on composed widgets.** `ClideButton` wraps
  `Semantics(button: true, enabled:, label:, hint:, onTap:)`; panels set
  `container: true, explicitChildNodes: true` with landmark labels.
- **State coverage exists in data panels.** `git_panel_view.dart:86-104` handles error,
  loading, and empty ("working tree clean") states distinctly; `file_tree_view.dart`
  handles error + loading.
- **Manual a11y discipline is documented.** `docs/testing/a11y-manual.md` prescribes a
  per-tier Orca/VoiceOver pass and is honest about why prose quality can't be automated.
- **Disabled state is handled at the cursor level.** `clide_button.dart:41` switches to
  `SystemMouseCursors.forbidden` and drops the semantic `onTap` when `onPressed == null`.

### Findings

- **[Critical] `ClideTappable` is mouse-only — no `Focus`, no keyboard activation.**
  `lib/widgets/src/clide_tappable.dart:37-54` is `MouseRegion` + `GestureDetector` only.
  It is the base for `ClideButton`, `_WinBtn`, `_RecentProjectRow`, `_ActionRow`, and
  most builtin list items. None can receive Tab focus or be activated with Enter/Space.
  The keyboard-traversal test only passes because it manually wraps the button in an
  external `Focus` node — it tests that the widget doesn't *block* focus, not that it
  *accepts* it.
- **[Critical] Command palette is not keyboard-navigable.** `clide_palette.dart` —
  `onSubmitted` only ever invokes `filtered.first` (`:77-80`); no up/down handling, no
  selected index, no selection highlight, no Escape handler.
- **[Major] No focus-traversal wiring between panels.** `FocusTracker`
  (`lib/kernel/src/focus.dart`) tracks an active *contribution id* for the `clide active`
  CLI, but is not Flutter `FocusScope`/`FocusTraversalGroup` integration. Nothing
  establishes Tab order across sidebar → workspace → context.
- **[Major] Drag-resize handles have no keyboard equivalent — parity gap.**
  `drag_resize.dart` and `app.dart:870-912` are pure `Listener` pointer handlers, with no
  Semantics node at all. Per "User/Claude parity", panel sizing should have a CLI
  affordance; none is evident.
- **[Major] Single global `KeyboardListener` is a fragile keybinding architecture.**
  `app.dart:90-148` routes all shortcuts through one root `KeyboardListener` — no
  per-context scoping, will conflict with text-input fields.
  `KeybindingResolver.fromKeyEvent` keys off layout-dependent `logicalKey.keyLabel`.
- **[Major] Text scale is the *only* in-app a11y accommodation, and it's hidden.**
  `app.dart:122-138` implements Ctrl +/-/0 text scaling but it's undiscoverable. No
  high-contrast toggle, no reduced-motion handling, no focus-ring rendering anywhere.
- **[Minor] Contrast gate covers only 11 token pairs** — omits `globalTextMuted` (muted
  text is everywhere), the `status*` foregrounds, syntax tokens on `panelBackground`, and
  `panelActiveBorder`.
- **[Minor] ~43 hardcoded-color sites bypass the token system** — some defensible (ANSI
  palette), but the modal/palette shadow and window-control colors won't adapt to the
  `paper` light theme.
- **[Minor] Hover state is inconsistent and not paired with focus** — every interactive
  widget reimplements its own `_hover` bool; none render a focus indicator.
- **[Minor] `_LeftHatContent` is dead code** — `app.dart:281-292` always returns
  `SizedBox.shrink()`.

### Recommendations

**Quick wins:** add a `Focus` + `Actions`/`Shortcuts` (Enter/Space → onTap) wrapper and
a focus-ring inside `ClideTappable` — fixes the [Critical] for every button/list-item at
once; add arrow-key + Escape + selected-index to `ClidePalette` (copy the existing
`_ProjectSwitcherDropdown` `onKeyEvent` pattern at `app.dart:446-452`); expand
`canonicalPairs`; surface text-zoom and theme switching in the palette; tokenize the
modal shadow and window-control colors.

**Larger efforts:** establish a real focus-traversal model and integrate `FocusTracker`
with Flutter's focus system; replace the root `KeyboardListener` with scoped
`Shortcuts`/`Actions` and move off `keyLabel`; add keyboard operability + Semantics to
drag-resize handles plus a `clide panel resize` CLI; add an a11y test tier that asserts
*operability*, not just Semantics presence.

### Scorecard

| Dimension | Score | Justification |
|---|---|---|
| Interaction model | 2/5 | Coherent slot/panel structure and good drag-resize *with a mouse*, but keyboard operability is largely unbuilt. |
| Accessibility | 3/5 | Genuine contrast gate, Semantics on composed widgets, i18n contract tests — but keyboard operability and focus order are not implemented. |
| Visual consistency | 4/5 | Strong semantic token system consumed consistently; a few hardcoded-color sites are real theme-adaptation bugs. |
| Discoverability | 2/5 | Command palette isn't keyboard-navigable; accommodations are undiscoverable; no in-app keybinding reference. |
| State coverage | 3/5 | Data panels and dialogs handle loading/error/empty; but no focus states anywhere and no reduced-motion handling. |

---

## 4. Code quality & craft — Senior Dart/Flutter Engineer

### Executive summary

clide is, for a solo pre-v2.0 project, in genuinely good shape. The core subsystems (IPC
envelope, daemon dispatch, git client, PTY) are small, single-responsibility,
well-typed, and consistent. `flutter analyze` is clean for `lib/` — the 9 reported issues
are all in `test/`, none are suppressions. The biggest strength is the FFI/PTY layer:
`lib/src/pty/native_pty.dart` shows real systems-programming discipline (pre-fork
allocation, errno captured before `free`, isolate-teardown ordering documented and
correct). The biggest risk is concentrated in two places: a genuine isolate-leak race in
`SchedulerService`, and the large vendored-but-owned `lib/src/terminal/` xterm.dart fork
(~7k LOC) which carries a different style, commented-out `print`s, and dangling TODOs
that the project's own "lib is owned, not vendored" rule says must be held to the same
bar.

### Strengths

- **PTY/FFI layer is excellent.** `native_pty.dart:129-145` force-resolves FFI
  trampolines and pre-allocates *all* native memory before `forkpty()`.
  `native_pty.dart:171-177` captures `errno` before `_freeAll` because `free()` can
  clobber it. `close()` (367-397) documents and implements the kill→EOF→close ordering
  to avoid fd-reuse races. The child branch touches no Dart heap.
- **IPC envelope is clean and idiomatic** — `lib/src/ipc/envelope.dart` uses a `sealed`
  class hierarchy, named constructors, a private unifying constructor, and conditional
  map keys. Decode is total over the type discriminant.
- **Typed, meaningful errors.** `PtyException` carries `op` + optional `errno`;
  `GitException` carries `stderr`; `errnoToIpcError` maps POSIX errno to actionable IPC
  error kinds. Errors are values, not strings.
- **Resource lifecycle is taken seriously across most subsystems.** `FileWatcher.stop()`
  cancels the subscription *and* closes the controller; `withBuffer`/`setWinsize` in
  `libc.dart` use `try/finally` around every native allocation. 45 files define
  `dispose`/`close`.
- **The `DaemonEventSink` interface** keeps the dependency graph pointing the right way
  (server→subsystems) and is documented as such.
- **The one `ignore_for_file` (`libc.dart:11-27`) is exemplary** — textbook FFI case,
  multi-paragraph justification exactly as CLAUDE.md requires.

### Findings

- **[Major] Isolate-leak race in `SchedulerService._startTicker`** — `scheduler.dart:71`:
  `Isolate.spawn(...).then((iso) => _isolate = iso)`. If `_stopTicker()` runs before the
  spawn future completes, `_isolate` is still null, nothing is killed, and the
  just-spawned isolate (with its `Timer.periodic`) leaks. `native_pty.dart` solved
  exactly this with `_readerReady`.
- **[Major] `lib/src/terminal/` held below the project's own bar.** Carries
  commented-out `print()` debugging (`custom_text_edit.dart:244-275`), dangling TODOs
  (`parser.dart:110-113`, `keytab.dart:91`), a 1137-line `parser.dart`, and the only
  `// ignore: invalid_use_of_protected_member` in the repo (`terminal_view.dart:363`).
  Either it's genuinely vendored (belongs in `native/` or documented as frozen) or it's
  owned (needs the cleanup pass).
- **[Minor] Empty `catch (_) {}` swallows in `tree_sitter_ffi.dart:197,206`** —
  `DynamicLibrary.open` failures silently discarded; caller gets a bare `null` with no
  diagnostic about *why*. Syntax highlighting silently not working is a support
  headache.
- **[Minor] Empty `catch (_) {}` in `test_app.dart:271,311`** — `:271` swallows a
  theme-load failure the harness exists to detect.
- **[Minor] Dead alias in `libc.dart:201-202`** — `typedef Cmsghdr = CmsghdrLinux;`
  flagged "backward compatibility"; CLAUDE.md forbids backwards-compat hacks in a solo
  repo.
- **[Minor] `// ignore: unused_field` in `editor_controller.dart:25`** "kept for future
  subscription changes" — speculative retention; the no-suppression rule wants it fixed,
  not silenced.
- **[Minor] Magic numbers in hot FFI paths.** `native_pty.dart` inlines `0x0001
  // POLLIN`, `28 /* SIGWINCH */`, `4 /* EINTR */`, `9 /* EBADF */` — but `libc.dart`
  already has a constants section and `errno_mapping.dart` has `PosixErrno.ebadf`.
- **[Minor] `git_commands.dart` has ~16 near-identical handler bodies** — a
  `_guarded(req, () async {...})` helper would remove ~60 lines of structural
  duplication. Borderline.

### Recommendations

**Quick wins:** fix the `SchedulerService` spawn race (track the spawn future like
`NativePty._readerReady`); replace the three silent `catch (_)` in `tree_sitter_ffi.dart`
with a logged last-error; delete the `Cmsghdr` alias and the `unused_field` suppression;
have the PTY layer consume `libc.dart` constants / `PosixErrno` instead of inline hex.

**Larger efforts:** decide the status of `lib/src/terminal/` — formally vendor it
(freeze, document, decision-record) or do the cleanup sweep; optionally a `_guarded`
helper for `git_commands.dart` (check whether `files_commands` / `editor_commands` share
the shape).

### Scorecard

| Dimension | Score | Justification |
|---|---|---|
| Idiomatic Dart | 4/5 | Sealed classes, named ctors, records, `const`, immutability used well; the vendored terminal tree pulls the average down. |
| Error handling | 4/5 | Typed errors with context everywhere in core; a few silent `catch (_)` in the FFI loader and test harness cost the 5th point. |
| Naming & readability | 4/5 | Clear, intention-revealing names; comments earn their place; inline magic numbers are the main blemish. |
| Consistency across subsystems | 3/5 | IPC/git/files/pty are uniform; `lib/src/terminal/` is a different codebase in style; PTY duplicates constants `libc.dart` owns. |
| Resource/lifecycle safety | 4/5 | `try/finally` around native allocs, controllers closed, subscriptions cancelled; the one real defect is the `SchedulerService` race. |

---

## 5. Security & supply chain — Security Engineer

### Executive summary

clide's security posture is **above average for a solo pre-v2.0 project**. All
subprocess calls use `Process.run`/`Process.start` with argument *lists* (no shell
interpolation), the IPC transport is a per-user Unix socket (not a TCP port), and there
is an explicit `path_safety` module with a containment check. The single biggest strength
is the disciplined no-shell subprocess layer. The single biggest risk is
**untrusted-workspace code execution via toolchain resolution**
(`toolchain_paths.dart:79`): a malicious repo can ship a `native/dugite/bin/git`
executable that clide will resolve and run. Secondary real issues: path-safety does not
defend against symlink escape, and IPC command args are largely unvalidated/un-bounded.
Supply-chain hygiene is mostly good but `licenses.yaml` has drifted from `pubspec.yaml`
and native binaries are committed without SHA pinning.

### Strengths

- **No-shell subprocess execution.** `GitClient._run` (`client.dart:210`),
  `PqlClient._run` (`client.dart:165`), and the PTY layer all pass `List<String>` args
  directly. Classic command injection is structurally prevented.
- **Toolchain uses resolved absolute paths** — git/pql/tmux resolved once to absolute
  paths and reused.
- **Path containment check exists and is used.** `resolveUnderRoot`
  (`path_safety.dart:21`) collapses `..`/`.` without touching the filesystem and enforces
  a prefix check with a separator guard. `files.read`/`files.ls` both call it.
- **IPC is a per-user Unix socket, not a network listener.** No `ServerSocket` over TCP
  anywhere; the default runtime path is in-process, eliminating the socket attack
  surface in the shipped app.
- **PTY FFI memory discipline** — all native memory allocated before `forkpty()`, `errno`
  captured before `free()`, freed on every path.
- **`pubspec.lock` is committed**, deps use exact pins (no carets), `licenses.yaml`
  exists with per-dep purpose/license.

### Findings

- **[Critical] Malicious workspace can plant a git binary that clide executes.**
  `toolchain_paths.dart:79-84` builds `'$workspaceRoot/native/dugite/bin'` and runs
  `_firstExisting(['$dugite/git'])`; if that file exists it becomes the git binary for
  all `GitClient` calls, **before** falling back to PATH. An attacker commits an
  executable at `native/dugite/bin/git`; clide runs it on the first `git.status` (which
  fires automatically on workspace open). Arbitrary code execution from merely opening a
  repo. The `native/dugite` convention should resolve relative to the *clide install
  dir*, never the workspace root.
- **[Major] Path-safety does not defend against symlink escape.** `path_safety.dart:
  35-51` explicitly does not resolve symlinks, and the filesystem layer
  (`files_commands.dart:81-85`) never does either. A repo symlink `config -> /etc/shadow`
  passes the containment check (the *link path* is under root) and clide reads the
  target. Fix: after `resolveUnderRoot`, `resolveSymbolicLinksSync()` and re-verify
  containment.
- **[Major] IPC command arguments are unvalidated and unbounded.**
  `DaemonDispatcher.dispatch` (`dispatcher.dart:26`) and `IpcRequest.fromJson`
  (`envelope.dart:49`) do no schema validation. No size limit on `files.read`, no count
  cap on `git.log`, no check that `git.checkout`'s `branch` (`git_commands.dart:240`)
  isn't a `-`-prefixed flag. `git diff`/`stage` use `--` separators (good), but
  `checkout(branch)` and `push(remote, branch)` do not — argument injection
  (`git checkout --upload-pack=...`) is possible.
- **[Minor] macOS entitlements disable library validation.**
  `macos/Runner/Release.entitlements` sets `disable-library-validation` = true with no
  App Sandbox entitlement. Arguably needed for the `dlopen` of `libtree-sitter.so`, but
  combined with no sandbox a compromised process has full user-level filesystem access.
- **[Minor] `licenses.yaml` has drifted from `pubspec.yaml`.** Lists dev-dep `test` at
  `1.25.8` but `pubspec.yaml:60` pins `1.30.0`; lists a `lints 5.0.0` not in
  `pubspec.yaml` at all. The two-step-commit guardrail is being violated.
- **[Minor] Native binaries committed without SHA pinning.** `native/linux-x64/` has
  `libtree-sitter.so` (24 MB) and `ptyc` (22 KB) committed with no `SHA256SUMS` manifest.
  CLAUDE.md says native deps are "pinned by SHA"; that pinning is not evidenced.
- **[Informational] No secrets service** — clide stores no tokens; git auth is delegated
  to the system credential helper. The right call; noted so the absence reads as
  deliberate.
- **[Informational] Lua runtime is a stub** — `lib/lua/src/host.dart` is Tier-0. Design
  intent (strip `io`/`os.execute`/`package.loadlib`/`debug`) is sound; re-assess at Tier
  6 — sandbox-escape via FFI re-entry will be the concern.

### Recommendations

**Quick wins:** fix toolchain resolution to resolve `native/dugite` against
`Platform.resolvedExecutable`'s directory, never `workspaceRoot` (closes the Critical);
add symlink re-check in `files.read`/`files.ls`; reconcile `licenses.yaml` with
`pubspec.yaml`; reject `-`-prefixed values for `branch`/`remote`/`path` args (or use
`--` everywhere, including `checkout`).

**Larger efforts:** schema-validate the IPC surface with typed arg schemas + size/count
bounds; add a committed `native/SHA256SUMS` verified by `make` and CI; revisit macOS
sandboxing (App Sandbox with explicit exceptions); security-review the Lua FFI boundary
and capability table before Tier 6 ships.

### Scorecard

| Area | Rating | Justification |
|---|---|---|
| Subprocess safety | 2/5 | No-shell arg lists are excellent, but the workspace-relative dugite path is a real RCE; argument-injection on `checkout`/`push` unmitigated. |
| IPC input validation | 3/5 | Per-user Unix socket + in-process default sharply limits exposure, but zero arg-schema validation and no size/count bounds. |
| Path/filesystem safety | 3/5 | Real containment check that's actually wired in, undermined by the unhandled symlink-escape gap. |
| Dependency/supply-chain hygiene | 3/5 | Exact pins, committed lockfile, documented deps — but `licenses.yaml` drift and missing SHA manifest for committed native binaries. |
| Secrets & sandboxing | 3/5 | Correctly delegates secrets; Lua sandbox is only a stub; macOS runs with library validation off and no App Sandbox. |

---

## 6. Docs, governance & DX — TPM / Developer-Experience Consultant

### Executive summary

clide runs an unusually disciplined governance system for a solo-dev pre-v2.0 project:
67 decision records across six domains, with a parser-validated DQR structure, anchored
cross-references, and a `make decisions-validate` gate wired into pre-push. The biggest
strength is that the DQR system is genuinely *alive* — questions get resolved with dated
amendments, superseded decisions are marked, and decisions cite the commits that
implement them. The biggest risk is **documentation drift in the narrative docs**:
`README.md` and `docs/initial-plan.md` describe an architecture (Go sidecar, `ptyc/` C
helper, `app/` subdirectory, separate daemon) that three major decisions (D-5, D-56, the
FFI pivot) have since dissolved. A new contributor reading the README first would build
a wrong mental model.

### Strengths

- **DQR system is maintained, not ornamental.** Resolved questions carry dated
  resolution lines pointing to the deciding D-record (`questions/architecture.md:39`
  Q-6→D-57). D-40 carries a `[SUPERSEDED]` tag and an amendment line.
- **Decisions are linked to code and commits.** D-67 (`decisions/process.md:61`) cites
  implementing commits `01a99ed`, `d162ba2`. D-66 references `ci/test.sh` by path.
- **Governance migration was done cleanly** — the `decisions/` → `governance/`
  restructure updated cross-references and the auto-generated index.
- **Commit discipline is real.** `git log` shows imperative subjects, no Conventional
  Commits prefixes, ticket refs, logical scoping — exactly what `git-commit/SKILL.md`
  prescribes.
- **`licenses.yaml` is thorough** — all six runtime Dart deps present, plus fonts/native
  libs, with purpose justifications. *(Note: the Security reviewer found version drift
  in this file — see Finding above; the two reviewers examined different rows.)*
- **Makefile is self-documenting** (`##` help annotations) and matches `CLAUDE.md`.

### Findings

- **[Critical] `docs/initial-plan.md` is badly stale.** The "north-star" doc (linked
  from `CLAUDE.md:14` and `README.md:44`) still describes a Go sidecar
  (`initial-plan.md:4,55,189`), `clide --daemon` long-running process (`:162-164`),
  `app/` subdirectory layout (`:184-204`), and `project.yaml` (`:172`) — all contradicted
  by D-5, D-56, and the single-package-at-root reality. Nothing flags it as historical.
- **[Critical] `README.md` describes a dissolved architecture.** `README.md:10`
  documents `ptyc/` as a live component; `README.md:36` lists `make ptyc-build`. The
  `ptyc/` directory does not exist, the Makefile has no such target, and the CHANGELOG's
  own Unreleased section records ptyc's removal.
- **[Major] `README.md:44` links to `decisions/`** — a directory that no longer exists
  (migrated to `governance/`). Dead link in the primary onboarding doc.
- **[Major] CHANGELOG has duplicate subsection headings in `[Unreleased]`.** Three
  `### Changed` blocks (`CHANGELOG.md:100, 114, 168`), two `### Fixed`, two `### Removed`
  in the 2.0.0 section. Keep a Changelog 1.1.0 expects one of each per release.
- **[Major] No `CONTRIBUTING.md` or onboarding doc.** For a project "intended to ship
  publicly to other developers," there is no contributor guide; the build/test story is
  scattered across `CLAUDE.md` (Claude-oriented), `README.md` (partly wrong), and
  Makefile help.
- **[Major] Coverage-floor governance contradicts itself.** D-66 (`testing.md:65`) says
  the floor lives at `coverage/floor.txt` starting "≈35%"; `CHANGELOG.md:44-46` says it's
  in `pubspec.yaml` `coverage_floor:` starting at 34%; the latest commit is `9030e56
  hold coverage_floor fixed at 90`. Three sources, three mechanisms/values. D-66 was
  never amended.
- **[Minor] `ci/release.sh` is a stub that still references goreleaser/sidecar** — Go
  tooling for a project with no Go.
- **[Minor] CHANGELOG `[2.0.0] — 2026-05-03` dating** — the v2.0.0 tag is dated
  2026-05-03 but the enormous Unreleased section represents ~80 commits of post-tag work
  with no interim version.
- **[Minor] Stale-ish open questions** — Q-25 (body text face) is de facto resolved by
  D-43/D-44 and the shipped impl; Q-1/Q-2/Q-3 ("defer until Tier 1 is in real use") are
  due for triage now that Tier 1 has shipped.
- **[Minor] Skills system is coherent but undocumented as a set** — eight skills under
  `.claude/skills/`, no index.

### Recommendations

**Quick wins:** rewrite `README.md`'s `ptyc/` sections and fix the `decisions/` link;
banner `docs/initial-plan.md` as historical (or split out a current
`docs/architecture.md`); merge the duplicate changelog subsection headings; amend D-66 to
reflect the floor's actual location/mechanism/value with a dated amendment line; triage
Q-1/2/3/25.

**Larger efforts:** write a human-facing `CONTRIBUTING.md` (clone →
`make hooks && flutter pub get` → `make test` → DQR workflow → commit conventions); cut
an interim release to drain the ~80-commit Unreleased backlog; add a
`.claude/skills/README.md` inventory; establish a periodic governance sweep (the repo
even has a `clean-house` skill for exactly this).

### Scorecard

| Area | Score | Justification |
|---|---|---|
| Governance discipline | 4/5 | DQR system genuinely maintained — but D-66 drift and untriaged Tier-1-era questions show the sweep cadence lags the code. |
| Documentation accuracy | 2/5 | Both primary onboarding docs describe a dissolved Go-sidecar/ptyc/daemon architecture; `CLAUDE.md` is accurate by contrast. |
| Changelog hygiene | 3/5 | Per-commit discipline is followed, but duplicate subsection headings violate the standard and an 80-commit Unreleased backlog undermines the format. |
| Contributor onboarding | 2/5 | No `CONTRIBUTING.md`; build story split across three docs, one wrong; `CLAUDE.md` is Claude-addressed, not human-addressed. |
| Convention adherence | 4/5 | Commit style, DQR claiming, `licenses.yaml` two-step rule demonstrably followed; docked for the changelog defects and the README gap. |

---

## Closing note

The recurring pattern across all six reviews: **clide's foundations are excellent and
its finishing is incomplete.** The extension contract, test helpers, FFI discipline,
governance system, and token system are all things most projects never get right. The
gaps — IPC not wired, keyboard not operable, docs describing a dead architecture, a
workspace-relative binary path — are all the kind of thing that happens when a fast-moving
solo project's implementation outruns its connective tissue. They are concentrated, not
diffuse, and the quick-win column above would close most of the critical ones in a few
focused days.
