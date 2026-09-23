# Test-suite quality audit

**Date:** 2026-09-23 · **Baseline:** `c9e080a7` (main) · **Scope:** `test/**` + `integration_test/**`, about 400 files and about 67k LOC.

This is a review of test **quality**, not a coverage-% report. Six read-only reviewers each took one cluster and applied the same rubric:

- assertion strength
- behaviour vs implementation coupling
- coverage padding
- flakiness
- missing cases
- duplication
- readability
- fake/mock drift
- skipped tests

Every finding cites `file:line`. Anything marked **verified** was re-read in the source by the coordinating session. Everything else is the reviewer's evidence-backed claim and should be spot-checked before acting on it.

## Summary

| Cluster | Files | ~LOC | Grade |
|---|---:|---:|:--:|
| `test/builtin/claude` | 55 | 14.5k | **B** |
| `test/builtin/*` (everything except claude) | 92 | 17.2k | **B** |
| Core subsystems (daemon, ipc, pty, cli, git, files, pql, …) | 82 | 11.8k | **B** |
| `test/kernel` | 63 | 8.6k | **B-** |
| Widgets, goldens, a11y, svg/draw, app, helpers, integration | ~90 | 8k | **B-** |
| `test/terminal` | 20 | 7.3k | **C+** |

**Overall: B-.** The best parts of the suite are behavioural, protocol-aware and regression-driven. Examples:

- `stream_json_session_test`, IPC server framing and UTF-8 split tests
- `self_update_test`, path-safety, companion lifecycle
- the terminal escape parser, settings round-trips, extension-lifecycle rollback

Three recurring problems pull the grade down:

1. **The 95% coverage gate has produced padding.** Several files say in their own headers that they exist to execute lines: `coverage_trivials_test`, `parser_and_scroll_test`, `more_widgets_test`, `zero_coverage_widgets_test`, `mop_up_test`. Beyond those, dozens of tests end with `findsOneWidget`, `isNotNull`, `isA<List>` or "no crash", and would pass against a broken implementation. Some of them hide real bugs.
2. **Some tests encode bugs as the expected behaviour.** The reviewers found at least 10 real product bugs, and 6 of them are locked in or masked by an existing test (see §1).
3. **Isolation and timing hygiene is uneven.**
   - About 190 `pumpAndSettle` calls, although the shared harness says "never".
   - Fixed `Future.delayed` waits, and about 30 hardcoded 2-second socket timeouts.
   - Tests that touch the live pql DB, the real `$XDG_RUNTIME_DIR` and the user's global git config.
   - About 17 copies of a process fake that no longer matches the real process.

## 1. Product bugs surfaced by the audit

These are defects in `lib/`, not in the tests. Each one needs a ticket and a failing test first.

| # | Bug | Where | Test status | Verified |
|---|---|---|---|:--:|
| 1 | **HTS (`ESC H`) never sets a tab stop.** It calls `isSetAt` (a read) instead of `setAt`. | `lib/src/terminal/src/terminal.dart:455` | Locked in: `terminal_test.dart:393` "setTapStop is a query, not a write" | ✅ |
| 2 | **Mouse wheel ids are 68–71 instead of 64–67.** xterm decodes 68 as wheel-up+Shift, so every scroll reaches vim/tmux as Shift+wheel. | `lib/src/terminal/src/core/mouse/button.dart:10-16` | Locked in: `mouse_test.dart:87-90` | ✅ |
| 3 | **X10/UTF mouse row is off by one.** The row gets an extra `+1` that the column doesn't. | `core/mouse/reporter.dart:28` | Locked in: `mouse_test.dart:101-103` | ✅ |
| 4 | **Palette index 15 (bright white, SGR 97/107) renders as `white`.** | `ui/palette_builder.dart:49-50` | Locked in: `ui/ui_pure_test.dart:54` | ✅ |
| 5 | **DECAWM off (`?7l`) still wraps to the next line.** It should overwrite the last column. | `core/buffer/buffer.dart:110-116` | Masked: `buffer_test.dart:212` only checks `isWrapped` | ✅ |
| 6 | **DECCKM (`?1h`) is ignored.** Arrow-key encoding follows `appKeypadMode` instead of `cursorKeysMode`. | `core/input/handler.dart:117` | Masked: the input fake hard-codes `cursorKeysMode => false`, and the mode test only checks the getter | ✅ |
| 7 | **Scheduler leaks after close/dispose.** The `ProjectClosed` subscription is never stored or cancelled, so listeners pile up on every `start()`. The four staggered initial `Timer`s are never cancelled either, so ticks fire after close. | `lib/kernel/src/scheduler.dart:52, 64` | Masked: `services_bigger_test.dart:212` asserts nothing | ✅ |
| 8 | **Settings YAML emitter doesn't quote leading indicator chars** (`[ { - * & ! \| > ' " % @`). A value such as `*.dart` or `[wip] x` writes invalid YAML, and the next load moves the whole file aside as `.broken`. | `lib/kernel/src/settings.dart:361-369` | Gap: `settings_test.dart:142` only covers `:` and `#` | ✅ |
| 9 | **Decision reader shows stale data.** `_load` has no request token, so a slow reply for D-1 that arrives after D-5 overwrites D-5. | `lib/builtin/decisions/src/decision_detail_view.dart:54-66` | Masked: `decision_reader_test.dart:268` uses a stub that answers synchronously | ✅ |
| 10 | **Wrong-type IPC fields become toolErrors.** `j['id']! as String` throws a `TypeError`, not a `FormatException`, so `{"id":1}` is reported as an internal toolError with `id: ''`. The `v` field is never checked. | `lib/src/ipc/envelope.dart:40` | Gap | ✅ |
| 11 | **`git apply` launch failure escapes unwrapped.** `_applyPatch` calls `Process.start` without the `ProcessException` wrapping `_run` has. Stderr is also read only after `exitCode`, so a large stderr can deadlock. | `lib/src/git/client.dart:230-237` | Worked around: `git_commands_errors_test.dart:48-52` excludes the hunk commands | ✅ |
| 12 | IRM (`CSI 4 h`) and focus reporting (`?1004`) are stored but never used. | `terminal.dart`, `buffer.dart` | Masked by getter-only mode test | reviewer |
| 13 | A keymap binding in a higher layer whose `when` is false falls through to a lower layer, contradicting the "fully shadow" comment. `_rebuildActive` uses `notifyListeners`, not `_safeNotify`. | `lib/kernel/src/keymap/keymap.dart:153-156`, `keymap_service.dart:148` | Gap | reviewer |
| 14 | `CommandRegistry.register` silently overwrites an existing id, and the first owner's `unregister` then removes the second owner's command. | `lib/kernel/src/commands/registry.dart:8-15` | Gap | reviewer |
| 15 | Terminal parser gaps: DCS, SOS, PM and APC are printed as text. ESC/CAN/SUB don't abort a CSI. A huge CSI param (`CSI 2147483647 b`) spins `repeatPreviousCharacter`. | `core/escape/parser.dart`, `terminal.dart:481` | Gap | reviewer |
| 16 | `pql` retry matches any stderr containing `locked` (e.g. "unlocked"), and there is no process timeout. | `lib/src/pql/client.dart:190` | Gap | reviewer |
| 17 | `_reap` uses `WNOHANG`, so a child that exits after EOF can be left as a zombie. | `lib/src/pty/native_pty.dart:510` | Gap | reviewer |
| 18 | Team-chat rows are keyed by `microsecondsSinceEpoch`, so two posts in the same µs get duplicate keys. | `lib/builtin/claude/src/team_chat_sidebar.dart:170` | Gap | reviewer |
| 19 | Editor echo suppression is a single boolean, so a real remote edit that arrives between a local edit and its echo is swallowed. | `lib/builtin/editor/src/editor_controller.dart` | Gap | reviewer |

For the terminal fixes (#1–6 and #12), take the expected values from xterm's *ctlseqs* documentation, not from the current code's output.

## 2. Cross-cutting themes

### 2.1 Tests that assert nothing, or the obvious

Look for a test name that promises a behaviour, followed by `findsOneWidget` on the root widget, `isNotNull` on a non-nullable field, `isA<T>` on a typed return, `>= 0`, or "no crash". Representative cases:

- **claude**
  - `team_chat_sidebar_test.dart:176-280, 373-443`: 8 @-completion tests end with "still functional". They also mention `_showOverlay`, which no longer exists.
  - `claude_pane_test.dart:303, 429`: "draft retained", "tap focuses composer".
  - `conversation_view_test.dart:541`: `findsWidgets` is already satisfied by the card's own `SvgView`.
- **kernel**
  - `facade_test.dart:13-34`: 22 `isNotNull` checks on `final` fields.
  - `services_stubs_test.dart:113-173`: five FocusTracker tests with no `expect`.
  - `toolchain_test.dart:82-103`: the T-98 security test can't fail, because `resolveToolchainPaths()` never reads the working directory.
- **core**
  - `git_commands_errors_test.dart:74` `if (!r.ok) expect(...)`: none of the 14 cases is actually required to fail.
  - `pql/client_test.dart`: `isA<List>` ×6.
  - `pty/session_test.dart:120`: `echo write-test-ok` is satisfied by the tty's own echo, even if the shell never ran it.
- **terminal**
  - `buffer_test.dart:772` strips every `\n` before checking "no inserted newline".
  - `render_test.dart:194` `isNonNegative`.
  - About 20 `isNotEmpty` checks where the exact escape string is known.
- **widgets/a11y**
  - `a11y/keyboard_traversal_test.dart:19-34` puts the button inside the test's own `Focus` and tests Flutter, not ClideButton. The traversal test it cross-references doesn't exist.
  - `a11y/semantic_coverage_test.dart` pumps no widgets.
  - `app_test.dart:317` "tap as no-ops" never taps.
- **builtin**
  - `file_tree_controller_test.dart:347` `expect(countAfterLoad, 1); // just confirming test ran`.
  - `syntax_text_controller_test.dart:79` "maps byte offsets" checks only the plain text.
  - Painter tests assert `hasInk == true` for feature-specific behaviour.

**Coverage-closeout files to retire or rewrite:** `test/terminal/coverage_trivials_test.dart`, `test/terminal/parser_and_scroll_test.dart`, `test/widgets/more_widgets_test.dart`, `test/widgets/zero_coverage_widgets_test.dart`, `test/kernel/**/mop_up_test.dart`. Move the cases that can carry a behavioural assertion into their per-widget or per-module files, and delete the rest. Expect coverage to drop. Budget the replacement tests before deleting anything, so the 95% floor holds.

### 2.2 Test names that claim more than they check

These are common enough to count as a pattern:

- `clide_face_test.dart:145`: the "parks" test asserts that it does *not* park.
- `settings_test.dart:92` "fires on set and load" checks only set.
- `extensions_manager_test.dart:253, 265` "warns" never checks the log.
- `client_test.dart:206` "logged" uses a logger with no sinks.
- `buffer_test.dart:487` "round-trips style + charset" checks position only.
- `clide_cli_e2e_test.dart:138` "→ notFound exit code" asserts `isNot(0)`.
- `decision_reader_test.dart:387, 476, 502`.

When the assertion can't be strengthened, rename the test.

### 2.3 Timing and flakiness

- **`pumpAndSettle`: about 190 calls**, roughly 90 in `test/builtin` and 100 in widgets/integration. `widget_harness.dart:98-106` says "never", because it has wedged the pre-push gate before. These calls pass today only because the trees are static. Replace them with `pumpAsync`/bounded pumps, and add a grep gate.
- **Wall-clock waits used as synchronisation:**
  - `claude_pane_test.dart:115-131`: 60 ms
  - `conversation_card_test.dart:79, 117`: 20 ms
  - `graph_controller_test.dart:198`: a 40 ms wait for a 20 ms debounce
  - `kernel/ipc/client_test.dart`: 13 waits of 50 ms before checking "connected"
  - `editor/registry_test.dart:239`
  - 20 ms waits to drain the bus in `server_streaming_test`/`server_events_pull_test`; use `pumpEventQueue()` instead.
- **Negative assertions after a short sleep** also pass if the system is merely slow: `files_commands_test.dart:366`, `mcp_server_test.dart:302`, `companion_extension_test.dart:111`. Use the pre/post marker technique from `watcher_test.dart:80-95`.
- **About 30 hardcoded 2 s socket timeouts** in `test/ipc/*` and `mcp_server_test.dart` bypass the shared `ioTimeout`.
- **`pumpUntil` fails silently** (`transcript_reader_test.dart:30`): it returns on timeout instead of calling `fail()`.
- **No suite-wide timeout** in `dart_test.yaml`, so a hung settle burns the long default.

### 2.4 Isolation from the host

- **pql tests read *and write* the live planning DB.** `test/pql/client_test.dart` and `test/daemon/pql_commands_test.dart` rely on real D-1/T-1/T-6 records and call `pql.decisions.sync`. This is also why the `serial` tag is needed. Use a fixture vault in a temp dir, or an argv-echo fake-pql (the helper already exists at `client_test.dart:170`).
- **IPC tests use the real `$XDG_RUNTIME_DIR/clide`.** `withXdg` (`test/ipc/server_test.dart:37-52`) does nothing (✅ verified), while the file header claims it overrides the variable. `server.start()` probes, and may unlink, the sockets of a running clide. Give `IpcServer` and the path helpers a `socketDir` override, as `McpServer.discoveryDirOverride` already does.
- **Git sandboxes inherit global git config** (`gpgsign`, `hooksPath`, `defaultBranch`) and don't check `git` exit codes. The setup is repeated 4 times. Add `test/helpers/git_sandbox.dart` with `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`.
- **Other host dependencies:**
  - `menubar/file_actions_test.dart:27` opens the developer's real checkout.
  - `extension/src/host_test.dart:62` reads the real `~/.clide/extensions`.
  - `toolchain_test.dart:105` depends on the host `CLIDE_DUGITE_DIR`.

### 2.5 Fakes that have drifted from the real code

- **Process fake:** about 17 local `_FakeProc` copies (8 in claude, 7 in companion, plus others). The real `ClaudeStreamJsonProcess` has a single-subscription `lines`, an `exitCode` that is never null, and a `kill()` that waits for exit. Most fakes use broadcast streams, a null `exitCode` and an instant kill. As a result, double-listen bugs can't show up and `ClaudePane._onSessionEnd` can't be reached. Make one `test/helpers/fake_stream_json_process.dart`.
- **`FakeDaemonClient` (`test/helpers/fake_ipc.dart`):**
  - It answers stubs even when disconnected; the real client returns "daemon not connected".
  - Unstubbed commands silently return `notFound`.
  - It keeps no call log, so a destructive verb like `git.discard` with the wrong `paths` still passes.
  - It doesn't override `reconnect*`.

  Add call recording, a strict mode, a disconnected-path error and `Completer`-backed deferred stubs. The deferred stubs are what make race tests such as bug #9 possible.
- **`TerminalState` fake:** copied 3 times, with a hard-coded `cursorKeysMode => false` that hid bug #6.
- **In-memory `AssetBundle`:** copied 3 times. `keymap_service_test.dart:220` uses `codeUnits`, which isn't UTF-8.

### 2.6 Test infrastructure

- **`harness()` is misleading.** It pairs `MediaQueryData()` (0×0) with `OverlayHost(canSizeOverlay: true)`, which hands the child unbounded width. Its docstring claims the opposite. The consequences:
  - width, Flexible and Expanded behaviour can't be tested through it;
  - about 23 tests hand-roll their own kernel/theme/MediaQuery tree to work around it.

  Make a sized, bounded harness the default, keep the intrinsic variant opt-in under an honest name, and fix the docstring.
- **Silent platform skips.** An early `return` registers zero tests or passes green instead of showing as skipped:
  - `tree_sitter_smoke_test.dart:24`, `watchdog_test.dart:31`
  - `pty/session_test.dart:27, 215`, `pane_commands_test.dart:18`, `panes/registry_test.dart:19`
  - `windows_pty_test.dart:21`, `paths_test.dart` ×4

  Use `skip:` or `@TestOn` instead.
- **Goldens.**
  - Skipping the comparison on CI is a documented trade-off (`golden_harness.dart:12-20`), so pixel validation happens only in the local pre-push.
  - Given that, the **macOS golden set is incomplete**: 8 PNGs against 15 for Linux (✅ verified), and the ones present are older. A macOS pre-push would fail or compare against stale images. Either complete the set or skip goldens off Linux explicitly.
  - Every golden uses the `_miniTheme` fixture and default state only: no hover, focus, overflow, long label, light or high-contrast theme. The companion and conversation goldens, which cover multiple states and widths, are the model to follow.
- **a11y depth.** No test uses `meetsGuideline(...)`. Semantics are unchecked on the menu, status indicator, filter box, spine, pty view and lightbox. `contrastRatio` has no known-value test (black/white = 21), yet the WCAG gate depends on it.
- **Teardown on failure.** Several places dispose or unmount as the last statement instead of with `addTearDown`, so a failed `expect` leaks tickers or semantics into later tests and hides the real failure behind timer errors: companion widget tests, `claude_meta_sidebar_test`, `drag_resize_test`, the integration tests. Temp dirs are leaked in `kernel/ipc/client_test`, the integration tests and `clide_cli_e2e`.

### 2.7 Duplication

Candidates for `test/helpers/`:

- **Process and state fakes:** `fake_stream_json_process.dart`, `terminal/_support.dart` (the `TerminalState` fake and `_host` wrapper, each copied 3–4 times).
- **Painting and assets:** `paint_probe.dart` (`hasInk`/`inkCount`/`tokensFrom` ×3), `map_asset_bundle.dart` plus `testPalette()`.
- **I/O:** `ipc_socket.dart` (line reader, round-trip, silent logger, SSE connect; 3–4 copies each), `git_sandbox.dart`.
- **Local copies worth folding into a helper:** the response map pasted 8 times in `decision_reader_test.dart`, and the sidebar and pane groups in `team_chat_sidebar_test` that mirror each other and should be parameterised.

## 3. What's done well (copy these)

- **Wire-shaped fixtures and contract tests:**
  - `stream_json_session_test.dart`: optimistic update with rollback on a `control_response` error, and status replayed to late subscribers.
  - `ipc/server_test.dart:251, 273`: ordering of pipelined frames and a UTF-8 character split across writes.
  - `escape/parser_test.dart`: a recording handler with truncated/hostile SGR input.
- **Tests with real dependencies:**
  - `update/self_update_test.dart`: real tar and sha256, only the download is faked.
  - `files/path_safety_test.dart`: symlink-chain escapes.
  - Companion lifecycle tests: through the real orchestrator, and nearly every `expect` has a `reason:`.
- **Race-free time:**
  - `file_tail_follower_test` drives `pollOnce()` directly.
  - `toast_test` uses fake-time pumps.
  - `transcript_reader_test.dart:790` pins mtimes.
  - The ClideFace goldens pin both clocks.
- **Pixel probes:**
  - `svg_painter_test.dart:44-123`, which reads back ARGB without depending on fonts.
  - `face_painter_test.dart:115-177`, which compares against a baseline render.
- **Guards that can't pass vacuously:** `no_bare_editable_text_test.dart:48`, `contrast_test.dart:58` (theme drift guard), `i18n_coverage_test`, and `serial_tags_test`, which reads the live scripts.

## 4. Action plan (priority order)

1. **Fix the verified product bugs (§1, #1–11), writing a failing test first.** The terminal tests that lock in bugs #1–5 are changed to match the xterm spec in the same commit.
2. **Upgrade the shared fakes.**
   - `FakeDaemonClient`: call log, strict mode, disconnected error, deferred stubs.
   - A single `FakeStreamJsonProcess` that matches the real contract.
   - Then write the race tests: decision `_load`, editor echo suppression, `_onSessionEnd`.
3. **Isolate from the host:** pql fixture vault or argv-echo fake (this also drops the `serial` tag), an `IpcServer.socketDir` override, `git_sandbox` helper, and no reads of the real checkout or `~/.clide`.
4. **Timing sweep.**
   - Mechanical: `pumpAndSettle` → `pumpAsync`; fixed delays → condition polling that `fail()`s at the deadline; 2 s → `ioTimeout`; drain sleeps → `pumpEventQueue()`.
   - Add a grep gate for `pumpAndSettle` and `Future.delayed` in `test/`.
   - Set a suite timeout in `dart_test.yaml`.
5. **Retire the coverage-closeout files (§2.1) and rewrite the vacuous tests** with behavioural assertions. Pair each deletion with replacement tests so the 95% floor holds. Rename any test whose claim still can't be asserted.
6. **Harness:** a sized `harness()` as the default, correct docstrings, and fold in the ~23 hand-rolled trees. Replace silent `return` skips with visible `skip:`.
7. **Make the a11y and golden gates mean what they say:**
   - a real Tab-order traversal test;
   - `matchesSemantics` / `labeledTapTargetGuideline` sweeps;
   - a known-value `contrastRatio` test;
   - hover, focus, overflow and real-theme golden scenarios;
   - resolve the half-populated macOS golden set.
8. **Terminal conformance layer.** Add `test/terminal/conformance_test.dart`, which feeds bytes to `write()` and asserts `getText()`, the cursor and cell attributes. Cover:
   - CSI split across chunks, DCS/APC, ESC aborting a CSI, huge params;
   - wide char at the last column, combining marks, pending wrap;
   - scroll regions, alt-screen round-trip, resize reflow, scrollback cap;
   - DECSC restoring SGR, and DECCKM/IRM behaviour.
9. **Consolidate the duplicated helpers (§2.7).**

## 5. Untested code of substance

- `lib/src/shell/{layout,hat_bar,root_shell,project_switcher}.dart` (~980 LOC): reached only indirectly through `app_test`.
- `lib/builtin/git/src/git_panel_view.dart` (503), `git_status_item.dart` (264): commit, push, pull and open-file actions have no widget test.
- `lib/builtin/pql/src/pql_search_body.dart` (299), `problems/src/problems_view.dart` (159), `theme_picker/src/appearance_control.dart` (126).
- `lib/builtin/view/src/extension.dart`: zoom in/out/reset commands.
- `lib/builtin/shared/reader_chrome.dart` (165): exercised only through the readers.
- `lib/src/editor/buffer.dart`: `Selection` JSON round-trip and equality.
- `lib/builtin/claude/src/stream_json_session.dart:70-138` `ClaudeStreamJsonProcess`: the argv contract, and SIGTERM → 2 s → SIGKILL escalation (T-437).
- `lib/src/panes/registry.dart:135-143`: `pane.exit` on natural child exit. No test references it.
- `lib/src/ipc/mcp_server.dart:209`: SSE session cleanup. The file header promises this test.
- `lib/src/terminal/src/ui/gesture/*` (~280 LOC) and `core/escape/csi_handlers.dart` (437): checked only indirectly or through the recording handler.
- `lib/widgets/src/`:
  - `clide_resize_border` (pan → `startResize(edge)`)
  - `clide_pty_view` semantics
  - `clide_spine` badge
  - `clide_typeahead` keyboard navigation and Esc
  - `clide_toast` per-severity rendering
  - `clide_svg_view`

---

## Appendix: per-cluster detail

### A. `test/builtin/claude` (B)

**Strengths:**
- `stream_json_session_test` is exemplary.
- The concurrency tests in `session_orchestrator_test.dart:142, 148` are real.
- `session_lifecycle_test` has `_GatedProc`, which proves `close()` waits for the process to die.
- The `session_reader_test` fake goes through the production path.
- `extension_commands_test.dart:27-57` is a table-driven D-6 error-envelope check.

**Findings:**
- **High**
  - `team_chat_sidebar_test.dart:176-280, 373-443`: tests with no real assertion that reference removed internals. Assert the `ClideTypeahead` suggestion, Escape, and `_completeName` rewrite.
  - `claude_pane_test.dart:303-311, 429-434`: draft and focus are never checked.
  - `conversation_view_test.dart:541`: tautological `findsWidgets`. Use `findsNWidgets(2)` or `dialog.isOpen`.
  - `session_lifecycle_test.dart:263-333`: re-implements the `_killAllSessions` loop in the test. Drive `claude.kill-all-sessions` with live fake sessions instead.
- **Med**
  - `_FakeProc` drift (§2.5).
  - Wall-clock waits: `claude_pane_test.dart:115`, `conversation_card_test.dart:79, 117`, `transcript_reader_test.dart:30, 903`.
  - `conversation_view_test.dart:534`: colour never checked.
  - `extension_commands_test.dart:124-155`: no `expect`.
  - `conversation_card_test.dart:34`: `widgetList<Opacity>().first` coupling.
  - `image_thumbnail_test.dart:23`: the async load never runs.
- **Low**
  - `transcript_reader_test.dart:147-194`: tests `String.replaceAll`, getters and `toString`.
  - `stream_json_session_test.dart:432`: the time is never checked.
  - `claude_pane_test.dart:295`: `contains('permission')`.
  - `claude_meta_sidebar_test`: dispose without `addTearDown`, and un-disposed `ClaudeConfig`.
  - Setup duplicated in `conversation_view_test` and `claude_meta_sidebar_test`.

### B. `test/builtin/*` except claude (B)

**Strengths:**
- The companion lifecycle and strip tests, where nearly every `expect` has a `reason:`.
- Canvas geometry checked against `CanvasViewport.fit`, including "onChanged fires once per gesture".
- The glyph-coverage guard, ticker-parking checks, and "no network on open".
- Good `runAsync` discipline.

**Findings:**
- **High**
  - `decision_reader_test.dart:268`: a race test that can't race (bug #9).
  - `file_tree_controller_test.dart:347-369, 479-493`: tests with no real assertion.
  - `syntax_text_controller_test.dart:61-95`: the byte-offset mapping is untested.
- **Med**
  - About 90 `pumpAndSettle` calls across 13 files (e.g. `editor_view_test` has 20+).
  - `graph_controller_test.dart:173-213`: real debounce timers.
  - `clide_face_test.dart:145, 256`: names contradict the assertions.
  - `canvas_painter_test.dart:98, 135-147` and `graph_painter_test.dart:59-77`: `hasInk`-only checks.
  - `git_controller_test.dart:100`: stubs ignore args, including `git.discard`.
  - `file_actions_test.dart:27`: opens the real checkout.
  - Fakes and paint helpers duplicated.
  - `decision_reader_test.dart` (801 LOC): heavy duplication.
- **Low**
  - `welcome/dialog_test.dart:42-111`: duplication, and the non-repo case proves nothing.
  - Getter padding: `cli_install`, `tools_settings`, `ipc_status`.
  - `face_state_test.dart:131` is a tautology.
  - `tools_settings/extension_test.dart:22`: dispose isn't awaited.
  - Stale comments: `category_view_test.dart:230, 283`, `clide_face_test.dart:18`.
  - `companion_extension_test.dart:111, 121, 262`: 20 ms negative waits.
- **No test dir:** `claude_control`, `grammars_core`, `todos` (thin shims, fine) and `view` (worth a test). The empty `test/builtin/shared/` directory can be removed.

### C. Core subsystems (B)

**Strengths:**
- IPC framing, ordering, UTF-8 split, stale-socket handling, and 0600/0700 permission checks.
- Path safety and ref-injection rejection.
- MCP auth.
- `self_update_test`.
- Guard tests that read the live scripts.
- Event-driven waits in the watcher and PTY tests.

**Findings:**
- **High**
  - `git_commands_errors_test.dart:74`: the conditional `expect` (and bug #11).
  - The pql tests depend on the live DB (§2.4).
  - Padding in `files_commands_test.dart:344`, `pql/client_test.dart` (`isA<List>` ×6, a tautology at `:73`, pass-if-no-throw at `:150`), `pql_commands_test.dart:183` and `host_test.dart:62`.
  - `pty/session_test.dart:120`: the command is echoed by the tty, not run by the shell.
- **Med**
  - The real `XDG_RUNTIME_DIR` (§2.4).
  - About 30 2-second timeouts.
  - Sleep-then-assert-nothing checks.
  - Wrong-type envelope fields (bug #10).
  - "Doesn't throw" tests in `session_test.dart:126, 194, 246`, `server_streaming_test.dart:241`, `server_test.dart:216`, `pane_commands_test.dart:68`.
  - `FakeDaemonClient` drift.
  - Git sandboxes use the global config.
- **Low**
  - Silent platform skips.
  - `clide_cli_e2e`: 11 repeated skip guards, and the compiled binary's temp dir leaks.
  - Weak checks: `paths_test.dart:25, 69`, `clide_cli_e2e_test.dart:138` (should assert 3), `mcp_server_test.dart:276` (should assert -32601), `git/client_test.dart:109`, and `session_test.dart:84`, which swallows the timeout.
  - SSE, socket and logger helpers duplicated.
  - `contribution_test.dart`: getter echo.

### D. `test/kernel` (B-)

**Strengths:**
- Keymap parser error paths and layer precedence.
- Settings regressions: number-shaped keys, maps in lists, the `.broken` copy, atomic writes.
- Transactional rollback tests for the extension lifecycle.
- Injected env/home and fake-time toasts.

**Findings:**
- **High**
  - Scheduler (bug #7).
  - Settings quoting (bug #8).
  - `toolchain_test.dart:82-116`: the security test can't fail, and the env test depends on the host. Make `resolveToolchainPaths({env, exeDir})` injectable.
- **Med**
  - `ipc/client_test.dart`: 13 waits of 50 ms, and leaked temp sockets.
  - Tests without assertions: `services_stubs_test.dart:113-173`, `drag_resize_test.dart:226`, `extensions_manager_test.dart:239, 271`, `facade_test.dart:51`, `services_bigger_test.dart:192`, `keymap_service_test.dart:147`.
  - Tautologies: `facade_test.dart:13-34`, `mop_up_test.dart:54`, `client_test.dart:118`.
  - Names that overclaim (§2.2).
  - Silent skips in `tree_sitter_smoke_test` and `watchdog_test`.
  - Command-id conflicts (bug #14) and keymap fall-through (bug #13).
- **Low**
  - `AssetBundle` and palette duplication.
  - Padding: `toString`/`hashCode` tests, and `mop_up_test.dart:140`'s `1 < ratio < 21`.
  - Comments that cite lib line numbers: `extensions_manager_test.dart:313, 318`.
  - Inline dispose in `drag_resize_test`.
  - `DateTime.now()` used for temp paths: `mop_up_test.dart:169`.
- **Gaps:**
  - `contrastRatio` known values.
  - Theme loader: the `syntax:` block, invalid hex, and wrong-type `TypeError`.
  - Settings: `_unflatten` key collision, `canSet`, `keysAt`.
  - `KeymapService.resolveSequence`.
  - Facade dispose order.

### E. Widgets, goldens, a11y, helpers (B-)

**Strengths:**
- The per-primitive interaction tests: menu, anchored autoFlip, tooltip, context menu, collapser semantics, quick-open, multitab reorder.
- SVG pixel probes.
- The WCAG contrast gate with its drift guard.
- i18n parity.
- Pinned clocks in the face goldens.
- The harness has its own test (`widget_harness_test`).

**Findings:**
- **High**
  - `keyboard_traversal_test.dart:19-34` doesn't test ClideButton, and cross-references a traversal test that doesn't exist.
  - `more_widgets_test.dart` and `zero_coverage_widgets_test.dart` are coverage padding (spine badge, resize border, pty-view semantics and scrollbar are all unasserted).
  - The golden CI comparison is skipped and the macOS set is incomplete.
- **Med**
  - Goldens cover only default states on the mini theme.
  - a11y lacks `meetsGuideline` and semantics checks.
  - `semantic_coverage_test` is mis-scoped.
  - Tautologies: `clide_icon_test.dart:22`, `svg_painter_test.dart:142-166` (asserts the image size it created), `icons_test.dart:25`.
  - `app_test.dart:190, 246-263, 317` checks nothing.
  - About 100 `pumpAndSettle` calls.
- **Low**
  - Widgets tested twice: code block, filter box, markdown.
  - About 23 hand-rolled trees.
  - Integration-test temp dir and dispose hygiene.
  - Static `counts` map shared across tests: `multitab_pane_test.dart:28`.
  - `clide_file_image_test`: no same-length re-export case, and `mtime ^ size` can collide.

### F. `test/terminal` (C+)

**Strengths:**
- `escape/parser_test.dart`: recorded call sequences, colon-form SGR, hostile input (T-369), CSI intermediates, table-driven DECSCUSR, ESC/OSC held back across chunks.
- UTF-8 split across `writeBytes` (T-373).
- The recording-canvas cursor geometry test in `painter_test.dart:116`.
- Reflow anchor tests (T-92).
- No real timers anywhere.

**Findings:**
- **High:** bugs #1–6. The mode-flag test (`terminal_test.dart:588`) checks only storage.
- **Med**
  - `coverage_trivials_test` and `parser_and_scroll_test` (bounds like `>= 4` where the exact value is known).
  - Tests with no assertions in `terminal_test`, `painter_test.dart:109-217` and `render_test`.
  - `isNotEmpty`/`isNotNull` where the exact escape string or selection range is known.
  - Misleading names: `buffer_test.dart:222, 487`, `mouse_test.dart:206`.
  - Coupled to internals: `line_test.dart:323` (backing-array capacity), `core_test.dart:337, 384` (lib line numbers).
- **Low**
  - Weak resize assertions, and no end-to-end reflow test through `Terminal.resize`.
  - `TerminalState` fake copied 3 times, `_host` 4 times.
  - `painter_bold_metrics_test.dart:22` depends on the cwd.
- **Gaps:** the conformance list in §4 item 8, plus:
  - `sendCursorPosition`/`sendSize` output (only 2 of 6 checked);
  - invalid UTF-8 → U+FFFD;
  - `?1002`/`?1003` motion reporting;
  - modifier bits in mouse reports;
  - selection text across wrapped lines.
