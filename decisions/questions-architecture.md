# Open Questions — Architecture

IPC, events, canvas, window chrome, macOS signing, pql absorption,
ticket persistence.

---

### Q-001: Authorisation granularity on the IPC socket
- **Status:** Open
- **Question:** The daemon's token auth is coarse (allow all / deny all). Do we need per-subsystem grants later (e.g. restrict `git push`), and if so, what's the model — capability tokens? An explicit grant table per client? Time-limited grants?
- **Context:** Surfaced in the old ADR 0006 open-questions footer; deferred until Tier 1 is in real use.
- **Source:** ADR 0006 (migrated to [D-006](architecture.md)).

### Q-002: Back-pressure on event streams
- **Status:** Open
- **Question:** A subscriber that falls behind on `pane.output` (a firehose) needs a policy: drop oldest, block producer, coalesce, or kill subscriber. Which?
- **Context:** The event bus is in-memory; back-pressure policy is undefined. Defer until Tier 1 is in real use and we have a real firehose to measure against.
- **Source:** ADR 0006 (migrated to [D-006](architecture.md)).

### Q-003: Event persistence + audit/undo
- **Status:** Open
- **Question:** Events are in-memory only in v1. If a future need (audit log, undo history) wants persistence, is it a property of the bus or a subsystem that subscribes and writes?
- **Context:** ADR 0006 leaned "subsystem that subscribes and writes" but didn't commit.
- **Source:** ADR 0006 (migrated to [D-006](architecture.md)).

### Q-004: `.canvas` schema compatibility with Obsidian
- **Status:** Open
- **Question:** Clide's canvas (Tier 5) should read/write something — either Obsidian's `.canvas` JSON schema verbatim, a compatible-ish superset, or our own format. Each has trade-offs.
- **Context:** Obsidian's canvas users might want their canvases portable; conversely, bending to Obsidian's schema constrains our canvas features.
- **Source:** CLAUDE.md "Open questions" footer.

### Q-005: IPC wire-format stability + `schema_version:`
- **Status:** Open
- **Question:** When do we freeze the IPC envelope / schema and introduce `schema_version:` in `pubspec.yaml`? What's the bump policy for breaking changes?
- **Context:** Covered partially by [D-006](architecture.md)'s `v: 1` starting point; CLAUDE.md flags this as "decide when the first real subcommand lands."
- **Source:** CLAUDE.md "Open questions" footer.

### Q-006: Window chrome — native frame vs frameless custom
- **Status:** Resolved → [D-057](architecture.md#d-057-frameless-custom-chrome-with-per-column-24px-hats)
- **Question:** Does clide ship with the OS-native window frame (title bar, min/max/close from the WM) or a frameless custom chrome that gives us pixel control at the cost of reimplementing window controls per-platform?
- **Context:** Surfaced during Tier-0 plumbing discussion; resolved 2026-04-23 — frameless with per-column 24px hats.
- **Source:** 2026-04-21 planning.

### Q-007: macOS app bundle signing / notarisation
- **Status:** Open
- **Question:** Distributing a signed macOS `.app` requires a Developer ID and a notarisation pipeline. Do we gate macOS builds on this (Tier 6), or ship unsigned with a known "right-click, open" user workflow for early testers?
- **Context:** Linux is primary; macOS is a stretch target. Notarisation is a separate cost from the Flutter build.
- **Source:** 2026-04-21 planning.

### Q-021: Pql absorbs planning vs keeps separate
- **Status:** Open
- **Question:** Three shapes for planning tooling's long-term home: (A) Pql absorbs planning — `pql decisions …` + `pql ticket …` subcommands; clide shells out. (B) Clide absorbs pql — reverse [D-003](architecture.md), one big Dart tool. (C) Separate new binary just for planning.
- **Context:** User is leaning (A). This plan assumes (A) without committing. If (A) doesn't land, [D-040](process.md#d-040-python-stopgap-under-toolsscriptsplan)'s sunset condition changes. Gates all tooling work. Integration constraints that shape this question are captured in [D-039](process.md#d-039-planning-tooling-lives-in-pql) / [R-009](rejected.md#r-009-port-planning-tooling-into-clide).
- **Source:** 2026-04-21 planning.

### Q-023: SSH-remote development — run clide against a remote workspace
- **Status:** Open
- **Question:** Clide today assumes the workspace, the daemon, and the Flutter UI all run on the same machine. A growing class of users edits on remote systems (build servers, GPU boxes, cloud dev environments). What's the architecture for "open repo on host-B from UI on host-A"? Two shapes: (A) daemon-on-remote — clide's Dart daemon runs on the remote; the app talks to it over an SSH-tunnelled unix socket or a dedicated TCP socket (mTLS?), pty/process/filesystem work stays server-side; local app is pure UI. (B) filesystem-mounted — remote mounted via sshfs/9p/rclone, daemon runs locally against the mount; simpler but every fs op + git call crosses the network, and PTYs get complicated (local shell on remote filesystem? ssh-exec per command?). (A) matches VS Code Remote / JetBrains Gateway; (B) matches nothing load-bearing. Sub-questions either way: auth (ssh-agent? per-project keys? OIDC?), tmux / Claude session persistence semantics (does primary-per-repo re-key on host + repo?), multi-host identity in `.pql/pql.db`, latency tolerance for the event stream, re-sync on disconnect.
- **Context:** Surfaced 2026-04-22 during Tier-1 planning. Not a Tier 1 concern — terminal + Claude panes land local-first — but the daemon/IPC seam decisions (notably `D-005` and `D-006`) constrain the future answer. Worth scoping before Tier 6 (extension API) so third-party extensions don't accrue assumptions the remote path would have to unwind.
- **Source:** 2026-04-22 planning (user-raised).

### Q-022: Ticket persistence strategy
- **Status:** Open
- **Question:** Once [Q-021](#q-021-pql-absorbs-planning-vs-keeps-separate) resolves in favour of (A), how do tickets handle shared team state? (1) Never commit (per-dev, ephemeral — works for solo). (2) Commit on milestone (settled-reach's sprint-close pattern — kanban has no natural equivalent, `release` or `tier-cut` is the closest). (3) Markdown mirror — every mutation writes `tickets/T-NNN.md` alongside SQLite; git-legible authoritative record; DB is rebuildable. (3) is probably the eventual answer.
- **Context:** Kanban's lack of a sync event breaks settled-reach's SQLite-authoritative approach the moment two devs collaborate.
- **Source:** 2026-04-21 planning.

### Q-025: Body text face — mono everywhere vs Josefin Sans UI + mono code
- **Status:** Open
- **Question:** The design handoff uses JetBrains Mono for all UI text (tab labels, file paths, status bar, sidebar labels), reserving Josefin Sans only for display/title text. Our current implementation uses Josefin Sans as the ambient UI face with JetBrains Mono only for code/terminal/diff surfaces. Which direction?
- **Context:** The design's "mono everywhere" rationale: clide is an IDE for people who like grids. The current Josefin Sans rationale: visual distinction between chrome text and code text, warmer feel. Both are valid — this is a feel decision, not a technical one.
- **Source:** 2026-04-22 design handoff review.

### Q-026: Small screen layout (< 1000px)
- **Status:** Open
- **Question:** Below 1000px window width, should clide switch to modal viewer/editor instead of split, or stack panels vertically? The spec defers this but flags it.
- **Context:** The interaction model defines breakpoints down to 1200px but punts on < 1000px. This matters for small laptops and tiling WM users who give clide half a screen.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 1.

### Q-027: Two-editor split
- **Status:** Open
- **Question:** Should clide support two files open in the editor simultaneously (horizontal split in the middle column)? The spec says resist until proven needed — feels like tabs creeping back.
- **Context:** [D-048](architecture.md#d-048-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first) deletes buffer tabs. A two-editor split would be the only way to compare files side-by-side without using the viewer ↔ editor swap. The diff view may cover most of this need.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 2.

### Q-028: Terminal strip scope — shell only or logs/errors/tests
- **Status:** Open
- **Question:** Is the app strip (bottom bar) purely a terminal shell + status, or does it also host tabs for logs, errors, and test output? Probably both, later.
- **Context:** The interaction model spec defines the app strip as 14px with terminal shell + daemon indicator + branch; expanding on focus. If it grows to host logs/errors/tests, it becomes a mini-panel with its own tab model.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 3.

### Q-029: Branch picker location
- **Status:** Open
- **Question:** The branch picker was moved out of the bottom status bar. Best place is inside the git section header (left panel), with a compact indicator in the app strip. Confirm or revise?
- **Context:** The interaction model spec suggests the git section header as the primary location. The app strip shows a compact indicator (branch name only) for at-a-glance awareness.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 4.

### Q-030: Focus behavior when editor is dirty and viewer is peeked
- **Status:** Open
- **Question:** When the editor has unsaved changes and the user peeks a viewer, where does focus land? The spec says prompt-bar-rule wins: focus stays in Claude.
- **Context:** This intersects [D-047](architecture.md#d-047-interaction-model-claude-is-home-layout) (Claude is home) and [D-049](architecture.md#d-049-editor-mode-inline-above-claude-viewer-swap) (editor mode). If focus always snaps to Claude, the user must explicitly re-focus the editor to continue typing.
- **Source:** 2026-04-22 interaction model spec (Wireframe — Flows v3), open question 5.

### Q-031: XWayland fallback for frameless — proper Wayland protocol needed
- **Status:** Open (load-bearing workaround in place)
- **Question:** The frameless window (D-057) currently forces `GDK_BACKEND=x11` because GTK3 doesn't implement the `xdg-decoration` Wayland protocol and KWin ignores `gtk_window_set_decorated(FALSE)` on native Wayland. When do we replace this with a proper implementation?
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

- **Source:** 2026-04-23 D-057 implementation.

---
