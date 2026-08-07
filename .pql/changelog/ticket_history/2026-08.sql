INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FD0ABC7QNEC3XCTV73YPSGR4', 'description', 'User report 2026-06-16: Claude Code''s **remote-control** feature (start / monitor / steer a running Claude Code session remotely — e.g. from claude.ai or the mobile app) is **not plumbed into clide**.

clide hosts the `claude` CLI as a stream-json child (`--session-id` / `--resume`, D-77). For remote control to work through clide, a clide-hosted session needs to be discoverable + steerable by the remote-control surface the same way a terminal-launched `claude` is.

**Step 1 — characterize (don''t assume the mechanism):** determine exactly what Claude Code exposes for remote control on the running CLI version. Likely touch points:
- the `~/.claude/sessions/<pid>.json` live-session registry we characterized in T-437 (PID-keyed: sessionId, cwd, version, kind, entrypoint, status) — is this what the remote-control surface enumerates? clide-spawned sessions DO write an entry (we saw `entrypoint: sdk-cli`). Confirm whether clide''s entry is visible/controllable remotely, or whether `entrypoint: sdk-cli` / headless spawn excludes it.
- any flag / capability in the `initialize` stream-json probe (T-411/T-151 cache) advertising remote control.
- whether enrollment requires the interactive TUI (and so is suppressed under clide''s stream-json spawn).

**Step 2 — plumb:** wire clide so a clide-hosted session participates in remote control (register correctly / pass the needed flag), and surface its state in the UI (e.g. an indicator that the session is remote-controllable / being driven remotely). If it conflicts with clide''s session ownership (pane pins a session-id, T-156), document the boundary.

**Open question:** is the goal (a) clide sessions become remotely controllable from claude.ai/mobile, or (b) clide can act as a remote controller of other sessions? Default read is (a). Confirm with the user before building.

Related: D-77 (stream-json session model), T-437 (sessions registry characterization), T-156 (clide owns session lifecycle), T-411 (capability probe).', 'User report 2026-06-16: Claude Code''s **remote-control** feature (start / monitor / steer a running Claude Code session remotely — e.g. from claude.ai or the mobile app) is **not plumbed into clide**.

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
  which runs a per-directory daemon with `--spawn same-dir|worktree|session`.', NULL, '2026-08-07 12:21:08', '2026-08-07 12:21:08.809', '2026-08-07 12:21:08.809', NULL, '3908441f5df127b533670e4b4e35b283', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'description', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

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
`2>/dev/null || true`.', NULL, '2026-08-07 12:30:44', '2026-08-07 12:30:44.880', '2026-08-07 12:30:44.880', NULL, 'aaccee60badf01e93df53301dd52dc79', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'priority', 'medium', 'high', NULL, '2026-08-07 12:30:59', '2026-08-07 12:30:59.962', '2026-08-07 12:30:59.962', NULL, '98d21d1e300343931ea7601b217a3b8e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'title', 'pre-commit changelog hook leaves ticket_deps/ticket_idmap unstaged', 'pre-commit hook stages no .pql/changelog files (pql plan export --stage)', NULL, '2026-08-07 12:30:59', '2026-08-07 12:30:59.967', '2026-08-07 12:30:59.967', NULL, '4f3d1bf15c90af6ba608067a90d78e77', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGYS06SDJGZ4W3Z9V9HDEATW', 'description', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

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
`2>/dev/null || true`.', 'The pre-commit hook re-exports + stages .pql/changelog on commit but only catches the tickets + ticket_history tables — it leaves ticket_deps (blocker edges) and ticket_idmap (new T-NNN <-> record_id mappings) UNSTAGED. Seen repeatedly this session (D-103 re-sequencing blockers; T-495 id mapping), each needing a manual follow-up commit; otherwise the planning state silently doesn''t persist and a later branch switch drops it — exactly the failure the hook exists to prevent. Fix: stage ALL of .pql/changelog/ (git add .pql/changelog/), not just the tables the export rewrote. Repro: pql ticket block X --by Y + create a ticket, commit unrelated files, observe ticket_deps/ticket_idmap still modified afterward.

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
failure is visible instead of silent.', NULL, '2026-08-07 12:31:41', '2026-08-07 12:31:41.109', '2026-08-07 12:31:41.109', NULL, '52366e812f9b77586b07f322791e4fd3', 2) ON CONFLICT(hash) DO NOTHING;
