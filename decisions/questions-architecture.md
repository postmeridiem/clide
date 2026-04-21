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
- **Question:** When do we freeze the IPC envelope / schema and introduce `schema_version:` in `project.yaml`? What's the bump policy for breaking changes?
- **Context:** Covered partially by [D-006](architecture.md)'s `v: 1` starting point; CLAUDE.md flags this as "decide when the first real subcommand lands."
- **Source:** CLAUDE.md "Open questions" footer.

### Q-006: Window chrome — native frame vs frameless custom
- **Status:** Open
- **Question:** Does clide ship with the OS-native window frame (title bar, min/max/close from the WM) or a frameless custom chrome that gives us pixel control at the cost of reimplementing window controls per-platform?
- **Context:** Surfaced during Tier-0 plumbing discussion; decision deferred.
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

### Q-022: Ticket persistence strategy
- **Status:** Open
- **Question:** Once [Q-021](#q-021-pql-absorbs-planning-vs-keeps-separate) resolves in favour of (A), how do tickets handle shared team state? (1) Never commit (per-dev, ephemeral — works for solo). (2) Commit on milestone (settled-reach's sprint-close pattern — kanban has no natural equivalent, `release` or `tier-cut` is the closest). (3) Markdown mirror — every mutation writes `tickets/T-NNN.md` alongside SQLite; git-legible authoritative record; DB is rebuildable. (3) is probably the eventual answer.
- **Context:** Kanban's lack of a sync event breaks settled-reach's SQLite-authoritative approach the moment two devs collaborate.
- **Source:** 2026-04-21 planning.

---
