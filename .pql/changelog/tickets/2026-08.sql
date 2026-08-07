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
  which runs a per-directory daemon with `--spawn same-dir|worktree|session`.', 'backlog', 'medium', NULL, NULL, NULL, '2026-06-16 11:20:36', '2026-08-07 12:21:08.809', NULL, 'a420c6a2175901ac10d20685907847a5', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at > tickets.updated_at OR (excluded.updated_at = tickets.updated_at AND excluded.hash > tickets.hash);
