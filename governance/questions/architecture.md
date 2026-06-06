# Open Questions — Architecture

IPC, events, canvas, window chrome, macOS signing, pql absorption,
ticket persistence.

---

### Q-1: Authorisation granularity on the IPC socket
- **Status:** Open
- **Question:** The daemon's token auth is coarse (allow all / deny all). Do we need per-subsystem grants later (e.g. restrict `git push`), and if so, what's the model — capability tokens? An explicit grant table per client? Time-limited grants?
- **Context:** Surfaced in the old ADR 0006 open-questions footer; deferred until Tier 1 is in real use.
- **Triage (2026-05-17):** Still open. Tier 1 has shipped but the IPC socket server itself is unimplemented (T-99). Re-evaluate once the socket lands and external CLI clients exist.
- **Source:** ADR 0006 (migrated to [D-6](architecture.md)).

### Q-2: Back-pressure on event streams
- **Status:** Resolved → [D-85](../decisions/architecture.md#d-85-event-bus-delivery--bounded-ring-buffer-back-pressure-in-memory-cursor-retention-bus-owned-if-persisted)
- **Resolved (2026-06-06):** Bounded per-subscriber ring buffer, drop-oldest, with a per-subscriber dropped-count surfaced as a gap marker — producer never blocks, subscribers never killed. The ring also serves the [Q-3](#q-3-event-persistence--auditundo) cursor retention.
- **Question:** A subscriber that falls behind on `pane.output` (a firehose) needs a policy: drop oldest, block producer, coalesce, or kill subscriber. Which?
- **Context:** The event bus is in-memory; back-pressure policy is undefined. Defer until Tier 1 is in real use and we have a real firehose to measure against.
- **Triage (2026-05-17):** Still open. PTY panes ship and produce real firehoses, but no subscriber has fallen behind in observed use. Re-evaluate when a multi-client IPC scenario (T-99) makes this measurable.
- **Source:** ADR 0006 (migrated to [D-6](architecture.md)).

### Q-3: Event persistence + audit/undo
- **Status:** Resolved → [D-85](../decisions/architecture.md#d-85-event-bus-delivery--bounded-ring-buffer-back-pressure-in-memory-cursor-retention-bus-owned-if-persisted)
- **Resolved (2026-06-06):** In-memory cursor ring only in v1 (no disk); serves `clide events --since`. If persistence is ever needed it is **owned by the bus**, not a subscriber-subsystem — reversing ADR 0006's unreasoned open-questions footer (it asserted "a subsystem that subscribes and writes — not a property of the bus" with no rationale, which is why it became this question).
- **Question:** Events are in-memory only in v1. If a future need (audit log, undo history) wants persistence, is it a property of the bus or a subsystem that subscribes and writes?
- **Context:** ADR 0006 leaned "subsystem that subscribes and writes" but didn't commit.
- **Triage (2026-05-17):** Still open; no concrete trigger yet. Revisit when the first persistence requirement lands (likely Tier-6 audit/undo).
- **Source:** ADR 0006 (migrated to [D-6](architecture.md)).

### Q-4: `.canvas` schema compatibility with Obsidian
- **Status:** Open
- **Question:** Clide's canvas (Tier 5) should read/write something — either Obsidian's `.canvas` JSON schema verbatim, a compatible-ish superset, or our own format. Each has trade-offs.
- **Context:** Obsidian's canvas users might want their canvases portable; conversely, bending to Obsidian's schema constrains our canvas features.
- **Source:** CLAUDE.md "Open questions" footer.

### Q-5: IPC wire-format stability + `schema_version:`
- **Status:** Open
- **Question:** When do we freeze the IPC envelope / schema and introduce `schema_version:` in `pubspec.yaml`? What's the bump policy for breaking changes?
- **Context:** Covered partially by [D-6](architecture.md)'s `v: 1` starting point; CLAUDE.md flags this as "decide when the first real subcommand lands."
- **Source:** CLAUDE.md "Open questions" footer.

### Q-6: Window chrome — native frame vs frameless custom
- **Status:** Resolved → [D-57](../decisions/architecture.md#d-57-frameless-custom-chrome-with-per-column-24px-hats)
- **Question:** Does clide ship with the OS-native window frame (title bar, min/max/close from the WM) or a frameless custom chrome that gives us pixel control at the cost of reimplementing window controls per-platform?
- **Context:** Surfaced during Tier-0 plumbing discussion; resolved 2026-04-23 — frameless with per-column 24px hats.
- **Source:** 2026-04-21 planning.

### Q-7: macOS app bundle signing / notarisation
- **Status:** Open
- **Question:** Distributing a signed macOS `.app` requires a Developer ID and a notarisation pipeline. Do we gate macOS builds on this (Tier 6), or ship unsigned with a known "right-click, open" user workflow for early testers?
- **Context:** Linux is primary; macOS is a stretch target. Notarisation is a separate cost from the Flutter build.
- **Source:** 2026-04-21 planning.

### Q-21: Pql absorbs planning vs keeps separate
- **Status:** Resolved → [D-3](../decisions/architecture.md#d-3-pql-as-supporter-tool-clide-wraps-never-duplicates) + [D-39](../decisions/process.md#d-39-planning-tooling-lives-in-pql-not-clide)
- **Question:** Three shapes for planning tooling's long-term home: (A) Pql absorbs planning — `pql decisions …` + `pql ticket …` subcommands; clide shells out. (B) Clide absorbs pql — reverse [D-3](../decisions/architecture.md#d-3-pql-as-supporter-tool-clide-wraps-never-duplicates), one big Dart tool. (C) Separate new binary just for planning.
- **Context:** Resolved 2026-05-11 in favour of (A). pql 1.4.30 ships full planning surface (`pql decisions …`, `pql ticket …`, `pql plan …`). Clide consumes via shell-out under `lib/src/pql/`. D-39 already encoded the intent; D-3 the wrap-don't-duplicate rule. The Python stopgap ([D-40](../decisions/process.md#d-40-superseded-python-stopgap-under-toolsscriptsplan)) was sunset on schedule.
- **Source:** 2026-04-21 planning.

### Q-23: SSH-remote development — run clide against a remote workspace
- **Status:** Open
- **Question:** Clide today assumes the workspace, the daemon, and the Flutter UI all run on the same machine. A growing class of users edits on remote systems (build servers, GPU boxes, cloud dev environments). What's the architecture for "open repo on host-B from UI on host-A"? Two shapes: (A) daemon-on-remote — clide's Dart daemon runs on the remote; the app talks to it over an SSH-tunnelled unix socket or a dedicated TCP socket (mTLS?), pty/process/filesystem work stays server-side; local app is pure UI. (B) filesystem-mounted — remote mounted via sshfs/9p/rclone, daemon runs locally against the mount; simpler but every fs op + git call crosses the network, and PTYs get complicated (local shell on remote filesystem? ssh-exec per command?). (A) matches VS Code Remote / JetBrains Gateway; (B) matches nothing load-bearing. Sub-questions either way: auth (ssh-agent? per-project keys? OIDC?), tmux / Claude session persistence semantics (does primary-per-repo re-key on host + repo?), multi-host identity in `.pql/pql.db`, latency tolerance for the event stream, re-sync on disconnect.
- **Context:** Surfaced 2026-04-22 during Tier-1 planning. Not a Tier 1 concern — terminal + Claude panes land local-first — but the daemon/IPC seam decisions (notably `D-5` and `D-6`) constrain the future answer. Worth scoping before Tier 6 (extension API) so third-party extensions don't accrue assumptions the remote path would have to unwind.
- **Source:** 2026-04-22 planning (user-raised).

### Q-22: Ticket persistence strategy
- **Status:** Resolved → [D-67](../decisions/process.md#d-67-pql-changelog-files-are-committed-alongside-code)
- **Question:** Once [Q-21](#q-21-pql-absorbs-planning-vs-keeps-separate) resolves in favour of (A), how do tickets handle shared team state? (1) Never commit (per-dev, ephemeral — works for solo). (2) Commit on milestone (settled-reach's sprint-close pattern — kanban has no natural equivalent, `release` or `tier-cut` is the closest). (3) Markdown mirror — every mutation writes `tickets/T-NNN.md` alongside SQLite; git-legible authoritative record; DB is rebuildable. (3) is probably the eventual answer.
- **Context:** Resolved 2026-05-11 → option (3), evolved. Pql 1.4.x reshaped ticket persistence into append-only per-month `.pql/changelog/<table>/<YYYY-MM>.sql` files with inline LWW guards. Committed alongside code; `pql.db` rebuildable from changelog + `governance/*.md`. Clide migrated on 2026-05-09.
- **Source:** 2026-04-21 planning.

### Q-25: Body text face — mono everywhere vs Josefin Sans UI + mono code
- **Status:** Open
- **Question:** The design handoff uses JetBrains Mono for all UI text (tab labels, file paths, status bar, sidebar labels), reserving Josefin Sans only for display/title text. Our current implementation uses Josefin Sans as the ambient UI face with JetBrains Mono only for code/terminal/diff surfaces. Which direction?
- **Context:** The design's "mono everywhere" rationale: clide is an IDE for people who like grids. The current Josefin Sans rationale: visual distinction between chrome text and code text, warmer feel. Both are valid — this is a feel decision, not a technical one.
- **Triage (2026-05-17):** Still open. The Josefin-Sans-as-UI-face implementation has shipped and is the current default; the design's "mono everywhere" direction remains unrealised. Convert to a D-record when the design call is made.
- **Source:** 2026-04-22 design handoff review.

### Q-26: Small screen layout (< 1000px)
- **Status:** Open
- **Question:** Below 1000px window width, should clide switch to modal viewer/editor instead of split, or stack panels vertically? The spec defers this but flags it.
- **Context:** The interaction model defines breakpoints down to 1200px but punts on < 1000px. This matters for small laptops and tiling WM users who give clide half a screen.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 1.

### Q-27: Two-editor split
- **Status:** Open
- **Question:** Should clide support two files open in the editor simultaneously (horizontal split in the middle column)? The spec says resist until proven needed — feels like tabs creeping back.
- **Context:** [D-48](../decisions/architecture.md#d-48-chrome-budget--no-tabs-no-breadcrumbs-keyboard-first) deletes buffer tabs. A two-editor split would be the only way to compare files side-by-side without using the viewer ↔ editor swap. The diff view may cover most of this need.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 2.

### Q-28: Terminal strip scope — shell only or logs/errors/tests
- **Status:** Open
- **Question:** Is the app strip (bottom bar) purely a terminal shell + status, or does it also host tabs for logs, errors, and test output? Probably both, later.
- **Context:** The interaction model spec defines the app strip as 14px with terminal shell + daemon indicator + branch; expanding on focus. If it grows to host logs/errors/tests, it becomes a mini-panel with its own tab model.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 3.

### Q-29: Branch picker location
- **Status:** Open
- **Question:** The branch picker was moved out of the bottom status bar. Best place is inside the git section header (left panel), with a compact indicator in the app strip. Confirm or revise?
- **Context:** The interaction model spec suggests the git section header as the primary location. The app strip shows a compact indicator (branch name only) for at-a-glance awareness.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 4.

### Q-30: Focus behavior when editor is dirty and viewer is peeked
- **Status:** Open
- **Question:** When the editor has unsaved changes and the user peeks a viewer, where does focus land? The spec says prompt-bar-rule wins: focus stays in Claude.
- **Context:** This intersects [D-47](../decisions/architecture.md#d-47-interaction-model--claude-is-home-layout) (Claude is home) and [D-49](../decisions/architecture.md#d-49-editor-mode--inline-above-claude-viewer-swap) (editor mode). If focus always snaps to Claude, the user must explicitly re-focus the editor to continue typing.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 5.

### Q-31: XWayland fallback for frameless — proper Wayland protocol needed
- **Status:** Open (load-bearing workaround in place)
- **Question:** The frameless window (D-57) currently forces `GDK_BACKEND=x11` because GTK3 doesn't implement the `xdg-decoration` Wayland protocol and KWin ignores `gtk_window_set_decorated(FALSE)` on native Wayland. When do we replace this with a proper implementation?
- **Context:** The XWayland fallback works but has tradeoffs: one extra buffer copy per frame, degraded fractional-scaling on HiDPI (125%/150% gets blurry), loss of native Wayland touchpad gestures and per-window DPI, and slightly less reliable cross-app drag-and-drop. For an IDE these are tolerable but not ideal.

  **Current workaround (`Makefile`):**
  ```
  GDK_BACKEND=x11 flutter run -d linux
  ```
  Also set in the native runner: `gtk_window_set_decorated(window, FALSE)` + `gdk_window_set_decorations(gdk_win, 0)` in `linux/runner/my_application.cc`.

  **Rollback if unstable:** Remove `GDK_BACKEND=x11` from the Makefile `run` target. The OS title bar returns but the app runs on native Wayland. Our hat bar renders below the OS bar (double chrome) until the proper fix lands.

  **Proper fix — bypass GTK, talk `libwayland-client` directly:**
  1. Link `libwayland-client` in `linux/runner/CMakeLists.txt`.
  2. Generate protocol headers from `xdg-decoration-unstable-v1.xml` (ships with `wayland-protocols` package) via `wayland-scanner`.
  3. In `my_application.cc` after window realize: get the `wl_display` via `gdk_wayland_display_get_wl_display()`, bind to `zxdg_decoration_manager_v1` from the registry, get the toplevel decoration object, call `zxdg_toplevel_decoration_v1_set_mode(deco, MODE_CLIENT_SIDE)`.
  4. ~100 lines C total. Needs `wayland-protocols` as a build dep.
  5. The `GDK_BACKEND=x11` env var is then removed.

  **Alternative timeline:** Flutter moves to GTK4 (which has built-in xdg-decoration support). Track Flutter issue #94381. When it ships, drop all native decoration code and use `gtk_window_set_decorated(FALSE)` — it will just work.

- **Source:** 2026-04-23 D-57 implementation.

### Q-32: MCP tool surface — minimum slash-ide or extended clide tools?
- **Status:** Resolved → [D-86](../decisions/architecture.md#d-86-mcp-tool-surface--full-clide-namespace-generated-from-the-co-registered-command-registry)
- **Resolved (2026-06-06):** Full `mcp__clide__*` namespace, but **generated from the co-registered command registry** ([D-74](../decisions/architecture.md#d-74-ipc-command-schema-is-co-registered-with-the-handler-validated-at-dispatch)) that already feeds the CLI + palette — so breadth costs no hand-maintained second surface, and the extensions-first model needs registry-driven surfacing anyway. Per-command MCP opt-out for poor-fit verbs.
- **Question:** [D-68](../decisions/architecture.md#d-68-dual-integration-surface--bash-cli-primary-mcp-secondary) commits clide to an `/ide`-compatible MCP server. The minimum surface is the two tools Claude Code's `/ide` integration currently expects: `mcp__ide__getDiagnostics` (lint/diagnostics for a file) and `mcp__ide__executeCode` (run code in a Jupyter kernel). Do we stop there, or also expose a `mcp__clide__*` namespace with higher-leverage tools (`open_file`, `goto_symbol`, `pql_query`, `pane_spawn`, `git_status`, …) so MCP clients other than Claude Code (Cursor, Windsurf, VS Code Copilot) can drive clide as a real backend?
- **Context:** The minimum surface keeps clide a good citizen in the `/ide` ecosystem and avoids duplicating the CLI in MCP form. The extended surface would let non-Claude-Code MCP clients integrate richly, but invites surface bloat (every CLI verb tempted to gain an MCP twin) and a maintenance second front. Note that for *Claude-Code-in-a-clide-pane*, the CLI surface already covers this — extended MCP tools serve external MCP clients only.
- **Source:** [D-68](../decisions/architecture.md#d-68-dual-integration-surface--bash-cli-primary-mcp-secondary).

### Q-33: MCP transport — SSE, WebSocket, stdio, or all?
- **Status:** Resolved → [D-73](../decisions/architecture.md#d-73-mcp-transport-for-ide-is-sse-over-http)
- **Resolved (2026-05-19, drift-fixed 2026-06-06):** SSE over HTTP only. Closed by D-73 (and confirmed in D-68's amendment) at the time, but this index was never flipped from Open. Re-confirmed 2026-06-06: stdio/WebSocket not added — D-73's reasoning (the always-running GUI is *connected to*, not spawned) still holds and no external process-spawn MCP client is a concrete need yet.
- **Question:** Claude Code's `/ide` integration connects via SSE-IDE or WS-IDE (URL passed at startup). MCP also supports stdio for process-spawn clients. Which transport(s) should clide's MCP server expose — SSE only (the most common `/ide` server pattern), SSE + WS (broader compatibility), or all three including stdio?
- **Context:** Transport choice affects discovery and lifecycle. SSE/WS need a port and a published URL, which collides with the `XDG_RUNTIME_DIR` Unix-socket model used for the CLI; we'd likely publish the URL alongside the socket path (env var or `XDG_RUNTIME_DIR` discovery file). stdio is process-per-client and works for clients that prefer process-spawn over network. Decision interacts with [Q-32](#q-32-mcp-tool-surface--minimum-slash-ide-or-extended-clide-tools) — if the surface stays at the `/ide` minimum, SSE alone is sufficient.
- **Source:** [D-68](../decisions/architecture.md#d-68-dual-integration-surface--bash-cli-primary-mcp-secondary).

---
