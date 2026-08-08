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
