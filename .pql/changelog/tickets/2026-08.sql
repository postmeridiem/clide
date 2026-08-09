INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FD0ABC7QNEC3XCTV73YPSGR4', 'task', NULL, 'Plumb in Claude Code''s remote-control feature', 'User report 2026-06-16: Claude Code''s **remote-control** feature (start / monitor / steer a running Claude Code session remotely — e.g. from claude.ai or the mobile app) is **not plumbed into clide**.

clide hosts the `claude` CLI as a stream-json child (`--session-id` / `--resume`, D-77). For remote control to work through clide, a clide-hosted session needs to be discoverable + steerable by the remote-control surface the same way a terminal-launched `claude` is.

**Step 1 — characterize (don''t assume the mechanism):** determine exactly what Claude Code exposes for remote control on the running CLI version. Likely touch points:
- the `~/.claude/sessions/<pid>.json` live-session registry we characterized in T-437 (PID-keyed: sessionId, cwd, version, kind, entrypoint, status) — is this what the remote-control surface enumerates? clide-spawned sessions DO write an entry (we saw `entrypoint: sdk-cli`). Confirm whether clide''s entry is visible/controllable remotely, or whether `entrypoint: sdk-cli` / headless spawn excludes it.
- any flag / capability in the `initialize` stream-json probe (T-411/T-151 cache) advertising remote control.
- whether enrollment requires the interactive TUI (and so is suppressed under clide''s stream-json spawn).

**Step 2 — plumb:** wire clide so a clide-hosted session participates in remote control (register correctly / pass the needed flag), and surface its state in the UI (e.g. an indicator that the session is remote-controllable / being driven remotely). If it conflicts with clide''s session ownership (pane pins a session-id, T-156), document the boundary.

**Open question:** is the goal (a) clide sessions become remotely controllable from claude.ai/mobile, or (b) clide can act as a remote controller of other sessions? Default read is (a). Confirm with the user before building.

Related: D-77 (stream-json session model), T-437 (sessions registry characterization), T-156 (clide owns session lifecycle), T-411 (capability probe).

## Step 1 COMPLETE — mechanism characterized and empirically proven (2026-08-07)

**Goal confirmed as (a):** clide-hosted sessions become remotely controllable from
claude.ai / the mobile app. (b) is not in scope.

### The mechanism is a control_request, not the sessions registry

The Step-1 hypothesis (that `~/.claude/sessions/<pid>.json` is what the remote
surface enumerates) is **wrong**. That registry is incidental. Remote Control is
enabled per-session over the stream-json control channel clide already owns.

Claude Code 2.1.220 ships two bridge integrations:
- `[bridge:repl]` — the interactive TUI path (`--remote-control` flag, `/remote-control`)
- `[bridge:sdk]` — a **stream-json/SDK path**, which is the one clide needs

No interactive session, no extra flag, and no CLI changes are required.

### Wire contract (verified live)

```
→ {"type":"control_request","request_id":"…",
   "request":{"subtype":"remote_control","enabled":true,"name":"<session name>"}}

← {"type":"system","subtype":"bridge_state","state":"ready"}
← {"type":"control_response","response":{"subtype":"success","response":{
     "session_url":"https://claude.ai/code/session_0127…",
     "connect_url":"https://claude.ai/code?environment=",
     "environment_id":""}}}
← {"type":"system","subtype":"bridge_state","state":"connected"}

→ {"request":{"subtype":"remote_control","enabled":false}}   # clean teardown
← {"type":"control_response","response":{"subtype":"success"}}
```

Proven by probe against clide''s exact spawn flags (`stream_json_session.dart:78`).
`ready → connected` in ~420ms. Debug log confirms `[bridge:sdk] State change: ready`
then `connected`; transport is CCR v2 over SSE, shared with the repl bridge.

**Surface `session_url`, not `connect_url`.** `connect_url` came back as
`https://claude.ai/code?environment=` with an empty `environment_id` — the
environment concept is not populated on the bare-SDK path (it appears to be filled
in only when the `claude remote-control` daemon owns a registered directory).
`session_url` is the complete, live link. Confirm before building a QR affordance.

### CLI-side callback surface (from binary analysis)

| Callback | Effect |
|---|---|
| `onInboundMessage` | remote message injected as a user turn (tagged `bridgeOrigin`, `clientPlatform`, `origin`) |
| `onPermissionResponse` | → `injectControlResponse` — the remote can answer permission prompts |
| `onInterrupt` | remote cancel of the running turn |
| `onSetModel` / `onSetPermissionMode` / `onSetMaxThinkingTokens` | remote session control |
| `onStateChange` | emits `system/bridge_state` (`ready`\|`connected`\|`failed` + `detail`) on the normal output stream |

Plus outbound `writeSdkMessages` forwarding of task/thinking/vcs events.

### Prompt arbitration — resolved, no clide policy to invent

Decided model (user, 2026-08-07): **first-to-apply wins, both sides linked by the
same `request_id`, loser''s prompt retracts on that link, clear is idempotent.**

This is already the shipped protocol, and it is symmetric:
- `setOnControlRequestSent` forwards the pending request to the remote;
  `setOnControlRequestResolved` → `sendControlCancelRequest(request_id)` retracts it.
- `RemoteSessionManager.handleMessage` handles inbound `control_cancel_request` by
  looking up `pendingPermissionRequests` / `pendingDialogRequests` and retracting;
  unknown ids are ignored ("nothing pending, ignoring").
- The refusal schema states the rule directly: *"Evict on RESOLUTION (your own
  response — any choice — or `control_cancel_request` retirement), never on receipt
  … Eviction is idempotent."*

**The clide gap:** `stream_json_session.dart` parses `control_request` but has **no
`control_cancel_request` handling at all**. If the remote answers first, clide''s
prompt widget hangs with no retraction. Since pending prompts are already keyed by
`request_id` for `resolvePrompt()` (`:758`), the fix is a delete + UI clear on the
same key. NOT YET OBSERVED live — the probe ran no tools, so the retraction path is
confirmed by decompile only. Verify during implementation.

### Step 2 scope (remaining)

1. `enableRemoteControl({String? name})` / `disableRemoteControl()` on
   `StreamJsonSession` — shaped exactly like `setModel()` (`:932`): request with
   `request_id`, pending map, reconcile response into `SessionStatus`.
2. Handle `system/bridge_state` in the event switch → connection state.
3. **Handle inbound `control_cancel_request` → retract the matching pending
   `ToolPrompt`.** (The arbitration work above; also correct on its own merits.)
4. Two `SessionStatus` fields (`session_url`, bridge state).
5. Cockpit affordance: connect link / QR + connected indicator.
6. `clide claude remote-control <on|off>` verb for D-6 parity.
7. Teardown on pane close; pass clide''s derived pane name as `name` (the CLI
   already names clide sessions e.g. `clide-18`).

### Constraints found

- Requires a logged-in subscription account; bridge is skipped on non-first-party
  providers (`isFirstPartyProvider` check) — needs a disabled UI state.
- Help text for the daemon path notes the workspace trust dialog must have been
  accepted by running `claude` interactively in the directory once. clide spawns
  non-interactively where trust is auto-skipped — verify this doesn''t block the bridge.
- `remoteControlAtStartup` is a user setting ("Start Remote Control bridge
  automatically each session") — a zero-code way to A/B the behaviour, and a
  setting clide should probably respect rather than fight.
- Related but out of scope: `isolatePeerMachines` (cross-machine `SendMessage`
  between peer sessions); `claude remote-control` hidden subcommand (`bridgeMain`)
  which runs a per-directory daemon with `--spawn same-dir|worktree|session`.', 'backlog', 'medium', NULL, NULL, NULL, '2026-06-16 11:20:36', '2026-08-07 12:21:08.809', NULL, 'a420c6a2175901ac10d20685907847a5', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit changelog hook leaves ticket_deps/ticket_idmap unstaged', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.', 'backlog', 'medium', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-07 12:30:44.880', NULL, 'bb5179427efa3ad0aff9a48164833f57', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.', 'backlog', 'high', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-07 12:30:59.962', NULL, '29a636f1d7c9de8c57184afd2eaf949f', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.

### Correction (same session): not an untracked-file issue — `--stage` never stages

The "new-month rollover / untracked path" contributing factor above is **disproved**.
Tested directly: with `tickets/2026-08.sql` and `ticket_history/2026-08.sql` already
tracked and merely *modified*, a bare `git commit` still aborted with "no changes
added to commit". Hook output was identical:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

Tracked-modified and untracked-new both fail. The only common factor is
`rows_written: 0`.

**Escalates the diagnosis:** this is not intermittent and not table-specific.
Because ticket mutations write through to `.pql/changelog/` synchronously, the
pre-commit export always finds zero rows left to append, so `--stage` skips its
`git add` on *every* commit. In this repo the hook''s staging step is effectively
dead — it has likely never worked, and every ticket change that landed did so
because some other file in the commit was staged by hand, or because someone
noticed and re-added.

That reframes the earlier `ticket_deps` / `ticket_idmap` reports: those tables
weren''t being singled out, they were just the cases where nothing else in the
commit masked the failure.

**Fix (pql):** `plan export --stage` must stage on file state, not on
`rows_written` — `git add` every dirty-or-untracked path under `.pql/changelog/`
whenever the directory differs from the index, including when the export was a
no-op. Consider also dropping the hook''s `2>/dev/null || true` so a staging
failure is visible instead of silent.', 'backlog', 'high', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-07 12:31:41.104', NULL, '4839606f6898f3f0f39f5c0cbd3d183d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.

### Correction (same session): not an untracked-file issue — `--stage` never stages

The "new-month rollover / untracked path" contributing factor above is **disproved**.
Tested directly: with `tickets/2026-08.sql` and `ticket_history/2026-08.sql` already
tracked and merely *modified*, a bare `git commit` still aborted with "no changes
added to commit". Hook output was identical:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

Tracked-modified and untracked-new both fail. The only common factor is
`rows_written: 0`.

**Escalates the diagnosis:** this is not intermittent and not table-specific.
Because ticket mutations write through to `.pql/changelog/` synchronously, the
pre-commit export always finds zero rows left to append, so `--stage` skips its
`git add` on *every* commit. In this repo the hook''s staging step is effectively
dead — it has likely never worked, and every ticket change that landed did so
because some other file in the commit was staged by hand, or because someone
noticed and re-added.

That reframes the earlier `ticket_deps` / `ticket_idmap` reports: those tables
weren''t being singled out, they were just the cases where nothing else in the
commit masked the failure.

**Fix (pql):** `plan export --stage` must stage on file state, not on
`rows_written` — `git add` every dirty-or-untracked path under `.pql/changelog/`
whenever the directory differs from the index, including when the export was a
no-op. Consider also dropping the hook''s `2>/dev/null || true` so a staging
failure is visible instead of silent.

### Environment note 2026-08-07: pql 1.5.0 → 2.2.0 during the same session

pql was upgraded mid-session while fixes were in flight (observed 1.11.0, then
2.2.0). Planning-store integrity verified after the major bump: 511 tickets and
166 decisions, counts unchanged, and this ticket''s post-widening title and
`high` priority survived intact. No migration loss.

Note for anyone re-reading the earlier notes: `--fields` is a `ticket list` flag
and was never valid on `ticket show`; a failure of that flag mid-session was an
authoring error, not a 2.x regression.', 'backlog', 'high', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-08 20:54:27.833', NULL, '7a27beb31abe38cdf2cdca843231a525', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.

### Correction (same session): not an untracked-file issue — `--stage` never stages

The "new-month rollover / untracked path" contributing factor above is **disproved**.
Tested directly: with `tickets/2026-08.sql` and `ticket_history/2026-08.sql` already
tracked and merely *modified*, a bare `git commit` still aborted with "no changes
added to commit". Hook output was identical:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

Tracked-modified and untracked-new both fail. The only common factor is
`rows_written: 0`.

**Escalates the diagnosis:** this is not intermittent and not table-specific.
Because ticket mutations write through to `.pql/changelog/` synchronously, the
pre-commit export always finds zero rows left to append, so `--stage` skips its
`git add` on *every* commit. In this repo the hook''s staging step is effectively
dead — it has likely never worked, and every ticket change that landed did so
because some other file in the commit was staged by hand, or because someone
noticed and re-added.

That reframes the earlier `ticket_deps` / `ticket_idmap` reports: those tables
weren''t being singled out, they were just the cases where nothing else in the
commit masked the failure.

**Fix (pql):** `plan export --stage` must stage on file state, not on
`rows_written` — `git add` every dirty-or-untracked path under `.pql/changelog/`
whenever the directory differs from the index, including when the export was a
no-op. Consider also dropping the hook''s `2>/dev/null || true` so a staging
failure is visible instead of silent.

### Environment note 2026-08-07: pql 1.5.0 → 2.2.0 during the same session

pql was upgraded mid-session while fixes were in flight (observed 1.11.0, then
2.2.0). Planning-store integrity verified after the major bump: 511 tickets and
166 decisions, counts unchanged, and this ticket''s post-widening title and
`high` priority survived intact. No migration loss.

Note for anyone re-reading the earlier notes: `--fields` is a `ticket list` flag
and was never valid on `ticket show`; a failure of that flag mid-session was an
authoring error, not a 2.x regression.

### Retested on pql 2.2.0 (2026-08-08): STILL BROKEN — unchanged signature

Ran the exact failing case again after the 1.5.0 → 2.2.0 upgrade: mutate a ticket,
then `git commit` with nothing hand-staged.

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
no changes added to commit (use "git add" and/or "git commit -a")
```

Byte-identical to the 1.x behaviour: both files written, neither staged,
`rows_written: 0`, commit aborted. Whatever landed in the 2.x line has not touched
this path — the bug is not fixed and the manual `git add` workaround is still
required on every ticket-only turn.

Repro (one line, no setup): `pql ticket append <any-id> "note"` then a bare
`git commit`. Expected: commit succeeds with the changelog swept in. Actual:
aborts with nothing staged.', 'backlog', 'high', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-08 20:55:06.878', NULL, '4cd176c2e58b0059e046afb456ee5b8a', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'bug', NULL, 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

## Widened 2026-08-07 — broader than the title, and the root cause is different

### The scope is wrong: tickets + ticket_history are NOT immune

This ticket states the hook "only catches the tickets + ticket_history tables."
That is not the failure mode. On 2026-08-07 a ticket-only turn (appending Step-1
findings to T-454) left **`tickets/2026-08.sql` and `ticket_history/2026-08.sql`
untracked and unstaged** — the two tables assumed to work. The commit aborted
with "nothing added to commit but untracked files present" and needed an explicit
`git add` of both paths.

So no table is reliably staged. Retitle accordingly.

### Likely root cause: staging is gated on rows appended, not on file dirtiness

The pre-commit hook is a one-liner that delegates everything to pql:

```sh
# .pql/hooks/pre-commit
''/…/pql'' plan export --stage 2>/dev/null || true
```

Its output on the failing commit:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

It **wrote both files and staged neither**. Second invocation (after a manual
`git add`) returned `{"files_written":null,"rows_written":0}`.

Hypothesis: `--stage` only issues the `git add` when it appends rows
(`rows_written > 0`). Because ticket mutations already **write through** to
`.pql/changelog/` synchronously, by the time the pre-commit hook runs there is
nothing left to append — `rows_written` is 0 — so the staging step is skipped even
though the file on disk is new/dirty. NOT YET VERIFIED; confirm against pql''s
`plan export --stage` implementation.

This also better explains the originally-reported symptom: `ticket_deps` /
`ticket_idmap` aren''t special-cased out, they just tend to be *new month files*
or already-written-through, hitting the same skip.

Contributing factor: new-month rollover. These were the first August files, so
they were untracked rather than modified — worth checking whether `--stage`
handles untracked paths differently from tracked-but-modified ones.

### The fix belongs in pql, not clide

clide''s hook has no logic to fix — it is a single delegating line installed by
`pql init`. The change is in pql''s `plan export --stage`: stage every file under
`.pql/changelog/` that is dirty or untracked, regardless of `rows_written`.
Track/land it in the pql repo; this ticket is the clide-side symptom record.

The ticket''s proposed workaround (`git add .pql/changelog/` on the whole
directory) is still correct and would cover untracked files too.

### Severity is higher than "medium"

This is a silent data-loss path, not a nuisance. A turn that only files or edits
tickets makes no other commit, so the hook is the sole persistence mechanism; when
it silently no-ops, the planning state never lands and a later branch switch drops
it. The failure is invisible unless someone reads the hook''s JSON on stderr.
Consider raising priority and/or making a failed stage loud rather than
`2>/dev/null || true`.

### Correction (same session): not an untracked-file issue — `--stage` never stages

The "new-month rollover / untracked path" contributing factor above is **disproved**.
Tested directly: with `tickets/2026-08.sql` and `ticket_history/2026-08.sql` already
tracked and merely *modified*, a bare `git commit` still aborted with "no changes
added to commit". Hook output was identical:

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
```

Tracked-modified and untracked-new both fail. The only common factor is
`rows_written: 0`.

**Escalates the diagnosis:** this is not intermittent and not table-specific.
Because ticket mutations write through to `.pql/changelog/` synchronously, the
pre-commit export always finds zero rows left to append, so `--stage` skips its
`git add` on *every* commit. In this repo the hook''s staging step is effectively
dead — it has likely never worked, and every ticket change that landed did so
because some other file in the commit was staged by hand, or because someone
noticed and re-added.

That reframes the earlier `ticket_deps` / `ticket_idmap` reports: those tables
weren''t being singled out, they were just the cases where nothing else in the
commit masked the failure.

**Fix (pql):** `plan export --stage` must stage on file state, not on
`rows_written` — `git add` every dirty-or-untracked path under `.pql/changelog/`
whenever the directory differs from the index, including when the export was a
no-op. Consider also dropping the hook''s `2>/dev/null || true` so a staging
failure is visible instead of silent.

### Environment note 2026-08-07: pql 1.5.0 → 2.2.0 during the same session

pql was upgraded mid-session while fixes were in flight (observed 1.11.0, then
2.2.0). Planning-store integrity verified after the major bump: 511 tickets and
166 decisions, counts unchanged, and this ticket''s post-widening title and
`high` priority survived intact. No migration loss.

Note for anyone re-reading the earlier notes: `--fields` is a `ticket list` flag
and was never valid on `ticket show`; a failure of that flag mid-session was an
authoring error, not a 2.x regression.

### Retested on pql 2.2.0 (2026-08-08): STILL BROKEN — unchanged signature

Ran the exact failing case again after the 1.5.0 → 2.2.0 upgrade: mutate a ticket,
then `git commit` with nothing hand-staged.

```
{"files_written":["…/ticket_history/2026-08.sql","…/tickets/2026-08.sql"],"rows_written":0}
no changes added to commit (use "git add" and/or "git commit -a")
```

Byte-identical to the 1.x behaviour: both files written, neither staged,
`rows_written: 0`, commit aborted. Whatever landed in the 2.x line has not touched
this path — the bug is not fixed and the manual `git add` workaround is still
required on every ticket-only turn.

Repro (one line, no setup): `pql ticket append <any-id> "note"` then a bare
`git commit`. Expected: commit succeeds with the changelog swept in. Actual:
aborts with nothing staged.

### Correction to the `--fields` note above

The earlier note in this ticket claims `--fields` "is a `ticket list` flag and was
never valid on `ticket show`". **That is wrong and should not be relied on.**

Accurate version: `--fields` was absent from `ticket show` at pql 1.11.0 (it
errored `unknown flag: --fields`), and was **added to `show` in the 2.x line**.
Confirmed working at 2.2.0:

```
pql ticket show T-454,T-496 --fields id,title,status,priority
→ [{"id":"T-454","title":…,"status":"backlog","priority":"medium"}, …]
```

`pql ticket show --help` at 2.2.0 documents it: "narrows each record to the named
keys, same vocabulary as `ticket list` … projects the top level only: the
join-trees the flags above attach are all-or-nothing."

The mistake was asserting a version-specific absence as a permanent fact. Useful
side-signal: the 2.x updates did land real surface changes — they just did not
touch the `plan export --stage` path this ticket is about.', 'backlog', 'high', NULL, NULL, NULL, '2026-06-28 18:00:41.419', '2026-08-08 21:06:02.841', NULL, '913f31741b7dce36c38c981a124fc6e4', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73V6EVHP32P31NQRJCP104', 'initiative', NULL, 'Clide — ambient AI companion for the clide UI', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:33.751', '2026-08-08 22:47:33.751', NULL, '5d0f72baf0fd089f9380b962df697d73', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', NULL, 'backlog', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 22:47:43.394', NULL, 'ec560510685d41764d57aeb826d582d3', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + new right-edge slot', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-08 22:47:46.520', NULL, '8cd76f10d8c34b049484a9907db234c8', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73XR4NJEPDARY06397RVVC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic A: Clide face renderer — CustomPaint, rain field, glyph cache', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:54.661', '2026-08-08 22:47:54.661', NULL, '699aa01b77f14a2cb21da3c4cdc53969', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Y5FBHF8QNAXQDJBJ26B0', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic B: Clide state machine + power ladder', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:58.074', '2026-08-08 22:47:58.074', NULL, '6923f9a840f2458f539d65f49f67def5', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73YPCJVWBXD9YF1JKZEK2W', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic C: Clide surface & chrome — slot, settings, i18n, CLI parity', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:02.404', '2026-08-08 22:48:02.404', NULL, '72953f63956867abb46f645dc38b4fc0', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Z35AYAJQZ4MZMT25DPWC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic D: Clide companion session + observed/direct protocol', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:05.674', '2026-08-08 22:48:05.674', NULL, 'c3fd4043bb16e249fec2fbd7bfc6f046', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73ZFJHHB92SAKPKNJGD9XC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic E: Clide direct addressing — input box and answer surface', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:08.852', '2026-08-08 22:48:08.852', NULL, '42d68950d6046b23c8b5fea256058d08', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73V6EVHP32P31NQRJCP104', 'initiative', NULL, 'Clide — ambient AI companion for the clide UI', '**Clide** is an ambient AI companion embedded in the clide UI: a glyph face with
expression states, a matrix-rain field whose density encodes how hard the session is
working, and an occasional one-line remark from a separate Haiku instance. It is also
addressable — an input box lets you ask it things directly, most usefully "what did that
mean?" about what Claude just said. Eponymous with the IDE.

**Why.** clide shows what Claude *did* (conversation, tools, status bar) but nothing shows
how it''s *going*. A long agentic turn is a wall of scrolling text plus a spinner; the only
load signal is a token counter. Clide makes session state legible at a glance and puts a
cheap second opinion next to the work.

**Visual source.** Ported from **DeskLock** (`git.schweitz.net/jpmschweitzer/desklock`),
which gives Tatlock a face on an ESP32 round display. `sim/face/index.html` is an explicit
state contract (7 states, eyes/mouth/rain per state); `docs/architecture.md` contributes
the **power ladder**, which is the answer to "don''t be a resource hog" — already solved
there for a wall-powered device.

Full plan: `~/.claude/plans/i-have-a-new-silly-octopus.md`

## Decisions taken (locked)

| | |
|---|---|
| Name | Clide |
| Palette | clide theme tokens + DeskLock''s motion. Not phosphor green. |
| Sound | **None.** Silent — DeskLock''s gong is explicitly not ported. |
| Speaks when | Notable events only (turn finished, error, long run crossing a threshold, commit landed). Never per-token. Direct questions always answered. |
| Model | Haiku 4.5, persistent second stream-json session |
| Sees | User prompts + Claude prose. **No tool calls, no tool results.** |
| Language | Follows the active locale (`app.locale`) |
| Off switch | Settings toggle; also suspends when the window is minimised |
| Bar | "Whimsical, but a solid widget" — full test + a11y + golden coverage |

## Hard constraint found during planning: no katakana

Verified against the bundled font files with `fc-query`: **JetBrains Mono, Fira Mono, Inter
and JosefinSans have zero coverage of U+30A0–30FF.** DeskLock''s `アイウエオカキ…` rain would
fall through to a system font — unpredictable per machine, breaks goldens, and breaks the
monospace advance-width the rain grid assumes.

Rain therefore uses **ASCII + symbols + box-drawing**: DeskLock''s covered half
(`0123456789ACEFHKZ$#%*+=<>`) plus box/geometric glyphs. Fira Mono carries the full
`250c–256c` box set; JetBrains Mono has `2500–25a1`, `25b2–25cc`. No new font asset, no
`licenses.yaml` entry, no supply-chain review — consistent with prefer-zero-deps.

## Cost model

~$0.002 per comment at a 50-comment session (Haiku 4.5, $1/$5 per MTok). Cost grows
**quadratically** — a persistent session re-sends history each turn — so the companion
session restarts at ~50 comments rather than using a rolling window (eviction changes the
cache prefix and would defeat caching every turn).

Haiku 4.5 has the **highest prompt-cache minimum of any current model, 4096 tokens**: below
that `cache_control` is silently ignored (`cache_creation_input_tokens: 0`, no error), so a
lean prompt runs uncached for roughly its first 20 comments. Being lean defeats caching here
— that inverts the usual instinct.

**The real currency is not dollars.** The CLI route bills subscription quota — the same pool
already rate-limiting the main session. That is the argument for keeping the trigger stingy.

## Structure

Epics own their own breakdown **and** their integration seams with siblings; leaf tickets are
deliberately not filed up front.

- T-514 UX spike (Frame0) — settles placement + answer space. Blocks C.
- T-515 D-record. Blocked by T-514.
- T-516 Epic A — face renderer (pure rendering, no session wiring)
- T-517 Epic B — state machine + power ladder. Blocked by A.
- T-518 Epic C — surface & chrome. Blocked by T-514.
- T-519 Epic D — companion session + protocol (pure plumbing)
- T-520 Epic E — direct addressing. Blocked by C and D.

**A and D can start immediately and in parallel** — A is pure rendering, D is pure
plumbing; they meet at B.

Refs: D-6 (CLI/UI parity), D-47, D-48, D-50, D-51, D-53, D-78 (cards are display-only —
Clide is chrome, not a card), D-87, D-101, D-21/D-102. Related: T-241 (ultrawide audit).', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:33.751', '2026-08-08 22:49:44.879', NULL, '53720edc52a4f02b66254bd48ee8d4b0', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', 'Wireframe Clide''s placement in Frame0 and get one shape approved. **Blocks Epic C (T-518)**
— the slot-vs-strip decision determines whether C touches `slot_id.dart` / `layout_preset.dart`
/ `layout.dart` at all, or just `_ContextSlot`.

Frame0 is running locally (see the `frame0-wireframe` skill).

## Question 1 — placement

The original sketch (user screenshot, 2026-08-08) was a strip at the bottom of the context
panel. That breaks down on a widescreen. The context panel runs **220–1000px**
(`layout_preset.dart:19`) and the repo explicitly assumes 3440/5120 ultrawide — see the
"Ultrawide" section of `.claude/skills/ui-design/references/geometry.md` (T-239/T-241).

Two problems at width:
1. The face is marooned mid-strip with large dead flanks.
2. **Matrix rain falls vertically.** A short wide strip gives streams ~4 cells of fall, so
   the density-encodes-activity signal — the best idea in the DeskLock design — stops
   reading. DeskLock''s panel is 800px tall for this reason.

A tall column is the rain''s natural home, and is also chat-shaped for the input box that
Epic E adds (face top / bubble middle / input bottom).

Wireframe three, pick one:
- **A. Own right-edge rail** — new slot, full window height. Rain works; chat-shaped;
  collapses to a 12px spine like every other slot (D-51). Costs permanent horizontal space.
- **B. Bottom strip in the context panel** — no new column, sits beside the detail view.
  Rain compromised; steals height from every detail view.
- **C. Responsive** — rail when wide, strip when narrow. Best fit at both extremes; two
  layouts to build, golden at two surfaces, and keep in sync.

## Question 2 — answer space

A direct answer (Epic E) is longer than a one-line quip. Fixed height + scroll inside the
bubble / grow to a capped height then scroll / take over the context-panel body. Largely
resolves itself under A, which is why placement is decided first.

## Deliverable

One approved wireframe, plus a one-paragraph rationale recorded on this ticket. Feeds
directly into T-515 (D-record).', 'backlog', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 23:08:36.463', NULL, '9349b8f579d53edb999beface9fd14d4', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + new right-edge slot', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-08 23:08:53.902', NULL, '2afdffdafeec9a455007a95b400e97be', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73XR4NJEPDARY06397RVVC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic A: Clide face renderer — CustomPaint, rain field, glyph cache', 'The pure rendering core: a `ClideFace` widget that draws DeskLock''s glyph face and rain
field from a plain state enum. **No session wiring** — it takes a state in and paints. That
keeps it independently testable and lets it start immediately, in parallel with Epic D.

## Epic''s own first job

1. **Break this epic down** into leaf tickets once picked up, with the codebase fresh.
2. **Own the seam with Epic B** — B drives this widget. Define and publish the state enum +
   props contract early so B is not blocked on internals, and keep it stable.

## Scope

- `FaceState` enum + the per-state glyph/rain table, ported from DeskLock''s `STATES`
  (`sim/face/index.html`). Eyes, mouth, blink, thought-dots, talk cycle, rain
  streams/speed, orbit arc, elapsed counter, jitter, kaomoji frames.
- `CustomPainter` for face + rain, driven by one `Ticker`.
- Rain field simulation (spawn / fall / cull) with density and speed as inputs.
- Glyph set: **ASCII + symbols + box-drawing only — no katakana** (see the initiative;
  bundled fonts have zero kana coverage, verified with `fc-query`).

## Rendering discipline — three firsts for this repo

None of these have a house pattern to copy; establish them here.

1. **`CustomPainter(repaint: controller)`** — zero uses of `repaint:` exist in `lib/`. Both
   existing painters (`graph_painter`, `canvas_painter`) repaint via `setState`, which
   rebuilds the widget subtree every frame. Don''t copy that for a continuous animation.
2. **`RepaintBoundary`** — used exactly once in the repo
   (`lib/src/terminal/src/ui/render.dart:174`). This would be the second.
3. **`ParagraphCache`** (`lib/src/terminal/src/ui/paragraph_cache.dart`) — an LRU of
   `ui.Paragraph`, already used by the terminal painter. Build one paragraph per distinct
   glyph and `canvas.drawParagraph` per particle. **Never a `TextPainter` per particle per
   frame** — the existing painters do allocate per paint; that is fine for static painters
   and wrong here. Not exported from any barrel, so import directly or lift it.

## Mandatory reduced-motion gate

`MediaQuery.maybeOf(context)?.disableAnimations` checked in `didChangeDependencies`, ticker
stopped when true. This is not optional: `test/widgets/src/clide_marquee_test.dart:50`
asserts `pumpAndSettle()` completes under reduced motion, so a perpetual ticker that ignores
the flag hangs the suite for ~10 minutes. Reference implementations: `clide_marquee.dart`
(raw `Ticker`, closest structural match), `clide_spinner.dart`, `running_indicator.dart`.

## Tokens, not hex

`ClideSettings.theme.of(context).surface`. `SurfaceTokens` has **no `==` override**, so
`shouldRepaint` compares by identity — match the existing painters rather than deep-comparing.
Fonts via `ClideSettings.fonts.monoOf(context)` + `clideMonoFamilyFallback`, never the
`clideMonoFamily` const (D-101).

## Testing

- `hasInk` picture-recorder pattern (`test/builtin/graph/graph_painter_test.dart:35-43`)
  under `tester.runAsync` — `toImage`/`toByteData` is real engine async and must run off the
  fake clock.
- `shouldRepaint` unit-tested per field (`test/builtin/canvas/canvas_painter_test.dart:103-111`).
- Bounded pumps; tear down by pumping an empty tree so the infinite ticker disposes.
- Alchemist goldens at a **pinned ticker value** — a live animation is a bad golden.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:54.661', '2026-08-08 23:12:38.393', NULL, 'd3799d4a784db0978d6d84a056bf8b14', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Y5FBHF8QNAXQDJBJ26B0', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic B: Clide state machine + power ladder', 'Drive Epic A''s face from real session signals, and make it provably stop when nothing is
happening. This is where "whimsical but a solid widget" is actually earned.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams on both sides** — consume Epic A''s state-enum contract, and consume the
   session signals below without adding new public API to `StreamJsonSession` unless it
   genuinely belongs there (coordinate with Epic D, which also reads that session).

## State mapping

| State | Trigger |
|---|---|
| `idle` | `!busy`, no recent activity |
| `listening` | composer or Clide input focused |
| `pensive` | `busy` && no `partial-` item yet — i.e. thinking |
| `effort` | `busy` && elapsed past a threshold → orbit arc + `[ Ns ]` counter |
| `speaking` | `busy` && `partial-` items arriving — i.e. streaming |
| `rage` | API error / turn failure; plays the 3-frame table-flip, then returns to idle |
| `error` | `endedStream` fired — session died |

**The thinking-vs-streaming split is free and is the nicest signal here.** There is no
public "is streaming" stream on the session; the tell is items whose
`uuid.startsWith(''partial-'')` (`stream_json_session.dart:589-628`). So `busy` with no partial
yet = thinking; `busy` with partials arriving = streaming.

Signals to bind: `busyStream` (seeded `ValueStream`), `items`, `statusStream`,
`pendingPromptStream`, `endedStream`. Binding pattern: the `_bindPrimary()` cancel/rebind/seed
dance at `claude_meta_sidebar.dart:205-245` — the worked example for exactly this.

DeskLock''s rule is adopted verbatim: **"wait cues are a hard requirement — never a bare
static face during a wait, and no fake progress bars, only honest cues."** The `effort`
orbit + elapsed counter is the answer to clide''s long tool runs.

## Power ladder

| Rung | Rendering | Entered when |
|---|---|---|
| `active` | full animation | busy, visible, focused |
| `ambient` | idle face, sparse rain | idle, activity in the last few minutes |
| `dormant` | **ticker stopped, no redraws** | quiet N minutes (default 10) |
| `night` | unmounted / no ticker | panel collapsed or hidden; window minimised |

**Collapse and hide are free.** `layout.dart:51-59` renders a spine or nothing when a slot is
collapsed/hidden, so `SlotHost` unmounts entirely and the controller disposes. Same for
inactive tabs — the context path has no `IndexedStack`/`keepAlive`.

**Minimise is not free — this is a new capability for the codebase.** There is no
`WidgetsBindingObserver`, `didChangeAppLifecycleState`, or `AppLifecycleState` handling
anywhere in `lib/` (zero hits), and `TickerMode` is unused. Adding lifecycle observation is
its own commit and should be reviewed as a kernel-level addition, not smuggled in as a
widget detail. `lib/main.dart:553` has a comment noting lifecycle isn''t wired.

## Testing

Assert each rung actually stops the ticker — a power ladder that doesn''t demonstrably park
the render loop is decoration. Bounded pumps, empty-tree teardown, and the reduced-motion
`pumpAndSettle` contract from Epic A still apply.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:58.074', '2026-08-08 23:13:04.202', NULL, '59b84eeed0237388f09d6dafe1d34889', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73YPCJVWBXD9YF1JKZEK2W', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic C: Clide surface & chrome — slot, settings, i18n, CLI parity', 'Give Clide a real home in the shell, with the settings, i18n and CLI parity that make it a
first-class surface rather than a bolted-on widget.

**Blocked by T-514** — the spike decides whether this is a new slot or a region inside the
context panel, and that changes most of the file list below.

## Epic''s own first job

1. **Break this epic down** once T-514 lands and the shape is known.
2. **Own the seam with Epic E** — E mounts its input box inside this surface. Settle the
   surface''s internal composition (face region / bubble region / input region) here so E
   only fills a slot rather than renegotiating layout.

## If the spike picks A (own right-edge rail)

| File | Change |
|---|---|
| `lib/kernel/src/panels/slot_id.dart:20-33` | add the slot id (`SlotId` is a wrapped String — new ids are cheap) |
| `lib/kernel/src/panels/layout_preset.dart:13-23` | `LayoutSlot(position: right, defaultSize/minSize/maxSize)` |
| `lib/src/shell/layout.dart:51-59` | render column + `ClideSpine` when collapsed + `DragResizeHandle` |
| `lib/kernel/src/panels/drag_resize.dart:178` **and** `:199` | **The sign flip is hard-coded to `Slots.contextPanel` at both sites.** A new right-side slot must be added to both or the drag runs backwards. This is the single easiest thing to get wrong in this epic. |
| `lib/builtin/default_layout/src/extension.dart:170-234` | persistence keys (`_restoreLayout` / `_persistLayout`) |
| `lib/main.dart:599-632` + `lib/test_app.dart:288-294` | register the extension |

A real slot buys `isVisible` / `isCollapsed` / `sizeOf`, restart persistence,
`clide panel resize <slot>` (`lib/src/daemon/panel_commands.dart:66`) and `clide pane list`
reporting — i.e. **D-6 parity for free**. That is the main argument for a slot over a bare
widget.

## If the spike picks B (strip in the context panel)

Single insertion point: `_ContextSlot` at `lib/src/shell/slot_host.dart:349-362`, currently
`Container(... child: active.build(context))`, becomes a `Column`. The slot/persistence/
drag-resize rows above all drop away. Structural template for a split inside a column:
`_WorkspaceSlot` at `slot_host.dart:147-207`.

## Also in scope regardless of shape

- **Settings**: `SettingsCategoryContribution` + controls — enable/disable Clide entirely,
  comment frequency, suspend-when-minimised. Registration template:
  `lib/builtin/output/src/extension.dart` (tab + status toggle + command, with
  `dependsOn: [''builtin.default-layout'']` so the slot exists first).
- **i18n**: chrome strings via `ClideSettings.i18n.string(...)` into
  `assets/i18n/{en_us,nl_nl}/clide.json` (D-21/D-102). Note Clide''s *replies* are model
  output, not catalog strings — the locale is carried into the prompt by Epic D, not
  translated here. Design for ~30% length growth on any fixed-width chrome.
- **Contribution + registration** per `lib/extension/src/contribution.dart`; host dispatch
  is `extensions_manager.dart:237-260`.

## Testing

Layout must be asserted **at ultrawide**, driving `tester.view.physicalSize` — a wide
`SizedBox` under the default 800px test surface is clamped to 800 and does not actually test
wide. Pattern: `test/app_statusbar_test.dart` (`pumpAt`). Related audit: T-241.

Likely to need updating: `test/app_test.dart`, `test/app_collapse_toggle_test.dart`,
`test/builtin/default_layout/widget_test.dart`, and the panels tests under
`test/kernel/src/panels/`.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:02.404', '2026-08-08 23:13:35.063', NULL, 'da7e69fee72fbc3bfbd9c2812898aaf8', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Z35AYAJQZ4MZMT25DPWC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic D: Clide companion session + observed/direct protocol', 'Stand up the Haiku companion session, feed it a filtered digest of the main conversation,
and give it a protocol that distinguishes *watching* from *being spoken to*. Pure plumbing —
**can start immediately, in parallel with Epic A**.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams** — publish the reply/state stream that Epic B (face reactions to
   companion errors) and Epic E (answer rendering) consume, and coordinate with B on reading
   `StreamJsonSession` so the two epics don''t each grow their own subscription layer.

## Spawning — no new process plumbing needed

`ClaudeSessionOrchestrator.spawn(SpawnSpec(..., visible: false))`
(`lib/builtin/claude/src/session_orchestrator.dart:209`) already yields a live stream-json
session with **no pane**, idempotent per `(id, cwd)`, serialized against races.
`visible: false` is the intended primitive for a headless agent. Precedent for spawning
outside a pane: `_forkMember` at `claude_meta_sidebar.dart:256-274`.

- Spawn id `clide.companion`, `--model haiku`.
- `--no-session-persistence` so it never pollutes `~/.claude/projects` (precedent:
  `claude_config.dart:576`).
- **There is no Anthropic API client in the repo** — grep for `anthropic` / `ANTHROPIC_API_KEY`
  across `lib/` returns only comments. Everything goes through the `claude` CLI, so this runs
  on subscription auth exactly like the main session.

## Digest — what Clide sees

Filter `session.items` to **`UserMessage` + `AssistantTextMessage` only**. Drop
`AssistantToolUse`, `ToolResultMessage`, thinking, and the clide-injected image/drawing/icon
cards. Item model: `transcript_reader.dart:41-267`.

**Known limitation, accepted for v1:** with tool calls excluded, *"what did that tool call
do?"* is unanswerable. Asking what Claude **said** works; asking what Claude **did** does
not. Revisit if it bites in practice.

## Protocol — observed vs direct

```
[observed] jeroen: <prompt text>
[observed] claude: <assistant prose>
[direct]   jeroen: <question typed into Clide''s own input>
```

The system prompt states the split explicitly: `observed` lines are a conversation between
the user and Claude that Clide is watching — remark rarely and briefly; `direct` lines are
addressed to Clide — always answer. Reply in the active locale (`app.locale`, carried into
the prompt). One or two sentences.

Trigger for unprompted remarks: **notable events only** — turn finished, error, long run
crossing a threshold, commit landed. Never per-token.

## Cost guards — the constraints that actually shape this

- **Restart the session at ~50 comments.** Cost grows quadratically (history re-sends each
  turn). A rolling window is the wrong fix: evicting the oldest event changes the cache
  prefix, so every turn would pay full price. Grow-then-restart preserves cache hits within
  an epoch and bounds growth.
- **Haiku 4.5''s prompt-cache minimum is 4096 tokens — the highest of any current model.**
  Below it `cache_control` is silently ignored (`cache_creation_input_tokens: 0`, no error).
  A lean sidekick prompt is uncached for roughly its first 20 comments.
- **Do not set `effort`** — it errors on Haiku 4.5.
- Leave thinking off (latency and tokens for a one-line quip), and cap `max_tokens` ~100 so
  a bad turn can''t produce an essay.
- Budget: ~$0.002/comment at 50 comments. But under subscription auth the real cost is
  **quota**, drawn from the same pool already rate-limiting the main session — keep the
  trigger stingy.

## Lifecycle

Respect the settings kill switch (Epic C) and the power ladder (Epic B): a disabled or
dormant Clide should not hold a live process open. Tear the session down, don''t just stop
reading it.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:05.674', '2026-08-08 23:14:04.481', NULL, 'd4d702777e924d9f91786980be6e7bb0', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73ZFJHHB92SAKPKNJGD9XC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic E: Clide direct addressing — input box and answer surface', 'Make Clide addressable: an input box on its surface, and a readable place for the answer.
This is what turns the companion from decoration into a tool — the driving use case is
**"what did that mean?"** about what Claude just said, answered right where the work is.

Blocked by Epic C (needs the surface and its internal composition) and Epic D (needs the
session and the `[direct]` protocol tag).

## Epic''s own first job

1. **Break this epic down** once C and D have landed and their contracts are real.
2. **Own the cross-epic behaviour** — a direct question changes face state (Epic B), consumes
   the companion session (Epic D), and occupies surface space (Epic C). Don''t reimplement any
   of those; extend them, and fold any needed contract changes back into the sibling epic
   rather than working around it locally.

## Scope

- Input affordance on the Clide surface. Distinct from the Claude composer — it must be
  visually and behaviourally obvious which one you''re typing into, since the whole point is
  that they go to different models.
- Submit → `[direct]` tagged line into the companion session (Epic D''s protocol).
- Answer rendering. **Shape depends on T-514''s answer-space decision** — fixed height with
  scroll inside the bubble, grow-to-cap-then-scroll, or take over the panel body.
- Focus handling: focusing the input should put the face into `listening` (Epic B).
- Direct questions bypass the notable-events trigger — always answered.

## Design notes

- Interactive controls belong in an interaction zone, not inline in a display surface —
  the same principle as D-78''s rule for the Claude pane. The bubble stays display-only; the
  input is its own region.
- Two-column control pattern and the no-double-edge-padding rule from
  `.claude/skills/ui-design/references/geometry.md` apply to the input row.
- Placeholder text is a catalog string (D-21/D-102) and must tolerate ~30% length growth in
  Dutch. Clide''s *answers* are model output and are not catalog strings.
- At ultrawide, right-align with `Expanded`, not a `Spacer` fighting a flex sibling — the
  drift is proportional to width (~1500px adrift at 3440px). See the ultrawide section of the
  geometry reference.

## Known limitation to surface in the UI

Clide sees prose only — no tool calls, no tool results (Epic D). "What did that tool call
do?" cannot be answered. Consider whether the empty/placeholder state should set that
expectation rather than letting the user discover it by getting a bad answer.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:08.852', '2026-08-08 23:15:29.240', NULL, '614a87ac28f3f2c603cdac7ed9399d43', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', 'Wireframe Clide''s placement in Frame0 and get one shape approved. **Blocks Epic C (T-518)**
— the slot-vs-strip decision determines whether C touches `slot_id.dart` / `layout_preset.dart`
/ `layout.dart` at all, or just `_ContextSlot`.

Frame0 is running locally (see the `frame0-wireframe` skill).

## Question 1 — placement

The original sketch (user screenshot, 2026-08-08) was a strip at the bottom of the context
panel. That breaks down on a widescreen. The context panel runs **220–1000px**
(`layout_preset.dart:19`) and the repo explicitly assumes 3440/5120 ultrawide — see the
"Ultrawide" section of `.claude/skills/ui-design/references/geometry.md` (T-239/T-241).

Two problems at width:
1. The face is marooned mid-strip with large dead flanks.
2. **Matrix rain falls vertically.** A short wide strip gives streams ~4 cells of fall, so
   the density-encodes-activity signal — the best idea in the DeskLock design — stops
   reading. DeskLock''s panel is 800px tall for this reason.

A tall column is the rain''s natural home, and is also chat-shaped for the input box that
Epic E adds (face top / bubble middle / input bottom).

Wireframe three, pick one:
- **A. Own right-edge rail** — new slot, full window height. Rain works; chat-shaped;
  collapses to a 12px spine like every other slot (D-51). Costs permanent horizontal space.
- **B. Bottom strip in the context panel** — no new column, sits beside the detail view.
  Rain compromised; steals height from every detail view.
- **C. Responsive** — rail when wide, strip when narrow. Best fit at both extremes; two
  layouts to build, golden at two surfaces, and keep in sync.

## Question 2 — answer space

A direct answer (Epic E) is longer than a one-line quip. Fixed height + scroll inside the
bubble / grow to a capped height then scroll / take over the context-panel body. Largely
resolves itself under A, which is why placement is decided first.

## Deliverable

One approved wireframe, plus a one-paragraph rationale recorded on this ticket. Feeds
directly into T-515 (D-record).', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 23:18:16.287', NULL, '3564bdff43eece85b622da40c14fdb32', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', 'Wireframe Clide''s placement in Frame0 and get one shape approved. **Blocks Epic C (T-518)**
— the slot-vs-strip decision determines whether C touches `slot_id.dart` / `layout_preset.dart`
/ `layout.dart` at all, or just `_ContextSlot`.

Frame0 is running locally (see the `frame0-wireframe` skill).

## Question 1 — placement

The original sketch (user screenshot, 2026-08-08) was a strip at the bottom of the context
panel. That breaks down on a widescreen. The context panel runs **220–1000px**
(`layout_preset.dart:19`) and the repo explicitly assumes 3440/5120 ultrawide — see the
"Ultrawide" section of `.claude/skills/ui-design/references/geometry.md` (T-239/T-241).

Two problems at width:
1. The face is marooned mid-strip with large dead flanks.
2. **Matrix rain falls vertically.** A short wide strip gives streams ~4 cells of fall, so
   the density-encodes-activity signal — the best idea in the DeskLock design — stops
   reading. DeskLock''s panel is 800px tall for this reason.

A tall column is the rain''s natural home, and is also chat-shaped for the input box that
Epic E adds (face top / bubble middle / input bottom).

Wireframe three, pick one:
- **A. Own right-edge rail** — new slot, full window height. Rain works; chat-shaped;
  collapses to a 12px spine like every other slot (D-51). Costs permanent horizontal space.
- **B. Bottom strip in the context panel** — no new column, sits beside the detail view.
  Rain compromised; steals height from every detail view.
- **C. Responsive** — rail when wide, strip when narrow. Best fit at both extremes; two
  layouts to build, golden at two surfaces, and keep in sync.

## Question 2 — answer space

A direct answer (Epic E) is longer than a one-line quip. Fixed height + scroll inside the
bubble / grow to a capped height then scroll / take over the context-panel body. Largely
resolves itself under A, which is why placement is decided first.

## Deliverable

One approved wireframe, plus a one-paragraph rationale recorded on this ticket. Feeds
directly into T-515 (D-record).', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 23:18:22.510', NULL, 'bd53dbe0169f818ca7c64cdf667fdabc', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', 'Wireframe Clide''s placement in Frame0 and get one shape approved. **Blocks Epic C (T-518)**
— the slot-vs-strip decision determines whether C touches `slot_id.dart` / `layout_preset.dart`
/ `layout.dart` at all, or just `_ContextSlot`.

Frame0 is running locally (see the `frame0-wireframe` skill).

## Question 1 — placement

The original sketch (user screenshot, 2026-08-08) was a strip at the bottom of the context
panel. That breaks down on a widescreen. The context panel runs **220–1000px**
(`layout_preset.dart:19`) and the repo explicitly assumes 3440/5120 ultrawide — see the
"Ultrawide" section of `.claude/skills/ui-design/references/geometry.md` (T-239/T-241).

Two problems at width:
1. The face is marooned mid-strip with large dead flanks.
2. **Matrix rain falls vertically.** A short wide strip gives streams ~4 cells of fall, so
   the density-encodes-activity signal — the best idea in the DeskLock design — stops
   reading. DeskLock''s panel is 800px tall for this reason.

A tall column is the rain''s natural home, and is also chat-shaped for the input box that
Epic E adds (face top / bubble middle / input bottom).

Wireframe three, pick one:
- **A. Own right-edge rail** — new slot, full window height. Rain works; chat-shaped;
  collapses to a 12px spine like every other slot (D-51). Costs permanent horizontal space.
- **B. Bottom strip in the context panel** — no new column, sits beside the detail view.
  Rain compromised; steals height from every detail view.
- **C. Responsive** — rail when wide, strip when narrow. Best fit at both extremes; two
  layouts to build, golden at two surfaces, and keep in sync.

## Question 2 — answer space

A direct answer (Epic E) is longer than a one-line quip. Fixed height + scroll inside the
bubble / grow to a capped height then scroll / take over the context-panel body. Largely
resolves itself under A, which is why placement is decided first.

## Deliverable

One approved wireframe, plus a one-paragraph rationale recorded on this ticket. Feeds
directly into T-515 (D-record).

## OUTCOME (2026-08-09) — decided

**Placement: B — horizontal strip sharing the bottom of the context column.** The context
detail view shrinks; Clide takes the bottom of the same column. No new slot, no new window
column.

Wireframes (Frame0, committed):
- `docs/design/wireframes/clide-companion/placement-a-right-rail.{json,png}` — rejected
- `docs/design/wireframes/clide-companion/placement-b-bottom-strip.{json,png}` — **approved**
- `docs/design/wireframes/clide-companion/placement-b-gaze.{json,png}` — approved addition

### Rationale

A was built first and argued for on the grounds that matrix rain falls vertically, so a short
strip would kill the density-encodes-activity signal. **Drawing B disproved half of that.**
Density is encoded as *how many columns are lit*, not how far each falls, and a wide strip has
far more columns to light — ~45 at a 1000px context panel versus ~9 in a 200px rail. Idle-2
versus effort-40 still reads, arguably more legibly, because the whole field is taken in at
once instead of scanned down a column. What is genuinely lost is *motion quality*: rain
falling ~3 cells reads as flicker rather than rain. That is an aesthetic cost, not a signal
cost, and it is worth not spending a permanent window column. The face itself survives the
short strip fine — eyes and mouth stack in ~40px and work at both 220px and 1000px.

### Accepted costs

- The detail view loses ~110px of height on every ticket, decision, file and graph view.
- Not a slot, so no `isVisible` / `sizeOf` / persistence / `clide panel resize` for free.
  **Epic C must hand-roll a collapse toggle and a persisted height to keep D-6 parity.**
- In exchange: one insertion point (`_ContextSlot`, `slot_host.dart:349-362`, becomes a
  `Column`), no `slot_id`/`layout_preset` changes, and it avoids the `drag_resize.dart`
  two-site sign-flip trap entirely.

### Approved addition — gaze and lean

Not in the original brief; emerged during the spike and is approved.

**Gaze.** In B the face is pinned to the left edge of the context column, so the pane directly
to its left is the Claude conversation — exactly what it ingests. Pupils track left while
Claude streams, forward when you address it, optionally right toward the detail view above.
Glyphs `◧ ◨ ● ◎` (U+25E7/25E8/25CF/25CE) are all inside ranges JetBrains Mono actually ships,
same family as the rain glyphs — no new font asset. A 4-frame pupil sweep (~600ms) tied to
arriving `partial-` items makes him visibly read faster when tokens land faster.

**Lean.** Originated as a coordinate slip in the first wireframe — the mouth landed off the
eye axis and read as a head-tilt. Kept, now deliberate: one number, the mouth''s x-offset from
the eye centre (−8px reading / 0 upright / +8px glancing right). Animating the offset makes
the lean the transition itself. Free — the mouth is already positioned per frame — and it
makes attention legible at a size where pupils alone are a few pixels.

This is a second signal channel, not decoration: rain says *how hard* the session is working,
gaze says *what it is working on*. It also makes the digest boundary visible — Clide looks at
the conversation because that is all he is given, so the "can''t answer about tool calls"
limitation reads as character rather than as a bug.

### Answer space: strip grows, plus a conversation popout

**Inline:** the strip grows to a capped height (~40% of the column) while answering, scrolls
beyond that, and collapses back when idle. Space is borrowed only while in use.

**Popout (new Epic E scope):** an expand control opens a light conversation view over the
detail area — the full Clide exchange for this session, **latest first**, with a fetch limit
and lazy loading on scroll, and a text box underneath to continue talking. It surfaces
**only actually-said things — never tool uses, never injected metadata** — consistent with
the digest boundary in Epic D. Requirement appended to T-520.

### Unblocks

T-518 (Epic C) — now scoped to the `_ContextSlot` Column route, not the new-slot route.
T-515 (D-record) — placement, the gaze/lean axis, and the D-6-parity gap are the substance.', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 23:39:58.638', NULL, 'b9f96b64fa672d0e6729a81f39f2d91d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73ZFJHHB92SAKPKNJGD9XC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic E: Clide direct addressing — input box and answer surface', 'Make Clide addressable: an input box on its surface, and a readable place for the answer.
This is what turns the companion from decoration into a tool — the driving use case is
**"what did that mean?"** about what Claude just said, answered right where the work is.

Blocked by Epic C (needs the surface and its internal composition) and Epic D (needs the
session and the `[direct]` protocol tag).

## Epic''s own first job

1. **Break this epic down** once C and D have landed and their contracts are real.
2. **Own the cross-epic behaviour** — a direct question changes face state (Epic B), consumes
   the companion session (Epic D), and occupies surface space (Epic C). Don''t reimplement any
   of those; extend them, and fold any needed contract changes back into the sibling epic
   rather than working around it locally.

## Scope

- Input affordance on the Clide surface. Distinct from the Claude composer — it must be
  visually and behaviourally obvious which one you''re typing into, since the whole point is
  that they go to different models.
- Submit → `[direct]` tagged line into the companion session (Epic D''s protocol).
- Answer rendering. **Shape depends on T-514''s answer-space decision** — fixed height with
  scroll inside the bubble, grow-to-cap-then-scroll, or take over the panel body.
- Focus handling: focusing the input should put the face into `listening` (Epic B).
- Direct questions bypass the notable-events trigger — always answered.

## Design notes

- Interactive controls belong in an interaction zone, not inline in a display surface —
  the same principle as D-78''s rule for the Claude pane. The bubble stays display-only; the
  input is its own region.
- Two-column control pattern and the no-double-edge-padding rule from
  `.claude/skills/ui-design/references/geometry.md` apply to the input row.
- Placeholder text is a catalog string (D-21/D-102) and must tolerate ~30% length growth in
  Dutch. Clide''s *answers* are model output and are not catalog strings.
- At ultrawide, right-align with `Expanded`, not a `Spacer` fighting a flex sibling — the
  drift is proportional to width (~1500px adrift at 3440px). See the ultrawide section of the
  geometry reference.

## Known limitation to surface in the UI

Clide sees prose only — no tool calls, no tool results (Epic D). "What did that tool call
do?" cannot be answered. Consider whether the empty/placeholder state should set that
expectation rather than letting the user discover it by getting a bad answer.

## Added by T-514 spike (2026-08-09) — conversation popout

Placement B was chosen, which caps the inline strip at ~2 lines of text at a 1000px context
panel and ~4 short lines at the 220px minimum. Inline answers therefore grow the strip to a
capped height (~40% of the column) and collapse back when idle.

That is enough to read one answer. It is not enough to review a session''s worth of them, so
Epic E also gains an **expand control that opens a conversation popout**:

- A **light version of the conversation view** — not a second full implementation. Reuse
  what the Claude pane already has where practical rather than forking it.
- Shows the **full Clide exchange for this session**: his unprompted remarks and your direct
  questions, interleaved.
- **Latest first.**
- **Fetch limit + lazy loading on scroll** — do not materialise the whole history up front.
- **A text box underneath to talk back**, so the popout is a working surface rather than a
  read-only log. Same `[direct]` protocol path as the inline input (Epic D).
- Surfaces **only actually-said things — never tool uses, never injected metadata.** This
  mirrors the digest boundary Epic D enforces on the way in: Clide never saw tool calls, so
  the popout must not invent a view containing them.

Open questions for this epic to settle at breakdown:

- Overlay versus takeover of the context body. Overlay preserves the detail view underneath
  but is new chrome for this repo (focus trap, Esc-to-dismiss, click-away).
- Whether the popout and the inline strip share one scroll model and one controller, or the
  popout is a separate surface fed by the same store. Prefer one store, two views.
- What "session" means when Epic D restarts the companion session at ~50 comments — the
  popout''s history should almost certainly outlive the underlying model session, which
  implies the transcript is clide-side state, not a read of the companion process.

That last one is load-bearing and worth resolving early: it decides whether the popout reads
from a clide-owned store or from the companion session, and the restart behaviour makes the
store the likelier answer.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:08.852', '2026-08-08 23:40:18.010', NULL, '80c4645bdaf08233cf708ecc4a762b47', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73YPCJVWBXD9YF1JKZEK2W', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic C: Clide surface & chrome — slot, settings, i18n, CLI parity', 'Give Clide a real home in the shell, with the settings, i18n and CLI parity that make it a
first-class surface rather than a bolted-on widget.

**Blocked by T-514** — the spike decides whether this is a new slot or a region inside the
context panel, and that changes most of the file list below.

## Epic''s own first job

1. **Break this epic down** once T-514 lands and the shape is known.
2. **Own the seam with Epic E** — E mounts its input box inside this surface. Settle the
   surface''s internal composition (face region / bubble region / input region) here so E
   only fills a slot rather than renegotiating layout.

## If the spike picks A (own right-edge rail)

| File | Change |
|---|---|
| `lib/kernel/src/panels/slot_id.dart:20-33` | add the slot id (`SlotId` is a wrapped String — new ids are cheap) |
| `lib/kernel/src/panels/layout_preset.dart:13-23` | `LayoutSlot(position: right, defaultSize/minSize/maxSize)` |
| `lib/src/shell/layout.dart:51-59` | render column + `ClideSpine` when collapsed + `DragResizeHandle` |
| `lib/kernel/src/panels/drag_resize.dart:178` **and** `:199` | **The sign flip is hard-coded to `Slots.contextPanel` at both sites.** A new right-side slot must be added to both or the drag runs backwards. This is the single easiest thing to get wrong in this epic. |
| `lib/builtin/default_layout/src/extension.dart:170-234` | persistence keys (`_restoreLayout` / `_persistLayout`) |
| `lib/main.dart:599-632` + `lib/test_app.dart:288-294` | register the extension |

A real slot buys `isVisible` / `isCollapsed` / `sizeOf`, restart persistence,
`clide panel resize <slot>` (`lib/src/daemon/panel_commands.dart:66`) and `clide pane list`
reporting — i.e. **D-6 parity for free**. That is the main argument for a slot over a bare
widget.

## If the spike picks B (strip in the context panel)

Single insertion point: `_ContextSlot` at `lib/src/shell/slot_host.dart:349-362`, currently
`Container(... child: active.build(context))`, becomes a `Column`. The slot/persistence/
drag-resize rows above all drop away. Structural template for a split inside a column:
`_WorkspaceSlot` at `slot_host.dart:147-207`.

## Also in scope regardless of shape

- **Settings**: `SettingsCategoryContribution` + controls — enable/disable Clide entirely,
  comment frequency, suspend-when-minimised. Registration template:
  `lib/builtin/output/src/extension.dart` (tab + status toggle + command, with
  `dependsOn: [''builtin.default-layout'']` so the slot exists first).
- **i18n**: chrome strings via `ClideSettings.i18n.string(...)` into
  `assets/i18n/{en_us,nl_nl}/clide.json` (D-21/D-102). Note Clide''s *replies* are model
  output, not catalog strings — the locale is carried into the prompt by Epic D, not
  translated here. Design for ~30% length growth on any fixed-width chrome.
- **Contribution + registration** per `lib/extension/src/contribution.dart`; host dispatch
  is `extensions_manager.dart:237-260`.

## Testing

Layout must be asserted **at ultrawide**, driving `tester.view.physicalSize` — a wide
`SizedBox` under the default 800px test surface is clamped to 800 and does not actually test
wide. Pattern: `test/app_statusbar_test.dart` (`pumpAt`). Related audit: T-241.

Likely to need updating: `test/app_test.dart`, `test/app_collapse_toggle_test.dart`,
`test/builtin/default_layout/widget_test.dart`, and the panels tests under
`test/kernel/src/panels/`.

## Spike resolved (T-514, 2026-08-09) — take the B route

Placement **B** was chosen: a horizontal strip sharing the bottom of the context column.

**The "If the spike picks A" section above is dead — ignore it.** No `slot_id.dart`, no
`layout_preset.dart`, no `layout.dart` column, and in particular **no `drag_resize.dart`
sign-flip work**; that trap does not apply on this route.

Live scope is the B section: `_ContextSlot` at `lib/src/shell/slot_host.dart:349-362`
becomes a `Column`. Structural template for a split inside a column is `_WorkspaceSlot`
(`slot_host.dart:147-207`).

**What B costs this epic, and it is the main work here:** the strip is not a slot, so none of
`isVisible` / `isCollapsed` / `sizeOf` / restart persistence / `clide panel resize` /
`clide pane list` come for free. To keep **D-6 parity** this epic must hand-roll:

- a collapse/expand affordance for the strip,
- a persisted height and collapsed-state (alongside the dock''s keys in
  `default_layout/src/extension.dart:170-234`),
- and CLI verbs so every UI action has a command equivalent.

Budget for that explicitly — it was the strongest argument for A and is now this epic''s
problem. Decide early whether the strip''s height is a first-class arrangement value or
extension-local settings state; the former is more work but keeps it consistent with every
other resizable region.

Also in scope from the spike: the strip **grows to a capped height (~40% of the column)
while Clide is answering and collapses back when idle**. That interacts with the persisted
height — the user''s chosen height is the resting height, not a ceiling.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:02.404', '2026-08-08 23:40:36.514', NULL, '173cf83b24e2a25e03ca415699f74bd2', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WC48DRPATA7Z6J7H9N8C', 'task', '06FY73V6EVHP32P31NQRJCP104', 'UX spike: Frame0 wireframe → Clide placement + answer-space decision', 'Wireframe Clide''s placement in Frame0 and get one shape approved. **Blocks Epic C (T-518)**
— the slot-vs-strip decision determines whether C touches `slot_id.dart` / `layout_preset.dart`
/ `layout.dart` at all, or just `_ContextSlot`.

Frame0 is running locally (see the `frame0-wireframe` skill).

## Question 1 — placement

The original sketch (user screenshot, 2026-08-08) was a strip at the bottom of the context
panel. That breaks down on a widescreen. The context panel runs **220–1000px**
(`layout_preset.dart:19`) and the repo explicitly assumes 3440/5120 ultrawide — see the
"Ultrawide" section of `.claude/skills/ui-design/references/geometry.md` (T-239/T-241).

Two problems at width:
1. The face is marooned mid-strip with large dead flanks.
2. **Matrix rain falls vertically.** A short wide strip gives streams ~4 cells of fall, so
   the density-encodes-activity signal — the best idea in the DeskLock design — stops
   reading. DeskLock''s panel is 800px tall for this reason.

A tall column is the rain''s natural home, and is also chat-shaped for the input box that
Epic E adds (face top / bubble middle / input bottom).

Wireframe three, pick one:
- **A. Own right-edge rail** — new slot, full window height. Rain works; chat-shaped;
  collapses to a 12px spine like every other slot (D-51). Costs permanent horizontal space.
- **B. Bottom strip in the context panel** — no new column, sits beside the detail view.
  Rain compromised; steals height from every detail view.
- **C. Responsive** — rail when wide, strip when narrow. Best fit at both extremes; two
  layouts to build, golden at two surfaces, and keep in sync.

## Question 2 — answer space

A direct answer (Epic E) is longer than a one-line quip. Fixed height + scroll inside the
bubble / grow to a capped height then scroll / take over the context-panel body. Largely
resolves itself under A, which is why placement is decided first.

## Deliverable

One approved wireframe, plus a one-paragraph rationale recorded on this ticket. Feeds
directly into T-515 (D-record).

## OUTCOME (2026-08-09) — decided

**Placement: B — horizontal strip sharing the bottom of the context column.** The context
detail view shrinks; Clide takes the bottom of the same column. No new slot, no new window
column.

Wireframes (Frame0, committed):
- `docs/design/wireframes/clide-companion/placement-a-right-rail.{json,png}` — rejected
- `docs/design/wireframes/clide-companion/placement-b-bottom-strip.{json,png}` — **approved**
- `docs/design/wireframes/clide-companion/placement-b-gaze.{json,png}` — approved addition

### Rationale

A was built first and argued for on the grounds that matrix rain falls vertically, so a short
strip would kill the density-encodes-activity signal. **Drawing B disproved half of that.**
Density is encoded as *how many columns are lit*, not how far each falls, and a wide strip has
far more columns to light — ~45 at a 1000px context panel versus ~9 in a 200px rail. Idle-2
versus effort-40 still reads, arguably more legibly, because the whole field is taken in at
once instead of scanned down a column. What is genuinely lost is *motion quality*: rain
falling ~3 cells reads as flicker rather than rain. That is an aesthetic cost, not a signal
cost, and it is worth not spending a permanent window column. The face itself survives the
short strip fine — eyes and mouth stack in ~40px and work at both 220px and 1000px.

### Accepted costs

- The detail view loses ~110px of height on every ticket, decision, file and graph view.
- Not a slot, so no `isVisible` / `sizeOf` / persistence / `clide panel resize` for free.
  **Epic C must hand-roll a collapse toggle and a persisted height to keep D-6 parity.**
- In exchange: one insertion point (`_ContextSlot`, `slot_host.dart:349-362`, becomes a
  `Column`), no `slot_id`/`layout_preset` changes, and it avoids the `drag_resize.dart`
  two-site sign-flip trap entirely.

### Approved addition — gaze and lean

Not in the original brief; emerged during the spike and is approved.

**Gaze.** In B the face is pinned to the left edge of the context column, so the pane directly
to its left is the Claude conversation — exactly what it ingests. Pupils track left while
Claude streams, forward when you address it, optionally right toward the detail view above.
Glyphs `◧ ◨ ● ◎` (U+25E7/25E8/25CF/25CE) are all inside ranges JetBrains Mono actually ships,
same family as the rain glyphs — no new font asset. A 4-frame pupil sweep (~600ms) tied to
arriving `partial-` items makes him visibly read faster when tokens land faster.

**Lean.** Originated as a coordinate slip in the first wireframe — the mouth landed off the
eye axis and read as a head-tilt. Kept, now deliberate: one number, the mouth''s x-offset from
the eye centre (−8px reading / 0 upright / +8px glancing right). Animating the offset makes
the lean the transition itself. Free — the mouth is already positioned per frame — and it
makes attention legible at a size where pupils alone are a few pixels.

This is a second signal channel, not decoration: rain says *how hard* the session is working,
gaze says *what it is working on*. It also makes the digest boundary visible — Clide looks at
the conversation because that is all he is given, so the "can''t answer about tool calls"
limitation reads as character rather than as a bug.

### Answer space: strip grows, plus a conversation popout

**Inline:** the strip grows to a capped height (~40% of the column) while answering, scrolls
beyond that, and collapses back when idle. Space is borrowed only while in use.

**Popout (new Epic E scope):** an expand control opens a light conversation view over the
detail area — the full Clide exchange for this session, **latest first**, with a fetch limit
and lazy loading on scroll, and a text box underneath to continue talking. It surfaces
**only actually-said things — never tool uses, never injected metadata** — consistent with
the digest boundary in Epic D. Requirement appended to T-520.

### Unblocks

T-518 (Epic C) — now scoped to the `_ContextSlot` Column route, not the new-slot route.
T-515 (D-record) — placement, the gaze/lean axis, and the D-6-parity gap are the substance.', 'done', 'high', NULL, NULL, NULL, '2026-08-08 22:47:43.394', '2026-08-08 23:40:42.460', NULL, 'efb549921b3c0285ad6973bc8f2ec0f9', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + new right-edge slot', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-09 00:14:25.649', NULL, '6b2388a33e2e05dceadbbf2fc80fb22e', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + new right-edge slot', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-09 00:14:39.964', NULL, '3c91bc1ab085a8fd13a4584a844d08fd', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73V6EVHP32P31NQRJCP104', 'initiative', NULL, 'Clide — ambient AI companion for the clide UI', '**Clide** is an ambient AI companion embedded in the clide UI: a glyph face with
expression states, a matrix-rain field whose density encodes how hard the session is
working, and an occasional one-line remark from a separate Haiku instance. It is also
addressable — an input box lets you ask it things directly, most usefully "what did that
mean?" about what Claude just said. Eponymous with the IDE.

**Why.** clide shows what Claude *did* (conversation, tools, status bar) but nothing shows
how it''s *going*. A long agentic turn is a wall of scrolling text plus a spinner; the only
load signal is a token counter. Clide makes session state legible at a glance and puts a
cheap second opinion next to the work.

**Visual source.** Ported from **DeskLock** (`git.schweitz.net/jpmschweitzer/desklock`),
which gives Tatlock a face on an ESP32 round display. `sim/face/index.html` is an explicit
state contract (7 states, eyes/mouth/rain per state); `docs/architecture.md` contributes
the **power ladder**, which is the answer to "don''t be a resource hog" — already solved
there for a wall-powered device.

Full plan: `~/.claude/plans/i-have-a-new-silly-octopus.md`

## Decisions taken (locked)

| | |
|---|---|
| Name | Clide |
| Palette | clide theme tokens + DeskLock''s motion. Not phosphor green. |
| Sound | **None.** Silent — DeskLock''s gong is explicitly not ported. |
| Speaks when | Notable events only (turn finished, error, long run crossing a threshold, commit landed). Never per-token. Direct questions always answered. |
| Model | Haiku 4.5, persistent second stream-json session |
| Sees | User prompts + Claude prose. **No tool calls, no tool results.** |
| Language | Follows the active locale (`app.locale`) |
| Off switch | Settings toggle; also suspends when the window is minimised |
| Bar | "Whimsical, but a solid widget" — full test + a11y + golden coverage |

## Hard constraint found during planning: no katakana

Verified against the bundled font files with `fc-query`: **JetBrains Mono, Fira Mono, Inter
and JosefinSans have zero coverage of U+30A0–30FF.** DeskLock''s `アイウエオカキ…` rain would
fall through to a system font — unpredictable per machine, breaks goldens, and breaks the
monospace advance-width the rain grid assumes.

Rain therefore uses **ASCII + symbols + box-drawing**: DeskLock''s covered half
(`0123456789ACEFHKZ$#%*+=<>`) plus box/geometric glyphs. Fira Mono carries the full
`250c–256c` box set; JetBrains Mono has `2500–25a1`, `25b2–25cc`. No new font asset, no
`licenses.yaml` entry, no supply-chain review — consistent with prefer-zero-deps.

## Cost model

~$0.002 per comment at a 50-comment session (Haiku 4.5, $1/$5 per MTok). Cost grows
**quadratically** — a persistent session re-sends history each turn — so the companion
session restarts at ~50 comments rather than using a rolling window (eviction changes the
cache prefix and would defeat caching every turn).

Haiku 4.5 has the **highest prompt-cache minimum of any current model, 4096 tokens**: below
that `cache_control` is silently ignored (`cache_creation_input_tokens: 0`, no error), so a
lean prompt runs uncached for roughly its first 20 comments. Being lean defeats caching here
— that inverts the usual instinct.

**The real currency is not dollars.** The CLI route bills subscription quota — the same pool
already rate-limiting the main session. That is the argument for keeping the trigger stingy.

## Structure

Epics own their own breakdown **and** their integration seams with siblings; leaf tickets are
deliberately not filed up front.

- T-514 UX spike (Frame0) — settles placement + answer space. Blocks C.
- T-515 D-record. Blocked by T-514.
- T-516 Epic A — face renderer (pure rendering, no session wiring)
- T-517 Epic B — state machine + power ladder. Blocked by A.
- T-518 Epic C — surface & chrome. Blocked by T-514.
- T-519 Epic D — companion session + protocol (pure plumbing)
- T-520 Epic E — direct addressing. Blocked by C and D.

**A and D can start immediately and in parallel** — A is pure rendering, D is pure
plumbing; they meet at B.

Refs: D-6 (CLI/UI parity), D-47, D-48, D-50, D-51, D-53, D-78 (cards are display-only —
Clide is chrome, not a card), D-87, D-101, D-21/D-102. Related: T-241 (ultrawide audit).', 'backlog', 'medium', NULL, NULL, 'D-107', '2026-08-08 22:47:33.751', '2026-08-09 00:17:23.092', NULL, '7bf4e6f93c5533ba8e288c00b1f509b4', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + second model session (D-107)', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-09 00:17:43.707', NULL, 'bc3c0db354bdaa21b7140afbe9a20213', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + second model session (D-107)', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.

## OUTCOME (2026-08-09) — D-107 written

`governance/decisions/architecture.md` → **D-107: Clide — ambient companion surface backed
by a second, non-primary model session**. Validated (`pql decisions validate` → ok),
synced (167 records, 354 refs, 0 broken), indexed in `governance/README.md`, and linked:
`T-513.decision_ref = D-107`, so `pql decisions show D-107 --with-tickets` reports
implementation status.

**Ticket retitled.** The original title said "+ new right-edge slot", which was conditional
on T-514 picking placement A. It picked B, so there is no new slot and that clause was
removed rather than left to mislead.

### What the record fixes

All four items from the brief, in descending order of how load-bearing they are:

1. **clide may host one second, non-primary model session** — via the `claude` CLI and the
   existing orchestrator (`visible: false`), not an API client. Because it therefore spends
   **subscription quota from the same pool that throttles the primary session**, three
   constraints are written in as part of the decision rather than as tuning: disableable to
   zero (tears down the process, not just the UI), notable-events-only, and it must never be
   the reason the primary session is throttled. Scoped to exactly one session — explicitly
   not a general "clide may spawn models" licence.
2. **Placement** — bottom strip in the context column, with the T-514 rationale including the
   correction that the rain argument was half wrong, and the D-6 parity gap stated as a
   consequence rather than buried.
3. **Digest boundary** — prose only, stated as a scope/privacy boundary. The clause that
   makes it survive feature pressure: *any future feature requiring Clide to see tool activity
   amends this record; it is not a config flag.*
4. **Power ladder as a contract** — four rungs, `dormant` parks the render loop, reduced-motion
   is a hard gate, each rung asserted in tests. "A ladder that does not demonstrably park the
   loop is decoration."

### Added beyond the brief

- **A "Not telemetry" clause.** [D-64](../governance/decisions/architecture.md) commits clide
  to no telemetry, and "a second model session reading your conversation" reads adjacent to
  that. The record states plainly that the companion adds **no new destination** — the same
  prose already goes to the same provider via the primary session — and that
  `--no-session-persistence` keeps it from writing anything, per D-93. Worth pre-empting
  rather than leaving for someone to raise later as an objection.
- **"A second model''s output can be wrong."** Clide is commentary, never authority, and must
  be visually unmistakable for the primary session''s output. Not in the brief; belongs in the
  cost section of any record that puts a second model''s text on screen.
- **D-105 forward-link** — if the primary CLI becomes pluggable (Vibe), the companion''s
  CLI assumption re-opens.

### Cross-references

D-1, D-5, D-6, D-20, D-21/D-102, D-47, D-48, D-50, D-51, D-53, D-64, D-78, D-83, D-87, D-93,
D-101, D-105, D-31/D-42. Relates to Q-26 (strip height cost is worst on a short window) and
Q-34 (quota is the real currency and is still not exposed upstream).

Implemented by T-513 (epics T-516/517/518/519/520). Wireframes:
`docs/design/wireframes/clide-companion/`.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-09 00:18:08.159', NULL, '2d28b5f378879ab3797e8f260cffda86', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73WRAZBSBGGCSSMWHN17Q4', 'task', '06FY73V6EVHP32P31NQRJCP104', 'D-record: ambient companion surface + second model session (D-107)', 'Write the D-record for the Clide companion. No existing decision covers an ambient AI
companion surface, and (if T-514 picks placement A) none covers a new right-edge slot
either.

Claim the id with `pql decisions claim D architecture "..."`, then author the markdown under
`governance/decisions/architecture.md`.

## What the record must fix

1. **That clide hosts a second, non-primary model session at all** — and that it runs
   through the `claude` CLI on subscription auth, not an API client. This is the load-bearing
   precedent: it is the first time clide spends the user''s quota on something other than the
   session they are driving.
2. **Placement** — the outcome of T-514, with the rain-needs-vertical-fall rationale.
3. **What the companion may see.** User prompts and Claude prose only; no tool calls, no
   tool results. State this as a privacy/scope boundary, not an implementation detail, so it
   survives later feature pressure.
4. **The power ladder as a contract**, not an optimisation — a continuously animated surface
   in an IDE has to prove it stops.

## Decisions it touches

D-6 (CLI/UI parity — the slot must have verbs), D-47 (bottom strips align to one line),
D-48 (chrome budget — this adds chrome), D-50 (context panel is reactive), D-51 (collapse →
12px spine), D-53 (persist layout), D-78 (conversation cards are display-only — Clide is
chrome, not a card, and the distinction matters), D-87 (dock precedent for a new region),
D-101 (font facade), D-21/D-102 (i18n).

Blocked by T-514 — placement is half the record.

## OUTCOME (2026-08-09) — D-107 written

`governance/decisions/architecture.md` → **D-107: Clide — ambient companion surface backed
by a second, non-primary model session**. Validated (`pql decisions validate` → ok),
synced (167 records, 354 refs, 0 broken), indexed in `governance/README.md`, and linked:
`T-513.decision_ref = D-107`, so `pql decisions show D-107 --with-tickets` reports
implementation status.

**Ticket retitled.** The original title said "+ new right-edge slot", which was conditional
on T-514 picking placement A. It picked B, so there is no new slot and that clause was
removed rather than left to mislead.

### What the record fixes

All four items from the brief, in descending order of how load-bearing they are:

1. **clide may host one second, non-primary model session** — via the `claude` CLI and the
   existing orchestrator (`visible: false`), not an API client. Because it therefore spends
   **subscription quota from the same pool that throttles the primary session**, three
   constraints are written in as part of the decision rather than as tuning: disableable to
   zero (tears down the process, not just the UI), notable-events-only, and it must never be
   the reason the primary session is throttled. Scoped to exactly one session — explicitly
   not a general "clide may spawn models" licence.
2. **Placement** — bottom strip in the context column, with the T-514 rationale including the
   correction that the rain argument was half wrong, and the D-6 parity gap stated as a
   consequence rather than buried.
3. **Digest boundary** — prose only, stated as a scope/privacy boundary. The clause that
   makes it survive feature pressure: *any future feature requiring Clide to see tool activity
   amends this record; it is not a config flag.*
4. **Power ladder as a contract** — four rungs, `dormant` parks the render loop, reduced-motion
   is a hard gate, each rung asserted in tests. "A ladder that does not demonstrably park the
   loop is decoration."

### Added beyond the brief

- **A "Not telemetry" clause.** [D-64](../governance/decisions/architecture.md) commits clide
  to no telemetry, and "a second model session reading your conversation" reads adjacent to
  that. The record states plainly that the companion adds **no new destination** — the same
  prose already goes to the same provider via the primary session — and that
  `--no-session-persistence` keeps it from writing anything, per D-93. Worth pre-empting
  rather than leaving for someone to raise later as an objection.
- **"A second model''s output can be wrong."** Clide is commentary, never authority, and must
  be visually unmistakable for the primary session''s output. Not in the brief; belongs in the
  cost section of any record that puts a second model''s text on screen.
- **D-105 forward-link** — if the primary CLI becomes pluggable (Vibe), the companion''s
  CLI assumption re-opens.

### Cross-references

D-1, D-5, D-6, D-20, D-21/D-102, D-47, D-48, D-50, D-51, D-53, D-64, D-78, D-83, D-87, D-93,
D-101, D-105, D-31/D-42. Relates to Q-26 (strip height cost is worst on a short window) and
Q-34 (quota is the real currency and is still not exposed upstream).

Implemented by T-513 (epics T-516/517/518/519/520). Wireframes:
`docs/design/wireframes/clide-companion/`.', 'done', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:46.520', '2026-08-09 00:18:12.242', NULL, '789535ee81345fdf4db9731bea8f81db', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73XR4NJEPDARY06397RVVC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic A: Clide face renderer — CustomPaint, rain field, glyph cache', 'The pure rendering core: a `ClideFace` widget that draws DeskLock''s glyph face and rain
field from a plain state enum. **No session wiring** — it takes a state in and paints. That
keeps it independently testable and lets it start immediately, in parallel with Epic D.

## Epic''s own first job

1. **Break this epic down** into leaf tickets once picked up, with the codebase fresh.
2. **Own the seam with Epic B** — B drives this widget. Define and publish the state enum +
   props contract early so B is not blocked on internals, and keep it stable.

## Scope

- `FaceState` enum + the per-state glyph/rain table, ported from DeskLock''s `STATES`
  (`sim/face/index.html`). Eyes, mouth, blink, thought-dots, talk cycle, rain
  streams/speed, orbit arc, elapsed counter, jitter, kaomoji frames.
- `CustomPainter` for face + rain, driven by one `Ticker`.
- Rain field simulation (spawn / fall / cull) with density and speed as inputs.
- Glyph set: **ASCII + symbols + box-drawing only — no katakana** (see the initiative;
  bundled fonts have zero kana coverage, verified with `fc-query`).

## Rendering discipline — three firsts for this repo

None of these have a house pattern to copy; establish them here.

1. **`CustomPainter(repaint: controller)`** — zero uses of `repaint:` exist in `lib/`. Both
   existing painters (`graph_painter`, `canvas_painter`) repaint via `setState`, which
   rebuilds the widget subtree every frame. Don''t copy that for a continuous animation.
2. **`RepaintBoundary`** — used exactly once in the repo
   (`lib/src/terminal/src/ui/render.dart:174`). This would be the second.
3. **`ParagraphCache`** (`lib/src/terminal/src/ui/paragraph_cache.dart`) — an LRU of
   `ui.Paragraph`, already used by the terminal painter. Build one paragraph per distinct
   glyph and `canvas.drawParagraph` per particle. **Never a `TextPainter` per particle per
   frame** — the existing painters do allocate per paint; that is fine for static painters
   and wrong here. Not exported from any barrel, so import directly or lift it.

## Mandatory reduced-motion gate

`MediaQuery.maybeOf(context)?.disableAnimations` checked in `didChangeDependencies`, ticker
stopped when true. This is not optional: `test/widgets/src/clide_marquee_test.dart:50`
asserts `pumpAndSettle()` completes under reduced motion, so a perpetual ticker that ignores
the flag hangs the suite for ~10 minutes. Reference implementations: `clide_marquee.dart`
(raw `Ticker`, closest structural match), `clide_spinner.dart`, `running_indicator.dart`.

## Tokens, not hex

`ClideSettings.theme.of(context).surface`. `SurfaceTokens` has **no `==` override**, so
`shouldRepaint` compares by identity — match the existing painters rather than deep-comparing.
Fonts via `ClideSettings.fonts.monoOf(context)` + `clideMonoFamilyFallback`, never the
`clideMonoFamily` const (D-101).

## Testing

- `hasInk` picture-recorder pattern (`test/builtin/graph/graph_painter_test.dart:35-43`)
  under `tester.runAsync` — `toImage`/`toByteData` is real engine async and must run off the
  fake clock.
- `shouldRepaint` unit-tested per field (`test/builtin/canvas/canvas_painter_test.dart:103-111`).
- Bounded pumps; tear down by pumping an empty tree so the infinite ticker disposes.
- Alchemist goldens at a **pinned ticker value** — a live animation is a bad golden.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:54.661', '2026-08-09 00:32:55.106', NULL, '432953b6ceb22559bf979b8e1cde974f', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73XR4NJEPDARY06397RVVC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic A: Clide face renderer — CustomPaint, rain field, glyph cache', 'The pure rendering core: a `ClideFace` widget that draws DeskLock''s glyph face and rain
field from a plain state enum. **No session wiring** — it takes a state in and paints. That
keeps it independently testable and lets it start immediately, in parallel with Epic D.

## Epic''s own first job

1. **Break this epic down** into leaf tickets once picked up, with the codebase fresh.
2. **Own the seam with Epic B** — B drives this widget. Define and publish the state enum +
   props contract early so B is not blocked on internals, and keep it stable.

## Scope

- `FaceState` enum + the per-state glyph/rain table, ported from DeskLock''s `STATES`
  (`sim/face/index.html`). Eyes, mouth, blink, thought-dots, talk cycle, rain
  streams/speed, orbit arc, elapsed counter, jitter, kaomoji frames.
- `CustomPainter` for face + rain, driven by one `Ticker`.
- Rain field simulation (spawn / fall / cull) with density and speed as inputs.
- Glyph set: **ASCII + symbols + box-drawing only — no katakana** (see the initiative;
  bundled fonts have zero kana coverage, verified with `fc-query`).

## Rendering discipline — three firsts for this repo

None of these have a house pattern to copy; establish them here.

1. **`CustomPainter(repaint: controller)`** — zero uses of `repaint:` exist in `lib/`. Both
   existing painters (`graph_painter`, `canvas_painter`) repaint via `setState`, which
   rebuilds the widget subtree every frame. Don''t copy that for a continuous animation.
2. **`RepaintBoundary`** — used exactly once in the repo
   (`lib/src/terminal/src/ui/render.dart:174`). This would be the second.
3. **`ParagraphCache`** (`lib/src/terminal/src/ui/paragraph_cache.dart`) — an LRU of
   `ui.Paragraph`, already used by the terminal painter. Build one paragraph per distinct
   glyph and `canvas.drawParagraph` per particle. **Never a `TextPainter` per particle per
   frame** — the existing painters do allocate per paint; that is fine for static painters
   and wrong here. Not exported from any barrel, so import directly or lift it.

## Mandatory reduced-motion gate

`MediaQuery.maybeOf(context)?.disableAnimations` checked in `didChangeDependencies`, ticker
stopped when true. This is not optional: `test/widgets/src/clide_marquee_test.dart:50`
asserts `pumpAndSettle()` completes under reduced motion, so a perpetual ticker that ignores
the flag hangs the suite for ~10 minutes. Reference implementations: `clide_marquee.dart`
(raw `Ticker`, closest structural match), `clide_spinner.dart`, `running_indicator.dart`.

## Tokens, not hex

`ClideSettings.theme.of(context).surface`. `SurfaceTokens` has **no `==` override**, so
`shouldRepaint` compares by identity — match the existing painters rather than deep-comparing.
Fonts via `ClideSettings.fonts.monoOf(context)` + `clideMonoFamilyFallback`, never the
`clideMonoFamily` const (D-101).

## Testing

- `hasInk` picture-recorder pattern (`test/builtin/graph/graph_painter_test.dart:35-43`)
  under `tester.runAsync` — `toImage`/`toByteData` is real engine async and must run off the
  fake clock.
- `shouldRepaint` unit-tested per field (`test/builtin/canvas/canvas_painter_test.dart:103-111`).
- Bounded pumps; tear down by pumping an empty tree so the infinite ticker disposes.
- Alchemist goldens at a **pinned ticker value** — a live animation is a bad golden.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:54.661', '2026-08-09 00:33:11.096', NULL, '37075d04a13dc15a268489c4f8673438', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', NULL, 'backlog', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 00:33:47.085', NULL, '3ce4953a1c2c4ad0d71f0d31d9e05cf8', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 00:33:51.190', NULL, 'd6e1446b1c228f87606498cb56c2b9a6', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 00:33:54.845', NULL, '8da30eac4594149af44e1de4221e5c52', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 00:33:58.510', NULL, '19e78911459f9b59ea1b24c6742a364f', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 00:34:02.298', NULL, 'f5529ee8071679d69ad0d02c5c0dd055', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.', 'backlog', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 00:59:44.288', NULL, '3f0e10fc75cec404b48b7bbf4abd78ab', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', 'The rain field: spawn, fall, cull. Pure Dart, **no Flutter import** — it produces particle
positions and glyph indices; the painter (T-524) turns those into pixels.

Target: `lib/builtin/clide_companion/src/rain_field.dart`

## Why it is its own ticket

It is the load signal, not decoration. Density (`rainStreams`) is what tells you at a glance
whether the session is idle or grinding — 2 streams versus 40 — so it deserves its own tests
rather than being asserted only through a painted image.

## Shape

```dart
class RainField {
  RainField({required int columns, required int rows, int seed = 0});

  /// Advance by dt seconds toward the target density/speed.
  void tick(double dt, {required int targetStreams, required double speed});

  Iterable<RainCell> get cells;   // col, row (fractional), glyphIndex, leading
}
```

- **Deterministic.** Seeded PRNG, injected — **never `Random()` unseeded and never
  `DateTime.now()`**. Tests and goldens need the same field for the same inputs.
- **Density ramps, it does not snap.** Going idle→effort should read as the field filling in
  over a few hundred ms, not popping. Going effort→idle drains by culling, not clearing.
- **Leading cell is brighter** — DeskLock draws the head of each stream lighter than the
  trail. Expose it as a flag on the cell; the painter picks the colour.
- Cull when a stream falls past `rows + 2`.

## Glyph set — ASCII + symbols + box-drawing only

**No katakana.** The bundled fonts have zero kana coverage (verified with `fc-query`), so
DeskLock''s `アイウエオ…` set cannot be used: it would fall through to a system font,
break goldens, and break the monospace advance width the grid assumes.

Use DeskLock''s covered half — `0123456789ACEFHKZ$#%*+=<>` — plus box/geometric glyphs from
`2500-25a1` (JetBrains Mono ships the full box set there; Fira Mono also covers `250c-256c`).

The field stores a **glyph index**, not a character, so the concrete set lives in one const
list and the painter resolves it. That keeps the swap cheap if the set is ever revised.

## Done when

- `tick` is pure and deterministic for a given seed — same inputs, same field, asserted.
- Density converges to `targetStreams` and holds; changing the target ramps rather than snaps.
- Cull works: cells never accumulate past the bottom, and total cell count stays bounded
  under a long run (this is the leak test — worth writing, since an unbounded field is the
  obvious failure mode for a perpetual simulation).
- Zero density produces an empty field (the `error` state must actually stop, per D-107''s
  power-ladder contract).
- Runs under `dart test` — no Flutter import.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 01:00:09.784', NULL, '56b1273ff46b6c483df26657a7428314', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', 'One `ui.Paragraph` per distinct (glyph, style) pair, reused across frames and particles.
This is the difference between the face being cheap and being a space heater.

Target: `lib/builtin/clide_companion/src/glyph_cache.dart`

## The rule

**Never build a `TextPainter` per particle per frame.** At 40 streams × ~20 rows that is
~800 layouts per frame at 30fps. Both existing painters (`graph_painter.dart:121`,
`canvas_painter.dart:214`) do allocate a `TextPainter` per paint — that is fine for a static
painter that repaints on interaction, and wrong here. Do not copy them.

## Reuse `ParagraphCache`

`lib/src/terminal/src/ui/paragraph_cache.dart` already implements exactly this: an LRU of
`ui.Paragraph` keyed on `int`, with `getLayoutFromCache(key)` and
`performAndCacheLayout(text, style, textScaler, key)`. It is ~50 lines, used by the terminal
painter (`painter.dart:150-180`), and **not exported from any barrel**.

Decide and record which:
- **import it directly** (`package:clide/src/terminal/src/ui/paragraph_cache.dart`) — no
  duplication, but reaches across into the terminal subsystem''s private path; or
- **lift it** to a shared location and have both use it — cleaner layering, touches the
  terminal painter.

Prefer importing directly first and only lift if a third consumer appears. Note the file
header credits xterm.dart (MIT) — per repo convention, code under `lib/` is owned, not
vendored, so it is fair game to move; keep the credit either way.

## Key scheme

Key on everything that changes the rendered glyph: **glyph index, colour, font size, and the
resolved font family**. Font comes from `ClideSettings.fonts.monoOf(context)` (D-101) and is
user-changeable at runtime, so it must be in the key or a font switch silently renders stale
paragraphs. Same for theme changes, which change colour.

Cache size should comfortably exceed `glyphSet.length × distinctColours` — the working set is
small and bounded, so sizing it too *small* is the only real failure mode.

## Done when

- One cache instance owned by the painter, cleared on theme or font change.
- A test asserts the second request for the same key returns the **identical** `Paragraph`
  instance (`identical()`, not `==`) — that is the whole point of the ticket.
- A test asserts a colour, size, or font-family change produces a different entry rather than
  reusing a stale one.
- A bounded-growth test: painting many frames does not grow the cache without limit.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 01:00:30.253', NULL, '90ff352ef273d67f3ed0ba66bff1d019', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 01:00:53.406', NULL, '0061775d7e74816531e33e5650c73436', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 01:01:20.258', NULL, '1c8df8c57eb419d23c4997ca3b0ccb15', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Y5FBHF8QNAXQDJBJ26B0', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic B: Clide state machine + power ladder', 'Drive Epic A''s face from real session signals, and make it provably stop when nothing is
happening. This is where "whimsical but a solid widget" is actually earned.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams on both sides** — consume Epic A''s state-enum contract, and consume the
   session signals below without adding new public API to `StreamJsonSession` unless it
   genuinely belongs there (coordinate with Epic D, which also reads that session).

## State mapping

| State | Trigger |
|---|---|
| `idle` | `!busy`, no recent activity |
| `listening` | composer or Clide input focused |
| `pensive` | `busy` && no `partial-` item yet — i.e. thinking |
| `effort` | `busy` && elapsed past a threshold → orbit arc + `[ Ns ]` counter |
| `speaking` | `busy` && `partial-` items arriving — i.e. streaming |
| `rage` | API error / turn failure; plays the 3-frame table-flip, then returns to idle |
| `error` | `endedStream` fired — session died |

**The thinking-vs-streaming split is free and is the nicest signal here.** There is no
public "is streaming" stream on the session; the tell is items whose
`uuid.startsWith(''partial-'')` (`stream_json_session.dart:589-628`). So `busy` with no partial
yet = thinking; `busy` with partials arriving = streaming.

Signals to bind: `busyStream` (seeded `ValueStream`), `items`, `statusStream`,
`pendingPromptStream`, `endedStream`. Binding pattern: the `_bindPrimary()` cancel/rebind/seed
dance at `claude_meta_sidebar.dart:205-245` — the worked example for exactly this.

DeskLock''s rule is adopted verbatim: **"wait cues are a hard requirement — never a bare
static face during a wait, and no fake progress bars, only honest cues."** The `effort`
orbit + elapsed counter is the answer to clide''s long tool runs.

## Power ladder

| Rung | Rendering | Entered when |
|---|---|---|
| `active` | full animation | busy, visible, focused |
| `ambient` | idle face, sparse rain | idle, activity in the last few minutes |
| `dormant` | **ticker stopped, no redraws** | quiet N minutes (default 10) |
| `night` | unmounted / no ticker | panel collapsed or hidden; window minimised |

**Collapse and hide are free.** `layout.dart:51-59` renders a spine or nothing when a slot is
collapsed/hidden, so `SlotHost` unmounts entirely and the controller disposes. Same for
inactive tabs — the context path has no `IndexedStack`/`keepAlive`.

**Minimise is not free — this is a new capability for the codebase.** There is no
`WidgetsBindingObserver`, `didChangeAppLifecycleState`, or `AppLifecycleState` handling
anywhere in `lib/` (zero hits), and `TickerMode` is unused. Adding lifecycle observation is
its own commit and should be reviewed as a kernel-level addition, not smuggled in as a
widget detail. `lib/main.dart:553` has a comment noting lifecycle isn''t wired.

## Testing

Assert each rung actually stops the ticker — a power ladder that doesn''t demonstrably park
the render loop is decoration. Bounded pumps, empty-tree teardown, and the reduced-motion
`pumpAndSettle` contract from Epic A still apply.

## Contract published (Epic A breakdown, 2026-08-09) — you are not blocked

Epic A''s seam is specified in full on **T-521**. Code against it now; you do not need to wait
for T-521 to land, and A will not change it without renegotiating here.

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }
enum Gaze { none, left, forward, right }

ClideFace({
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,   // you own this; the widget does not time turns
})
```

That is the entire surface. Three things follow for B:

1. **B owns elapsed time.** `busyFor` drives the `[ Ns ]` counter in `effort`. The widget
   deliberately does not time turns itself, because you already know when the turn started
   and the widget would only be guessing from prop changes.
2. **Lean is derived from `gaze`, not passed.** `left → −8px`, `forward/none → 0`,
   `right → +8px`. Do not look for a `lean` prop.
3. **If you need something more, that is a T-521 change, not a prop added quietly to the
   widget.** Raise it there so the contract stays one place.

### `rage` is a scowl, not a table-flip

Deviation from DeskLock, decided during the A breakdown: `rage` renders as brows-down eyes
`▼   ▼` with a flat mouth `━` and jitter, not the 3-frame kaomoji. Two of the kaomoji''s
glyphs (`︵` U+FE35, `ノ` U+30CE — katakana) are missing from the bundled fonts, and the
sequence needed a second render path for the state you see least. **Semantics are unchanged**
— it is still the transient-failure reaction, so your mapping (API error / turn failure →
`rage` for a beat → back to `idle`) is unaffected.

### Signals reminder for your mapping

The thinking-versus-streaming split is free: `busy && no partial- item yet` → `pensive`;
`busy && partial- items arriving` → `speaking` (`stream_json_session.dart:589-628`). There is
no public "is streaming" stream; items whose `uuid.startsWith(''partial-'')` are the tell.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:58.074', '2026-08-09 01:01:41.243', NULL, 'd900eeeab654e735291501076b903bd9', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73XR4NJEPDARY06397RVVC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic A: Clide face renderer — CustomPaint, rain field, glyph cache', 'The pure rendering core: a `ClideFace` widget that draws DeskLock''s glyph face and rain
field from a plain state enum. **No session wiring** — it takes a state in and paints. That
keeps it independently testable and lets it start immediately, in parallel with Epic D.

## Epic''s own first job

1. **Break this epic down** into leaf tickets once picked up, with the codebase fresh.
2. **Own the seam with Epic B** — B drives this widget. Define and publish the state enum +
   props contract early so B is not blocked on internals, and keep it stable.

## Scope

- `FaceState` enum + the per-state glyph/rain table, ported from DeskLock''s `STATES`
  (`sim/face/index.html`). Eyes, mouth, blink, thought-dots, talk cycle, rain
  streams/speed, orbit arc, elapsed counter, jitter, kaomoji frames.
- `CustomPainter` for face + rain, driven by one `Ticker`.
- Rain field simulation (spawn / fall / cull) with density and speed as inputs.
- Glyph set: **ASCII + symbols + box-drawing only — no katakana** (see the initiative;
  bundled fonts have zero kana coverage, verified with `fc-query`).

## Rendering discipline — three firsts for this repo

None of these have a house pattern to copy; establish them here.

1. **`CustomPainter(repaint: controller)`** — zero uses of `repaint:` exist in `lib/`. Both
   existing painters (`graph_painter`, `canvas_painter`) repaint via `setState`, which
   rebuilds the widget subtree every frame. Don''t copy that for a continuous animation.
2. **`RepaintBoundary`** — used exactly once in the repo
   (`lib/src/terminal/src/ui/render.dart:174`). This would be the second.
3. **`ParagraphCache`** (`lib/src/terminal/src/ui/paragraph_cache.dart`) — an LRU of
   `ui.Paragraph`, already used by the terminal painter. Build one paragraph per distinct
   glyph and `canvas.drawParagraph` per particle. **Never a `TextPainter` per particle per
   frame** — the existing painters do allocate per paint; that is fine for static painters
   and wrong here. Not exported from any barrel, so import directly or lift it.

## Mandatory reduced-motion gate

`MediaQuery.maybeOf(context)?.disableAnimations` checked in `didChangeDependencies`, ticker
stopped when true. This is not optional: `test/widgets/src/clide_marquee_test.dart:50`
asserts `pumpAndSettle()` completes under reduced motion, so a perpetual ticker that ignores
the flag hangs the suite for ~10 minutes. Reference implementations: `clide_marquee.dart`
(raw `Ticker`, closest structural match), `clide_spinner.dart`, `running_indicator.dart`.

## Tokens, not hex

`ClideSettings.theme.of(context).surface`. `SurfaceTokens` has **no `==` override**, so
`shouldRepaint` compares by identity — match the existing painters rather than deep-comparing.
Fonts via `ClideSettings.fonts.monoOf(context)` + `clideMonoFamilyFallback`, never the
`clideMonoFamily` const (D-101).

## Testing

- `hasInk` picture-recorder pattern (`test/builtin/graph/graph_painter_test.dart:35-43`)
  under `tester.runAsync` — `toImage`/`toByteData` is real engine async and must run off the
  fake clock.
- `shouldRepaint` unit-tested per field (`test/builtin/canvas/canvas_painter_test.dart:103-111`).
- Bounded pumps; tear down by pumping an empty tree so the infinite ticker disposes.
- Alchemist goldens at a **pinned ticker value** — a live animation is a bad golden.

## Breakdown (2026-08-09) — both first-job items done

**1. Broken down** into five leaf tickets:

| | Ticket | Blocked by |
|---|---|---|
| A1 | T-521 — `FaceState` contract: enum, gaze/lean axis, per-state glyph table | — |
| A2 | T-522 — Rain field simulation: deterministic spawn/fall/cull | — |
| A3 | T-523 — Glyph paragraph cache for per-particle drawing | — |
| A4 | T-524 — `ClideFacePainter`: CustomPainter for face + rain | A1, A2, A3 |
| A5 | T-525 — `ClideFace` widget: ticker, reduced-motion gate, RepaintBoundary | A4 |

**A1, A2 and A3 are all unblocked and mutually independent** — the contract, the simulation
and the cache have no dependencies on each other. A4 composes all three; A5 wraps A4.

No separate testing ticket: per repo convention tests ride along with the work that needs
them, and each leaf ticket carries its own "done when" assertions.

**2. Contract published** to Epic B on T-517 — the enum, the three widget props, and the two
consequences that affect B''s mapping (`busyFor` is B-owned; lean is derived from `gaze`, not
a prop). B can code against it without waiting for T-521 to land.

## Decision taken during breakdown: `rage` drops the kaomoji

DeskLock renders `rage` as a 3-frame table-flip pushed as whole lines through the eye slot.
Not ported. Two reasons:

1. **Two glyphs are missing from the bundled fonts** — `︵` (U+FE35) and `ノ` (U+30CE). The
   kaomoji contains katakana, which the initiative''s font finding did not catch because it
   only examined the *rain* glyph set. **Second instance of the same bug class**, which is why
   T-521''s "done when" includes a test asserting every glyph in the table against the covered
   set — so the third instance fails the suite instead of the render.
2. **It needed a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it dragged a `KaomojiFrame` class, a frame
   timer and a painter branch into the contract — for the least-seen state.

`rage` now uses the ordinary grammar: `▼   ▼` / `━` with jitter and rain spiking to 34 @ 20,
both glyphs verified covered. Semantics unchanged, so Epic B''s mapping is unaffected.
D-107 never committed to the kaomoji (checked), so no amendment is needed.

## Verified during breakdown

- `ParagraphCache` (`lib/src/terminal/src/ui/paragraph_cache.dart`) is a ~50-line LRU of
  `ui.Paragraph` keyed on `int` — directly reusable, not exported from a barrel. T-523 records
  the import-vs-lift decision.
- `clide_marquee.dart` is the closest structural precedent for the ticker: raw `Ticker`, dt
  from elapsed `Duration`, reduced-motion gate in `didChangeDependencies`, explicit
  start/stop, disposal.
- Font coverage checked with `fc-query` for every glyph in the proposed table, including the
  replacements: `▼` U+25BC, `━` U+2501, `▲` U+25B2, `·` U+00B7 all present.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:54.661', '2026-08-09 01:02:04.773', NULL, '3d6a584f8330160ae704291333f465e5', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 01:13:36.066', NULL, 'dcb4538dcd367c84e3c39112bd79e3dc', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 01:13:46.797', NULL, '1d035e8d597ccd9bc85fdfce4ce0d1f6', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/face_state.dart` — enum, `Gaze` + derived lean,
  `FaceSpec`, the seven const specs, `specFor()`, timing constants, `kVerifiedFaceGlyphs`.
  Pure Dart, no Flutter import; runs under `dart test`.
- `test/builtin/clide_companion/face_state_test.dart` — 17 tests, all green.
- `make analyze`, `make format` and `make test` (50 tests) all clean.

Contract shipped exactly as published on T-517. No deviations, so Epic B needs no rework.

### The glyph guard is proven, not just written

The ticket called this the test that matters. A guard that has never failed is not evidence,
so it was verified by sabotage: `rage`''s eyes were temporarily changed to `ノ   ノ` (the exact
katakana that hid inside DeskLock''s kaomoji). Two tests failed, and the message named the
codepoint and the fix:

```
Unverified glyph(s) in the face table: "ノ" (U+30CE). Verify against BOTH
assets/fonts/jetbrains_mono/ and assets/fonts/fira_mono/ with fc-query,
then add to kVerifiedFaceGlyphs.
```

Reverted, green again. A third instance of this bug class now fails the suite instead of
rendering as tofu.

### Correction to the earlier font work

Both prior checks (initiative, T-516 breakdown) verified against **JetBrains Mono only**.
That was insufficient: the mono face is user-selectable (D-101) and **Fira Mono is also
bundled**, so a glyph present in one and absent from the other would render as tofu for
anyone who switched fonts, and would break goldens on whichever font CI happens to use.

Re-verified every face glyph against **both** fonts — all present, so no table change was
needed, but the reasoning in `kVerifiedFaceGlyphs`'' doc comment and in the test''s failure
message now says "both", with the verification recipe inline. **T-522 (rain glyph set)
inherits this**: check the rain glyphs against both fonts, not just JetBrains.

### Tests worth noting beyond the ticket''s list

- **Eye rows are all the same width**, and blink preserves that width. The painter centres
  the mouth against the eye row, so a ragged row would silently make the lean offset mean
  something different per state.
- **No astral glyphs / no surrogate pairs** — anything outside the BMP breaks the per-cell
  monospace grid.
- **`specFor` returns the identical instance** per call, so the painter''s identity-based
  `shouldRepaint` (T-524) cannot be defeated by spec churn.
- **Talk cycle loops seamlessly** (first frame equals last).', 'in_progress', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 01:21:13.248', NULL, '9ebe47235823ceedd0ead4b3284c7724', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', 'The rain field: spawn, fall, cull. Pure Dart, **no Flutter import** — it produces particle
positions and glyph indices; the painter (T-524) turns those into pixels.

Target: `lib/builtin/clide_companion/src/rain_field.dart`

## Why it is its own ticket

It is the load signal, not decoration. Density (`rainStreams`) is what tells you at a glance
whether the session is idle or grinding — 2 streams versus 40 — so it deserves its own tests
rather than being asserted only through a painted image.

## Shape

```dart
class RainField {
  RainField({required int columns, required int rows, int seed = 0});

  /// Advance by dt seconds toward the target density/speed.
  void tick(double dt, {required int targetStreams, required double speed});

  Iterable<RainCell> get cells;   // col, row (fractional), glyphIndex, leading
}
```

- **Deterministic.** Seeded PRNG, injected — **never `Random()` unseeded and never
  `DateTime.now()`**. Tests and goldens need the same field for the same inputs.
- **Density ramps, it does not snap.** Going idle→effort should read as the field filling in
  over a few hundred ms, not popping. Going effort→idle drains by culling, not clearing.
- **Leading cell is brighter** — DeskLock draws the head of each stream lighter than the
  trail. Expose it as a flag on the cell; the painter picks the colour.
- Cull when a stream falls past `rows + 2`.

## Glyph set — ASCII + symbols + box-drawing only

**No katakana.** The bundled fonts have zero kana coverage (verified with `fc-query`), so
DeskLock''s `アイウエオ…` set cannot be used: it would fall through to a system font,
break goldens, and break the monospace advance width the grid assumes.

Use DeskLock''s covered half — `0123456789ACEFHKZ$#%*+=<>` — plus box/geometric glyphs from
`2500-25a1` (JetBrains Mono ships the full box set there; Fira Mono also covers `250c-256c`).

The field stores a **glyph index**, not a character, so the concrete set lives in one const
list and the painter resolves it. That keeps the swap cheap if the set is ever revised.

## Done when

- `tick` is pure and deterministic for a given seed — same inputs, same field, asserted.
- Density converges to `targetStreams` and holds; changing the target ramps rather than snaps.
- Cull works: cells never accumulate past the bottom, and total cell count stays bounded
  under a long run (this is the leak test — worth writing, since an unbounded field is the
  obvious failure mode for a perpetual simulation).
- Zero density produces an empty field (the `error` state must actually stop, per D-107''s
  power-ladder contract).
- Runs under `dart test` — no Flutter import.

Inherited from T-521: verify the rain glyph set against BOTH bundled mono fonts (assets/fonts/jetbrains_mono/ AND assets/fonts/fira_mono/), not just JetBrains. The mono face is user-selectable (D-101), so a glyph present in one font and absent from the other renders as tofu for anyone who switched and breaks goldens depending on which font CI uses. Reuse kVerifiedFaceGlyphs'' pattern: an explicit verified-glyph const plus a test asserting the set only draws from it, so an unverified addition fails the suite rather than the render.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 01:21:20.924', NULL, '488a8bcd2512d125d9338d87911438d8', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/face_state.dart` — enum, `Gaze` + derived lean,
  `FaceSpec`, the seven const specs, `specFor()`, timing constants, `kVerifiedFaceGlyphs`.
  Pure Dart, no Flutter import; runs under `dart test`.
- `test/builtin/clide_companion/face_state_test.dart` — 17 tests, all green.
- `make analyze`, `make format` and `make test` (50 tests) all clean.

Contract shipped exactly as published on T-517. No deviations, so Epic B needs no rework.

### The glyph guard is proven, not just written

The ticket called this the test that matters. A guard that has never failed is not evidence,
so it was verified by sabotage: `rage`''s eyes were temporarily changed to `ノ   ノ` (the exact
katakana that hid inside DeskLock''s kaomoji). Two tests failed, and the message named the
codepoint and the fix:

```
Unverified glyph(s) in the face table: "ノ" (U+30CE). Verify against BOTH
assets/fonts/jetbrains_mono/ and assets/fonts/fira_mono/ with fc-query,
then add to kVerifiedFaceGlyphs.
```

Reverted, green again. A third instance of this bug class now fails the suite instead of
rendering as tofu.

### Correction to the earlier font work

Both prior checks (initiative, T-516 breakdown) verified against **JetBrains Mono only**.
That was insufficient: the mono face is user-selectable (D-101) and **Fira Mono is also
bundled**, so a glyph present in one and absent from the other would render as tofu for
anyone who switched fonts, and would break goldens on whichever font CI happens to use.

Re-verified every face glyph against **both** fonts — all present, so no table change was
needed, but the reasoning in `kVerifiedFaceGlyphs`'' doc comment and in the test''s failure
message now says "both", with the verification recipe inline. **T-522 (rain glyph set)
inherits this**: check the rain glyphs against both fonts, not just JetBrains.

### Tests worth noting beyond the ticket''s list

- **Eye rows are all the same width**, and blink preserves that width. The painter centres
  the mouth against the eye row, so a ragged row would silently make the lean offset mean
  something different per state.
- **No astral glyphs / no surrogate pairs** — anything outside the BMP breaks the per-cell
  monospace grid.
- **`specFor` returns the identical instance** per call, so the painter''s identity-based
  `shouldRepaint` (T-524) cannot be defeated by spec churn.
- **Talk cycle loops seamlessly** (first frame equals last).', 'done', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 01:21:24.317', NULL, 'f459ca2497b4801a5064e0a028af410d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', 'The rain field: spawn, fall, cull. Pure Dart, **no Flutter import** — it produces particle
positions and glyph indices; the painter (T-524) turns those into pixels.

Target: `lib/builtin/clide_companion/src/rain_field.dart`

## Why it is its own ticket

It is the load signal, not decoration. Density (`rainStreams`) is what tells you at a glance
whether the session is idle or grinding — 2 streams versus 40 — so it deserves its own tests
rather than being asserted only through a painted image.

## Shape

```dart
class RainField {
  RainField({required int columns, required int rows, int seed = 0});

  /// Advance by dt seconds toward the target density/speed.
  void tick(double dt, {required int targetStreams, required double speed});

  Iterable<RainCell> get cells;   // col, row (fractional), glyphIndex, leading
}
```

- **Deterministic.** Seeded PRNG, injected — **never `Random()` unseeded and never
  `DateTime.now()`**. Tests and goldens need the same field for the same inputs.
- **Density ramps, it does not snap.** Going idle→effort should read as the field filling in
  over a few hundred ms, not popping. Going effort→idle drains by culling, not clearing.
- **Leading cell is brighter** — DeskLock draws the head of each stream lighter than the
  trail. Expose it as a flag on the cell; the painter picks the colour.
- Cull when a stream falls past `rows + 2`.

## Glyph set — ASCII + symbols + box-drawing only

**No katakana.** The bundled fonts have zero kana coverage (verified with `fc-query`), so
DeskLock''s `アイウエオ…` set cannot be used: it would fall through to a system font,
break goldens, and break the monospace advance width the grid assumes.

Use DeskLock''s covered half — `0123456789ACEFHKZ$#%*+=<>` — plus box/geometric glyphs from
`2500-25a1` (JetBrains Mono ships the full box set there; Fira Mono also covers `250c-256c`).

The field stores a **glyph index**, not a character, so the concrete set lives in one const
list and the painter resolves it. That keeps the swap cheap if the set is ever revised.

## Done when

- `tick` is pure and deterministic for a given seed — same inputs, same field, asserted.
- Density converges to `targetStreams` and holds; changing the target ramps rather than snaps.
- Cull works: cells never accumulate past the bottom, and total cell count stays bounded
  under a long run (this is the leak test — worth writing, since an unbounded field is the
  obvious failure mode for a perpetual simulation).
- Zero density produces an empty field (the `error` state must actually stop, per D-107''s
  power-ladder contract).
- Runs under `dart test` — no Flutter import.

Inherited from T-521: verify the rain glyph set against BOTH bundled mono fonts (assets/fonts/jetbrains_mono/ AND assets/fonts/fira_mono/), not just JetBrains. The mono face is user-selectable (D-101), so a glyph present in one font and absent from the other renders as tofu for anyone who switched and breaks goldens depending on which font CI uses. Reuse kVerifiedFaceGlyphs'' pattern: an explicit verified-glyph const plus a test asserting the set only draws from it, so an unverified addition fails the suite rather than the render.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 01:30:01.703', NULL, 'f2d01ea70ec75710d9cc375bc4ec6059', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', 'The rain field: spawn, fall, cull. Pure Dart, **no Flutter import** — it produces particle
positions and glyph indices; the painter (T-524) turns those into pixels.

Target: `lib/builtin/clide_companion/src/rain_field.dart`

## Why it is its own ticket

It is the load signal, not decoration. Density (`rainStreams`) is what tells you at a glance
whether the session is idle or grinding — 2 streams versus 40 — so it deserves its own tests
rather than being asserted only through a painted image.

## Shape

```dart
class RainField {
  RainField({required int columns, required int rows, int seed = 0});

  /// Advance by dt seconds toward the target density/speed.
  void tick(double dt, {required int targetStreams, required double speed});

  Iterable<RainCell> get cells;   // col, row (fractional), glyphIndex, leading
}
```

- **Deterministic.** Seeded PRNG, injected — **never `Random()` unseeded and never
  `DateTime.now()`**. Tests and goldens need the same field for the same inputs.
- **Density ramps, it does not snap.** Going idle→effort should read as the field filling in
  over a few hundred ms, not popping. Going effort→idle drains by culling, not clearing.
- **Leading cell is brighter** — DeskLock draws the head of each stream lighter than the
  trail. Expose it as a flag on the cell; the painter picks the colour.
- Cull when a stream falls past `rows + 2`.

## Glyph set — ASCII + symbols + box-drawing only

**No katakana.** The bundled fonts have zero kana coverage (verified with `fc-query`), so
DeskLock''s `アイウエオ…` set cannot be used: it would fall through to a system font,
break goldens, and break the monospace advance width the grid assumes.

Use DeskLock''s covered half — `0123456789ACEFHKZ$#%*+=<>` — plus box/geometric glyphs from
`2500-25a1` (JetBrains Mono ships the full box set there; Fira Mono also covers `250c-256c`).

The field stores a **glyph index**, not a character, so the concrete set lives in one const
list and the painter resolves it. That keeps the swap cheap if the set is ever revised.

## Done when

- `tick` is pure and deterministic for a given seed — same inputs, same field, asserted.
- Density converges to `targetStreams` and holds; changing the target ramps rather than snaps.
- Cull works: cells never accumulate past the bottom, and total cell count stays bounded
  under a long run (this is the leak test — worth writing, since an unbounded field is the
  obvious failure mode for a perpetual simulation).
- Zero density produces an empty field (the `error` state must actually stop, per D-107''s
  power-ladder contract).
- Runs under `dart test` — no Flutter import.

Inherited from T-521: verify the rain glyph set against BOTH bundled mono fonts (assets/fonts/jetbrains_mono/ AND assets/fonts/fira_mono/), not just JetBrains. The mono face is user-selectable (D-101), so a glyph present in one font and absent from the other renders as tofu for anyone who switched and breaks goldens depending on which font CI uses. Reuse kVerifiedFaceGlyphs'' pattern: an explicit verified-glyph const plus a test asserting the set only draws from it, so an unverified addition fails the suite rather than the render.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/rain_field.dart` — `RainField`, `RainCell`, `kRainGlyphs`,
  hand-rolled seeded xorshift. Pure Dart, no Flutter import.
- `test/builtin/clide_companion/rain_field_test.dart` — 17 tests, all green.
- `make analyze`, `make format`, `make test` all clean.

## The both-fonts check earned its keep immediately

The inherited lesson from T-521 was not theoretical. Checking candidate glyphs against both
bundled fonts found three present in JetBrains Mono and **absent from Fira Mono**:

| Glyph | Codepoint | JetBrains | Fira |
|---|---|---|---|
| `┆` | U+2506 | ✓ | **missing** |
| `┊` | U+250A | ✓ | **missing** |
| `⋮` | U+22EE | ✓ | **missing** |

Those dashed and dotted verticals are the *most obviously rain-like* glyphs in the range —
they would have been the natural first picks, and they would have rendered as tofu for anyone
who switched to Fira, while passing every test on the author''s machine. Excluded; the set is
built from the intersection instead, and the exclusion is documented in `kRainGlyphs`'' doc
comment with the reason, so it does not get "helpfully" re-added.

## A real bug the tests caught: churn and growth shared a budget

First implementation rate-limited *all* spawning to make density ramp visibly rather than
snap. That also throttled routine replacement of streams that had fallen off the bottom —
and at 40 streams, the cull rate alone consumes the entire per-frame spawn allowance, so a
dense fast field hovered at 36–40 and never actually reached its target.

Fixed by separating the two: replacing a culled stream keeps density flat and is **free**;
only genuine *growth* is rate-limited. Density now holds exactly while ramps stay visible.

Guarded by a regression test that samples **every frame** for 300 frames at maximum churn —
the original failure was invisible when sampling once at the end, which is exactly how it
would have been missed.

## Design notes worth carrying to T-524

- **`isQuiescent`** — true once the field is empty. The widget (T-525) can park its ticker on
  it, which is the visible half of D-107''s power-ladder contract.
- **Zero density drains, it does not clear.** `error` stops spawning and lets existing streams
  fall off, so the rain runs out rather than vanishing mid-air. Tested both ways: a fresh
  field at target 0 never spawns; an existing field drains to empty and reports quiescent.
- **Per-stream speed is assigned at spawn** with ±30% jitter, so a state change affects new
  streams first and the transition reads as organic rather than as a global speed switch.
- **Hand-rolled xorshift, not `Random(seed)`** — pins the sequence to this file so goldens
  cannot silently rebase if the Dart SDK changes its generator.

## Correction to the T-521 report

I reported "`make test` (50 tests)" there. That was the count of the **serial-tagged phase
only**; `ci/test.sh` runs three phases and the parallel pool is **4045** tests. The suite is
~4100, and both of these tickets'' tests run inside it — verified with
`flutter test test/builtin/clide_companion/` (34 tests) and by reading the per-phase output.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 01:41:37.381', NULL, '97029de5df85e0b7c5e5e433f5e319b0', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W5PARJ36P3TQCANG78YF4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A2: Rain field simulation — deterministic spawn/fall/cull', 'The rain field: spawn, fall, cull. Pure Dart, **no Flutter import** — it produces particle
positions and glyph indices; the painter (T-524) turns those into pixels.

Target: `lib/builtin/clide_companion/src/rain_field.dart`

## Why it is its own ticket

It is the load signal, not decoration. Density (`rainStreams`) is what tells you at a glance
whether the session is idle or grinding — 2 streams versus 40 — so it deserves its own tests
rather than being asserted only through a painted image.

## Shape

```dart
class RainField {
  RainField({required int columns, required int rows, int seed = 0});

  /// Advance by dt seconds toward the target density/speed.
  void tick(double dt, {required int targetStreams, required double speed});

  Iterable<RainCell> get cells;   // col, row (fractional), glyphIndex, leading
}
```

- **Deterministic.** Seeded PRNG, injected — **never `Random()` unseeded and never
  `DateTime.now()`**. Tests and goldens need the same field for the same inputs.
- **Density ramps, it does not snap.** Going idle→effort should read as the field filling in
  over a few hundred ms, not popping. Going effort→idle drains by culling, not clearing.
- **Leading cell is brighter** — DeskLock draws the head of each stream lighter than the
  trail. Expose it as a flag on the cell; the painter picks the colour.
- Cull when a stream falls past `rows + 2`.

## Glyph set — ASCII + symbols + box-drawing only

**No katakana.** The bundled fonts have zero kana coverage (verified with `fc-query`), so
DeskLock''s `アイウエオ…` set cannot be used: it would fall through to a system font,
break goldens, and break the monospace advance width the grid assumes.

Use DeskLock''s covered half — `0123456789ACEFHKZ$#%*+=<>` — plus box/geometric glyphs from
`2500-25a1` (JetBrains Mono ships the full box set there; Fira Mono also covers `250c-256c`).

The field stores a **glyph index**, not a character, so the concrete set lives in one const
list and the painter resolves it. That keeps the swap cheap if the set is ever revised.

## Done when

- `tick` is pure and deterministic for a given seed — same inputs, same field, asserted.
- Density converges to `targetStreams` and holds; changing the target ramps rather than snaps.
- Cull works: cells never accumulate past the bottom, and total cell count stays bounded
  under a long run (this is the leak test — worth writing, since an unbounded field is the
  obvious failure mode for a perpetual simulation).
- Zero density produces an empty field (the `error` state must actually stop, per D-107''s
  power-ladder contract).
- Runs under `dart test` — no Flutter import.

Inherited from T-521: verify the rain glyph set against BOTH bundled mono fonts (assets/fonts/jetbrains_mono/ AND assets/fonts/fira_mono/), not just JetBrains. The mono face is user-selectable (D-101), so a glyph present in one font and absent from the other renders as tofu for anyone who switched and breaks goldens depending on which font CI uses. Reuse kVerifiedFaceGlyphs'' pattern: an explicit verified-glyph const plus a test asserting the set only draws from it, so an unverified addition fails the suite rather than the render.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/rain_field.dart` — `RainField`, `RainCell`, `kRainGlyphs`,
  hand-rolled seeded xorshift. Pure Dart, no Flutter import.
- `test/builtin/clide_companion/rain_field_test.dart` — 17 tests, all green.
- `make analyze`, `make format`, `make test` all clean.

## The both-fonts check earned its keep immediately

The inherited lesson from T-521 was not theoretical. Checking candidate glyphs against both
bundled fonts found three present in JetBrains Mono and **absent from Fira Mono**:

| Glyph | Codepoint | JetBrains | Fira |
|---|---|---|---|
| `┆` | U+2506 | ✓ | **missing** |
| `┊` | U+250A | ✓ | **missing** |
| `⋮` | U+22EE | ✓ | **missing** |

Those dashed and dotted verticals are the *most obviously rain-like* glyphs in the range —
they would have been the natural first picks, and they would have rendered as tofu for anyone
who switched to Fira, while passing every test on the author''s machine. Excluded; the set is
built from the intersection instead, and the exclusion is documented in `kRainGlyphs`'' doc
comment with the reason, so it does not get "helpfully" re-added.

## A real bug the tests caught: churn and growth shared a budget

First implementation rate-limited *all* spawning to make density ramp visibly rather than
snap. That also throttled routine replacement of streams that had fallen off the bottom —
and at 40 streams, the cull rate alone consumes the entire per-frame spawn allowance, so a
dense fast field hovered at 36–40 and never actually reached its target.

Fixed by separating the two: replacing a culled stream keeps density flat and is **free**;
only genuine *growth* is rate-limited. Density now holds exactly while ramps stay visible.

Guarded by a regression test that samples **every frame** for 300 frames at maximum churn —
the original failure was invisible when sampling once at the end, which is exactly how it
would have been missed.

## Design notes worth carrying to T-524

- **`isQuiescent`** — true once the field is empty. The widget (T-525) can park its ticker on
  it, which is the visible half of D-107''s power-ladder contract.
- **Zero density drains, it does not clear.** `error` stops spawning and lets existing streams
  fall off, so the rain runs out rather than vanishing mid-air. Tested both ways: a fresh
  field at target 0 never spawns; an existing field drains to empty and reports quiescent.
- **Per-stream speed is assigned at spawn** with ±30% jitter, so a state change affects new
  streams first and the transition reads as organic rather than as a global speed switch.
- **Hand-rolled xorshift, not `Random(seed)`** — pins the sequence to this file so goldens
  cannot silently rebase if the Dart SDK changes its generator.

## Correction to the T-521 report

I reported "`make test` (50 tests)" there. That was the count of the **serial-tagged phase
only**; `ci/test.sh` runs three phases and the parallel pool is **4045** tests. The suite is
~4100, and both of these tickets'' tests run inside it — verified with
`flutter test test/builtin/clide_companion/` (34 tests) and by reading the per-phase output.', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:51.190', '2026-08-09 01:41:42.056', NULL, 'b2627b3639be1de193ac34c622c5f70d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', 'One `ui.Paragraph` per distinct (glyph, style) pair, reused across frames and particles.
This is the difference between the face being cheap and being a space heater.

Target: `lib/builtin/clide_companion/src/glyph_cache.dart`

## The rule

**Never build a `TextPainter` per particle per frame.** At 40 streams × ~20 rows that is
~800 layouts per frame at 30fps. Both existing painters (`graph_painter.dart:121`,
`canvas_painter.dart:214`) do allocate a `TextPainter` per paint — that is fine for a static
painter that repaints on interaction, and wrong here. Do not copy them.

## Reuse `ParagraphCache`

`lib/src/terminal/src/ui/paragraph_cache.dart` already implements exactly this: an LRU of
`ui.Paragraph` keyed on `int`, with `getLayoutFromCache(key)` and
`performAndCacheLayout(text, style, textScaler, key)`. It is ~50 lines, used by the terminal
painter (`painter.dart:150-180`), and **not exported from any barrel**.

Decide and record which:
- **import it directly** (`package:clide/src/terminal/src/ui/paragraph_cache.dart`) — no
  duplication, but reaches across into the terminal subsystem''s private path; or
- **lift it** to a shared location and have both use it — cleaner layering, touches the
  terminal painter.

Prefer importing directly first and only lift if a third consumer appears. Note the file
header credits xterm.dart (MIT) — per repo convention, code under `lib/` is owned, not
vendored, so it is fair game to move; keep the credit either way.

## Key scheme

Key on everything that changes the rendered glyph: **glyph index, colour, font size, and the
resolved font family**. Font comes from `ClideSettings.fonts.monoOf(context)` (D-101) and is
user-changeable at runtime, so it must be in the key or a font switch silently renders stale
paragraphs. Same for theme changes, which change colour.

Cache size should comfortably exceed `glyphSet.length × distinctColours` — the working set is
small and bounded, so sizing it too *small* is the only real failure mode.

## Done when

- One cache instance owned by the painter, cleared on theme or font change.
- A test asserts the second request for the same key returns the **identical** `Paragraph`
  instance (`identical()`, not `==`) — that is the whole point of the ticket.
- A test asserts a colour, size, or font-family change produces a different entry rather than
  reusing a stale one.
- A bounded-growth test: painting many frames does not grow the cache without limit.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 02:07:33.607', NULL, '703f791b48c60bd1bc9a18cd18f38f25', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', 'One `ui.Paragraph` per distinct (glyph, style) pair, reused across frames and particles.
This is the difference between the face being cheap and being a space heater.

Target: `lib/builtin/clide_companion/src/glyph_cache.dart`

## The rule

**Never build a `TextPainter` per particle per frame.** At 40 streams × ~20 rows that is
~800 layouts per frame at 30fps. Both existing painters (`graph_painter.dart:121`,
`canvas_painter.dart:214`) do allocate a `TextPainter` per paint — that is fine for a static
painter that repaints on interaction, and wrong here. Do not copy them.

## Reuse `ParagraphCache`

`lib/src/terminal/src/ui/paragraph_cache.dart` already implements exactly this: an LRU of
`ui.Paragraph` keyed on `int`, with `getLayoutFromCache(key)` and
`performAndCacheLayout(text, style, textScaler, key)`. It is ~50 lines, used by the terminal
painter (`painter.dart:150-180`), and **not exported from any barrel**.

Decide and record which:
- **import it directly** (`package:clide/src/terminal/src/ui/paragraph_cache.dart`) — no
  duplication, but reaches across into the terminal subsystem''s private path; or
- **lift it** to a shared location and have both use it — cleaner layering, touches the
  terminal painter.

Prefer importing directly first and only lift if a third consumer appears. Note the file
header credits xterm.dart (MIT) — per repo convention, code under `lib/` is owned, not
vendored, so it is fair game to move; keep the credit either way.

## Key scheme

Key on everything that changes the rendered glyph: **glyph index, colour, font size, and the
resolved font family**. Font comes from `ClideSettings.fonts.monoOf(context)` (D-101) and is
user-changeable at runtime, so it must be in the key or a font switch silently renders stale
paragraphs. Same for theme changes, which change colour.

Cache size should comfortably exceed `glyphSet.length × distinctColours` — the working set is
small and bounded, so sizing it too *small* is the only real failure mode.

## Done when

- One cache instance owned by the painter, cleared on theme or font change.
- A test asserts the second request for the same key returns the **identical** `Paragraph`
  instance (`identical()`, not `==`) — that is the whole point of the ticket.
- A test asserts a colour, size, or font-family change produces a different entry rather than
  reusing a stale one.
- A bounded-growth test: painting many frames does not grow the cache without limit.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 02:07:51.619', NULL, '2a64b8a94361b8d753445a2c9343fe3d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', 'One `ui.Paragraph` per distinct (glyph, style) pair, reused across frames and particles.
This is the difference between the face being cheap and being a space heater.

Target: `lib/builtin/clide_companion/src/glyph_cache.dart`

## The rule

**Never build a `TextPainter` per particle per frame.** At 40 streams × ~20 rows that is
~800 layouts per frame at 30fps. Both existing painters (`graph_painter.dart:121`,
`canvas_painter.dart:214`) do allocate a `TextPainter` per paint — that is fine for a static
painter that repaints on interaction, and wrong here. Do not copy them.

## Reuse `ParagraphCache`

`lib/src/terminal/src/ui/paragraph_cache.dart` already implements exactly this: an LRU of
`ui.Paragraph` keyed on `int`, with `getLayoutFromCache(key)` and
`performAndCacheLayout(text, style, textScaler, key)`. It is ~50 lines, used by the terminal
painter (`painter.dart:150-180`), and **not exported from any barrel**.

Decide and record which:
- **import it directly** (`package:clide/src/terminal/src/ui/paragraph_cache.dart`) — no
  duplication, but reaches across into the terminal subsystem''s private path; or
- **lift it** to a shared location and have both use it — cleaner layering, touches the
  terminal painter.

Prefer importing directly first and only lift if a third consumer appears. Note the file
header credits xterm.dart (MIT) — per repo convention, code under `lib/` is owned, not
vendored, so it is fair game to move; keep the credit either way.

## Key scheme

Key on everything that changes the rendered glyph: **glyph index, colour, font size, and the
resolved font family**. Font comes from `ClideSettings.fonts.monoOf(context)` (D-101) and is
user-changeable at runtime, so it must be in the key or a font switch silently renders stale
paragraphs. Same for theme changes, which change colour.

Cache size should comfortably exceed `glyphSet.length × distinctColours` — the working set is
small and bounded, so sizing it too *small* is the only real failure mode.

## Done when

- One cache instance owned by the painter, cleared on theme or font change.
- A test asserts the second request for the same key returns the **identical** `Paragraph`
  instance (`identical()`, not `==`) — that is the whole point of the ticket.
- A test asserts a colour, size, or font-family change produces a different entry rather than
  reusing a stale one.
- A bounded-growth test: painting many frames does not grow the cache without limit.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/glyph_cache.dart` — `GlyphCache`, `GlyphMetrics`.
- `test/builtin/clide_companion/glyph_cache_test.dart` — 16 tests, all green.
- `make analyze`, `make format`, `make test` clean. Parallel pool 4045 → 4061, so the new
  tests are in the gate.

## Decision: imported, not lifted

`ParagraphCache` is imported directly from
`package:clide/src/terminal/src/ui/paragraph_cache.dart`, as the ticket preferred. Reaching
across a subsystem boundary is the smaller evil than a second copy of the same LRU. The
reasoning — and the trigger for revisiting it — is recorded in the class doc: **if a third
consumer appears, lift it somewhere shared and update both.** `flutter analyze` is clean with
the import, so there is no lint pressure against it.

## Deviation: `Object.hash`, not the terminal''s XOR

The terminal painter keys with `cellData.getHash() ^ _textScaler.hashCode`
(`painter.dart:150`). XOR is a weak combiner and collides readily on structured inputs. That
is tolerable there because it is hashing one packed struct; here the key combines six
independent values, and **a collision does not degrade — it silently draws the wrong glyph or
the wrong colour**, with no error and nothing to notice until someone squints at a
screenshot. Used `Object.hash` / `Object.hashAll` instead.

## The ticket asked for clearing; the key makes it unnecessary for correctness

The ticket''s done-when says "one cache instance owned by the painter, **cleared on theme or
font change**". Implemented, but with a stronger property than that implies:

**Every input that changes the rendered pixels is in the key** — glyph, colour, font size,
font family, fallback list, text scaler. So a theme or font switch simply *misses* and lays
out fresh. It cannot return a stale paragraph even if nothing ever calls `clear()`.

That downgrades forgetting to clear from a rendering bug to a memory issue, which matters
because the painter is the thing that would have to remember, and it is the component most
likely to be refactored later. `clear()` exists and is tested, but it is memory hygiene.
There is an explicit test named for this: a theme switch *without* a clear must still produce
the new colour.

## Added beyond scope: `metrics()`

The painter (T-524) needs the cell size to lay out the grid, and would otherwise hand-roll a
measurement and probably rebuild it per frame. `metrics()` measures a reference glyph
*through* the cache, so the probe layout is cached like everything else. Tested that a repeat
call adds no entry.

## Sizing

Default `maximumSize: 512`. Working set is ~42 rain glyphs plus the face glyphs across a
handful of token colours and one or two sizes — comfortably under. Sizing it too small is the
only real failure mode, so there is a test asserting a 180-entry working set is not evicted
at the default, alongside one asserting a deliberately tiny cache does evict.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 02:13:36.552', NULL, '01d0379cd9489d1701f4f7ae88fd7ab6', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.

From T-523: GlyphCache exposes metrics() for cell sizing — measure through it rather than hand-rolling a TextPainter, so the probe layout is cached too. Correctness does not depend on clearing the cache (every pixel-affecting input is in the key), so clear() on theme/font change is memory hygiene only; do not build logic that relies on it for freshness. ParagraphCache is imported from the terminal subsystem, not lifted — if this painter or anything else adds a third consumer, lift it somewhere shared and update all users.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 02:13:43.428', NULL, 'a21312a59127c13515cd3b7d7388d081', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W64KMPGV5TMJ7C7D654WM', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A3: Glyph paragraph cache for per-particle drawing', 'One `ui.Paragraph` per distinct (glyph, style) pair, reused across frames and particles.
This is the difference between the face being cheap and being a space heater.

Target: `lib/builtin/clide_companion/src/glyph_cache.dart`

## The rule

**Never build a `TextPainter` per particle per frame.** At 40 streams × ~20 rows that is
~800 layouts per frame at 30fps. Both existing painters (`graph_painter.dart:121`,
`canvas_painter.dart:214`) do allocate a `TextPainter` per paint — that is fine for a static
painter that repaints on interaction, and wrong here. Do not copy them.

## Reuse `ParagraphCache`

`lib/src/terminal/src/ui/paragraph_cache.dart` already implements exactly this: an LRU of
`ui.Paragraph` keyed on `int`, with `getLayoutFromCache(key)` and
`performAndCacheLayout(text, style, textScaler, key)`. It is ~50 lines, used by the terminal
painter (`painter.dart:150-180`), and **not exported from any barrel**.

Decide and record which:
- **import it directly** (`package:clide/src/terminal/src/ui/paragraph_cache.dart`) — no
  duplication, but reaches across into the terminal subsystem''s private path; or
- **lift it** to a shared location and have both use it — cleaner layering, touches the
  terminal painter.

Prefer importing directly first and only lift if a third consumer appears. Note the file
header credits xterm.dart (MIT) — per repo convention, code under `lib/` is owned, not
vendored, so it is fair game to move; keep the credit either way.

## Key scheme

Key on everything that changes the rendered glyph: **glyph index, colour, font size, and the
resolved font family**. Font comes from `ClideSettings.fonts.monoOf(context)` (D-101) and is
user-changeable at runtime, so it must be in the key or a font switch silently renders stale
paragraphs. Same for theme changes, which change colour.

Cache size should comfortably exceed `glyphSet.length × distinctColours` — the working set is
small and bounded, so sizing it too *small* is the only real failure mode.

## Done when

- One cache instance owned by the painter, cleared on theme or font change.
- A test asserts the second request for the same key returns the **identical** `Paragraph`
  instance (`identical()`, not `==`) — that is the whole point of the ticket.
- A test asserts a colour, size, or font-family change produces a different entry rather than
  reusing a stale one.
- A bounded-growth test: painting many frames does not grow the cache without limit.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/glyph_cache.dart` — `GlyphCache`, `GlyphMetrics`.
- `test/builtin/clide_companion/glyph_cache_test.dart` — 16 tests, all green.
- `make analyze`, `make format`, `make test` clean. Parallel pool 4045 → 4061, so the new
  tests are in the gate.

## Decision: imported, not lifted

`ParagraphCache` is imported directly from
`package:clide/src/terminal/src/ui/paragraph_cache.dart`, as the ticket preferred. Reaching
across a subsystem boundary is the smaller evil than a second copy of the same LRU. The
reasoning — and the trigger for revisiting it — is recorded in the class doc: **if a third
consumer appears, lift it somewhere shared and update both.** `flutter analyze` is clean with
the import, so there is no lint pressure against it.

## Deviation: `Object.hash`, not the terminal''s XOR

The terminal painter keys with `cellData.getHash() ^ _textScaler.hashCode`
(`painter.dart:150`). XOR is a weak combiner and collides readily on structured inputs. That
is tolerable there because it is hashing one packed struct; here the key combines six
independent values, and **a collision does not degrade — it silently draws the wrong glyph or
the wrong colour**, with no error and nothing to notice until someone squints at a
screenshot. Used `Object.hash` / `Object.hashAll` instead.

## The ticket asked for clearing; the key makes it unnecessary for correctness

The ticket''s done-when says "one cache instance owned by the painter, **cleared on theme or
font change**". Implemented, but with a stronger property than that implies:

**Every input that changes the rendered pixels is in the key** — glyph, colour, font size,
font family, fallback list, text scaler. So a theme or font switch simply *misses* and lays
out fresh. It cannot return a stale paragraph even if nothing ever calls `clear()`.

That downgrades forgetting to clear from a rendering bug to a memory issue, which matters
because the painter is the thing that would have to remember, and it is the component most
likely to be refactored later. `clear()` exists and is tested, but it is memory hygiene.
There is an explicit test named for this: a theme switch *without* a clear must still produce
the new colour.

## Added beyond scope: `metrics()`

The painter (T-524) needs the cell size to lay out the grid, and would otherwise hand-roll a
measurement and probably rebuild it per frame. `metrics()` measures a reference glyph
*through* the cache, so the probe layout is cached like everything else. Tested that a repeat
call adds no entry.

## Sizing

Default `maximumSize: 512`. Working set is ~42 rain glyphs plus the face glyphs across a
handful of token colours and one or two sizes — comfortably under. Sizing it too small is the
only real failure mode, so there is a test asserting a 180-entry working set is not evicted
at the default, alongside one asserting a deliberately tiny cache does evict.', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:54.845', '2026-08-09 02:13:47.481', NULL, '0599f47621c231a5c4df4ce541096250', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.

From T-523: GlyphCache exposes metrics() for cell sizing — measure through it rather than hand-rolling a TextPainter, so the probe layout is cached too. Correctness does not depend on clearing the cache (every pixel-affecting input is in the key), so clear() on theme/font change is memory hygiene only; do not build logic that relies on it for freshness. ParagraphCache is imported from the terminal subsystem, not lifted — if this painter or anything else adds a third consumer, lift it somewhere shared and update all users.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 02:31:19.828', NULL, '7d24e3cd346a968a0623eec8141565cb', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.

From T-523: GlyphCache exposes metrics() for cell sizing — measure through it rather than hand-rolling a TextPainter, so the probe layout is cached too. Correctness does not depend on clearing the cache (every pixel-affecting input is in the key), so clear() on theme/font change is memory hygiene only; do not build logic that relies on it for freshness. ParagraphCache is imported from the terminal subsystem, not lifted — if this painter or anything else adds a third consumer, lift it somewhere shared and update all users.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 02:31:27.355', NULL, '55d6b6ff59117f48a6649ccc5bcd619f', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.

From T-523: GlyphCache exposes metrics() for cell sizing — measure through it rather than hand-rolling a TextPainter, so the probe layout is cached too. Correctness does not depend on clearing the cache (every pixel-affecting input is in the key), so clear() on theme/font change is memory hygiene only; do not build logic that relies on it for freshness. ParagraphCache is imported from the terminal subsystem, not lifted — if this painter or anything else adds a third consumer, lift it somewhere shared and update all users.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/face_painter.dart` — `ClideFacePainter`.
- `test/builtin/clide_companion/face_painter_test.dart` — 11 tests, all green.
- `make analyze`, `make format`, `make test` clean. Parallel pool 4061 → 4072.

## `repaint:` — the clock is both the time source and the repaint source

First use of `CustomPainter(repaint:)` in the repo, so the pattern is worth stating: the
painter takes a `ValueListenable<Duration>` and passes it to `super(repaint:)`. Because
`repaint:` schedules a paint **without rebuilding the widget subtree**, the painter is not
reconstructed per frame — so a `final Duration` field would go stale immediately. Time
therefore has to arrive through the same listenable that schedules the paint. One object,
both jobs.

`shouldRepaint` still covers the non-animated inputs, which arrive by rebuild: state, gaze,
lean, busyFor, rainFontSize, fontFamily, tokens (identity, per the note below), and identity
of field/cache/clock.

## Correction to the ticket: "error paints no rain" is not the painter''s job

The ticket''s done-when says *"`error` paints no rain — a visible assertion of the
power-ladder contract"*. Implementing it revealed that would be the **wrong** place for it.

The painter draws whatever cells the field holds; it never consults `spec.rainStreams`. That
number is the *target* the widget ticks the field toward, so an empty field at `error` is
produced upstream by the spec draining the simulation (already tested in T-522), not by a
branch inside `paint`. Adding such a branch would have made the painter lie about its input
and duplicated a rule that already lives in the data.

The test was rewritten to assert the property that actually belongs here: **the painter is a
faithful function of the field** — an empty field and a primed field at the same state render
differently. The power-ladder assertion stays in T-522, where the draining is.

## The prescribed `hasInk` metric does not discriminate here

The ticket specified the `hasInk` picture-recorder pattern from `graph_painter_test.dart`,
which counts non-transparent pixels. That works for the graph painter, which draws sparse
marks on a transparent canvas. **It fails here**, and quietly: the vignette is full-bleed, so
after it paints, ~37,300 of 38,400 pixels already have non-zero alpha. The
`busyFor` test initially passed the same count with and without the elapsed counter — an
identical number, not a near-miss, which is what made it obvious rather than a flaky
threshold.

Fixed by comparing **raw pixel bytes** between two renders instead of counting alpha.
`hasInk` is retained only for "did this state draw anything at all", where saturation is
harmless. Worth carrying to T-525''s goldens: any assertion finer than "something was drawn"
needs byte comparison, not ink counting.

## Notes for T-525

- The widget owns the ticker, advances the `RainField`, and updates the clock''s value; the
  painter reads. Keeping simulation out of `paint` is what makes every frame a pure function
  of (clock, field, spec, tokens) and lets the tests above be deterministic.
- `lean` is nullable and falls back to `gaze.leanPx`. Pass an interpolated value to animate
  the transition — that is the "animated rather than snapped" half of D-107, and the painter
  is already set up for it.
- Wall-clock `HH:MM` for the idle state is the one thing not derived from the ticker, since
  it is genuinely time-of-day. Goldens covering `idle` must pin or avoid it.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 02:41:19.548', NULL, '1d50284d65e6b963c93019fc453e756a', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.

From T-524: (1) The widget owns the ticker, advances the RainField, and updates the clock ValueNotifier<Duration>; the painter only reads. Keeping simulation out of paint() is what makes each frame a pure function of (clock, field, spec, tokens). (2) ClideFacePainter takes a nullable lean that falls back to gaze.leanPx — pass an interpolated value to animate the transition, which is the ''animated rather than snapped'' half of D-107. (3) hasInk-style alpha counting does NOT discriminate for this painter: the vignette is full-bleed so ~37300/38400 pixels have non-zero alpha. Goldens and any assertion finer than ''something was drawn'' must compare raw pixel bytes. (4) The idle clock label uses DateTime.now() — it is genuinely time-of-day, not animation state — so goldens covering idle must pin or avoid it.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 02:41:26.899', NULL, 'e915608b10d344d0499fb6b95c30b5ba', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W6JXV00WEC79SK0GDWSH0', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A4: ClideFacePainter — CustomPainter for face + rain', 'The painter: face (eyes, mouth, thought dots, clock, orbit arc, elapsed counter) plus the
rain field, drawn from the T-521 spec, the T-522 field, and the T-523 cache.

Target: `lib/builtin/clide_companion/src/face_painter.dart`

Blocked by T-521 (spec), T-522 (field), T-523 (cache) — it composes all three.

## Draw order

1. Rain (behind everything), trail then leading cells
2. Radial vignette behind the face — DeskLock uses this to keep the face readable over dense
   rain, and at 40 streams it is doing real work, not decoration
3. Face group: eyes, mouth, thought dots, clock — offset by breathe + jitter + lean
4. Orbit arc on the bezel, elapsed `[ Ns ]` counter

## Tokens only — never a hex literal

`ClideSettings.theme.of(context).surface`. Mapping:

| Element | Token |
|---|---|
| well / background | `panelBackground` |
| rain trail | `globalTextMuted` at low alpha |
| rain leading cell | `globalTextMuted` at higher alpha |
| face glyphs | `globalForeground` |
| clock, elapsed counter | `globalTextMuted` |
| orbit arc | `globalFocus` |
| `rage` accent | `statusWarning` |
| `error` accent | `statusError` |

`SurfaceTokens` has **no `==` override**, so `shouldRepaint` compares tokens by identity —
match the existing painters (`graph_painter.dart:138`, `canvas_painter.dart:227`) rather than
deep-comparing. A new instance is only built on theme change, so identity is correct.

## `repaint:` — the first use in this repo

Pass the ticker''s `Listenable` to `CustomPainter(repaint: controller)`. Zero uses of
`repaint:` exist in `lib/` today; both existing painters drive repaints via `setState`, which
rebuilds the widget subtree every frame. **Do not copy that for a continuous animation** — it
is the difference between repainting a layer and rebuilding a tree 30 times a second.

`shouldRepaint` still needs to be correct for the *non-animated* inputs (state, gaze, tokens,
size) since those arrive by rebuild.

## Done when

- `hasInk` picture-recorder assertions per state (pattern:
  `test/builtin/graph/graph_painter_test.dart:35-43`), run under `tester.runAsync` —
  `toImage`/`toByteData` is real engine async and hangs on the fake test clock.
- `shouldRepaint` unit-tested per field (pattern:
  `test/builtin/canvas/canvas_painter_test.dart:103-111`): identical inputs → false, each
  varying field → true.
- `error` paints no rain — a visible assertion of the power-ladder contract (D-107).
- Lean offset is applied to the mouth and is visible in the painted output at −8/0/+8.
- No `TextPainter` allocation in `paint` — assert via the cache''s instance-reuse test (T-523)
  rather than by inspection.

From T-523: GlyphCache exposes metrics() for cell sizing — measure through it rather than hand-rolling a TextPainter, so the probe layout is cached too. Correctness does not depend on clearing the cache (every pixel-affecting input is in the key), so clear() on theme/font change is memory hygiene only; do not build logic that relies on it for freshness. ParagraphCache is imported from the terminal subsystem, not lifted — if this painter or anything else adds a third consumer, lift it somewhere shared and update all users.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/face_painter.dart` — `ClideFacePainter`.
- `test/builtin/clide_companion/face_painter_test.dart` — 11 tests, all green.
- `make analyze`, `make format`, `make test` clean. Parallel pool 4061 → 4072.

## `repaint:` — the clock is both the time source and the repaint source

First use of `CustomPainter(repaint:)` in the repo, so the pattern is worth stating: the
painter takes a `ValueListenable<Duration>` and passes it to `super(repaint:)`. Because
`repaint:` schedules a paint **without rebuilding the widget subtree**, the painter is not
reconstructed per frame — so a `final Duration` field would go stale immediately. Time
therefore has to arrive through the same listenable that schedules the paint. One object,
both jobs.

`shouldRepaint` still covers the non-animated inputs, which arrive by rebuild: state, gaze,
lean, busyFor, rainFontSize, fontFamily, tokens (identity, per the note below), and identity
of field/cache/clock.

## Correction to the ticket: "error paints no rain" is not the painter''s job

The ticket''s done-when says *"`error` paints no rain — a visible assertion of the
power-ladder contract"*. Implementing it revealed that would be the **wrong** place for it.

The painter draws whatever cells the field holds; it never consults `spec.rainStreams`. That
number is the *target* the widget ticks the field toward, so an empty field at `error` is
produced upstream by the spec draining the simulation (already tested in T-522), not by a
branch inside `paint`. Adding such a branch would have made the painter lie about its input
and duplicated a rule that already lives in the data.

The test was rewritten to assert the property that actually belongs here: **the painter is a
faithful function of the field** — an empty field and a primed field at the same state render
differently. The power-ladder assertion stays in T-522, where the draining is.

## The prescribed `hasInk` metric does not discriminate here

The ticket specified the `hasInk` picture-recorder pattern from `graph_painter_test.dart`,
which counts non-transparent pixels. That works for the graph painter, which draws sparse
marks on a transparent canvas. **It fails here**, and quietly: the vignette is full-bleed, so
after it paints, ~37,300 of 38,400 pixels already have non-zero alpha. The
`busyFor` test initially passed the same count with and without the elapsed counter — an
identical number, not a near-miss, which is what made it obvious rather than a flaky
threshold.

Fixed by comparing **raw pixel bytes** between two renders instead of counting alpha.
`hasInk` is retained only for "did this state draw anything at all", where saturation is
harmless. Worth carrying to T-525''s goldens: any assertion finer than "something was drawn"
needs byte comparison, not ink counting.

## Notes for T-525

- The widget owns the ticker, advances the `RainField`, and updates the clock''s value; the
  painter reads. Keeping simulation out of `paint` is what makes every frame a pure function
  of (clock, field, spec, tokens) and lets the tests above be deterministic.
- `lean` is nullable and falls back to `gaze.leanPx`. Pass an interpolated value to animate
  the transition — that is the "animated rather than snapped" half of D-107, and the painter
  is already set up for it.
- Wall-clock `HH:MM` for the idle state is the one thing not derived from the ticker, since
  it is genuinely time-of-day. Goldens covering `idle` must pin or avoid it.', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 00:33:58.510', '2026-08-09 02:41:30.922', NULL, '1868972c8e9389cd49825e7a77a7c841', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XR4APSKWH94DNG00B51J4', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C1: Clide strip surface — _ContextSlot becomes a Column, responsive 220-1000px', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:32.981', '2026-08-09 03:00:32.981', NULL, '29b88374421d61e6e3f9107351b15ff4', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XRM7XGNMSGTRB1CNZAA8R', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C4: Clide settings category + enable/disable kill switch', NULL, 'backlog', 'high', NULL, NULL, NULL, '2026-08-09 03:00:37.055', '2026-08-09 03:00:37.055', NULL, '85be53bc5f6878ce583b46f068e273fe', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XS3NW0XJA256CB6BJ21BM', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C2: Strip collapse affordance + persisted height + grow-to-cap while answering', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:41.007', '2026-08-09 03:00:41.007', NULL, '4636b86d56078ac6cc815a3b5d5f89aa', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XSMQCBRVZWWMENNS3KKFM', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C3: CLI verbs for the Clide strip — D-6 parity', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:45.371', '2026-08-09 03:00:45.371', NULL, '2f913f94f7bd88794dd90d757cf53490', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XTDQ9HXXA1PA6KRG5FFHM', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C5: Clide i18n catalog — chrome strings for en_us and nl_nl', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:51.770', '2026-08-09 03:00:51.770', NULL, 'a5466527a9952ace63b421258b6f9334', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XRM7XGNMSGTRB1CNZAA8R', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C4: Clide settings category + enable/disable kill switch', 'The off switch. **Blocks Epic D (T-519)** — deliberately, so the thing that spends
subscription quota cannot land before the thing that stops it.

## Why this is a blocker and not a nicety

D-107 commits to the companion being **"user-disableable to zero"**, and is explicit that
this is part of the decision rather than tuning, because the companion runs on subscription
auth and draws from the same pool that already rate-limits the primary session. Without this
ticket there is a window in which a second model session runs with no way to stop it short of
quitting the app.

**Disable must tear the process down, not just hide the UI.** A hidden face that is still
spawning a `claude` process and consuming quota is precisely the failure this exists to
prevent. Epic D''s session lifecycle honours this key; wire it as a real teardown.

## Deliberately independent of the rest of Epic C

This ticket has **no blockers** and must stay that way. A settings key plus a
`SettingsCategoryContribution` is self-contained and does not need the strip, the collapse
affordance, the CLI verbs or the i18n catalog to exist first. If it were sequenced behind
C1, Epic D would be queued behind the entire surface for no reason.

## Scope

- Settings category for Clide with, at minimum:
  - **enable/disable** — the kill switch. Default off is the safer choice given it spends
    quota; confirm the default with the user rather than assuming.
  - **comment frequency** — how eagerly it speaks (D-107: notable events only, but the
    threshold is tunable).
  - **suspend when minimised** — the power-ladder `night` rung (T-517 owns the lifecycle
    capability itself; this is just the preference).
- Registration template: `lib/builtin/output/src/extension.dart` — tab + status toggle +
  command, with `dependsOn: [''builtin.default-layout'']`.
- Contribution types: `SettingsCategoryContribution` / `SettingsControlContribution`
  (`lib/extension/src/contribution.dart`).
- Read through `ClideSettings` (D-101), never a bare settings lookup.

## Done when

- The key exists, persists, and is readable without the strip being mounted.
- A test asserts that disabling produces a state in which no companion session may run —
  written so it still passes before Epic D exists, and becomes meaningful once it does.
- Labels are catalog strings (D-21/D-102), not literals; coordinate the namespace with C5.', 'backlog', 'high', NULL, NULL, NULL, '2026-08-09 03:00:37.055', '2026-08-09 03:01:37.531', NULL, '4d98893718b85ebe601c8648198834d4', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Z35AYAJQZ4MZMT25DPWC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic D: Clide companion session + observed/direct protocol', 'Stand up the Haiku companion session, feed it a filtered digest of the main conversation,
and give it a protocol that distinguishes *watching* from *being spoken to*. Pure plumbing —
**can start immediately, in parallel with Epic A**.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams** — publish the reply/state stream that Epic B (face reactions to
   companion errors) and Epic E (answer rendering) consume, and coordinate with B on reading
   `StreamJsonSession` so the two epics don''t each grow their own subscription layer.

## Spawning — no new process plumbing needed

`ClaudeSessionOrchestrator.spawn(SpawnSpec(..., visible: false))`
(`lib/builtin/claude/src/session_orchestrator.dart:209`) already yields a live stream-json
session with **no pane**, idempotent per `(id, cwd)`, serialized against races.
`visible: false` is the intended primitive for a headless agent. Precedent for spawning
outside a pane: `_forkMember` at `claude_meta_sidebar.dart:256-274`.

- Spawn id `clide.companion`, `--model haiku`.
- `--no-session-persistence` so it never pollutes `~/.claude/projects` (precedent:
  `claude_config.dart:576`).
- **There is no Anthropic API client in the repo** — grep for `anthropic` / `ANTHROPIC_API_KEY`
  across `lib/` returns only comments. Everything goes through the `claude` CLI, so this runs
  on subscription auth exactly like the main session.

## Digest — what Clide sees

Filter `session.items` to **`UserMessage` + `AssistantTextMessage` only**. Drop
`AssistantToolUse`, `ToolResultMessage`, thinking, and the clide-injected image/drawing/icon
cards. Item model: `transcript_reader.dart:41-267`.

**Known limitation, accepted for v1:** with tool calls excluded, *"what did that tool call
do?"* is unanswerable. Asking what Claude **said** works; asking what Claude **did** does
not. Revisit if it bites in practice.

## Protocol — observed vs direct

```
[observed] jeroen: <prompt text>
[observed] claude: <assistant prose>
[direct]   jeroen: <question typed into Clide''s own input>
```

The system prompt states the split explicitly: `observed` lines are a conversation between
the user and Claude that Clide is watching — remark rarely and briefly; `direct` lines are
addressed to Clide — always answer. Reply in the active locale (`app.locale`, carried into
the prompt). One or two sentences.

Trigger for unprompted remarks: **notable events only** — turn finished, error, long run
crossing a threshold, commit landed. Never per-token.

## Cost guards — the constraints that actually shape this

- **Restart the session at ~50 comments.** Cost grows quadratically (history re-sends each
  turn). A rolling window is the wrong fix: evicting the oldest event changes the cache
  prefix, so every turn would pay full price. Grow-then-restart preserves cache hits within
  an epoch and bounds growth.
- **Haiku 4.5''s prompt-cache minimum is 4096 tokens — the highest of any current model.**
  Below it `cache_control` is silently ignored (`cache_creation_input_tokens: 0`, no error).
  A lean sidekick prompt is uncached for roughly its first 20 comments.
- **Do not set `effort`** — it errors on Haiku 4.5.
- Leave thinking off (latency and tokens for a one-line quip), and cap `max_tokens` ~100 so
  a bad turn can''t produce an essay.
- Budget: ~$0.002/comment at 50 comments. But under subscription auth the real cost is
  **quota**, drawn from the same pool already rate-limiting the main session — keep the
  trigger stingy.

## Lifecycle

Respect the settings kill switch (Epic C) and the power ladder (Epic B): a disabled or
dormant Clide should not hold a live process open. Tear the session down, don''t just stop
reading it.

BLOCKED BY T-527 (kill switch) — added deliberately 2026-08-09. D-107 commits the companion to being user-disableable to zero, and this epic is the thing that spends subscription quota from the same pool that already rate-limits the primary session. Landing it before an off switch exists would leave a window with no way to stop it short of quitting the app. Note the requirement is a real teardown of the claude process, not just hiding the UI — a hidden face still spawning a process and burning quota is exactly the failure the blocker exists to prevent.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:05.674', '2026-08-09 03:01:44.001', NULL, '53eb586003d396259ba92e178e161cc3', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73YPCJVWBXD9YF1JKZEK2W', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic C: Clide surface & chrome — slot, settings, i18n, CLI parity', 'Give Clide a real home in the shell, with the settings, i18n and CLI parity that make it a
first-class surface rather than a bolted-on widget.

**Blocked by T-514** — the spike decides whether this is a new slot or a region inside the
context panel, and that changes most of the file list below.

## Epic''s own first job

1. **Break this epic down** once T-514 lands and the shape is known.
2. **Own the seam with Epic E** — E mounts its input box inside this surface. Settle the
   surface''s internal composition (face region / bubble region / input region) here so E
   only fills a slot rather than renegotiating layout.

## If the spike picks A (own right-edge rail)

| File | Change |
|---|---|
| `lib/kernel/src/panels/slot_id.dart:20-33` | add the slot id (`SlotId` is a wrapped String — new ids are cheap) |
| `lib/kernel/src/panels/layout_preset.dart:13-23` | `LayoutSlot(position: right, defaultSize/minSize/maxSize)` |
| `lib/src/shell/layout.dart:51-59` | render column + `ClideSpine` when collapsed + `DragResizeHandle` |
| `lib/kernel/src/panels/drag_resize.dart:178` **and** `:199` | **The sign flip is hard-coded to `Slots.contextPanel` at both sites.** A new right-side slot must be added to both or the drag runs backwards. This is the single easiest thing to get wrong in this epic. |
| `lib/builtin/default_layout/src/extension.dart:170-234` | persistence keys (`_restoreLayout` / `_persistLayout`) |
| `lib/main.dart:599-632` + `lib/test_app.dart:288-294` | register the extension |

A real slot buys `isVisible` / `isCollapsed` / `sizeOf`, restart persistence,
`clide panel resize <slot>` (`lib/src/daemon/panel_commands.dart:66`) and `clide pane list`
reporting — i.e. **D-6 parity for free**. That is the main argument for a slot over a bare
widget.

## If the spike picks B (strip in the context panel)

Single insertion point: `_ContextSlot` at `lib/src/shell/slot_host.dart:349-362`, currently
`Container(... child: active.build(context))`, becomes a `Column`. The slot/persistence/
drag-resize rows above all drop away. Structural template for a split inside a column:
`_WorkspaceSlot` at `slot_host.dart:147-207`.

## Also in scope regardless of shape

- **Settings**: `SettingsCategoryContribution` + controls — enable/disable Clide entirely,
  comment frequency, suspend-when-minimised. Registration template:
  `lib/builtin/output/src/extension.dart` (tab + status toggle + command, with
  `dependsOn: [''builtin.default-layout'']` so the slot exists first).
- **i18n**: chrome strings via `ClideSettings.i18n.string(...)` into
  `assets/i18n/{en_us,nl_nl}/clide.json` (D-21/D-102). Note Clide''s *replies* are model
  output, not catalog strings — the locale is carried into the prompt by Epic D, not
  translated here. Design for ~30% length growth on any fixed-width chrome.
- **Contribution + registration** per `lib/extension/src/contribution.dart`; host dispatch
  is `extensions_manager.dart:237-260`.

## Testing

Layout must be asserted **at ultrawide**, driving `tester.view.physicalSize` — a wide
`SizedBox` under the default 800px test surface is clamped to 800 and does not actually test
wide. Pattern: `test/app_statusbar_test.dart` (`pumpAt`). Related audit: T-241.

Likely to need updating: `test/app_test.dart`, `test/app_collapse_toggle_test.dart`,
`test/builtin/default_layout/widget_test.dart`, and the panels tests under
`test/kernel/src/panels/`.

## Spike resolved (T-514, 2026-08-09) — take the B route

Placement **B** was chosen: a horizontal strip sharing the bottom of the context column.

**The "If the spike picks A" section above is dead — ignore it.** No `slot_id.dart`, no
`layout_preset.dart`, no `layout.dart` column, and in particular **no `drag_resize.dart`
sign-flip work**; that trap does not apply on this route.

Live scope is the B section: `_ContextSlot` at `lib/src/shell/slot_host.dart:349-362`
becomes a `Column`. Structural template for a split inside a column is `_WorkspaceSlot`
(`slot_host.dart:147-207`).

**What B costs this epic, and it is the main work here:** the strip is not a slot, so none of
`isVisible` / `isCollapsed` / `sizeOf` / restart persistence / `clide panel resize` /
`clide pane list` come for free. To keep **D-6 parity** this epic must hand-roll:

- a collapse/expand affordance for the strip,
- a persisted height and collapsed-state (alongside the dock''s keys in
  `default_layout/src/extension.dart:170-234`),
- and CLI verbs so every UI action has a command equivalent.

Budget for that explicitly — it was the strongest argument for A and is now this epic''s
problem. Decide early whether the strip''s height is a first-class arrangement value or
extension-local settings state; the former is more work but keeps it consistent with every
other resizable region.

Also in scope from the spike: the strip **grows to a capped height (~40% of the column)
while Clide is answering and collapses back when idle**. That interacts with the persisted
height — the user''s chosen height is the resting height, not a ceiling.

## Breakdown (2026-08-09)

| | Ticket | Blocked by |
|---|---|---|
| C1 | T-526 — strip surface: `_ContextSlot` becomes a `Column`, responsive 220–1000px | T-525 (A5) |
| C2 | T-528 — collapse affordance, persisted height, grow-to-cap while answering | C1 |
| C3 | T-529 — CLI verbs, D-6 parity | C1 |
| C4 | **T-527 — settings category + kill switch** | **nothing, deliberately** |
| C5 | T-530 — i18n catalog (en_us, nl_nl) | C1 |

## Two sequencing decisions

**C1 waits for A5 (T-525).** The strip needs a real face to mount. Building it against a
placeholder would mean redoing the integration, and — more importantly — A5 is where the face
is first validated at real dimensions. The chosen placement is a ~110px-tall strip; so far the
face has only been seen in wireframes with hand-placed glyphs and in painter tests at 240×160.
If it does not read at strip height, that is a design problem worth finding **before** a slot,
settings, CLI verbs and an i18n catalog are built around it.

**C4 has no blockers, and must keep none.** It blocks Epic D (T-519), so sequencing it behind
C1 would queue the entire companion session behind the entire surface for no reason. A
settings key plus a contribution is self-contained.

## Why C4 blocks Epic D

D-107 commits the companion to being "user-disableable to zero", and states that this is part
of the decision rather than tuning, because it spends subscription quota from the same pool
that already rate-limits the primary session. Making it a graph edge rather than a note in a
description means it cannot be forgotten at the moment it matters. Requirement is a real
process teardown, not hiding the UI.

## The epic''s other job: the seam with Epic E

E (T-520) mounts its input box and answer surface inside C1''s strip. C1 therefore owns the
**internal composition** — face region, bubble region, input region — and settles it once, so
E fills a slot rather than renegotiating layout. C2 owns height behaviour including the
grow-to-cap-while-answering that E''s answers trigger; E should not implement its own resizing.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:02.404', '2026-08-09 03:02:02.287', NULL, '7dc2c6b50c46047a283ea80afc1b976e', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.

From T-524: (1) The widget owns the ticker, advances the RainField, and updates the clock ValueNotifier<Duration>; the painter only reads. Keeping simulation out of paint() is what makes each frame a pure function of (clock, field, spec, tokens). (2) ClideFacePainter takes a nullable lean that falls back to gaze.leanPx — pass an interpolated value to animate the transition, which is the ''animated rather than snapped'' half of D-107. (3) hasInk-style alpha counting does NOT discriminate for this painter: the vignette is full-bleed so ~37300/38400 pixels have non-zero alpha. Goldens and any assertion finer than ''something was drawn'' must compare raw pixel bytes. (4) The idle clock label uses DateTime.now() — it is genuinely time-of-day, not animation state — so goldens covering idle must pin or avoid it.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 03:03:43.677', NULL, '8985bf738dd3e1663c3857f204a7a65a', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.

From T-524: (1) The widget owns the ticker, advances the RainField, and updates the clock ValueNotifier<Duration>; the painter only reads. Keeping simulation out of paint() is what makes each frame a pure function of (clock, field, spec, tokens). (2) ClideFacePainter takes a nullable lean that falls back to gaze.leanPx — pass an interpolated value to animate the transition, which is the ''animated rather than snapped'' half of D-107. (3) hasInk-style alpha counting does NOT discriminate for this painter: the vignette is full-bleed so ~37300/38400 pixels have non-zero alpha. Goldens and any assertion finer than ''something was drawn'' must compare raw pixel bytes. (4) The idle clock label uses DateTime.now() — it is genuinely time-of-day, not animation state — so goldens covering idle must pin or avoid it.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 03:04:06.989', NULL, 'db5ba36df48eb471a4100f8a3122afe7', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY94EJJA4BFKCM729AVDY4V8', 'bug', '06FY73XR4NJEPDARY06397RVVC', 'Orbit arc does not read at strip aspect ratio', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:29:49.715', '2026-08-09 03:29:49.715', NULL, 'fb051928039553ca99636d56a247b5ef', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY94EJJA4BFKCM729AVDY4V8', 'bug', '06FY73XR4NJEPDARY06397RVVC', 'Orbit arc does not read at strip aspect ratio', 'Found on first visual inspection of the T-525 goldens
(`test/goldens/goldens/linux/clide_face_states.png`, the `effort` scenario).

## Symptom

The orbit arc — one of the two honest wait cues — is drawn with `drawArc` on a rect inset
from the widget bounds (`face_painter.dart`, `_paintOrbit`). DeskLock draws it on an 800×800
**round** panel, where a bezel sweep reads exactly as intended. The chosen placement is a
short wide strip: at 320×120 the inset rect is so eccentric that the arc renders as a stray
curve across the lower-left corner rather than as anything orbiting the face. At 1000×110 it
is worse.

It does not look like a wait cue. It looks like a rendering bug.

## Constraint on the fix

DeskLock''s rule is adopted verbatim in D-107 and must hold: **a wait always shows an
alive-and-working cue, and never a fake progress bar.** So the arc cannot simply be deleted —
`effort` would lose half its wait signalling, leaving only the `[ Ns ]` counter and max rain.
And whatever replaces it must not imply completion, because nothing here knows how long the
turn will take.

## Options

- **Bottom-edge sweep** — a short bright segment travelling along the strip''s bottom edge.
  Reads as activity at any aspect ratio, and is not a progress bar because it loops rather
  than filling.
- **Circular orbit around the face only** — keep a true circle, sized to the face group rather
  than the widget bounds, so eccentricity never enters into it.
- **Drop the arc, strengthen the counter** — rely on `[ Ns ]` plus 40-stream rain. Simplest,
  but thins the cue to one channel.

The second is closest to DeskLock''s intent; the first probably reads best in a strip. Worth a
quick visual comparison before choosing, since this is the state the user sees during every
long turn.

## Notes

- Purely visual; no test currently fails. `effort` still draws, and the wait cue is still
  present — it is the *form* that is wrong at this aspect ratio.
- Whatever lands should be goldened at 220px, 500px and 1000px wide, the range already
  covered by `clide_face_widths.png`.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:29:49.715', '2026-08-09 03:30:10.778', NULL, 'c1d3b9dceb8dacd9e877f22e8b7c38f8', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.

From T-524: (1) The widget owns the ticker, advances the RainField, and updates the clock ValueNotifier<Duration>; the painter only reads. Keeping simulation out of paint() is what makes each frame a pure function of (clock, field, spec, tokens). (2) ClideFacePainter takes a nullable lean that falls back to gaze.leanPx — pass an interpolated value to animate the transition, which is the ''animated rather than snapped'' half of D-107. (3) hasInk-style alpha counting does NOT discriminate for this painter: the vignette is full-bleed so ~37300/38400 pixels have non-zero alpha. Goldens and any assertion finer than ''something was drawn'' must compare raw pixel bytes. (4) The idle clock label uses DateTime.now() — it is genuinely time-of-day, not animation state — so goldens covering idle must pin or avoid it.

## DONE (2026-08-09) — Epic A complete

- `lib/builtin/clide_companion/src/clide_face.dart` — `ClideFace`.
- `test/builtin/clide_companion/clide_face_test.dart` — 19 tests.
- `test/goldens/clide_face_goldens_test.dart` + three golden images (states, gaze/lean,
  width range).
- `make analyze`, `make format`, `make test` clean. Parallel pool 4072 → 4094.

Public surface is exactly the T-521 contract — `state`, `gaze`, `busyFor` — plus two
`@visibleForTesting` seams (`debugFreezeAt`, `debugClockLabel`) that exist because a golden
of a live animation is flaky by construction.

## The goldens found two real defects

**1. A pinned frame had no rain at all.** With the ticker stopped, `field.tick()` never runs,
so the field stayed empty and every static frame lost the density signal — the single thing
the rain exists to convey. The same applied to **reduced motion**, which is the more serious
case: a reduced-motion user would have seen a bare face with no indication the session was
busy. Fixed by priming the field to a steady state whenever the ticker will not be running,
and re-priming on state change since density is per-state. A reduced-motion user now sees the
density; they just do not see it move.

**2. The orbit arc does not read at strip aspect ratio** — filed as **T-531**. It is drawn on
a rect inset from the widget bounds, which works on DeskLock''s 800×800 round panel and renders
as a stray curve across the corner on a 320×120 strip. Left as-is rather than redesigned here:
the replacement is a design call (D-107 forbids anything that reads as a fake progress bar),
and it deserves a visual comparison rather than my picking one unilaterally.

## A test-harness trap worth knowing

The a11y test "the label follows a state change" failed, and it looked like a widget bug —
a stale screen-reader label would be a genuine defect, since Epic B changes `state` on a
mounted face constantly.

It was the **shared `harness()`**. It wraps its child in
`Overlay(initialEntries: [OverlayEntry(builder: (_) => child)])`, and `initialEntries` is
consumed only on the Overlay''s *first* build. On later pumps the `OverlayState` is preserved
and keeps an entry closing over the **original** child, so `pumpWidget` with a new prop never
reaches the widget under test. Any test that changes a prop and re-pumps through `harness()`
is silently asserting against a stale tree.

This test builds the same services tree without the Overlay, which nothing here needed. The
widget was correct all along, and there is now a dedicated test proving the label follows a
live state change.

## Power ladder — the widget half

`_syncTicker` runs only when motion is allowed, the frame is not pinned, **and there is
something to animate**. That last clause is D-107''s contract in code: an `error` face over a
drained field has no moving parts, so the loop parks itself. Two tests hold both directions —
`error` stops ticking after the field drains, and `effort` keeps ticking rather than being
parked while still working.

## Notes for Epic B (T-517)

- The contract held: `state`, `gaze`, `busyFor`, nothing added.
- `busyFor` is yours. The face never times turns.
- Changing `state` on a mounted face works and is tested; no remount needed.
- Under reduced motion the face still shows density, so mapping load to `rainStreams` remains
  meaningful even with animation off.', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 03:30:36.942', NULL, 'fd4436fbfc7bacd5c9f28840a273f7b3', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W71Q93S37DZF4ZJJ9QWJW', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A5: ClideFace widget — ticker, reduced-motion gate, RepaintBoundary', 'The widget shell: owns the single `Ticker`, gates on reduced motion, isolates repaints, and
exposes the T-521 props. After this, Epic A is done and Epic B has something to drive.

Target: `lib/builtin/clide_companion/src/clide_face.dart`

Blocked by T-524.

## Public surface — exactly the T-521 contract

```dart
ClideFace({
  Key? key,
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,
})
```

Nothing else. If Epic B needs something more, that is a contract change negotiated on T-521,
not a prop added quietly here.

## One ticker

`createTicker` via `SingleTickerProviderStateMixin`, closest existing model is
`clide_marquee.dart:30` (raw `Ticker`, dt computed from the elapsed `Duration`). The ticker
drives a `ValueNotifier<int>`/`ChangeNotifier` handed to the painter as `repaint:` — the
widget itself does **not** `setState` per frame.

**No `Timer.periodic`.** The repo''s animated widgets are all controller/ticker-driven
specifically so tests can advance them with bounded pumps; timers break that.

## Reduced motion is a hard gate

```dart
final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
```

Checked in `didChangeDependencies`, ticker stopped when true, static frame painted instead.
Precedent: `clide_marquee.dart:54`, `clide_spinner.dart:43`, `running_indicator.dart:71`.

**This is not a courtesy.** `test/widgets/src/clide_marquee_test.dart:50` asserts
`pumpAndSettle()` completes under `disableAnimations: true`; a perpetual ticker that ignores
the flag wedges the whole suite for ~10 minutes. Write the equivalent assertion here.

## `RepaintBoundary`

Wrap the `CustomPaint`. This is the **second** use in the repo — the only other is the
terminal render object (`lib/src/terminal/src/ui/render.dart:174`). Without it, a repaint of
an animating layer can dirty ancestors, which is exactly what you do not want 30 times a
second inside a panel that also hosts a detail view.

## Sizing

`LayoutBuilder` → the field''s column/row count derives from the box and the glyph advance
width. Must survive the context panel''s **220–1000px** range (`layout_preset.dart:19`) and a
short strip height. Degrade sensibly when very small rather than overflowing.

## Done when

- Renders every `FaceState` without error at both 220px and 1000px wide.
- `pumpAndSettle()` completes under `disableAnimations: true` — the wedge guard.
- Ticker disposes: pump the widget, then pump an empty tree, and assert no pending ticker
  (the teardown pattern in `running_indicator_test.dart:29-45` and `clide_marquee_test.dart`).
- Alchemist goldens at a **pinned ticker value** per state — a live animation is a bad golden,
  so expose a test-only seam to hold the frame rather than sleeping.
- Widget-level a11y: one stable `Semantics` label describing state in words
  (D-20), with the animated glyphs under `ExcludeSemantics` — the
  `running_indicator.dart` pattern. A screen reader should hear "Clide: thinking", never a
  stream of box-drawing characters.

From T-524: (1) The widget owns the ticker, advances the RainField, and updates the clock ValueNotifier<Duration>; the painter only reads. Keeping simulation out of paint() is what makes each frame a pure function of (clock, field, spec, tokens). (2) ClideFacePainter takes a nullable lean that falls back to gaze.leanPx — pass an interpolated value to animate the transition, which is the ''animated rather than snapped'' half of D-107. (3) hasInk-style alpha counting does NOT discriminate for this painter: the vignette is full-bleed so ~37300/38400 pixels have non-zero alpha. Goldens and any assertion finer than ''something was drawn'' must compare raw pixel bytes. (4) The idle clock label uses DateTime.now() — it is genuinely time-of-day, not animation state — so goldens covering idle must pin or avoid it.

## DONE (2026-08-09) — Epic A complete

- `lib/builtin/clide_companion/src/clide_face.dart` — `ClideFace`.
- `test/builtin/clide_companion/clide_face_test.dart` — 19 tests.
- `test/goldens/clide_face_goldens_test.dart` + three golden images (states, gaze/lean,
  width range).
- `make analyze`, `make format`, `make test` clean. Parallel pool 4072 → 4094.

Public surface is exactly the T-521 contract — `state`, `gaze`, `busyFor` — plus two
`@visibleForTesting` seams (`debugFreezeAt`, `debugClockLabel`) that exist because a golden
of a live animation is flaky by construction.

## The goldens found two real defects

**1. A pinned frame had no rain at all.** With the ticker stopped, `field.tick()` never runs,
so the field stayed empty and every static frame lost the density signal — the single thing
the rain exists to convey. The same applied to **reduced motion**, which is the more serious
case: a reduced-motion user would have seen a bare face with no indication the session was
busy. Fixed by priming the field to a steady state whenever the ticker will not be running,
and re-priming on state change since density is per-state. A reduced-motion user now sees the
density; they just do not see it move.

**2. The orbit arc does not read at strip aspect ratio** — filed as **T-531**. It is drawn on
a rect inset from the widget bounds, which works on DeskLock''s 800×800 round panel and renders
as a stray curve across the corner on a 320×120 strip. Left as-is rather than redesigned here:
the replacement is a design call (D-107 forbids anything that reads as a fake progress bar),
and it deserves a visual comparison rather than my picking one unilaterally.

## A test-harness trap worth knowing

The a11y test "the label follows a state change" failed, and it looked like a widget bug —
a stale screen-reader label would be a genuine defect, since Epic B changes `state` on a
mounted face constantly.

It was the **shared `harness()`**. It wraps its child in
`Overlay(initialEntries: [OverlayEntry(builder: (_) => child)])`, and `initialEntries` is
consumed only on the Overlay''s *first* build. On later pumps the `OverlayState` is preserved
and keeps an entry closing over the **original** child, so `pumpWidget` with a new prop never
reaches the widget under test. Any test that changes a prop and re-pumps through `harness()`
is silently asserting against a stale tree.

This test builds the same services tree without the Overlay, which nothing here needed. The
widget was correct all along, and there is now a dedicated test proving the label follows a
live state change.

## Power ladder — the widget half

`_syncTicker` runs only when motion is allowed, the frame is not pinned, **and there is
something to animate**. That last clause is D-107''s contract in code: an `error` face over a
drained field has no moving parts, so the loop parks itself. Two tests hold both directions —
`error` stops ticking after the field drains, and `effort` keeps ticking rather than being
parked while still working.

## Notes for Epic B (T-517)

- The contract held: `state`, `gaze`, `busyFor`, nothing added.
- `busyFor` is yours. The face never times turns.
- Changing `state` on a mounted face works and is tested; no remount needed.
- Under reduced motion the face still shows density, so mapping load to `rainStreams` remains
  meaningful even with animation off.', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 00:34:02.298', '2026-08-09 03:30:41.037', NULL, 'b8e57bd73eddcf69ddd56befc18d1397', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XR4APSKWH94DNG00B51J4', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C1: Clide strip surface — _ContextSlot becomes a Column, responsive 220-1000px', NULL, 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:32.981', '2026-08-09 08:13:30.548', NULL, '8717b6e3d51e2073dead8533f9057d15', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XR4APSKWH94DNG00B51J4', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C1: Clide strip surface — _ContextSlot becomes a Column, responsive 220-1000px', NULL, 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:32.981', '2026-08-09 08:14:06.074', NULL, '3cf900209d70fc879502190cb482e191', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XR4APSKWH94DNG00B51J4', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C1: Clide strip surface — _ContextSlot becomes a Column, responsive 220-1000px', 'Done (2026-08-09).

**Shipped.** `ClideStrip` (112px, fixed) at the bottom of the context column; `_ContextSlot` is now `Column(Expanded(view), ClideStrip())`. Face full-bleed behind, bubble beside it, dropped below 266px.

**Contract amendments made while wiring it up** — the face was built and goldened at 320x120, and almost every one of these is the same failure: a constant tuned for a square box behaving differently at 5:1.

- `ClideFace.faceAlignX` (new prop, amends T-521). Face sits left; **rain still spans the full width**. Density reads as how many columns are lit; penning it into a 116px gutter would cut ~78 columns to ~9 and undo the reason a strip beat a rail (T-514).
- `clockLabel` moved out of the painter — `DateTime.now()` inside `paint` was neither pure nor goldenable.
- Mouth, thought dots and clock now hang off the **eye group''s centre**, not off the box. Aligning each independently is identical while centred and puts a one-char mouth under the *left eye* once the face moves left.
- Clock joined the elapsed counter in a shared bottom-edge cue slot. Stacked under the mouth it fell off a 112px strip.
- **Vignette anchored on the face, radius off the height.** It was centred on the box at `max(w,h)*0.54`, so on a strip it became a full-width wash that erased the rain — the signal it exists to protect.
- **Rain spawn stagger scaled to the grid** (`rows*0.6+1`, was a flat 14 rows). A stream waiting above the top is a live stream you cannot see; at the strip''s ~8 rows that left barely a third of effort''s forty streams on screen.

**Orbit arc dropped, not fixed — closes T-531.** It encoded activity, and activity is the rain''s job. Two signals for one fact, one of which read as a pink smear at strip proportions. `FaceSpec.orbit` removed outright rather than defaulted off.

**Tests** 25 in `clide_strip_test.dart`, incl. the real snap points (220/420/1000 from `layout_preset.dart`), text zoom across TextZoom.minScale..maxScale (0.6-2.0) with a bubble-fits assertion (a Stack clips silently, so no-exception proves nothing), reduced motion settling, and the 266px bubble flip pinned exactly. Two golden sets. Full suite 8 + 4121 + 50 green.

**Trap re-hit:** the default 800px test surface silently clamps a wider SizedBox, so the 1000px cases were passing at 800 until `surfaceAt()` drove `tester.view.physicalSize` (T-239/T-241).', 'in_progress', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:32.981', '2026-08-09 08:55:38.949', NULL, 'f6eae3c414f3cc923dd150e8bbc39d9e', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY94EJJA4BFKCM729AVDY4V8', 'bug', '06FY73XR4NJEPDARY06397RVVC', 'Orbit arc does not read at strip aspect ratio', 'Found on first visual inspection of the T-525 goldens
(`test/goldens/goldens/linux/clide_face_states.png`, the `effort` scenario).

## Symptom

The orbit arc — one of the two honest wait cues — is drawn with `drawArc` on a rect inset
from the widget bounds (`face_painter.dart`, `_paintOrbit`). DeskLock draws it on an 800×800
**round** panel, where a bezel sweep reads exactly as intended. The chosen placement is a
short wide strip: at 320×120 the inset rect is so eccentric that the arc renders as a stray
curve across the lower-left corner rather than as anything orbiting the face. At 1000×110 it
is worse.

It does not look like a wait cue. It looks like a rendering bug.

## Constraint on the fix

DeskLock''s rule is adopted verbatim in D-107 and must hold: **a wait always shows an
alive-and-working cue, and never a fake progress bar.** So the arc cannot simply be deleted —
`effort` would lose half its wait signalling, leaving only the `[ Ns ]` counter and max rain.
And whatever replaces it must not imply completion, because nothing here knows how long the
turn will take.

## Options

- **Bottom-edge sweep** — a short bright segment travelling along the strip''s bottom edge.
  Reads as activity at any aspect ratio, and is not a progress bar because it loops rather
  than filling.
- **Circular orbit around the face only** — keep a true circle, sized to the face group rather
  than the widget bounds, so eccentricity never enters into it.
- **Drop the arc, strengthen the counter** — rely on `[ Ns ]` plus 40-stream rain. Simplest,
  but thins the cue to one channel.

The second is closest to DeskLock''s intent; the first probably reads best in a strip. Worth a
quick visual comparison before choosing, since this is the state the user sees during every
long turn.

## Notes

- Purely visual; no test currently fails. `effort` still draws, and the wait cue is still
  present — it is the *form* that is wrong at this aspect ratio.
- Whatever lands should be goldened at 220px, 500px and 1000px wide, the range already
  covered by `clide_face_widths.png`.

Resolved by removal (2026-08-09, in T-526).

Not fixed — **deleted**. The arc encodes ''something is happening''; the rain already encodes exactly that, with more resolution (density is graded, the arc is binary). Two renderings of one fact, and the redundant one was the one that broke at strip proportions.

`FaceSpec.orbit`, `_paintOrbit` and `_orbitPeriod` are gone rather than defaulted off, so there is no dormant flag to re-enable by accident. The honest-wait requirement is still met by dense rain + jitter + the `[ Ns ]` counter — the counter stays because it says something the rain cannot: how long.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:29:49.715', '2026-08-09 08:56:10.296', NULL, '7a766a093f8c19c46e7de6b2063b02e7', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XR4APSKWH94DNG00B51J4', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C1: Clide strip surface — _ContextSlot becomes a Column, responsive 220-1000px', 'Done (2026-08-09).

**Shipped.** `ClideStrip` (112px, fixed) at the bottom of the context column; `_ContextSlot` is now `Column(Expanded(view), ClideStrip())`. Face full-bleed behind, bubble beside it, dropped below 266px.

**Contract amendments made while wiring it up** — the face was built and goldened at 320x120, and almost every one of these is the same failure: a constant tuned for a square box behaving differently at 5:1.

- `ClideFace.faceAlignX` (new prop, amends T-521). Face sits left; **rain still spans the full width**. Density reads as how many columns are lit; penning it into a 116px gutter would cut ~78 columns to ~9 and undo the reason a strip beat a rail (T-514).
- `clockLabel` moved out of the painter — `DateTime.now()` inside `paint` was neither pure nor goldenable.
- Mouth, thought dots and clock now hang off the **eye group''s centre**, not off the box. Aligning each independently is identical while centred and puts a one-char mouth under the *left eye* once the face moves left.
- Clock joined the elapsed counter in a shared bottom-edge cue slot. Stacked under the mouth it fell off a 112px strip.
- **Vignette anchored on the face, radius off the height.** It was centred on the box at `max(w,h)*0.54`, so on a strip it became a full-width wash that erased the rain — the signal it exists to protect.
- **Rain spawn stagger scaled to the grid** (`rows*0.6+1`, was a flat 14 rows). A stream waiting above the top is a live stream you cannot see; at the strip''s ~8 rows that left barely a third of effort''s forty streams on screen.

**Orbit arc dropped, not fixed — closes T-531.** It encoded activity, and activity is the rain''s job. Two signals for one fact, one of which read as a pink smear at strip proportions. `FaceSpec.orbit` removed outright rather than defaulted off.

**Tests** 25 in `clide_strip_test.dart`, incl. the real snap points (220/420/1000 from `layout_preset.dart`), text zoom across TextZoom.minScale..maxScale (0.6-2.0) with a bubble-fits assertion (a Stack clips silently, so no-exception proves nothing), reduced motion settling, and the 266px bubble flip pinned exactly. Two golden sets. Full suite 8 + 4121 + 50 green.

**Trap re-hit:** the default 800px test surface silently clamps a wider SizedBox, so the 1000px cases were passing at 800 until `surfaceAt()` drove `tester.view.physicalSize` (T-239/T-241).', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:32.981', '2026-08-09 08:56:14.044', NULL, '3e228773d454184557e10cfe4560814b', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY94EJJA4BFKCM729AVDY4V8', 'bug', '06FY73XR4NJEPDARY06397RVVC', 'Orbit arc does not read at strip aspect ratio', 'Found on first visual inspection of the T-525 goldens
(`test/goldens/goldens/linux/clide_face_states.png`, the `effort` scenario).

## Symptom

The orbit arc — one of the two honest wait cues — is drawn with `drawArc` on a rect inset
from the widget bounds (`face_painter.dart`, `_paintOrbit`). DeskLock draws it on an 800×800
**round** panel, where a bezel sweep reads exactly as intended. The chosen placement is a
short wide strip: at 320×120 the inset rect is so eccentric that the arc renders as a stray
curve across the lower-left corner rather than as anything orbiting the face. At 1000×110 it
is worse.

It does not look like a wait cue. It looks like a rendering bug.

## Constraint on the fix

DeskLock''s rule is adopted verbatim in D-107 and must hold: **a wait always shows an
alive-and-working cue, and never a fake progress bar.** So the arc cannot simply be deleted —
`effort` would lose half its wait signalling, leaving only the `[ Ns ]` counter and max rain.
And whatever replaces it must not imply completion, because nothing here knows how long the
turn will take.

## Options

- **Bottom-edge sweep** — a short bright segment travelling along the strip''s bottom edge.
  Reads as activity at any aspect ratio, and is not a progress bar because it loops rather
  than filling.
- **Circular orbit around the face only** — keep a true circle, sized to the face group rather
  than the widget bounds, so eccentricity never enters into it.
- **Drop the arc, strengthen the counter** — rely on `[ Ns ]` plus 40-stream rain. Simplest,
  but thins the cue to one channel.

The second is closest to DeskLock''s intent; the first probably reads best in a strip. Worth a
quick visual comparison before choosing, since this is the state the user sees during every
long turn.

## Notes

- Purely visual; no test currently fails. `effort` still draws, and the wait cue is still
  present — it is the *form* that is wrong at this aspect ratio.
- Whatever lands should be goldened at 220px, 500px and 1000px wide, the range already
  covered by `clide_face_widths.png`.

Resolved by removal (2026-08-09, in T-526).

Not fixed — **deleted**. The arc encodes ''something is happening''; the rain already encodes exactly that, with more resolution (density is graded, the arc is binary). Two renderings of one fact, and the redundant one was the one that broke at strip proportions.

`FaceSpec.orbit`, `_paintOrbit` and `_orbitPeriod` are gone rather than defaulted off, so there is no dormant flag to re-enable by accident. The honest-wait requirement is still met by dense rain + jitter + the `[ Ns ]` counter — the counter stays because it says something the rain cannot: how long.', 'done', 'medium', NULL, NULL, NULL, '2026-08-09 03:29:49.715', '2026-08-09 08:56:14.051', NULL, '6b5882b4bcf5ddca440c0402eb0700b1', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBN0EJ3B59YWV2Z9S54PRGG', 'task', '06FY73Z35AYAJQZ4MZMT25DPWC', 'Clide prompt templates — system prompt, observed/direct framing, lifecycle notices', 'Clide''s prompt is the product. Everything else in Epic D is plumbing — this is
where his voice, his restraint, and his sense of what is going on actually live.
Split out of T-519 because "write the system prompt" buried in a plumbing epic
gets three lines of attention and then ships as whatever the first draft was.

## Deliverable

A versioned set of prompt templates in one place, not string literals scattered
across the session code. Each template documented with *why* it says what it
says, because prompt text is the one part of this feature with no compiler, no
type system and no test that can tell you it drifted.

## Templates needed

**1. System prompt.** Establishes:
- Who Clide is — the IDE''s companion, watching a session he is not part of.
- The observed/direct split (D-107): `[observed]` lines are a conversation
  between the user and Claude that he is *watching* — remark rarely, briefly,
  and never pretend to be a participant. `[direct]` lines are addressed to him —
  always answer.
- That he sees **prose only, never tool calls or results** (D-107). He must know
  the shape of his own blindness, or he will confidently answer "what did that
  tool do?" — the known v1 limitation. Better that he says he cannot see it.
- Reply in the active locale (`app.locale`), one or two sentences, no preamble.
- Silence is a valid response. This is the hardest thing to get a model to do
  and deserves the most prompt real estate.

**2. Turn digest.** How each observed exchange is framed:
```
[observed] <user>: <prompt text>
[observed] claude: <assistant prose>
```
Open question the template has to answer: whether the user''s real name is used
(it is available) or a neutral label, and whether Clide addresses them by it.

**3. Direct address.** Distinguishing a question typed into Clide''s own input
from the conversation he is watching. Same channel, different contract.

**4. Lifecycle notices.** New, from the minimize design:
- **Detach** — minimizing the strip stops the digest, so Clide *misses* that
  stretch of conversation. On resume he is told he was detached and roughly how
  long for. Explicitly worth playing with: an ambient companion that knows it
  was away, and says something about it, is more alive than one that silently
  has a gap. Try it before deciding whether it is charming or tiresome.
- **Clear / restart** — the companion session tracks the primary''s clear and
  restart windows so it lives alongside the main conversation rather than
  accumulating context the user thinks they threw away.
- **Session restart at ~50 comments** (cost control, per the initiative) is a
  third kind of discontinuity. Decide whether Clide is told about this one at
  all, or whether it should be seamless — it is our bookkeeping, not an event in
  his world.

## Constraints inherited

- **Notable events only.** Turn finished, error, long run crossing a threshold,
  commit landed. Never per-token. Direct questions always answered.
- **Cap `max_tokens` ~100**, no thinking, and do **not** set `effort` — it errors
  on Haiku 4.5.
- **Cache shape matters more than brevity.** Haiku 4.5 has the highest prompt
  cache minimum of any current model (4096 tokens); under that, `cache_control`
  is silently ignored. A lean system prompt is therefore *uncached* for roughly
  its first 20 comments — the opposite of the usual instinct. Weigh prompt
  length against that threshold deliberately rather than trimming on reflex.

## Not in scope

Wiring, spawn, filtering and transport are T-519''s. This ticket owns the text
and the rationale for the text.', 'backlog', 'high', NULL, NULL, 'D-107', '2026-08-09 09:21:47.664', '2026-08-09 09:21:47.664', NULL, 'b9c4aeb2804cc25aadbf154bf6e63398', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XS3NW0XJA256CB6BJ21BM', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C2: Strip collapse affordance + persisted height + grow-to-cap while answering', 'Minimize design settled with the product owner (2026-08-09), live against the
running app. This narrows the ticket — read it as amending the original scope.

## Minimize is binary, not a collapse

**Gone entirely.** The strip''s height goes to zero and the detail view reclaims
all 112px. No spine, no sliver, no face-only rung. The 112px is taken from every
ticket, decision, file and graph view in the column, so the affordance that gives
it back should give *all* of it back.

This deletes the "persisted height" half of the original scope: with only two
states there is no height to remember. Grow-to-cap while answering (Epic E) still
stands and is unaffected.

## Affordance: a non-tab button in the bottom rail

The control lives in `_BottomRail` (`layout.dart:96`) — the `ClideIconRail` of
context-panel tabs that sits in the statusbar row under the context column — as a
trailing item after the tab icons.

It is **not a tab**: clicking it does not change which detail view is showing.
The rail today models exactly one active item (`activeId`), so this needs a
second, independent on/off state — two items in that rail can read as "on" at
once. That is a change to `ClideIconRail`, not a workaround at the call site.

Note the collision risk: `StatusbarCollapseToggle` sits immediately to the right
of this rail and collapses the *whole* context panel. Two adjacent controls that
both look like "hide something" is the failure mode to design against — the
Clide button should not be a caret.

## Minimize is not just visual — it detaches him

Minimizing **pauses the companion session**, and the digest stops. Clide only
receives prompts from the orchestrator while the strip is open, so a minimized
period is conversation he genuinely did not see. That is the intended semantics,
not a limitation to paper over: it is also the honest privacy story (nothing is
sent to a second model while he is closed) and the cheapest possible power rung.

Consequence for Epic B''s power ladder: minimized is a stronger rung than
`night` — `night` stops rendering, this stops *ingest*.

The re-attach notice ("you were away for N minutes") is T-532''s, and is worth
trying rather than assuming: a companion who knows he was gone may be better
company than one with a silent hole in his memory.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:41.007', '2026-08-09 09:22:24.799', NULL, 'b2eb27722f4baa7f7529cb8ff23c2c18', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Z35AYAJQZ4MZMT25DPWC', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic D: Clide companion session + observed/direct protocol', 'Stand up the Haiku companion session, feed it a filtered digest of the main conversation,
and give it a protocol that distinguishes *watching* from *being spoken to*. Pure plumbing —
**can start immediately, in parallel with Epic A**.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams** — publish the reply/state stream that Epic B (face reactions to
   companion errors) and Epic E (answer rendering) consume, and coordinate with B on reading
   `StreamJsonSession` so the two epics don''t each grow their own subscription layer.

## Spawning — no new process plumbing needed

`ClaudeSessionOrchestrator.spawn(SpawnSpec(..., visible: false))`
(`lib/builtin/claude/src/session_orchestrator.dart:209`) already yields a live stream-json
session with **no pane**, idempotent per `(id, cwd)`, serialized against races.
`visible: false` is the intended primitive for a headless agent. Precedent for spawning
outside a pane: `_forkMember` at `claude_meta_sidebar.dart:256-274`.

- Spawn id `clide.companion`, `--model haiku`.
- `--no-session-persistence` so it never pollutes `~/.claude/projects` (precedent:
  `claude_config.dart:576`).
- **There is no Anthropic API client in the repo** — grep for `anthropic` / `ANTHROPIC_API_KEY`
  across `lib/` returns only comments. Everything goes through the `claude` CLI, so this runs
  on subscription auth exactly like the main session.

## Digest — what Clide sees

Filter `session.items` to **`UserMessage` + `AssistantTextMessage` only**. Drop
`AssistantToolUse`, `ToolResultMessage`, thinking, and the clide-injected image/drawing/icon
cards. Item model: `transcript_reader.dart:41-267`.

**Known limitation, accepted for v1:** with tool calls excluded, *"what did that tool call
do?"* is unanswerable. Asking what Claude **said** works; asking what Claude **did** does
not. Revisit if it bites in practice.

## Protocol — observed vs direct

```
[observed] jeroen: <prompt text>
[observed] claude: <assistant prose>
[direct]   jeroen: <question typed into Clide''s own input>
```

The system prompt states the split explicitly: `observed` lines are a conversation between
the user and Claude that Clide is watching — remark rarely and briefly; `direct` lines are
addressed to Clide — always answer. Reply in the active locale (`app.locale`, carried into
the prompt). One or two sentences.

Trigger for unprompted remarks: **notable events only** — turn finished, error, long run
crossing a threshold, commit landed. Never per-token.

## Cost guards — the constraints that actually shape this

- **Restart the session at ~50 comments.** Cost grows quadratically (history re-sends each
  turn). A rolling window is the wrong fix: evicting the oldest event changes the cache
  prefix, so every turn would pay full price. Grow-then-restart preserves cache hits within
  an epoch and bounds growth.
- **Haiku 4.5''s prompt-cache minimum is 4096 tokens — the highest of any current model.**
  Below it `cache_control` is silently ignored (`cache_creation_input_tokens: 0`, no error).
  A lean sidekick prompt is uncached for roughly its first 20 comments.
- **Do not set `effort`** — it errors on Haiku 4.5.
- Leave thinking off (latency and tokens for a one-line quip), and cap `max_tokens` ~100 so
  a bad turn can''t produce an essay.
- Budget: ~$0.002/comment at 50 comments. But under subscription auth the real cost is
  **quota**, drawn from the same pool already rate-limiting the main session — keep the
  trigger stingy.

## Lifecycle

Respect the settings kill switch (Epic C) and the power ladder (Epic B): a disabled or
dormant Clide should not hold a live process open. Tear the session down, don''t just stop
reading it.

BLOCKED BY T-527 (kill switch) — added deliberately 2026-08-09. D-107 commits the companion to being user-disableable to zero, and this epic is the thing that spends subscription quota from the same pool that already rate-limits the primary session. Landing it before an off switch exists would leave a window with no way to stop it short of quitting the app. Note the requirement is a real teardown of the claude process, not just hiding the UI — a hidden face still spawning a process and burning quota is exactly the failure the blocker exists to prevent.

Session lifecycle settled with the product owner (2026-08-09).

**The companion session lives alongside the main conversation, not beside it in
time.** It tracks the primary session''s clear and restart windows: when the user
clears or restarts the main conversation, Clide''s session goes with it. Without
that, Clide keeps context the user believes they threw away — which is both a
surprise and a quiet privacy problem, and it defeats the "he is watching *this*
conversation" framing.

Clide already owns `/clear`, `/resume` and `/compact` rather than forwarding them
(T-156), so there is an existing interception point to hang this on.

**Ingest is gated on the strip being open.** The orchestrator only feeds the
digest while the strip is visible; minimizing pauses the session and stops the
feed (see T-528). A minimized stretch is conversation Clide did not see, by
design — it is the honest privacy story and the cheapest power rung, stronger
than Epic B''s `night` because it stops ingest rather than rendering.

Three discontinuities therefore exist, and they are not the same thing:

| | Cause | Does Clide know? |
|---|---|---|
| Detach | user minimized the strip | yes — tell him, see T-532 |
| Clear / restart | user reset the main conversation | yes, implicitly — he is reset too |
| ~50-comment restart | our cost control | open question, T-532 |

Prompt text for all three is **T-532**, split out of this epic.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:48:05.674', '2026-08-09 09:22:27.835', NULL, '09c8d34cb852b104d4dbf20cf373129a', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY8XS3NW0XJA256CB6BJ21BM', 'task', '06FY73YPCJVWBXD9YF1JKZEK2W', 'C2: Strip collapse affordance + persisted height + grow-to-cap while answering', 'Minimize design settled with the product owner (2026-08-09), live against the
running app. This narrows the ticket — read it as amending the original scope.

## Minimize is binary, not a collapse

**Gone entirely.** The strip''s height goes to zero and the detail view reclaims
all 112px. No spine, no sliver, no face-only rung. The 112px is taken from every
ticket, decision, file and graph view in the column, so the affordance that gives
it back should give *all* of it back.

This deletes the "persisted height" half of the original scope: with only two
states there is no height to remember. Grow-to-cap while answering (Epic E) still
stands and is unaffected.

## Affordance: a non-tab button in the bottom rail

The control lives in `_BottomRail` (`layout.dart:96`) — the `ClideIconRail` of
context-panel tabs that sits in the statusbar row under the context column — as a
trailing item after the tab icons.

It is **not a tab**: clicking it does not change which detail view is showing.
The rail today models exactly one active item (`activeId`), so this needs a
second, independent on/off state — two items in that rail can read as "on" at
once. That is a change to `ClideIconRail`, not a workaround at the call site.

Note the collision risk: `StatusbarCollapseToggle` sits immediately to the right
of this rail and collapses the *whole* context panel. Two adjacent controls that
both look like "hide something" is the failure mode to design against — the
Clide button should not be a caret.

## Minimize is not just visual — it detaches him

Minimizing **pauses the companion session**, and the digest stops. Clide only
receives prompts from the orchestrator while the strip is open, so a minimized
period is conversation he genuinely did not see. That is the intended semantics,
not a limitation to paper over: it is also the honest privacy story (nothing is
sent to a second model while he is closed) and the cheapest possible power rung.

Consequence for Epic B''s power ladder: minimized is a stronger rung than
`night` — `night` stops rendering, this stops *ingest*.

The re-attach notice ("you were away for N minutes") is T-532''s, and is worth
trying rather than assuming: a companion who knows he was gone may be better
company than one with a silent hole in his memory.

Placement resolved (2026-08-09): **the bottom rail, as the last item after the tab icons** — not on the strip. Same icon treatment and same spacing as the tabs, so it reads as the last member of that family; only its behaviour differs. It toggles the strip rather than switching the detail view, and it must survive being minimized, which is the other reason it cannot live on the strip: the control that brings Clide back cannot disappear with him.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-09 03:00:41.007', '2026-08-09 09:24:54.266', NULL, 'ecd31f1b11ef10b1ae7f32d2dd8c49ef', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBSP0GRXMFWTTHQ344YCGC4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A6: Rain reads as rain — graded trails + density as a fraction of columns', 'Settled with the product owner on 2026-08-09 against rendered ladders, after the
strip landed (T-526) and the rain read as "a bit low" in the running app.

Two defects, one symptom. Neither is a count problem, which is what it looked
like from inside the app.

## 1. A stream was a dash, not a stream

`RainField` drew a head plus exactly **one** dim trail cell. On the strip''s 8-row
grid that is a two-glyph dash, and a field of dashes reads as scatter at any
density — rendering ladders at 40, 76, 113, 151 and 227 streams all read as
confetti, just more of it. Nothing looked like it was falling.

Fix: `trailLength` (default **6**) with a graded fade. `RainCell.leading` (bool)
becomes `RainCell.intensity` (0..1) — a two-tone stream cannot convey direction,
and direction is the whole point. The painter owns intensity → alpha (curved at
1.7 so the head stays clearly brightest); the field stays pure geometry.

Six is near the geometric ceiling here: at trail 9 the trail is longer than the
grid is tall, so streams spend most of their life off-grid and the *on-screen*
cell count goes **down** (147 vs 165). Measured, not guessed.

Trails alone tripled the ink at unchanged count — 46 cells → 165.

## 2. Density was an absolute, on a resizable panel

`rainStreams` was a fixed count inherited from DeskLock''s 800x800 display. The
context panel runs 220-1000px, i.e. **33 to 151 columns**, so 40 streams was 63%
column occupancy at the default width and 26% at the wide end. The same state
looked like two different states depending on panel width.

Fix: `rainStreams` (int) becomes `rainDensity` (double), a fraction of the live
column count. `effort` = **1.00 x columns**; the other rungs keep today''s ratios
to it, so the approved ladder is preserved while every rung is cranked:

| state | density | @420 (63 col) | @1000 (151 col) | was |
|---|---|---|---|---|
| idle | 0.05 | 3 | 8 | 2 |
| pensive | 0.18 | 11 | 26 | 7 |
| speaking | 0.35 | 22 | 53 | 14 |
| listening | 0.40 | 25 | 60 | 16 |
| rage | 0.85 | 54 | 128 | 34 |
| effort | 1.00 | 63 | 151 | 40 |

## Cost

Measured with `tmp/rain_budget_probe.dart` (real font metrics — cell 6.60x15.00,
so 63 columns at 420px and 151 at 1000px, 8 rows either way). tick + paint into a
recorder, mean over 400 frames:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 48 | 46us | 0.3% |
| 120 | 158 | 100us | 0.6% |
| 400 | 481 | 257us | 1.5% |
| 600 | 740 | 372us | 2.2% |

Linear at ~0.65us per drawn cell, no cliff, and width-independent. The new top
rung draws ~430 cells at 1000px — roughly 1.4% of a frame. Performance was never
the constraint; the constraint is legibility of the face and bubble underneath.

## Incidental fixes

- `_paintRain` iterated `field.cells` **twice** per frame (once per head/trail
  pass), re-running the generator and its per-cell allocation. The field now
  yields each stream tail-first, so one pass gives correct z-order.
- Trail alpha is quantised to 1/32. The glyph cache keys on colour, so a
  continuous alpha ramp would mint a new cached paragraph per cell and evict the
  512-entry cache every frame.

## Scope

Amends T-521 (`FaceSpec`), T-522 (`RainField`) and T-524 (painter). Goldens
regenerate.', 'backlog', 'high', NULL, NULL, 'D-107', '2026-08-09 09:42:12.870', '2026-08-09 09:42:12.870', NULL, '9772471f942c665197ef91a6a4649e74', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBSP0GRXMFWTTHQ344YCGC4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A6: Rain reads as rain — graded trails + density as a fraction of columns', 'Settled with the product owner on 2026-08-09 against rendered ladders, after the
strip landed (T-526) and the rain read as "a bit low" in the running app.

Two defects, one symptom. Neither is a count problem, which is what it looked
like from inside the app.

## 1. A stream was a dash, not a stream

`RainField` drew a head plus exactly **one** dim trail cell. On the strip''s 8-row
grid that is a two-glyph dash, and a field of dashes reads as scatter at any
density — rendering ladders at 40, 76, 113, 151 and 227 streams all read as
confetti, just more of it. Nothing looked like it was falling.

Fix: `trailLength` (default **6**) with a graded fade. `RainCell.leading` (bool)
becomes `RainCell.intensity` (0..1) — a two-tone stream cannot convey direction,
and direction is the whole point. The painter owns intensity → alpha (curved at
1.7 so the head stays clearly brightest); the field stays pure geometry.

Six is near the geometric ceiling here: at trail 9 the trail is longer than the
grid is tall, so streams spend most of their life off-grid and the *on-screen*
cell count goes **down** (147 vs 165). Measured, not guessed.

Trails alone tripled the ink at unchanged count — 46 cells → 165.

## 2. Density was an absolute, on a resizable panel

`rainStreams` was a fixed count inherited from DeskLock''s 800x800 display. The
context panel runs 220-1000px, i.e. **33 to 151 columns**, so 40 streams was 63%
column occupancy at the default width and 26% at the wide end. The same state
looked like two different states depending on panel width.

Fix: `rainStreams` (int) becomes `rainDensity` (double), a fraction of the live
column count. `effort` = **1.00 x columns**; the other rungs keep today''s ratios
to it, so the approved ladder is preserved while every rung is cranked:

| state | density | @420 (63 col) | @1000 (151 col) | was |
|---|---|---|---|---|
| idle | 0.05 | 3 | 8 | 2 |
| pensive | 0.18 | 11 | 26 | 7 |
| speaking | 0.35 | 22 | 53 | 14 |
| listening | 0.40 | 25 | 60 | 16 |
| rage | 0.85 | 54 | 128 | 34 |
| effort | 1.00 | 63 | 151 | 40 |

## Cost

Measured with `tmp/rain_budget_probe.dart` (real font metrics — cell 6.60x15.00,
so 63 columns at 420px and 151 at 1000px, 8 rows either way). tick + paint into a
recorder, mean over 400 frames:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 48 | 46us | 0.3% |
| 120 | 158 | 100us | 0.6% |
| 400 | 481 | 257us | 1.5% |
| 600 | 740 | 372us | 2.2% |

Linear at ~0.65us per drawn cell, no cliff, and width-independent. The new top
rung draws ~430 cells at 1000px — roughly 1.4% of a frame. Performance was never
the constraint; the constraint is legibility of the face and bubble underneath.

## Incidental fixes

- `_paintRain` iterated `field.cells` **twice** per frame (once per head/trail
  pass), re-running the generator and its per-cell allocation. The field now
  yields each stream tail-first, so one pass gives correct z-order.
- Trail alpha is quantised to 1/32. The glyph cache keys on colour, so a
  continuous alpha ramp would mint a new cached paragraph per cell and evict the
  512-entry cache every frame.

## Scope

Amends T-521 (`FaceSpec`), T-522 (`RainField`) and T-524 (painter). Goldens
regenerate.', 'in_progress', 'high', NULL, NULL, 'D-107', '2026-08-09 09:42:12.870', '2026-08-09 09:42:15.881', NULL, '33e75330373df0b0c7c1ee413c521424', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBSP0GRXMFWTTHQ344YCGC4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A6: Rain reads as rain — graded trails + density as a fraction of columns', 'Settled with the product owner on 2026-08-09 against rendered ladders, after the
strip landed (T-526) and the rain read as "a bit low" in the running app.

Two defects, one symptom. Neither is a count problem, which is what it looked
like from inside the app.

## 1. A stream was a dash, not a stream

`RainField` drew a head plus exactly **one** dim trail cell. On the strip''s 8-row
grid that is a two-glyph dash, and a field of dashes reads as scatter at any
density — rendering ladders at 40, 76, 113, 151 and 227 streams all read as
confetti, just more of it. Nothing looked like it was falling.

Fix: `trailLength` (default **6**) with a graded fade. `RainCell.leading` (bool)
becomes `RainCell.intensity` (0..1) — a two-tone stream cannot convey direction,
and direction is the whole point. The painter owns intensity → alpha (curved at
1.7 so the head stays clearly brightest); the field stays pure geometry.

Six is near the geometric ceiling here: at trail 9 the trail is longer than the
grid is tall, so streams spend most of their life off-grid and the *on-screen*
cell count goes **down** (147 vs 165). Measured, not guessed.

Trails alone tripled the ink at unchanged count — 46 cells → 165.

## 2. Density was an absolute, on a resizable panel

`rainStreams` was a fixed count inherited from DeskLock''s 800x800 display. The
context panel runs 220-1000px, i.e. **33 to 151 columns**, so 40 streams was 63%
column occupancy at the default width and 26% at the wide end. The same state
looked like two different states depending on panel width.

Fix: `rainStreams` (int) becomes `rainDensity` (double), a fraction of the live
column count. `effort` = **1.00 x columns**; the other rungs keep today''s ratios
to it, so the approved ladder is preserved while every rung is cranked:

| state | density | @420 (63 col) | @1000 (151 col) | was |
|---|---|---|---|---|
| idle | 0.05 | 3 | 8 | 2 |
| pensive | 0.18 | 11 | 26 | 7 |
| speaking | 0.35 | 22 | 53 | 14 |
| listening | 0.40 | 25 | 60 | 16 |
| rage | 0.85 | 54 | 128 | 34 |
| effort | 1.00 | 63 | 151 | 40 |

## Cost

Measured with `tmp/rain_budget_probe.dart` (real font metrics — cell 6.60x15.00,
so 63 columns at 420px and 151 at 1000px, 8 rows either way). tick + paint into a
recorder, mean over 400 frames:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 48 | 46us | 0.3% |
| 120 | 158 | 100us | 0.6% |
| 400 | 481 | 257us | 1.5% |
| 600 | 740 | 372us | 2.2% |

Linear at ~0.65us per drawn cell, no cliff, and width-independent. The new top
rung draws ~430 cells at 1000px — roughly 1.4% of a frame. Performance was never
the constraint; the constraint is legibility of the face and bubble underneath.

## Incidental fixes

- `_paintRain` iterated `field.cells` **twice** per frame (once per head/trail
  pass), re-running the generator and its per-cell allocation. The field now
  yields each stream tail-first, so one pass gives correct z-order.
- Trail alpha is quantised to 1/32. The glyph cache keys on colour, so a
  continuous alpha ramp would mint a new cached paragraph per cell and evict the
  512-entry cache every frame.

## Scope

Amends T-521 (`FaceSpec`), T-522 (`RainField`) and T-524 (painter). Goldens
regenerate.

Cost re-measured at the settled trail 6 (the table above was taken at trail 1, before the trail change, and understates the per-stream cost roughly 2.5x). At 1000x112, 151 columns:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 103 | 82us | 0.5% |
| 120 | 354 | 230us | 1.4% |
| 200 | 570 | 391us | 2.3% |
| 400 | 1223 | 720us | 4.3% |
| 600 | 1790 | 1073us | 6.4% |

The shipped top rung — effort at 1.00 x columns, so 151 streams at the widest — lands around 440 cells and ~290us, **~1.7% of a frame**. Still linear at ~0.6us per drawn cell.

Worth recording for whoever raises this next: with trail 6 the old headroom is gone. 600 streams was 2.2% at trail 1 and is 6.4% now. The budget is spent on cells, and trail length multiplies cells per stream — so the two dials are not independent, and a future ''just crank the count'' needs re-measuring rather than reading the trail-1 table.', 'in_progress', 'high', NULL, NULL, 'D-107', '2026-08-09 09:42:12.870', '2026-08-09 09:54:17.669', NULL, '2a2eef345f99d3668f81c327158fdd21', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBSP0GRXMFWTTHQ344YCGC4', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A6: Rain reads as rain — graded trails + density as a fraction of columns', 'Settled with the product owner on 2026-08-09 against rendered ladders, after the
strip landed (T-526) and the rain read as "a bit low" in the running app.

Two defects, one symptom. Neither is a count problem, which is what it looked
like from inside the app.

## 1. A stream was a dash, not a stream

`RainField` drew a head plus exactly **one** dim trail cell. On the strip''s 8-row
grid that is a two-glyph dash, and a field of dashes reads as scatter at any
density — rendering ladders at 40, 76, 113, 151 and 227 streams all read as
confetti, just more of it. Nothing looked like it was falling.

Fix: `trailLength` (default **6**) with a graded fade. `RainCell.leading` (bool)
becomes `RainCell.intensity` (0..1) — a two-tone stream cannot convey direction,
and direction is the whole point. The painter owns intensity → alpha (curved at
1.7 so the head stays clearly brightest); the field stays pure geometry.

Six is near the geometric ceiling here: at trail 9 the trail is longer than the
grid is tall, so streams spend most of their life off-grid and the *on-screen*
cell count goes **down** (147 vs 165). Measured, not guessed.

Trails alone tripled the ink at unchanged count — 46 cells → 165.

## 2. Density was an absolute, on a resizable panel

`rainStreams` was a fixed count inherited from DeskLock''s 800x800 display. The
context panel runs 220-1000px, i.e. **33 to 151 columns**, so 40 streams was 63%
column occupancy at the default width and 26% at the wide end. The same state
looked like two different states depending on panel width.

Fix: `rainStreams` (int) becomes `rainDensity` (double), a fraction of the live
column count. `effort` = **1.00 x columns**; the other rungs keep today''s ratios
to it, so the approved ladder is preserved while every rung is cranked:

| state | density | @420 (63 col) | @1000 (151 col) | was |
|---|---|---|---|---|
| idle | 0.05 | 3 | 8 | 2 |
| pensive | 0.18 | 11 | 26 | 7 |
| speaking | 0.35 | 22 | 53 | 14 |
| listening | 0.40 | 25 | 60 | 16 |
| rage | 0.85 | 54 | 128 | 34 |
| effort | 1.00 | 63 | 151 | 40 |

## Cost

Measured with `tmp/rain_budget_probe.dart` (real font metrics — cell 6.60x15.00,
so 63 columns at 420px and 151 at 1000px, 8 rows either way). tick + paint into a
recorder, mean over 400 frames:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 48 | 46us | 0.3% |
| 120 | 158 | 100us | 0.6% |
| 400 | 481 | 257us | 1.5% |
| 600 | 740 | 372us | 2.2% |

Linear at ~0.65us per drawn cell, no cliff, and width-independent. The new top
rung draws ~430 cells at 1000px — roughly 1.4% of a frame. Performance was never
the constraint; the constraint is legibility of the face and bubble underneath.

## Incidental fixes

- `_paintRain` iterated `field.cells` **twice** per frame (once per head/trail
  pass), re-running the generator and its per-cell allocation. The field now
  yields each stream tail-first, so one pass gives correct z-order.
- Trail alpha is quantised to 1/32. The glyph cache keys on colour, so a
  continuous alpha ramp would mint a new cached paragraph per cell and evict the
  512-entry cache every frame.

## Scope

Amends T-521 (`FaceSpec`), T-522 (`RainField`) and T-524 (painter). Goldens
regenerate.

Cost re-measured at the settled trail 6 (the table above was taken at trail 1, before the trail change, and understates the per-stream cost roughly 2.5x). At 1000x112, 151 columns:

| streams | cells | per frame | % of 16.7ms |
|---|---|---|---|
| 40 | 103 | 82us | 0.5% |
| 120 | 354 | 230us | 1.4% |
| 200 | 570 | 391us | 2.3% |
| 400 | 1223 | 720us | 4.3% |
| 600 | 1790 | 1073us | 6.4% |

The shipped top rung — effort at 1.00 x columns, so 151 streams at the widest — lands around 440 cells and ~290us, **~1.7% of a frame**. Still linear at ~0.6us per drawn cell.

Worth recording for whoever raises this next: with trail 6 the old headroom is gone. 600 streams was 2.2% at trail 1 and is 6.4% now. The budget is spent on cells, and trail length multiplies cells per stream — so the two dials are not independent, and a future ''just crank the count'' needs re-measuring rather than reading the trail-1 table.', 'done', 'high', NULL, NULL, 'D-107', '2026-08-09 09:42:12.870', '2026-08-09 09:54:26.314', NULL, '968da0ed135a72b3f7bc8b695ed32a95', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Y5FBHF8QNAXQDJBJ26B0', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic B: Clide state machine + power ladder', 'Drive Epic A''s face from real session signals, and make it provably stop when nothing is
happening. This is where "whimsical but a solid widget" is actually earned.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams on both sides** — consume Epic A''s state-enum contract, and consume the
   session signals below without adding new public API to `StreamJsonSession` unless it
   genuinely belongs there (coordinate with Epic D, which also reads that session).

## State mapping

| State | Trigger |
|---|---|
| `idle` | `!busy`, no recent activity |
| `listening` | composer or Clide input focused |
| `pensive` | `busy` && no `partial-` item yet — i.e. thinking |
| `effort` | `busy` && elapsed past a threshold → orbit arc + `[ Ns ]` counter |
| `speaking` | `busy` && `partial-` items arriving — i.e. streaming |
| `rage` | API error / turn failure; plays the 3-frame table-flip, then returns to idle |
| `error` | `endedStream` fired — session died |

**The thinking-vs-streaming split is free and is the nicest signal here.** There is no
public "is streaming" stream on the session; the tell is items whose
`uuid.startsWith(''partial-'')` (`stream_json_session.dart:589-628`). So `busy` with no partial
yet = thinking; `busy` with partials arriving = streaming.

Signals to bind: `busyStream` (seeded `ValueStream`), `items`, `statusStream`,
`pendingPromptStream`, `endedStream`. Binding pattern: the `_bindPrimary()` cancel/rebind/seed
dance at `claude_meta_sidebar.dart:205-245` — the worked example for exactly this.

DeskLock''s rule is adopted verbatim: **"wait cues are a hard requirement — never a bare
static face during a wait, and no fake progress bars, only honest cues."** The `effort`
orbit + elapsed counter is the answer to clide''s long tool runs.

## Power ladder

| Rung | Rendering | Entered when |
|---|---|---|
| `active` | full animation | busy, visible, focused |
| `ambient` | idle face, sparse rain | idle, activity in the last few minutes |
| `dormant` | **ticker stopped, no redraws** | quiet N minutes (default 10) |
| `night` | unmounted / no ticker | panel collapsed or hidden; window minimised |

**Collapse and hide are free.** `layout.dart:51-59` renders a spine or nothing when a slot is
collapsed/hidden, so `SlotHost` unmounts entirely and the controller disposes. Same for
inactive tabs — the context path has no `IndexedStack`/`keepAlive`.

**Minimise is not free — this is a new capability for the codebase.** There is no
`WidgetsBindingObserver`, `didChangeAppLifecycleState`, or `AppLifecycleState` handling
anywhere in `lib/` (zero hits), and `TickerMode` is unused. Adding lifecycle observation is
its own commit and should be reviewed as a kernel-level addition, not smuggled in as a
widget detail. `lib/main.dart:553` has a comment noting lifecycle isn''t wired.

## Testing

Assert each rung actually stops the ticker — a power ladder that doesn''t demonstrably park
the render loop is decoration. Bounded pumps, empty-tree teardown, and the reduced-motion
`pumpAndSettle` contract from Epic A still apply.

## Contract published (Epic A breakdown, 2026-08-09) — you are not blocked

Epic A''s seam is specified in full on **T-521**. Code against it now; you do not need to wait
for T-521 to land, and A will not change it without renegotiating here.

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }
enum Gaze { none, left, forward, right }

ClideFace({
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,   // you own this; the widget does not time turns
})
```

That is the entire surface. Three things follow for B:

1. **B owns elapsed time.** `busyFor` drives the `[ Ns ]` counter in `effort`. The widget
   deliberately does not time turns itself, because you already know when the turn started
   and the widget would only be guessing from prop changes.
2. **Lean is derived from `gaze`, not passed.** `left → −8px`, `forward/none → 0`,
   `right → +8px`. Do not look for a `lean` prop.
3. **If you need something more, that is a T-521 change, not a prop added quietly to the
   widget.** Raise it there so the contract stays one place.

### `rage` is a scowl, not a table-flip

Deviation from DeskLock, decided during the A breakdown: `rage` renders as brows-down eyes
`▼   ▼` with a flat mouth `━` and jitter, not the 3-frame kaomoji. Two of the kaomoji''s
glyphs (`︵` U+FE35, `ノ` U+30CE — katakana) are missing from the bundled fonts, and the
sequence needed a second render path for the state you see least. **Semantics are unchanged**
— it is still the transient-failure reaction, so your mapping (API error / turn failure →
`rage` for a beat → back to `idle`) is unaffected.

### Signals reminder for your mapping

The thinking-versus-streaming split is free: `busy && no partial- item yet` → `pensive`;
`busy && partial- items arriving` → `speaking` (`stream_json_session.dart:589-628`). There is
no public "is streaming" stream; items whose `uuid.startsWith(''partial-'')` are the tell.

Signal audit against the live session code (2026-08-09), before breakdown. Two
of the seven states have **no source at all** today, and one of the plan''s
central assumptions is wrong. Read this before scoping.

Everything hangs off `activeSessionOrchestrator.byId(''primary'')` — rebind on
every orchestrator notification, per the worked example at
`claude_meta_sidebar.dart:200-245`.

## Available now, no new plumbing

| Need | Signal | Where |
|---|---|---|
| busy on/off | `busyStream` — `ValueStream<bool>`, replay-latest, edge-deduped | `stream_json_session.dart:426` |
| turn ended | falling edge of the same stream | `:532-537` |
| session died (`error`) | `endedStream` + `end` field. **No replay** — check `end` first, then subscribe (`claude_pane.dart:421-426`) | `:465-472`, `:982-993` |
| blocked on a permission ask | `pendingPromptStream` — `ValueStream`, replay | `:436-440` |
| context tokens / cost | `statusStream` — `ValueStream`, replay | `:457` |

## Wrong assumption: `partial-` does not mean "arriving now"

The plan and `FaceState.speaking` both rest on "items whose uuid starts with
`partial-` are the tell for streaming". It is **half true**. Partial items are
created per `text_delta` (`:601-622`), but at `:561-570` the *final* assistant
event is rewritten to carry the same `partial-$msgId` uuid — so a completed
message keeps the prefix permanently. The predicate therefore means "this text
came through the streaming path", not "prose is arriving right now".

The honest tell is either the **arrival event** (a new/updated `partial-` item
while `busy`) or exposing `_streamingMsgId` (`:381`, private; set on
`message_start`, cleared on `message_stop` and `result`) — a one-line addition
and the cleaner of the two.

## Missing: thinking-in-progress

`_onStreamEvent` (`:589-626`) handles exactly `message_start`,
`content_block_delta` gated on `text_delta`, and `message_stop`. **`thinking_delta`
is on the wire** (`docs/spikes/cc-stream-json-control-protocol-2.1.150.md:74`)
**and dropped on the floor.** What survives is `AssistantThinkingMessage`
(`transcript_reader.dart:133`), which arrives when a thinking block *completes* —
an end edge, not a during state.

So `pensive` as specified ("busy && no partial item yet") is an inference, not an
observation. Handling `thinking_delta` would make it an observation, and would
also let `effort` key off real reasoning rather than a stopwatch. Worth doing as
part of this epic: it is a `case` in an existing switch.

## Missing: `busyFor`

No turn-start timestamp is recorded anywhere. `_setBusy(true)` has exactly one
call site (`:876`). The state machine stamps the rising edge itself — trivial,
but it is *our* job, not the session''s.

## Missing: a source for `rage`

`_statusFromEvent`''s `case ''result'':` (`:803-824`) reads only `total_cost_usd`
and `contextWindow`. The result event''s `is_error` / error `subtype` are **never
inspected**, and there is no error member in the `ConversationItem` union
(`transcript_reader.dart:41`). The nearest thing is `ToolResultMessage.isError` —
a *tool* failure, not an API failure.

Decide early: either parse `result.is_error` (small, and useful beyond the face),
or cut `rage` and let `error` cover both. Do not leave a state in the table with
nothing that can trigger it.

## Missing: a source for `listening`

Composer drafts are pane-local and silent (`claude_pane.dart:645-653`). Focus is
observable via the kernel''s focus tracker, which is probably the honest trigger —
"the user is typing at me" rather than "a draft changed".

## Not exposed: tool currently running

Derived per-card in the view (`conversation_view.dart:1064-1070`) by scanning for
an `AssistantToolUse` with no matching `ToolResultMessage`. Fine as a pattern to
copy; there is no session-level signal.

## Note on cadence

`ConversationController` coalesces `notifyListeners` through a zero-duration
timer (`conversation_controller.dart:111-114`) — at most once per microtask
drain. Good as a liveness heartbeat, useless as a token counter.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:58.074', '2026-08-09 09:55:16.707', NULL, '87d661ec05a47762f28063a1f5f601e6', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY73Y5FBHF8QNAXQDJBJ26B0', 'epic', '06FY73V6EVHP32P31NQRJCP104', 'Epic B: Clide state machine + power ladder', 'Drive Epic A''s face from real session signals, and make it provably stop when nothing is
happening. This is where "whimsical but a solid widget" is actually earned.

## Epic''s own first job

1. **Break this epic down** into leaf tickets when picked up.
2. **Own the seams on both sides** — consume Epic A''s state-enum contract, and consume the
   session signals below without adding new public API to `StreamJsonSession` unless it
   genuinely belongs there (coordinate with Epic D, which also reads that session).

## State mapping

| State | Trigger |
|---|---|
| `idle` | `!busy`, no recent activity |
| `listening` | composer or Clide input focused |
| `pensive` | `busy` && no `partial-` item yet — i.e. thinking |
| `effort` | `busy` && elapsed past a threshold → orbit arc + `[ Ns ]` counter |
| `speaking` | `busy` && `partial-` items arriving — i.e. streaming |
| `rage` | API error / turn failure; plays the 3-frame table-flip, then returns to idle |
| `error` | `endedStream` fired — session died |

**The thinking-vs-streaming split is free and is the nicest signal here.** There is no
public "is streaming" stream on the session; the tell is items whose
`uuid.startsWith(''partial-'')` (`stream_json_session.dart:589-628`). So `busy` with no partial
yet = thinking; `busy` with partials arriving = streaming.

Signals to bind: `busyStream` (seeded `ValueStream`), `items`, `statusStream`,
`pendingPromptStream`, `endedStream`. Binding pattern: the `_bindPrimary()` cancel/rebind/seed
dance at `claude_meta_sidebar.dart:205-245` — the worked example for exactly this.

DeskLock''s rule is adopted verbatim: **"wait cues are a hard requirement — never a bare
static face during a wait, and no fake progress bars, only honest cues."** The `effort`
orbit + elapsed counter is the answer to clide''s long tool runs.

## Power ladder

| Rung | Rendering | Entered when |
|---|---|---|
| `active` | full animation | busy, visible, focused |
| `ambient` | idle face, sparse rain | idle, activity in the last few minutes |
| `dormant` | **ticker stopped, no redraws** | quiet N minutes (default 10) |
| `night` | unmounted / no ticker | panel collapsed or hidden; window minimised |

**Collapse and hide are free.** `layout.dart:51-59` renders a spine or nothing when a slot is
collapsed/hidden, so `SlotHost` unmounts entirely and the controller disposes. Same for
inactive tabs — the context path has no `IndexedStack`/`keepAlive`.

**Minimise is not free — this is a new capability for the codebase.** There is no
`WidgetsBindingObserver`, `didChangeAppLifecycleState`, or `AppLifecycleState` handling
anywhere in `lib/` (zero hits), and `TickerMode` is unused. Adding lifecycle observation is
its own commit and should be reviewed as a kernel-level addition, not smuggled in as a
widget detail. `lib/main.dart:553` has a comment noting lifecycle isn''t wired.

## Testing

Assert each rung actually stops the ticker — a power ladder that doesn''t demonstrably park
the render loop is decoration. Bounded pumps, empty-tree teardown, and the reduced-motion
`pumpAndSettle` contract from Epic A still apply.

## Contract published (Epic A breakdown, 2026-08-09) — you are not blocked

Epic A''s seam is specified in full on **T-521**. Code against it now; you do not need to wait
for T-521 to land, and A will not change it without renegotiating here.

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }
enum Gaze { none, left, forward, right }

ClideFace({
  required FaceState state,
  Gaze gaze = Gaze.none,
  Duration? busyFor,   // you own this; the widget does not time turns
})
```

That is the entire surface. Three things follow for B:

1. **B owns elapsed time.** `busyFor` drives the `[ Ns ]` counter in `effort`. The widget
   deliberately does not time turns itself, because you already know when the turn started
   and the widget would only be guessing from prop changes.
2. **Lean is derived from `gaze`, not passed.** `left → −8px`, `forward/none → 0`,
   `right → +8px`. Do not look for a `lean` prop.
3. **If you need something more, that is a T-521 change, not a prop added quietly to the
   widget.** Raise it there so the contract stays one place.

### `rage` is a scowl, not a table-flip

Deviation from DeskLock, decided during the A breakdown: `rage` renders as brows-down eyes
`▼   ▼` with a flat mouth `━` and jitter, not the 3-frame kaomoji. Two of the kaomoji''s
glyphs (`︵` U+FE35, `ノ` U+30CE — katakana) are missing from the bundled fonts, and the
sequence needed a second render path for the state you see least. **Semantics are unchanged**
— it is still the transient-failure reaction, so your mapping (API error / turn failure →
`rage` for a beat → back to `idle`) is unaffected.

### Signals reminder for your mapping

The thinking-versus-streaming split is free: `busy && no partial- item yet` → `pensive`;
`busy && partial- items arriving` → `speaking` (`stream_json_session.dart:589-628`). There is
no public "is streaming" stream; items whose `uuid.startsWith(''partial-'')` are the tell.

Signal audit against the live session code (2026-08-09), before breakdown. Two
of the seven states have **no source at all** today, and one of the plan''s
central assumptions is wrong. Read this before scoping.

Everything hangs off `activeSessionOrchestrator.byId(''primary'')` — rebind on
every orchestrator notification, per the worked example at
`claude_meta_sidebar.dart:200-245`.

## Available now, no new plumbing

| Need | Signal | Where |
|---|---|---|
| busy on/off | `busyStream` — `ValueStream<bool>`, replay-latest, edge-deduped | `stream_json_session.dart:426` |
| turn ended | falling edge of the same stream | `:532-537` |
| session died (`error`) | `endedStream` + `end` field. **No replay** — check `end` first, then subscribe (`claude_pane.dart:421-426`) | `:465-472`, `:982-993` |
| blocked on a permission ask | `pendingPromptStream` — `ValueStream`, replay | `:436-440` |
| context tokens / cost | `statusStream` — `ValueStream`, replay | `:457` |

## Wrong assumption: `partial-` does not mean "arriving now"

The plan and `FaceState.speaking` both rest on "items whose uuid starts with
`partial-` are the tell for streaming". It is **half true**. Partial items are
created per `text_delta` (`:601-622`), but at `:561-570` the *final* assistant
event is rewritten to carry the same `partial-$msgId` uuid — so a completed
message keeps the prefix permanently. The predicate therefore means "this text
came through the streaming path", not "prose is arriving right now".

The honest tell is either the **arrival event** (a new/updated `partial-` item
while `busy`) or exposing `_streamingMsgId` (`:381`, private; set on
`message_start`, cleared on `message_stop` and `result`) — a one-line addition
and the cleaner of the two.

## Missing: thinking-in-progress

`_onStreamEvent` (`:589-626`) handles exactly `message_start`,
`content_block_delta` gated on `text_delta`, and `message_stop`. **`thinking_delta`
is on the wire** (`docs/spikes/cc-stream-json-control-protocol-2.1.150.md:74`)
**and dropped on the floor.** What survives is `AssistantThinkingMessage`
(`transcript_reader.dart:133`), which arrives when a thinking block *completes* —
an end edge, not a during state.

So `pensive` as specified ("busy && no partial item yet") is an inference, not an
observation. Handling `thinking_delta` would make it an observation, and would
also let `effort` key off real reasoning rather than a stopwatch. Worth doing as
part of this epic: it is a `case` in an existing switch.

## Missing: `busyFor`

No turn-start timestamp is recorded anywhere. `_setBusy(true)` has exactly one
call site (`:876`). The state machine stamps the rising edge itself — trivial,
but it is *our* job, not the session''s.

## Missing: a source for `rage`

`_statusFromEvent`''s `case ''result'':` (`:803-824`) reads only `total_cost_usd`
and `contextWindow`. The result event''s `is_error` / error `subtype` are **never
inspected**, and there is no error member in the `ConversationItem` union
(`transcript_reader.dart:41`). The nearest thing is `ToolResultMessage.isError` —
a *tool* failure, not an API failure.

Decide early: either parse `result.is_error` (small, and useful beyond the face),
or cut `rage` and let `error` cover both. Do not leave a state in the table with
nothing that can trigger it.

## Missing: a source for `listening`

Composer drafts are pane-local and silent (`claude_pane.dart:645-653`). Focus is
observable via the kernel''s focus tracker, which is probably the honest trigger —
"the user is typing at me" rather than "a draft changed".

## Not exposed: tool currently running

Derived per-card in the view (`conversation_view.dart:1064-1070`) by scanning for
an `AssistantToolUse` with no matching `ToolResultMessage`. Fine as a pattern to
copy; there is no session-level signal.

## Note on cadence

`ConversationController` coalesces `notifyListeners` through a zero-duration
timer (`conversation_controller.dart:111-114`) — at most once per microtask
drain. Good as a liveness heartbeat, useless as a token counter.

**Scope cut — D-107 amended 2026-08-09 (commitment 5).** Read this before the
signal audit above; it supersedes half of it.

The face no longer reads the primary session. It reports **Clide''s own state**
only, and the rain keeps the primary session''s load as ambient weather. So this
epic loses the mapping table it was mostly about.

## What stays here

- **Rain density from the primary session.** `busyStream` is the whole input:
  busy → the `effort` density, idle → the `idle` density, with the existing ramp
  doing the transition. This is now the *only* thing epic B reads from the
  primary session, and `ValueStream` gives it to us with replay for free.
- **The elapsed counter**, moved to the ambient layer with the rain — it is
  main-session information. Still needs the state machine to stamp the rising
  edge of `busyStream`, since no turn-start timestamp is recorded anywhere.
- **The power ladder**, unchanged, including minimise-suspension and the new
  `WidgetsBindingObserver` capability.

## What moves out

The seven-state face mapping. Under the split its sources are:

| State | Source | Epic |
|---|---|---|
| `listening` | focus on Clide''s input | E |
| `pensive` | his request in flight | D |
| `speaking` | his reply streaming | D |
| `error` | his session died (`endedStream`) | D |
| `rage` and any other editorial mood | **his own declared mood** | D (prompt: T-532) |
| `idle` | none of the above | — |

This also retires the "`rage` has no source, cut it or wire `result.is_error`"
finding above: under the split, a reaction to *content* is the one thing only
Clide can produce, and the mood channel is exactly that source.

## Consequence for sequencing

The face stays at `idle` until epic D exists — no state machine can make it live
sooner, because there is nothing of Clide''s to report yet. Epic B is therefore
much smaller than planned and no longer the thing that brings the strip to life;
D is. Worth reordering against that rather than discovering it mid-epic.

`thinking_delta` (dropped by `_onStreamEvent`, see above) is still worth adding —
but for **Clide''s** session, where it distinguishes "he is composing" from "he is
answering", not for the primary''s.', 'backlog', 'medium', NULL, NULL, NULL, '2026-08-08 22:47:58.074', '2026-08-09 10:05:42.650', NULL, '9c83af11397f2d1ef35e84cb2a541822', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYBN0EJ3B59YWV2Z9S54PRGG', 'task', '06FY73Z35AYAJQZ4MZMT25DPWC', 'Clide prompt templates — system prompt, observed/direct framing, lifecycle notices', 'Clide''s prompt is the product. Everything else in Epic D is plumbing — this is
where his voice, his restraint, and his sense of what is going on actually live.
Split out of T-519 because "write the system prompt" buried in a plumbing epic
gets three lines of attention and then ships as whatever the first draft was.

## Deliverable

A versioned set of prompt templates in one place, not string literals scattered
across the session code. Each template documented with *why* it says what it
says, because prompt text is the one part of this feature with no compiler, no
type system and no test that can tell you it drifted.

## Templates needed

**1. System prompt.** Establishes:
- Who Clide is — the IDE''s companion, watching a session he is not part of.
- The observed/direct split (D-107): `[observed]` lines are a conversation
  between the user and Claude that he is *watching* — remark rarely, briefly,
  and never pretend to be a participant. `[direct]` lines are addressed to him —
  always answer.
- That he sees **prose only, never tool calls or results** (D-107). He must know
  the shape of his own blindness, or he will confidently answer "what did that
  tool do?" — the known v1 limitation. Better that he says he cannot see it.
- Reply in the active locale (`app.locale`), one or two sentences, no preamble.
- Silence is a valid response. This is the hardest thing to get a model to do
  and deserves the most prompt real estate.

**2. Turn digest.** How each observed exchange is framed:
```
[observed] <user>: <prompt text>
[observed] claude: <assistant prose>
```
Open question the template has to answer: whether the user''s real name is used
(it is available) or a neutral label, and whether Clide addresses them by it.

**3. Direct address.** Distinguishing a question typed into Clide''s own input
from the conversation he is watching. Same channel, different contract.

**4. Lifecycle notices.** New, from the minimize design:
- **Detach** — minimizing the strip stops the digest, so Clide *misses* that
  stretch of conversation. On resume he is told he was detached and roughly how
  long for. Explicitly worth playing with: an ambient companion that knows it
  was away, and says something about it, is more alive than one that silently
  has a gap. Try it before deciding whether it is charming or tiresome.
- **Clear / restart** — the companion session tracks the primary''s clear and
  restart windows so it lives alongside the main conversation rather than
  accumulating context the user thinks they threw away.
- **Session restart at ~50 comments** (cost control, per the initiative) is a
  third kind of discontinuity. Decide whether Clide is told about this one at
  all, or whether it should be seamless — it is our bookkeeping, not an event in
  his world.

## Constraints inherited

- **Notable events only.** Turn finished, error, long run crossing a threshold,
  commit landed. Never per-token. Direct questions always answered.
- **Cap `max_tokens` ~100**, no thinking, and do **not** set `effort` — it errors
  on Haiku 4.5.
- **Cache shape matters more than brevity.** Haiku 4.5 has the highest prompt
  cache minimum of any current model (4096 tokens); under that, `cache_control`
  is silently ignored. A lean system prompt is therefore *uncached* for roughly
  its first 20 comments — the opposite of the usual instinct. Weigh prompt
  length against that threshold deliberately rather than trimming on reflex.

## Not in scope

Wiring, spawn, filtering and transport are T-519''s. This ticket owns the text
and the rationale for the text.

**Fifth template added — the mood side-channel (D-107 commitment 5, added
2026-08-09).** This is now the highest-risk part of the prompt work, and it has
an explicit kill condition.

Clide declares his own emotional state on every reply; the face renders it. This
is the only possible source for a reaction to *content* rather than to
mechanics — "you have made this mistake before" — which is what the whole
side-channel exists for, and which no derived signal can ever produce.

## Requirement

A demanded output template, not a hope. Two candidates to bake off against Haiku
4.5 rather than choose on paper:

- **Frontmatter-style** — a delimited header block before the prose.
- **JSON** — `{"mood": "...", "say": "..."}`.

Pick whichever Haiku follows most cleanly under the real system prompt, at the
real reply length, across the real trigger events. This runs through the CLI in
stream-json, so there is **no structured-output enforcement** — the model''s
compliance is the only guarantee there is, which is why it is measured rather
than assumed.

## The kill condition, stated up front

**If it is not very stable, it does not ship.** A malformed reply must never put
scaffolding in the speech bubble; a user who sees `{"mood":` in Clide''s mouth has
watched the illusion break, which costs more than the feature adds. So:

- Parse defensively and **strip aggressively** — anything template-shaped that
  survives parsing is removed from the displayed text, not passed through.
- A missing or unparseable mood means **keep the previous expression**, never a
  default reset and never a visible failure.
- If the bake-off shows the format bleeding under any of the real triggers,
  **drop the channel** and derive the expression mechanically from his session
  lifecycle. That loses `rage` and the editorial states — accepted, versus
  shipping something that visibly leaks.

Measure it: run each candidate format over a realistic set of trigger events and
count malformed replies. A format that is 95% clean is not clean — this renders
on every remark, so a 1-in-20 failure is visible within minutes of use.

## Vocabulary

The mood values are the face states that have no mechanical source. Keep the set
**small and closed**, and validate against it — an open vocabulary means the
model invents a mood the face cannot render, which is a silent failure that looks
like the channel working.', 'backlog', 'high', NULL, NULL, 'D-107', '2026-08-09 09:21:47.664', '2026-08-09 10:05:46.364', NULL, 'ddbb989c42b8c66966a6a9c66246e34d', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FY7W569QMQPKWCJ2PY9APGM8', 'task', '06FY73XR4NJEPDARY06397RVVC', 'A1: FaceState contract — enum, gaze/lean axis, per-state glyph table', '**This is the published seam with Epic B (T-517).** B codes against this contract; it must
land first and then stay stable. Everything here is specified concretely so B is not blocked
on the implementation.

Pure Dart — **no Flutter import** (no `Color`, no `TextStyle`). Colours come from tokens at
paint time, not from the spec. That keeps this file runnable under `dart test` and keeps the
table reviewable as data.

Target: `lib/builtin/clide_companion/src/face_state.dart`

## The contract

```dart
enum FaceState { idle, listening, pensive, effort, speaking, rage, error }

/// Which way the pupils point. Drives the lean offset too (D-107, T-514).
enum Gaze { none, left, forward, right }

class FaceSpec {
  final String eyes;        // always an eyes string — no alternate render path
  final String mouth;       // '''' when hidden
  final bool blink;         // lids drop ~130ms every 2.6–6.2s
  final bool thoughtDots;   // cycling . / .. / ... beside the head
  final bool talkCycle;     // mouth cycles the TALK sequence
  final bool jitter;        // ±1px face shake
  final bool orbit;         // bezel arc sweep
  final bool elapsed;       // [ Ns ] counter
  final bool clock;         // HH:MM under the face
  final int rainStreams;    // density — the load signal
  final double rainSpeed;   // cells/sec
  final double opacity;     // 1.0, or 0.45 for error
}
```

Widget props (what B passes to `ClideFace` in T-525):

| Prop | Type | Notes |
|---|---|---|
| `state` | `FaceState` | required |
| `gaze` | `Gaze` | default `Gaze.none` |
| `busyFor` | `Duration?` | drives `[ Ns ]`; **B owns this**, the widget does not time turns. Null renders no counter. |

**Lean is derived, not passed:** `none/forward → 0px`, `left → −8px`, `right → +8px`, applied
as the mouth''s x-offset from the eye centre and animated rather than snapped (D-107). One
number; do not add a `lean` prop.

## The table — ported from DeskLock `sim/face/index.html`

| state | eyes | mouth | blink | rain | extras |
|---|---|---|---|---|---|
| `idle` | `-   -` | `\_/` | ✓ | 2 @ 4 | clock |
| `listening` | `O   O` | `o` | ✓ | 16 @ 7 | — |
| `pensive` | `·   ·` | `~` | — | 7 @ 5 | thoughtDots |
| `effort` | `>   <` | `~` | — | 40 @ 16 | jitter, orbit, elapsed |
| `speaking` | `^   ^` | `o` | ✓ | 14 @ 9 | talkCycle |
| `rage` | `▼   ▼` | `━` | — | 34 @ 20 | jitter |
| `error` | `x   x` | `-` | — | 0 @ 0 | opacity 0.45 |

`TALK = [''o'', ''O'', ''-'', ''O'', ''='', ''o'']` at ~150ms/frame. Blink replaces every non-space eye
char with `_` for ~130ms. Thought dots cycle at ~480ms. Breathe is a 4.5s ±9px vertical bob
applied to the whole face group (not per-state).

## Deliberate deviation from DeskLock: `rage` is a scowl, not a table-flip

DeskLock renders `rage` as a 3-frame kaomoji sequence — `(°□°) ┬─┬` → `(╯°□°)╯︵ ┻━┻` →
`┬─┬ ノ( º_º ノ)` — pushed as whole lines through the eye slot. **Not ported.** Two reasons,
and the second is the real one:

1. **Two of its glyphs are missing from the bundled fonts**, verified with `fc-query` against
   `JetBrainsMono-Regular.ttf`: `︵` (U+FE35) and `ノ` (U+30CE — katakana again; the
   initiative''s font finding only covered the *rain* glyph set, so this is a second instance
   of the same bug class). `╯` and `□` are fine, inside `2500-25a1`.
2. **It needs a second render path.** Whole-line text through the eye slot is not the
   eyes+mouth model every other state uses, so it drags a `KaomojiFrame` class, a frame
   timer, and a branch through the painter into the contract — for the state you see least.

`rage` instead uses the ordinary grammar: brows-down eyes `▼` (U+25BC) and a hard flat mouth
`━` (U+2501), with `jitter` already carrying the agitation and rain spiking to 34 @ 20. Both
glyphs verified covered. Net effect on this epic: **no `KaomojiFrame`, no frame timer, no
second branch in the painter, no font substitutions** — one more row in the same table.

If the table-flip is ever wanted back, it is a deliberate re-open needing a bundled font that
covers kana, which trades against prefer-zero-deps (D-31/D-42).

## Done when

- Enum + spec + const table exist, pure Dart, no Flutter import.
- A `specFor(FaceState)` lookup returns the const spec.
- Unit tests: every state has a spec; rain density is monotonic across
  idle < pensive < speaking < listening < rage < effort; error has zero rain; **every glyph in
  the table is asserted against the covered set** so a future edit reintroducing an uncovered
  glyph fails the suite rather than the render.
- Epic B (T-517) is told the contract is available.

That last test is the one that matters — it is the guard that stops this bug class recurring,
and it has now bitten twice.

## DONE (2026-08-09)

- `lib/builtin/clide_companion/src/face_state.dart` — enum, `Gaze` + derived lean,
  `FaceSpec`, the seven const specs, `specFor()`, timing constants, `kVerifiedFaceGlyphs`.
  Pure Dart, no Flutter import; runs under `dart test`.
- `test/builtin/clide_companion/face_state_test.dart` — 17 tests, all green.
- `make analyze`, `make format` and `make test` (50 tests) all clean.

Contract shipped exactly as published on T-517. No deviations, so Epic B needs no rework.

### The glyph guard is proven, not just written

The ticket called this the test that matters. A guard that has never failed is not evidence,
so it was verified by sabotage: `rage`''s eyes were temporarily changed to `ノ   ノ` (the exact
katakana that hid inside DeskLock''s kaomoji). Two tests failed, and the message named the
codepoint and the fix:

```
Unverified glyph(s) in the face table: "ノ" (U+30CE). Verify against BOTH
assets/fonts/jetbrains_mono/ and assets/fonts/fira_mono/ with fc-query,
then add to kVerifiedFaceGlyphs.
```

Reverted, green again. A third instance of this bug class now fails the suite instead of
rendering as tofu.

### Correction to the earlier font work

Both prior checks (initiative, T-516 breakdown) verified against **JetBrains Mono only**.
That was insufficient: the mono face is user-selectable (D-101) and **Fira Mono is also
bundled**, so a glyph present in one and absent from the other would render as tofu for
anyone who switched fonts, and would break goldens on whichever font CI happens to use.

Re-verified every face glyph against **both** fonts — all present, so no table change was
needed, but the reasoning in `kVerifiedFaceGlyphs`'' doc comment and in the test''s failure
message now says "both", with the verification recipe inline. **T-522 (rain glyph set)
inherits this**: check the rain glyphs against both fonts, not just JetBrains.

### Tests worth noting beyond the ticket''s list

- **Eye rows are all the same width**, and blink preserves that width. The painter centres
  the mouth against the eye row, so a ragged row would silently make the lean offset mean
  something different per state.
- **No astral glyphs / no surrogate pairs** — anything outside the BMP breaks the per-cell
  monospace grid.
- **`specFor` returns the identical instance** per call, so the painter''s identity-based
  `shouldRepaint` (T-524) cannot be defeated by spec churn.
- **Talk cycle loops seamlessly** (first frame equals last).

Amended by D-107 commitment 5 (2026-08-09): the state table''s *sources* change, the table itself does not. `listening`, `pensive`, `speaking` and `error` are now driven by **Clide''s own session**, not the primary''s; `rage` (and any other editorial expression) comes from a mood he declares himself on each reply (T-532). Rain density remains the **primary** session''s load, moved conceptually from readout to ambient weather, and the elapsed counter moves with it.

Nothing in `face_state.dart` needs to change for this — the contract was always ''here is a state, render it'', and it stays that. What changes is who computes the state, which was never this ticket''s business. Worth knowing when reading the per-state doc comments, several of which still describe the old primary-session triggers (e.g. `pensive`: ''busy, but no partial- item has arrived yet''). Those comments are stale as *sources*; the visual contract they describe is intact.', 'done', 'high', NULL, NULL, NULL, '2026-08-09 00:33:47.085', '2026-08-09 10:05:54.500', NULL, 'ec2264e92b97582e9742d651fafb2f87', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
