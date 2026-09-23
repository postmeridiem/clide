INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G64PCW3KDVCV1X83543FA5JC', 'description', NULL, 'Spike write-up: `docs/spikes/web-target-2026-09-02.md`. Built `flutter build web --wasm` at v2.12.0, served it, loaded it in Chrome, read the console and access log.

**The build succeeds and the app boots surprisingly far** — WASM, all fonts, all 12 themes, i18n catalogs, extension registration, keymap — then throws `Unsupported operation: _Namespace` and never paints. That''s `dart:io`''s filesystem layer, which has no web implementation.

## The finding that matters

D-100 fences `dart:ffi` and adds a `flutter build web --wasm` CI step "so the fence can''t silently rot". **That gate proves the tree compiles; it cannot prove the tree boots** — and those two came apart. This is a D-108 case in the wild: a negative check ("it didn''t fail to compile") standing in for a positive one, so compiling got mistaken for working.

Two holes, found only by running it:

1. **`main.dart:114`** — `resolveWorkspaceRoot(Directory.current)` sits six lines ABOVE the `if (!kIsWeb)` guard protecting everything after it. Constructing a `Directory` is inert on web; resolving one is not. **Fixed in the spike commit** (one line); took the boot from "themes loaded" to "extensions registered".
2. **A second `_Namespace`** during extension activation — NOT fixed. Twelve files on the activation path call existsSync/createSync/listSync/readAsStringSync: terminal_pane, conversation_view, path_preset_control, agent_bootstrap, account_registry, claude_pane, claude_config, cli_install, watchdog, toolchain_paths, file_log_sink, tree_sitter_ffi.

## Scope of THIS ticket

Keep it to making the fence honest — not porting the app:

- Plug hole 2 (and any it reveals) so the app paints.
- **Make the CI web job boot the bundle and assert first paint**, not merely compile it. Without that the next hole lands the same silent way. The harness exists (`tools/ui/`, D-26) and is already ticketed as **T-443**; it is currently dead — the Playwright browser isn''t even installed locally, which is how this went unnoticed.
- Quieten the i18n fallback probe: it emits ~20 404s + red engine errors per clean boot (probing `assets/i18n/en/*` before `en_us`), burying real errors exactly when you need to read them.

## Explicitly NOT this ticket

There is no IPC client on web at all — `main.dart:561` passes `daemonClientFactory: kIsWeb ? null : …`. Even with every hole plugged the UI would paint and do nothing, because the transport is a Unix socket a browser can''t open. That''s an absent layer, not a bug, and it''s a product decision (D-100 says web is a UI/e2e surface, not a functional replacement).

**If that decision is ever revisited, sequence it behind T-399.** "RemoteExecutionContext seam — subsystems stop calling Process.run/File directly" is verbatim the refactor a web backend needs; the web port and the SSH-remote epic (T-336) are the same work with a different pipe on the end. Doing them independently builds the same seam twice.

Note also that with such a seam the terminal is NOT a blocker: xterm.dart renders fine in a browser, and only the *spawn* is native. D-100''s "no PTY/terminal on web" is true of a standalone build, not of a front end to a host that owns the pty.', NULL, '2026-09-02 13:40:57', '2026-09-02 13:40:57.132', '2026-09-02 13:40:57.132', NULL, 'b6e9aab0c501f92e0a87a2c9ea157cd0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845R1ZRAZJ1V771N975HFXG', 'description', 'Give ClideSelectionArea a contextMenuBuilder so right-click over selected read-only prose offers Copy / Select all. Covers the conversation view and the team panel today, and every surface story T-582 adds.', 'Give ClideSelectionArea a contextMenuBuilder so right-click over selected read-only prose offers Copy / Select all. Covers the conversation view and the team panel today, and every surface T-583 adds.', NULL, '2026-09-08 17:35:47', '2026-09-08 17:35:47.339', '2026-09-08 17:35:47.339', NULL, '3af0735b5021be8f03433bd0a1aae5cd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845PXTGB6PKKRMCC614P2RC', 'status', 'backlog', 'in_progress', NULL, '2026-09-08 17:35:53', '2026-09-08 17:35:53.216', '2026-09-08 17:35:53.216', NULL, 'ca918050d72f924c3604b6c13834f900', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845PXTGB6PKKRMCC614P2RC', 'status', 'in_progress', 'done', NULL, '2026-09-08 20:15:47', '2026-09-08 20:15:47.186', '2026-09-08 20:15:47.186', NULL, '0adcea6f0f860901ffb0f425b453f3cb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845QBAC9SA9V90R7Q6BY1S0', 'status', 'backlog', 'done', NULL, '2026-09-08 20:15:47', '2026-09-08 20:15:47.189', '2026-09-08 20:15:47.189', NULL, 'c8e58febcfa1d77e1fb3cbcb785c9243', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845R1ZRAZJ1V771N975HFXG', 'status', 'backlog', 'done', NULL, '2026-09-08 20:15:47', '2026-09-08 20:15:47.189', '2026-09-08 20:15:47.189', NULL, 'cf7abc5ce713bb234bb78276c71aca43', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845QPVQWAARNGX951ZMN7C8', 'status', 'backlog', 'in_progress', NULL, '2026-09-08 20:15:49', '2026-09-08 20:15:49.082', '2026-09-08 20:15:49.082', NULL, '147a37104d8797086983c9fff5e0f7fb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845QPVQWAARNGX951ZMN7C8', 'status', 'in_progress', 'done', NULL, '2026-09-08 21:06:54', '2026-09-08 21:06:54.788', '2026-09-08 21:06:54.788', NULL, '8773165069c8b3de4338a7b0b67d49df', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845RHZ4JB3SQNQBFTVQ383G', 'status', 'backlog', 'done', NULL, '2026-09-08 21:06:54', '2026-09-08 21:06:54.796', '2026-09-08 21:06:54.796', NULL, 'd3eda7025087a1f595f3a3e5888c38b3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G845PDHQFC3XGEQ68S5QYXCR', 'status', 'backlog', 'done', NULL, '2026-09-09 06:27:10', '2026-09-09 06:27:10.917', '2026-09-09 06:27:10.917', NULL, '343e1c7deb5db62b051d67783eb96a44', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G89XGF4AFJXVDXNH6X8C7B5G', 'status', 'backlog', 'done', NULL, '2026-09-09 07:09:25', '2026-09-09 07:09:25.461', '2026-09-09 07:09:25.461', NULL, 'f784fc663ede592948b6deddb7d594c2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G8AA5V21410GE02SR26EPD6W', 'status', 'backlog', 'done', NULL, '2026-09-09 07:55:04', '2026-09-09 07:55:04.241', '2026-09-09 07:55:04.241', NULL, '2bacee21fd46a7979a2810f82528b895', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSTYAH54YEBZ4JE3ABQW4B8', 'status', 'backlog', 'done', NULL, '2026-09-23 06:20:01', '2026-09-23 06:20:01.655', '2026-09-23 06:20:01.655', NULL, '4c1d53de91892c7482eaebd0217f5638', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6DH7C6GQN9WNKQNXR', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 06:23:10', '2026-09-23 06:23:10.680', '2026-09-23 06:23:10.680', NULL, 'dcc981896efcb3344c85667108e51470', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6DH7C6GQN9WNKQNXR', 'status', 'in_progress', 'done', NULL, '2026-09-23 06:27:55', '2026-09-23 06:27:55.949', '2026-09-23 06:27:55.949', NULL, '65063006307fb43461766e7839eaa0e1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSWVHN0QF86TPSEFGW2JXFW', 'description', NULL, 'A message sent from the Claude composer while a turn is still running is queued by the CLI, but clide renders it as an ordinary user turn — the user can''t tell it hasn''t been picked up yet, and can''t take it back.

Want: a message sent mid-turn shows as **queued** (distinct styling, e.g. muted with a "queued" tag) until the session actually consumes it, and while queued it has a **dismiss** affordance that removes it so it is never sent.

Today: `StreamJsonSession.send` writes the stream-json user message to stdin immediately and echoes it locally as a normal user item; clide tracks no queue (the only `_queue` is permission prompts). Once written to stdin the CLI owns the message, so dismiss is not possible in the current design.

Likely shape: while `busy`, `send` holds the message in a clide-side queue instead of writing it (echo it as a queued item); on the turn''s `result`, flush the head to stdin and flip it to a normal user item. Dismiss drops it from the queue and removes the echo. Queued items belong in/near the interaction zone (D-78), not as inline interactive widgets in the conversation stream.

Open: whether several queued messages flush one per turn or all at once (the CLI merges consecutive queued messages into one turn today — verify); CLI parity (D-6) — e.g. a `clide claude queue list|drop` verb.

Acceptance: sending during a running turn shows the message as queued; dismissing it removes it and nothing reaches the session; an undismissed message sends when the turn ends and then renders as a normal user turn; covered by stream_json_session + pane tests.', NULL, '2026-09-23 06:28:23', '2026-09-23 06:28:23.349', '2026-09-23 06:28:23.349', NULL, '9e90adf5f505d2bad1518da52f901f68', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSWVHN0QF86TPSEFGW2JXFW', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 06:28:47', '2026-09-23 06:28:47.325', '2026-09-23 06:28:47.325', NULL, '2a911a339087c671e6871fb0ab429646', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSY64ZNRTGVRWGX504JH3TM', 'description', NULL, 'D-6 parity for the Claude pane''s queued messages (T-587): the UI can list, edit and dismiss messages queued mid-turn, but no `clide` verb can. Wanted: `clide claude queue list | edit <id> <text> | drop <id>` against the primary session.

There is no `claude` session surface on the CLI at all today (not even send), so this needs the bridge first: the dispatcher handler is Flutter-free and the queue lives on `StreamJsonSession` in the Claude extension. Pattern to follow: `claude account` (dispatcher publishes on the bus, extension acts), plus an injected read callback for `list` since it must return data.

Session API already exists: `queued`, `editQueued`, `dismissQueued`, `holdQueue` / `releaseQueue`.', NULL, '2026-09-23 06:34:12', '2026-09-23 06:34:12.275', '2026-09-23 06:34:12.275', NULL, '90ca887f27c56e63c50bff2972b15ed1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSWVHN0QF86TPSEFGW2JXFW', 'description', 'A message sent from the Claude composer while a turn is still running is queued by the CLI, but clide renders it as an ordinary user turn — the user can''t tell it hasn''t been picked up yet, and can''t take it back.

Want: a message sent mid-turn shows as **queued** (distinct styling, e.g. muted with a "queued" tag) until the session actually consumes it, and while queued it has a **dismiss** affordance that removes it so it is never sent.

Today: `StreamJsonSession.send` writes the stream-json user message to stdin immediately and echoes it locally as a normal user item; clide tracks no queue (the only `_queue` is permission prompts). Once written to stdin the CLI owns the message, so dismiss is not possible in the current design.

Likely shape: while `busy`, `send` holds the message in a clide-side queue instead of writing it (echo it as a queued item); on the turn''s `result`, flush the head to stdin and flip it to a normal user item. Dismiss drops it from the queue and removes the echo. Queued items belong in/near the interaction zone (D-78), not as inline interactive widgets in the conversation stream.

Open: whether several queued messages flush one per turn or all at once (the CLI merges consecutive queued messages into one turn today — verify); CLI parity (D-6) — e.g. a `clide claude queue list|drop` verb.

Acceptance: sending during a running turn shows the message as queued; dismissing it removes it and nothing reaches the session; an undismissed message sends when the turn ends and then renders as a normal user turn; covered by stream_json_session + pane tests.', 'A message sent from the Claude composer while a turn is still running is queued by the CLI, but clide renders it as an ordinary user turn — the user can''t tell it hasn''t been picked up yet, and can''t take it back.

Want: a message sent mid-turn shows as **queued** (distinct styling, e.g. muted with a "queued" tag) until the session actually consumes it, and while queued it has a **dismiss** affordance that removes it so it is never sent.

Today: `StreamJsonSession.send` writes the stream-json user message to stdin immediately and echoes it locally as a normal user item; clide tracks no queue (the only `_queue` is permission prompts). Once written to stdin the CLI owns the message, so dismiss is not possible in the current design.

Likely shape: while `busy`, `send` holds the message in a clide-side queue instead of writing it (echo it as a queued item); on the turn''s `result`, flush the head to stdin and flip it to a normal user item. Dismiss drops it from the queue and removes the echo. Queued items belong in/near the interaction zone (D-78), not as inline interactive widgets in the conversation stream.

Open: whether several queued messages flush one per turn or all at once (the CLI merges consecutive queued messages into one turn today — verify); CLI parity (D-6) — e.g. a `clide claude queue list|drop` verb.

Acceptance: sending during a running turn shows the message as queued; dismissing it removes it and nothing reaches the session; an undismissed message sends when the turn ends and then renders as a normal user turn; covered by stream_json_session + pane tests.

Done: clide-side queue on StreamJsonSession (submit/editQueued/dismissQueued/holdQueue/releaseQueue), flushed one per turn on result; QueuedMessagesDock above the composer with edit (holds the queue while editing) and dismiss. CLI verb split out to T-588.', NULL, '2026-09-23 06:34:13', '2026-09-23 06:34:13.635', '2026-09-23 06:34:13.635', NULL, '71dcc0b9f1b8f43f474396b780601b5d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSWVHN0QF86TPSEFGW2JXFW', 'status', 'in_progress', 'done', NULL, '2026-09-23 06:34:14', '2026-09-23 06:34:14.140', '2026-09-23 06:34:14.140', NULL, 'b924f50226cac7af44c61206bc2c1023', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66FTCTWHH9AQTNFKR', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 06:34:48', '2026-09-23 06:34:48.880', '2026-09-23 06:34:48.880', NULL, 'a008f11e7c75887d47f9e81c2500a88f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'description', NULL, 'After an app reload the primary Claude pane continues its conversation (`--resume`, D-77), but secondary panes disappear. By design today: D-41 made secondaries ephemeral — each spawn gets a random id (`freshSessionId()`, claude_pane.dart) and the open secondary tabs are not persisted. The transcripts survive on disk (reachable via `/resume`), so nothing is lost; the tabs just don''t come back.

User report 2026-09-23: resume "works well … the main conversation seems to reliably continue after an app reload. Only thing is that conversations in secondary panels disappear."

Want: on relaunch, restore the workspace''s open secondary panes, each resuming its own session, in their previous order.

Shape: persist the ordered list of secondary session ids per workspace in user-scope state (D-93/D-53 — not in the repo); on boot, spawn a secondary per entry with `resume: true` when its transcript exists (skip entries whose transcript is gone). Closing a secondary removes it from the list. Forks (`--fork-session`) persist their resolved claude session id, not the fork source.

Needs a D-41 amendment: "secondaries are ephemeral" → "secondaries persist until closed".

Acceptance: open two secondaries, talk in each, restart clide → both tabs return with their conversations; a closed secondary does not come back; a secondary whose transcript was deleted is dropped silently.', NULL, '2026-09-23 06:41:25', '2026-09-23 06:41:25.788', '2026-09-23 06:41:25.788', NULL, '6083658209193b8e3df9c15aab4e2faa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7CEKQCMZAV751402G', 'description', 'Check for new versions on startup (or on demand via command palette). Show a non-intrusive notification when an update is available. Support in-place update without losing running Claude sessions (tmux sessions survive). Respect POLICY.md: no silent network calls on default launch path — the check should be opt-in or gated behind a setting. Consider delta updates for bandwidth efficiency.

─────────────────────────────────────────────
REFINED 2026-06-11

## Current state (grounding)
- Version is surfaced at runtime via `lib/src/build_info.g.dart` (`clideVersion`,
  `clideCommit`, `clideDate`, `clideRepository` = github.com/postmeridiem/clide),
  generated from pubspec by `make gen-build-info`. This is the "installed version".
- Install layout (`make install`): Linux → bundle at `~/.local/lib/clide/`, C client
  at `~/.local/bin/clide`, desktop file + icons. macOS → `~/Applications/clide.app`
  + `~/.local/bin/clide`. Windows: not yet shipped.
- clide currently makes NO outbound HTTP calls anywhere in `lib/`. Self-update would
  be the FIRST one — so this is a policy-sensitive feature, not just plumbing.
- tmux owns Claude session persistence (D-41); the app re-attaches on restart. An
  in-place update that restarts the app does NOT lose sessions — they live in tmux,
  outside the bundle.

## HARD CONSTRAINTS (non-negotiable)
- **D-64 (no telemetry / no phone-home):** "No auto-update checks without user
  action." This is STRICTER than this ticket''s original "opt-in or gated behind a
  setting" wording. A background/startup check — even one a setting enabled — runs
  "without user action" at that launch and conflicts with D-64. RESOLUTION: the
  version check must be **explicitly user-initiated every time** (a command-palette
  "Check for updates…" action / an About-screen button). If we ever want a
  startup/periodic check, that needs a deliberate D-64 amendment first — flag, don''t
  assume.
- **POLICY.md §"no network on the default launch path":** opening the app, a file,
  or typing must never trigger the fetch. The update check + download are explicit
  user actions, so they''re allowed — but must meet the §"grudging allowance"
  criteria: clear error on failure (not silent), cached result, app fully functional
  if the fetch fails.

## BLOCKING PREREQUISITE (likely its own ticket under T-46)
There is no release channel to update FROM today: only 2 git tags (v2.0.0, v2.1.0)
despite being at 2.3.3, no CI (`.github/workflows` is empty), and no published binary
artifacts. Self-update is meaningless without:
  1. Consistent, automated release tagging (every `release vX.Y.Z` commit → a tag).
  2. CI that builds the per-platform bundles and publishes them as GitHub Releases.
  3. Each artifact accompanied by a checksum AND a signature (POLICY.md: "behavior is
     determined by the SIGNED release artifact"). An unsigned/unverified download
     would break the trust model the update is supposed to preserve.
  4. A machine-readable "latest version" source — the GitHub Releases API
     (`/repos/postmeridiem/clide/releases/latest`) is the zero-infra option; a
     committed `latest.json` manifest is the alternative.
RECOMMENDATION: split this prerequisite into a sibling story "Release channel: CI
build + signed GitHub Releases + version manifest" and make T-47 depend on it.

## DECISIONS TO MAKE (surface before building)
1. Check source: GitHub Releases API vs a hosted `latest.json`. (Lean: Releases API —
   no extra infra, origin is already GitHub.)
2. Signature scheme + verification: minisign/age/cosign? Where does the public key
   live (vendored in-repo, per POLICY.md provenance)?
3. Delivery: full bundle replacement vs delta/binary-patch (original ask). Lean full
   for v1 — deltas are a bandwidth optimization, not correctness; revisit if size hurts.
4. Apply strategy per platform: Linux is easy (swap `~/.local/lib/clide/` + the
   `~/.local/bin/clide` client atomically, then relaunch). macOS `.app` replacement +
   notarization/quarantine handling is harder. Windows out of scope until it ships.
5. Privilege: user-local installs (`~/.local`, `~/Applications`) need no sudo — good.
   A system-wide install would; declare user-local only for v1.

## PROPOSED SCOPE / PHASES (each independently shippable)
P0 (prereq, separate ticket): release channel — tags + CI + signed GitHub Releases.
P1: "Check for updates…" command (palette + About-screen button). Explicit fetch of
    the latest release, semver-compare against `clideVersion`, non-intrusive ToastService
    notification ("clide X.Y.Z is available") with a "What''s changed" link to the release
    notes. No download yet. Clear error toast on network failure. Fully covers the D-64 /
    POLICY-compliant "notify" half of the story.
P2: download + signature/checksum verify into a staging dir; show progress; verify before
    touching the install.
P3: apply + relaunch (Linux first): atomic swap of bundle + client, restart the app;
    tmux sessions survive (D-41). Confirm-before-apply.
P4 (optional): macOS apply path (.app swap + quarantine), delta updates.

## ACCEPTANCE (for the full story; refine per-phase ticket)
- No network call on any default launch path (verified — grep + a test that boot makes
  no outbound connection).
- "Check for updates" only runs on explicit user action; failure surfaces a clear
  toast, never a silent hang or degraded launch.
- A downloaded update is signature+checksum verified before it can replace the install;
  verification failure aborts with the old version intact.
- Applying an update and relaunching preserves running Claude/tmux sessions.
- Version comparison is correct semver (2.3.10 > 2.3.9, pre-release handling defined).

## REFERENCES
POLICY.md (network rule + grudging-allowance criteria); D-64 (no phone-home);
D-41 (tmux session persistence); `lib/src/build_info.g.dart` (version source);
`lib/kernel/src/toast.dart` (ToastService — the notification); settings bool pattern
(`app.*.enabled`, `lib/kernel/src/extensions_manager.dart`); `Makefile` install target
(per-platform layout); parent epic T-46 (cross-platform installer).

DECISION (user, 2026-06-28): MANUAL-ONLY. The update check is a ''Check for updates'' button inside the About-screen box — explicitly user-initiated every time, so NO D-64 amendment is needed (manual checks already comply). A ''check on startup'' checkbox (the opt-in poll) is DEFERRED, not rejected: it would sit next to the button later, and only THEN would it need the narrow, default-off D-64 amendment we discussed (a data-free version fetch; telemetry stays banned full stop). This supersedes any background/periodic-poll framing in the original scope. Build-order caveat: P1 (the About button) still needs the release channel (P0: CI + signed GitHub Releases + a version manifest) to have something to check against — /releases/latest 404s when no Releases are published (the repo has 2 tags, which are NOT Releases). So either P0 lands first, or P1 ships with graceful ''up to date / couldn''t reach GitHub'' handling that no-ops until Releases exist.

P0 release-channel prerequisite is now T-491 (CI builds + signed package artifacts on Releases). P1 (this About button) is independent of it — Releases already exist to check against; P2/P3 (download+verify+apply) depend on T-491.', 'Check for new versions on startup (or on demand via command palette). Show a non-intrusive notification when an update is available. Support in-place update without losing running Claude sessions (tmux sessions survive). Respect POLICY.md: no silent network calls on default launch path — the check should be opt-in or gated behind a setting. Consider delta updates for bandwidth efficiency.

─────────────────────────────────────────────
REFINED 2026-06-11

## Current state (grounding)
- Version is surfaced at runtime via `lib/src/build_info.g.dart` (`clideVersion`,
  `clideCommit`, `clideDate`, `clideRepository` = github.com/postmeridiem/clide),
  generated from pubspec by `make gen-build-info`. This is the "installed version".
- Install layout (`make install`): Linux → bundle at `~/.local/lib/clide/`, C client
  at `~/.local/bin/clide`, desktop file + icons. macOS → `~/Applications/clide.app`
  + `~/.local/bin/clide`. Windows: not yet shipped.
- clide currently makes NO outbound HTTP calls anywhere in `lib/`. Self-update would
  be the FIRST one — so this is a policy-sensitive feature, not just plumbing.
- tmux owns Claude session persistence (D-41); the app re-attaches on restart. An
  in-place update that restarts the app does NOT lose sessions — they live in tmux,
  outside the bundle.

## HARD CONSTRAINTS (non-negotiable)
- **D-64 (no telemetry / no phone-home):** "No auto-update checks without user
  action." This is STRICTER than this ticket''s original "opt-in or gated behind a
  setting" wording. A background/startup check — even one a setting enabled — runs
  "without user action" at that launch and conflicts with D-64. RESOLUTION: the
  version check must be **explicitly user-initiated every time** (a command-palette
  "Check for updates…" action / an About-screen button). If we ever want a
  startup/periodic check, that needs a deliberate D-64 amendment first — flag, don''t
  assume.
- **POLICY.md §"no network on the default launch path":** opening the app, a file,
  or typing must never trigger the fetch. The update check + download are explicit
  user actions, so they''re allowed — but must meet the §"grudging allowance"
  criteria: clear error on failure (not silent), cached result, app fully functional
  if the fetch fails.

## BLOCKING PREREQUISITE (likely its own ticket under T-46)
There is no release channel to update FROM today: only 2 git tags (v2.0.0, v2.1.0)
despite being at 2.3.3, no CI (`.github/workflows` is empty), and no published binary
artifacts. Self-update is meaningless without:
  1. Consistent, automated release tagging (every `release vX.Y.Z` commit → a tag).
  2. CI that builds the per-platform bundles and publishes them as GitHub Releases.
  3. Each artifact accompanied by a checksum AND a signature (POLICY.md: "behavior is
     determined by the SIGNED release artifact"). An unsigned/unverified download
     would break the trust model the update is supposed to preserve.
  4. A machine-readable "latest version" source — the GitHub Releases API
     (`/repos/postmeridiem/clide/releases/latest`) is the zero-infra option; a
     committed `latest.json` manifest is the alternative.
RECOMMENDATION: split this prerequisite into a sibling story "Release channel: CI
build + signed GitHub Releases + version manifest" and make T-47 depend on it.

## DECISIONS TO MAKE (surface before building)
1. Check source: GitHub Releases API vs a hosted `latest.json`. (Lean: Releases API —
   no extra infra, origin is already GitHub.)
2. Signature scheme + verification: minisign/age/cosign? Where does the public key
   live (vendored in-repo, per POLICY.md provenance)?
3. Delivery: full bundle replacement vs delta/binary-patch (original ask). Lean full
   for v1 — deltas are a bandwidth optimization, not correctness; revisit if size hurts.
4. Apply strategy per platform: Linux is easy (swap `~/.local/lib/clide/` + the
   `~/.local/bin/clide` client atomically, then relaunch). macOS `.app` replacement +
   notarization/quarantine handling is harder. Windows out of scope until it ships.
5. Privilege: user-local installs (`~/.local`, `~/Applications`) need no sudo — good.
   A system-wide install would; declare user-local only for v1.

## PROPOSED SCOPE / PHASES (each independently shippable)
P0 (prereq, separate ticket): release channel — tags + CI + signed GitHub Releases.
P1: "Check for updates…" command (palette + About-screen button). Explicit fetch of
    the latest release, semver-compare against `clideVersion`, non-intrusive ToastService
    notification ("clide X.Y.Z is available") with a "What''s changed" link to the release
    notes. No download yet. Clear error toast on network failure. Fully covers the D-64 /
    POLICY-compliant "notify" half of the story.
P2: download + signature/checksum verify into a staging dir; show progress; verify before
    touching the install.
P3: apply + relaunch (Linux first): atomic swap of bundle + client, restart the app;
    tmux sessions survive (D-41). Confirm-before-apply.
P4 (optional): macOS apply path (.app swap + quarantine), delta updates.

## ACCEPTANCE (for the full story; refine per-phase ticket)
- No network call on any default launch path (verified — grep + a test that boot makes
  no outbound connection).
- "Check for updates" only runs on explicit user action; failure surfaces a clear
  toast, never a silent hang or degraded launch.
- A downloaded update is signature+checksum verified before it can replace the install;
  verification failure aborts with the old version intact.
- Applying an update and relaunching preserves running Claude/tmux sessions.
- Version comparison is correct semver (2.3.10 > 2.3.9, pre-release handling defined).

## REFERENCES
POLICY.md (network rule + grudging-allowance criteria); D-64 (no phone-home);
D-41 (tmux session persistence); `lib/src/build_info.g.dart` (version source);
`lib/kernel/src/toast.dart` (ToastService — the notification); settings bool pattern
(`app.*.enabled`, `lib/kernel/src/extensions_manager.dart`); `Makefile` install target
(per-platform layout); parent epic T-46 (cross-platform installer).

DECISION (user, 2026-06-28): MANUAL-ONLY. The update check is a ''Check for updates'' button inside the About-screen box — explicitly user-initiated every time, so NO D-64 amendment is needed (manual checks already comply). A ''check on startup'' checkbox (the opt-in poll) is DEFERRED, not rejected: it would sit next to the button later, and only THEN would it need the narrow, default-off D-64 amendment we discussed (a data-free version fetch; telemetry stays banned full stop). This supersedes any background/periodic-poll framing in the original scope. Build-order caveat: P1 (the About button) still needs the release channel (P0: CI + signed GitHub Releases + a version manifest) to have something to check against — /releases/latest 404s when no Releases are published (the repo has 2 tags, which are NOT Releases). So either P0 lands first, or P1 ships with graceful ''up to date / couldn''t reach GitHub'' handling that no-ops until Releases exist.

P0 release-channel prerequisite is now T-491 (CI builds + signed package artifacts on Releases). P1 (this About button) is independent of it — Releases already exist to check against; P2/P3 (download+verify+apply) depend on T-491.

CORRECTION 2026-09-23: the tmux premise above is stale — D-77 replaced tmux with --resume; nothing in clide uses tmux (D-41 annotated). A relaunch kills the claude processes and terminal PTYs; the conversation continues via --resume (user confirmed this works reliably for the primary pane). So the acceptance ''applying an update and relaunching preserves running Claude/tmux sessions'' now means: conversations resume, in-flight turns and shells do not survive. User raised (during T-55) that clide processes may be spawned under a unifying invisible loader for this ticket''s purposes; since --resume is judged sufficient, such a loader would be thin (tray + window lifecycle), not session-owning — the session-owning variant would rebuild the daemon D-56 dissolved.', NULL, '2026-09-23 06:41:42', '2026-09-23 06:41:42.493', '2026-09-23 06:41:42.493', NULL, '445f6be73da7f96264cc2c09b8d1616d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66FTCTWHH9AQTNFKR', 'description', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.

Scope split (2026-06-10 sweep): the session-persistence half is effectively done - tmux keeps Claude/terminal sessions alive across restart (D-41). The OS-tray/AppIndicator + dock half is a stub only (lib/kernel/src/tray.dart - TrayRegistry has no platform-channel wiring) and is Tier-6+. Remaining work = the tray integration.', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.

Scope split (2026-06-10 sweep): the session-persistence half is effectively done - tmux keeps Claude/terminal sessions alive across restart (D-41). The OS-tray/AppIndicator + dock half is a stub only (lib/kernel/src/tray.dart - TrayRegistry has no platform-channel wiring) and is Tier-6+. Remaining work = the tray integration.

CORRECTION 2026-09-23: the ''session-persistence half is done (tmux)'' premise is stale — nothing in clide uses tmux since D-77. Quitting clide kills every claude child and terminal PTY; only conversations survive (--resume). So the tray/dock is now what keeps sessions alive while the window is closed. Decided with user: Linux tray = own StatusNotifierItem + minimal DBusMenu over GDBus (no new dep); close hides to tray behind an opt-out setting, quits when no tray host exists; tray right-click must offer Quit all (all clide windows); platforms Linux + macOS (Dock) + Windows (notification area), macOS/Windows as plumbing to be tested on those machines; ONE shared tray icon across all clide processes (each window is its own process). Open: which process owns the icon — elected among windows vs a thin loader process that also serves T-47.', NULL, '2026-09-23 06:41:45', '2026-09-23 06:41:45.769', '2026-09-23 06:41:45.769', NULL, 'b5edee4bc9972fe26157910537547ab5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0J6WR2VQ09N039Q4T73RC', 'status', 'backlog', 'done', NULL, '2026-09-23 06:53:44', '2026-09-23 06:53:44.429', '2026-09-23 06:53:44.429', NULL, '2b6c72fec381b5a719681e2d976e72fd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JARSZBYE6WJ9A7S5G0JW', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 06:53:44', '2026-09-23 06:53:44.816', '2026-09-23 06:53:44.816', NULL, 'b0057193353a7ac6e037eec391542d00', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JDZA1E8ACCF0W7H6Y198', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 07:05:52', '2026-09-23 07:05:52.447', '2026-09-23 07:05:52.447', NULL, 'ce64b924828ae8b3c177000388e58c6a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JGWXHDHNWAQ082S6ZQNM', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 07:07:00', '2026-09-23 07:07:00.007', '2026-09-23 07:07:00.007', NULL, '53f1b3078a4287ae5c297e75f9185947', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT8JAS881CFAHYWGRE4Y1WR', 'description', NULL, 'The context panel''s maximum width is a fixed 1000 logical px (`maxSize: 1000` for `Slots.contextPanel` in `lib/kernel/src/panels/layout_preset.dart:19`, clamped in `LayoutArrangement.setSize`). On a widescreen (user''s window: 3435px wide) the panel stops at ~29% of the window while the Claude pane gets the rest. Reading a ticket or decision there leaves a lot of screen unused.

User 2026-09-23: "make the maximum width of the context panel more responsive to widescreens: it could be a bit wider if I have this much screen."

Want: the max width scales with the window, e.g. `max(1000, fraction × window width)`. The fraction should still leave the Claude pane a sensible minimum (D-47: Claude stays the largest surface). The same probably applies to the sidebar''s fixed 400 max.

Notes:
- The max is currently static preset data (`LayoutSlot.maxSize`), so a window-relative limit needs either a resolver the arrangement consults at clamp time, or a max the shell recomputes when the window resizes. Pick one and apply it to both side slots.
- A persisted size saved while the window was wide must still clamp correctly on a narrow window (and vice versa).
- `clide panel resize --to` goes through the same clamp; its error/clamp messages should report the effective max.

Acceptance: on a wide window the context panel can be dragged well past 1000px (up to the fraction); on a ~1600px window behaviour is unchanged; Claude never drops below its minimum; covered by arrangement tests at two window widths.', NULL, '2026-09-23 07:19:41', '2026-09-23 07:19:41.110', '2026-09-23 07:19:41.110', NULL, 'c8fb4adb9c2cfdcc676ad2dd967d985e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT929BB9PM3C1NVM0FDNRJC', 'description', NULL, 'The ticket detail view (context panel) shows a ticket''s PARENT TREE but never its children. Opening an epic or story therefore hides what it contains. The user''s screenshot of T-276 (the UI tracker epic, which has dozens of children) showed only its own description.

User 2026-09-23: "a ticket to add child tickets. in the previous screenshot the 276 ticket has a lot of children, but they are not shown".

Today: `TicketDetailController.load` requests `pql.tickets.show` with `withContext: true` and reads only `ancestors` + `decisions`; `TicketDetail` has no children field; `ticket_detail_view.dart` renders a parents section (`_CompactCard` rows) and nothing below.

Want: a CHILDREN section under the description, listing the direct children as the same compact cards (id, type colour, title, status), each opening that ticket in the reader on click (via the same ReaderNav `selection` path, so back/forward works). Order: open work first (in_progress, then ready/backlog), done last. An epic like T-276 can have many, so collapse done children behind a "N done" toggle, or cap with "show all".

Data: pql already supports `pql ticket show <id> --with-children` (returns a `children` array: id/type/title/status/priority). Check whether the clide `pql.tickets.show` wrapper (lib/src/pql/) passes it through with `withContext`, or add a `withChildren` arg. Wrap, don''t duplicate (D-3).

Acceptance: opening T-276 lists its children; clicking one navigates to it and Back returns; a leaf ticket shows no children section; done children are de-emphasised or collapsed; covered by controller + widget tests.', NULL, '2026-09-23 07:21:44', '2026-09-23 07:21:44.503', '2026-09-23 07:21:44.503', NULL, '9629c8e5f2427465928bc0fcda421a37', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JARSZBYE6WJ9A7S5G0JW', 'status', 'in_progress', 'done', NULL, '2026-09-23 07:22:11', '2026-09-23 07:22:11.874', '2026-09-23 07:22:11.874', NULL, '659db6438e2f2f00a17f1248098add82', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66FTCTWHH9AQTNFKR', 'description', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.

Scope split (2026-06-10 sweep): the session-persistence half is effectively done - tmux keeps Claude/terminal sessions alive across restart (D-41). The OS-tray/AppIndicator + dock half is a stub only (lib/kernel/src/tray.dart - TrayRegistry has no platform-channel wiring) and is Tier-6+. Remaining work = the tray integration.

CORRECTION 2026-09-23: the ''session-persistence half is done (tmux)'' premise is stale — nothing in clide uses tmux since D-77. Quitting clide kills every claude child and terminal PTY; only conversations survive (--resume). So the tray/dock is now what keeps sessions alive while the window is closed. Decided with user: Linux tray = own StatusNotifierItem + minimal DBusMenu over GDBus (no new dep); close hides to tray behind an opt-out setting, quits when no tray host exists; tray right-click must offer Quit all (all clide windows); platforms Linux + macOS (Dock) + Windows (notification area), macOS/Windows as plumbing to be tested on those machines; ONE shared tray icon across all clide processes (each window is its own process). Open: which process owns the icon — elected among windows vs a thin loader process that also serves T-47.', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.

Scope split (2026-06-10 sweep): the session-persistence half is effectively done - tmux keeps Claude/terminal sessions alive across restart (D-41). The OS-tray/AppIndicator + dock half is a stub only (lib/kernel/src/tray.dart - TrayRegistry has no platform-channel wiring) and is Tier-6+. Remaining work = the tray integration.

CORRECTION 2026-09-23: the ''session-persistence half is done (tmux)'' premise is stale — nothing in clide uses tmux since D-77. Quitting clide kills every claude child and terminal PTY; only conversations survive (--resume). So the tray/dock is now what keeps sessions alive while the window is closed. Decided with user: Linux tray = own StatusNotifierItem + minimal DBusMenu over GDBus (no new dep); close hides to tray behind an opt-out setting, quits when no tray host exists; tray right-click must offer Quit all (all clide windows); platforms Linux + macOS (Dock) + Windows (notification area), macOS/Windows as plumbing to be tested on those machines; ONE shared tray icon across all clide processes (each window is its own process). Open: which process owns the icon — elected among windows vs a thin loader process that also serves T-47.

STATUS 2026-09-23: Linux done and verified live on KDE Plasma 6/Wayland (T-591); Dart half + General settings tab (T-590); notification pulse spins the tray icon. macOS Dock (T-592) and Windows notification-area loader (T-593) are committed as plumbing, untested — in review, to be built and exercised on a Mac and a Windows machine. Close T-55 once both are confirmed.', NULL, '2026-09-23 07:22:13', '2026-09-23 07:22:13.954', '2026-09-23 07:22:13.954', NULL, 'c09aa7a3a8c14ac23957757038eec5b5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JDZA1E8ACCF0W7H6Y198', 'status', 'in_progress', 'review', NULL, '2026-09-23 07:22:15', '2026-09-23 07:22:15.974', '2026-09-23 07:22:15.974', NULL, 'b5955b9756adda216a6768b030c27297', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT0JGWXHDHNWAQ082S6ZQNM', 'status', 'in_progress', 'review', NULL, '2026-09-23 07:22:16', '2026-09-23 07:22:16.417', '2026-09-23 07:22:16.417', NULL, '71f664c19361bb0bc9fb0efa43f85753', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTAMJH819FK1X5ZQAPBW6VG', 'description', NULL, 'User 2026-09-23: "a background agent context window in the context pane to see all background processes still running".

Want: a context-pane tab listing every piece of background work that is still running: background sub-agents, background shell commands, and Workflow runs, across all of this window''s Claude sessions (primary, secondaries, team members, the companion). Each row shows kind, description, owning session, elapsed time, and tokens/tool uses where the event carries them. It updates live and moves to a "finished" group (or drops off) on completion. Clicking a row reveals the owning session and scrolls to the launching tool call.

What exists: `workflow_run.dart` already folds the harness''s `system` task events (`task_started` / `task_progress` / `task_updated` / `task_notification`, keyed by `tool_use_id`) into `WorkflowRun`s (T-416). `StreamJsonSession.workflowsStream` publishes them, and they render as the workflow conversation card and the sidebar indicator. They are ephemeral: not in the resumed transcript, empty after reload.

Investigate first: do background Agent calls and background Bash commands (`run_in_background`) emit the same `task_*` event family over stream-json, or only Workflow? `isWorkflowSystemEvent` currently filters on the workflow subtypes, and any other task kinds may be dropped. Capture a real session that starts a background agent and a background shell. If the CLI doesn''t report them, the tab can''t show them honestly; say so in the ticket rather than guessing from tool_use/tool_result pairing.

Shape: generalise `WorkflowRun` into a per-session background-task model; an orchestrator-level aggregate across sessions; a context-panel tab (static, like tickets.detail) with a `subjectSource`-style count; D-6 parity via a `clide claude tasks` (list) verb. Stopping a task from the UI is out of scope unless the control protocol offers it (check for a task-stop control request).

History (user, same day: "maybe with history"): finished tasks stay listed in a History section: kind, description, session, start/end time, duration, final status (completed / failed / stopped), summary and usage from the terminal notification. Because the task events are not in the resumed transcript, clide must record them itself. Persist a capped, per-workspace log in user-scope state (D-93/D-53, never in the repo), e.g. the last N entries or last N days. It then survives an app reload and shows which session ran what. Clearing the history is a control in the tab plus the CLI verb (`clide claude tasks --history`, `--clear`).

Acceptance: with a background agent and a background shell running, the tab lists both with live elapsed time and moves them to finished when their notification arrives; a Workflow run appears with its per-agent rows; `clide claude tasks` returns the same list; empty state when nothing runs; finished tasks appear under History with duration and status, and are still there after restarting clide; the history is capped and clearable.', NULL, '2026-09-23 07:28:42', '2026-09-23 07:28:42.419', '2026-09-23 07:28:42.419', NULL, '660839b9fa2c18ce5a09b8cf61ebd577', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTAMJH819FK1X5ZQAPBW6VG', 'description', 'User 2026-09-23: "a background agent context window in the context pane to see all background processes still running".

Want: a context-pane tab listing every piece of background work that is still running: background sub-agents, background shell commands, and Workflow runs, across all of this window''s Claude sessions (primary, secondaries, team members, the companion). Each row shows kind, description, owning session, elapsed time, and tokens/tool uses where the event carries them. It updates live and moves to a "finished" group (or drops off) on completion. Clicking a row reveals the owning session and scrolls to the launching tool call.

What exists: `workflow_run.dart` already folds the harness''s `system` task events (`task_started` / `task_progress` / `task_updated` / `task_notification`, keyed by `tool_use_id`) into `WorkflowRun`s (T-416). `StreamJsonSession.workflowsStream` publishes them, and they render as the workflow conversation card and the sidebar indicator. They are ephemeral: not in the resumed transcript, empty after reload.

Investigate first: do background Agent calls and background Bash commands (`run_in_background`) emit the same `task_*` event family over stream-json, or only Workflow? `isWorkflowSystemEvent` currently filters on the workflow subtypes, and any other task kinds may be dropped. Capture a real session that starts a background agent and a background shell. If the CLI doesn''t report them, the tab can''t show them honestly; say so in the ticket rather than guessing from tool_use/tool_result pairing.

Shape: generalise `WorkflowRun` into a per-session background-task model; an orchestrator-level aggregate across sessions; a context-panel tab (static, like tickets.detail) with a `subjectSource`-style count; D-6 parity via a `clide claude tasks` (list) verb. Stopping a task from the UI is out of scope unless the control protocol offers it (check for a task-stop control request).

History (user, same day: "maybe with history"): finished tasks stay listed in a History section: kind, description, session, start/end time, duration, final status (completed / failed / stopped), summary and usage from the terminal notification. Because the task events are not in the resumed transcript, clide must record them itself. Persist a capped, per-workspace log in user-scope state (D-93/D-53, never in the repo), e.g. the last N entries or last N days. It then survives an app reload and shows which session ran what. Clearing the history is a control in the tab plus the CLI verb (`clide claude tasks --history`, `--clear`).

Acceptance: with a background agent and a background shell running, the tab lists both with live elapsed time and moves them to finished when their notification arrives; a Workflow run appears with its per-agent rows; `clide claude tasks` returns the same list; empty state when nothing runs; finished tasks appear under History with duration and status, and are still there after restarting clide; the history is capped and clearable.', 'User 2026-09-23: "a background agent context window in the context pane to see all background processes still running".

Want: a context-pane tab listing every piece of background work that is still running: background sub-agents, background shell commands, and Workflow runs, across all of this window''s Claude sessions (primary, secondaries, team members, the companion). Each row shows kind, description, owning session, elapsed time, and tokens/tool uses where the event carries them. It updates live and moves to a "finished" group (or drops off) on completion. Clicking a row reveals the owning session and scrolls to the launching tool call.

What exists: `workflow_run.dart` already folds the harness''s `system` task events (`task_started` / `task_progress` / `task_updated` / `task_notification`, keyed by `tool_use_id`) into `WorkflowRun`s (T-416). `StreamJsonSession.workflowsStream` publishes them, and they render as the workflow conversation card and the sidebar indicator. They are ephemeral: not in the resumed transcript, empty after reload.

Investigate first: do background Agent calls and background Bash commands (`run_in_background`) emit the same `task_*` event family over stream-json, or only Workflow? `isWorkflowSystemEvent` currently filters on the workflow subtypes, and any other task kinds may be dropped. Capture a real session that starts a background agent and a background shell. If the CLI doesn''t report them, the tab can''t show them honestly; say so in the ticket rather than guessing from tool_use/tool_result pairing.

Shape: generalise `WorkflowRun` into a per-session background-task model; an orchestrator-level aggregate across sessions; a context-panel tab (static, like tickets.detail) with a `subjectSource`-style count; D-6 parity via a `clide claude tasks` (list) verb. Stopping a task from the UI is out of scope unless the control protocol offers it (check for a task-stop control request).

History (user, same day: "maybe with history"): finished tasks stay listed in a History section: kind, description, session, start/end time, duration, final status (completed / failed / stopped), summary and usage from the terminal notification. Because the task events are not in the resumed transcript, clide must record them itself. Persist a capped, per-workspace log in user-scope state (D-93/D-53, never in the repo), e.g. the last N entries or last N days. It then survives an app reload and shows which session ran what. Clearing the history is a control in the tab plus the CLI verb (`clide claude tasks --history`, `--clear`).

Acceptance: with a background agent and a background shell running, the tab lists both with live elapsed time and moves them to finished when their notification arrives; a Workflow run appears with its per-agent rows; `clide claude tasks` returns the same list; empty state when nothing runs; finished tasks appear under History with duration and status, and are still there after restarting clide; the history is capped and clearable.

TEAM MODE (user, 2026-09-23): "revive the team-mode I used to use with great effect and joy. I loved running a team of agents more directly than just through you in the background."

State today (checked):
- The tmux-era team pipeline (Claude Code''s own agent-team mode, observed via tmux; tile grid, T-139/T-140) was removed in T-385, after D-77 moved Claude to stream-json, where CC''s team mode doesn''t work headless.
- D-77 phase 2''s replacement is half-built: `TeamBroker` + the clide-hosted MCP team tools (T-170, `SpawnSpec.team` / `memberName` injects roster + role + messaging tools), the team chat sidebar and poppable pane (T-180, `claude.team-chat.open` / `.post`), and the Team sub-tab.
- Nothing forms a team: no command, UI affordance or CLI verb spawns team-member sessions (`SpawnSpec.team` is never set anywhere in lib/). The roster still listens for ghost `TeamMemberJoined/Left` events from the deleted pipeline (T-396).

Want: forming and running a team is direct and first-class again. The user creates a team (name + members with roles/briefs, e.g. from a preset or ad hoc), each member is a visible, addressable session (its own Claude tab/tile, not only a background task), members message each other through the broker, the user can talk to any member or post to the team channel, and the roster + this tab show every member''s live state (working / idle / waiting on a prompt, model, mode, context, cost). Team members must appear in the background-work view above alongside sub-agents, shells and workflows.

This is larger than the rest of this ticket. Recommend splitting it out as its own epic when refined, with T-396 (roster rewired to TeamBroker membership) as its first child. Needs product decisions: how a team is defined and persisted (per workspace? presets?), where members render (tabs vs a tile grid like the old T-140), and whether members survive restarts (ties to T-589''s secondary-pane persistence).', NULL, '2026-09-23 07:34:47', '2026-09-23 07:34:47.224', '2026-09-23 07:34:47.224', NULL, '1ce1317b03a25537cada33a72ac6cd7c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTC3QRDPP5RJMFMCKRW045M', 'description', NULL, 'User 2026-09-23: auto mode is missing from the permission-mode picker; "bypass" is an old pattern, and auto is now Anthropic''s preferred mode. Implement the mode setter the modern way (as the desktop app / IDE extensions do).

Docs (code.claude.com/docs/en/permission-modes): modes are `default` (labelled **Manual** everywhere; CLI accepts `manual` as alias), `acceptEdits`, `plan`, `auto` (a classifier reviews each action instead of prompting), `dontAsk` (CI only, never in the cycle), `bypassPermissions` (containers/VMs only). Auto is the built-in starting mode on Pro/Max/Team for interactive sessions, but `claude -p` / the Agent SDK start in `default`. Desktop/VS Code: the picker shows Manual, Accept/Edit automatically, Plan, Auto (only when auto mode is available), Bypass (only when explicitly allowed in settings). Shift+Tab cycle: default → acceptEdits → plan → [bypass if enabled] → auto; from auto the first press goes to default.

Probe against the installed CLI, over clide''s own stream-json protocol (control handshake only):
- `set_permission_mode auto` → accepted (`{"mode":"auto"}`).
- `set_permission_mode bypassPermissions` → **error**: "Cannot set permission mode to bypassPermissions because the session was not launched with --dangerously-skip-permissions". clide never launches with it, and `StreamJsonSession.setPermissionMode` is fire-and-forget with an optimistic status merge. So choosing bypass today shows "bypass" while the session stays in its old mode (a lying UI).
- `manual` → normalised to `default`; `dontAsk` → accepted.
- The `initialize` response carries `current_permission_mode` and per-model `supportsAutoMode`.

Want:
1. Auto in the picker, the cycle chords, `/permissions`, the Claude settings'' default-mode field, the sidebar roster, and `clide claude.mode set`. Offered only when the session''s model supports it (from the handshake). If the CLI later rejects it (server-side off, `disableAutoMode`), roll back and say why.
2. Modern labels: Manual / Accept edits / Plan / Auto / Bypass permissions (i18n keys).
3. Mode changes become ack-aware like set_model: roll the status back and surface the CLI''s error on rejection.
4. Bypass follows the Desktop pattern: hidden unless a Claude setting "Allow bypass permissions mode" (default off) is on. When on, new sessions launch with `--allow-dangerously-skip-permissions` (adds bypass to what the session will accept without activating it), and bypass is a normal, clearly-dangerous picker row. The shift-click gate goes.
5. New sessions start in the configured default mode via `--permission-mode` at spawn instead of a post-spawn control request. The CLI then falls back to Manual itself when auto isn''t available, silently and correctly. Default for the setting: `auto` (Anthropic''s preferred mode); users who set another value keep it.', NULL, '2026-09-23 07:35:03', '2026-09-23 07:35:03.310', '2026-09-23 07:35:03.310', NULL, '4685aa58299ae65aea084b98a92d7f57', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTC3QRDPP5RJMFMCKRW045M', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 07:35:03', '2026-09-23 07:35:03.790', '2026-09-23 07:35:03.790', NULL, '8a73f3f6f7e7ddb31a91b3e4033499e7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTC3QRDPP5RJMFMCKRW045M', 'status', 'in_progress', 'done', NULL, '2026-09-23 07:44:03', '2026-09-23 07:44:03.874', '2026-09-23 07:44:03.874', NULL, '23eef9d44b07e715d8f752a641ce9169', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTF77KDWXQ4693GDWCC1YE0', 'description', NULL, 'User 2026-09-23, after the tray work converged only because they looked at the panel after each round (three icon problems they caught before I did): give the agent a way to see clide''s own UI, so it can verify visual changes instead of asking.

Want: `clide window screenshot` — render the live clide window to a PNG and return its path, so an agent can Read the image. Variants:
- `--pane <id>` / `--slot <sidebar|workspace|context|dock|statusbar>`: capture just that region (the ids `clide pane list` reports).
- `--out <path>`: where to write; default a per-workspace user-scope dir (never the repo, D-93), newest-N retained.
- `--scale <n>`: device-pixel ratio for the capture (default the window''s).

Shape: wrap the app root (and each slot/pane host) in a RepaintBoundary with a GlobalKey; `RenderRepaintBoundary.toImage()` → `toByteData(png)` → file. This is in-process and cross-platform (Linux, macOS, Windows) with no desktop screenshot permissions, since it''s clide rendering its own layer tree. It captures what clide painted, not the OS chrome; the frameless window has none anyway (D-57). It must work while the window is hidden to the tray (render off-screen), and return a clear error when there''s no frame yet.

D-6: a UI affordance too (e.g. a command-palette "Window: Save Screenshot" that writes to the same place and toasts the path).

Out of scope, noted: things outside clide''s window (the OS tray/panel, native dialogs) can''t be captured this way. That needs the desktop''s screenshot portal (xdg-desktop-portal Screenshot on Linux), which prompts the user and is a separate ticket if wanted.

Relates: T-573 (loading a pasted screenshot into the workspace — the input direction; this is the output direction).

Acceptance: `clide window screenshot` returns a PNG path whose image matches the current UI; `--pane claude.primary` returns only that pane; works with the window hidden; the palette command does the same; covered by a widget test that captures a known tree and checks dimensions + a sampled pixel.', NULL, '2026-09-23 07:48:38', '2026-09-23 07:48:38.253', '2026-09-23 07:48:38.253', NULL, '5ba9a4dee63d4fcdd8b81744bd44fe55', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FCZDVPBWGM5NHJ9BNQBVKCD0', 'status', 'backlog', 'done', NULL, '2026-09-23 07:49:05', '2026-09-23 07:49:05.866', '2026-09-23 07:49:05.866', NULL, 'dcb1243c2d0e6a20c6fbcb3f4490eadd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYDGH6NA4M13VHHSSDWN7TZ0', 'status', 'backlog', 'done', NULL, '2026-09-23 07:49:21', '2026-09-23 07:49:21.063', '2026-09-23 07:49:21.063', NULL, '0b6cb9f6ac413219c941628f19761643', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FCZDVPBWGM5NHJ9BNQBVKCD0', 'status', 'done', 'review', NULL, '2026-09-23 07:49:31', '2026-09-23 07:49:31.809', '2026-09-23 07:49:31.809', NULL, '3ab65b16df7227df40b45ccd36eda5dd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYDGH6NA4M13VHHSSDWN7TZ0', 'status', 'done', 'review', NULL, '2026-09-23 07:49:31', '2026-09-23 07:49:31.815', '2026-09-23 07:49:31.815', NULL, '0fd9a41908c95c511d77a3be9f88fe93', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTC3QRDPP5RJMFMCKRW045M', 'status', 'done', 'review', NULL, '2026-09-23 07:49:31', '2026-09-23 07:49:31.815', '2026-09-23 07:49:31.815', NULL, '1bacf01d34aefe6984a3211bc8a48521', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCT929BB9PM3C1NVM0FDNRJC', 'status', 'backlog', 'review', NULL, '2026-09-23 07:49:46', '2026-09-23 07:49:46.740', '2026-09-23 07:49:46.740', NULL, '0c9c8b8248a3bf7eff0b266900ce99b3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5DM43Q9HX352STN3M', 'status', 'backlog', 'review', NULL, '2026-09-23 07:50:08', '2026-09-23 07:50:08.554', '2026-09-23 07:50:08.554', NULL, 'bcd0a73a64818b584071b774a275f70c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KPN4VK4EZP013NNG', 'status', 'backlog', 'review', NULL, '2026-09-23 07:51:23', '2026-09-23 07:51:23.806', '2026-09-23 07:51:23.806', NULL, '7463c3ce319f7bf00f2774cda8196fb0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FD91RWDWZPHFPJ72FHHHWS08', 'status', 'backlog', 'review', NULL, '2026-09-23 07:51:58', '2026-09-23 07:51:58.176', '2026-09-23 07:51:58.176', NULL, '7a6f297c3adbb4f06a2204a4e14c1c53', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBTTMGKSYMTF8M1KQWTG774W', 'status', 'backlog', 'review', NULL, '2026-09-23 07:52:12', '2026-09-23 07:52:12.421', '2026-09-23 07:52:12.421', NULL, '862b48eb3e997fc9d1ccc482305985de', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYR002H0BYV99HPK769J2ZF8', 'status', 'backlog', 'review', NULL, '2026-09-23 07:52:32', '2026-09-23 07:52:32.328', '2026-09-23 07:52:32.328', NULL, '0006fbb257ceb548a2d9b866ade77ec4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FJ91RYFXBJH99HJ18QTHY2B0', 'description', 'REPORTED (2026-07-02, Jeroen): can''t trust that the model switch and the effort toggle actually took effect when used — the UI feedback + positioning leave it uncertain whether the change applied. INVESTIGATE: what confirmation (if any) fires today when the model or effort is changed, and where it surfaces relative to the control. Likely-related surfaces: the Config tab controls (T-414), /effort ownership (T-412), account/model settings control. IMPROVE: give an unmistakable, well-positioned confirmation that the change landed — e.g. the control reflects the new value immediately (selected state), and/or a brief toast/inline acknowledgement near the control, not somewhere the eye isn''t. Goal: after a switch, the user is certain which model/effort is now active.

EVIDENCE + ROOT CAUSE (2026-07-02, from a /model screenshot). The confirmation renders as a raw, unstyled line: literally ''<local-command-stdout>Set model to claude-fable-5[1m] (claude-fable-5)</local-command-stdout>'', shown under the ''you'' (user) speaker stripe. Three distinct defects in that one line: (a) the CLI''s <local-command-stdout> wrapper tag is displayed verbatim instead of being unwrapped; (b) an ANSI SGR bold code leaks through as literal ''[1m]'' (a \x1b[1m) — slash-command stdout is not ANSI-stripped; (c) it is attributed to the USER speaker, so a system/command acknowledgement masquerades as something the user typed. ROOT CAUSE: clide has NO handling for local-command-stdout at all (grep in lib/ = zero hits) — the slash-command result falls through and is rendered as plain user prose. ENTRY POINTS for the fix: inbound message parse / role attribution in lib/builtin/claude/src/transcript_reader.dart; existing ANSI-strip refs in transcript_reader.dart + claude_composer.dart. IMPROVE: detect local-command-stdout content, unwrap the tag + strip ANSI, and render it as a distinct, clearly-positioned system/command-acknowledgement (NOT the user stripe) so a /model or /effort change is an unmistakable confirmation. Affects all slash-command stdout (model, effort, etc.), so fix at the render/parse path, not per-command.

SCOPE (do not narrow): the local-command-stdout rendering defect above is ONE symptom, not the whole ticket. The core problem is that after switching model or effort the user has no reliable, well-placed signal that it took effect — so this stays a broad investigate-and-improve of the switch/toggle trust UX, with the render bug as just the first concrete instance. Other symptoms/questions to investigate (non-exhaustive): does the control itself (Config tab picker / effort control / any menu) visibly update to the NEW active value after a switch, or does it look unchanged? is there ANY acknowledgement at the point of interaction, or only (mangled) output buried in the transcript far from where the user clicked? do model vs effort behave consistently, or differently? can clide''s shown ''active'' value drift from what actually took effect (e.g. a switch that silently no-ops)? is the confirmation positioned where the eye already is? The deliverable is: across all these controls, a consistent and unmistakable ''this is now active'' — fixing the render path is necessary but not sufficient. Enumerate the full symptom set during investigation before designing the fix.', 'REPORTED (2026-07-02, Jeroen): can''t trust that the model switch and the effort toggle actually took effect when used — the UI feedback + positioning leave it uncertain whether the change applied. INVESTIGATE: what confirmation (if any) fires today when the model or effort is changed, and where it surfaces relative to the control. Likely-related surfaces: the Config tab controls (T-414), /effort ownership (T-412), account/model settings control. IMPROVE: give an unmistakable, well-positioned confirmation that the change landed — e.g. the control reflects the new value immediately (selected state), and/or a brief toast/inline acknowledgement near the control, not somewhere the eye isn''t. Goal: after a switch, the user is certain which model/effort is now active.

EVIDENCE + ROOT CAUSE (2026-07-02, from a /model screenshot). The confirmation renders as a raw, unstyled line: literally ''<local-command-stdout>Set model to claude-fable-5[1m] (claude-fable-5)</local-command-stdout>'', shown under the ''you'' (user) speaker stripe. Three distinct defects in that one line: (a) the CLI''s <local-command-stdout> wrapper tag is displayed verbatim instead of being unwrapped; (b) an ANSI SGR bold code leaks through as literal ''[1m]'' (a \x1b[1m) — slash-command stdout is not ANSI-stripped; (c) it is attributed to the USER speaker, so a system/command acknowledgement masquerades as something the user typed. ROOT CAUSE: clide has NO handling for local-command-stdout at all (grep in lib/ = zero hits) — the slash-command result falls through and is rendered as plain user prose. ENTRY POINTS for the fix: inbound message parse / role attribution in lib/builtin/claude/src/transcript_reader.dart; existing ANSI-strip refs in transcript_reader.dart + claude_composer.dart. IMPROVE: detect local-command-stdout content, unwrap the tag + strip ANSI, and render it as a distinct, clearly-positioned system/command-acknowledgement (NOT the user stripe) so a /model or /effort change is an unmistakable confirmation. Affects all slash-command stdout (model, effort, etc.), so fix at the render/parse path, not per-command.

SCOPE (do not narrow): the local-command-stdout rendering defect above is ONE symptom, not the whole ticket. The core problem is that after switching model or effort the user has no reliable, well-placed signal that it took effect — so this stays a broad investigate-and-improve of the switch/toggle trust UX, with the render bug as just the first concrete instance. Other symptoms/questions to investigate (non-exhaustive): does the control itself (Config tab picker / effort control / any menu) visibly update to the NEW active value after a switch, or does it look unchanged? is there ANY acknowledgement at the point of interaction, or only (mangled) output buried in the transcript far from where the user clicked? do model vs effort behave consistently, or differently? can clide''s shown ''active'' value drift from what actually took effect (e.g. a switch that silently no-ops)? is the confirmation positioned where the eye already is? The deliverable is: across all these controls, a consistent and unmistakable ''this is now active'' — fixing the render path is necessary but not sufficient. Enumerate the full symptom set during investigation before designing the fix.

2026-09-23: render slice done — <local-command-stdout> blocks now render as the muted clide notice (tag unwrapped, real ANSI escapes stripped, empty blocks dropped) instead of a user message. The rest of this ticket (did-the-model/effort-change-take-effect UX) is untouched, so it stays open. Note: the ''[1m]'' seen in the report is the 1M-context model suffix (claude-fable-5[1m]), not an escape code; whether to prettify it is a product call for the remaining work.', NULL, '2026-09-23 07:53:13', '2026-09-23 07:53:13.151', '2026-09-23 07:53:13.151', NULL, '28ca744c8c1d3aab013f6d70d9cb9b7a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7GJW4V3CXMMXXV988', 'status', 'backlog', 'review', NULL, '2026-09-23 07:55:09', '2026-09-23 07:55:09.167', '2026-09-23 07:55:09.167', NULL, '576ccc4f626a603be9c11cb320006bed', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBJM6XXQZ3EMGRC13XRYVBEM', 'status', 'backlog', 'review', NULL, '2026-09-23 07:55:22', '2026-09-23 07:55:22.255', '2026-09-23 07:55:22.255', NULL, 'abd3117f68ca74c88d8c2c2c50dd7fc4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM45BSF1B0R0JA1Z7FC', 'status', 'backlog', 'review', NULL, '2026-09-23 07:57:03', '2026-09-23 07:57:03.607', '2026-09-23 07:57:03.607', NULL, '34679ce06623836aa7ca48d2fb052550', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FZDK216SJHEHNB1R0B97JWDR', 'status', 'backlog', 'review', NULL, '2026-09-23 07:57:42', '2026-09-23 07:57:42.473', '2026-09-23 07:57:42.473', NULL, '5d214af20ecbcb99ca29931a88cb8ce4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM79CNBXJ2S3CFQR7VM', 'description', 'Catch-all for the medium-priority items from the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md) that didn`t earn dedicated tickets:

- **#17** — `files.read` `readAsStringSync` is unguarded; UTF-8 errors / permissions / mid-read deletion become 500-style dispatch errors. Wrap in try/catch and emit a clean `IpcResponse.err`.
- **#19** — `PtySession.close` swallows the 500ms timeout silently (`onTimeout: () {}`). Log when the timeout fires so we know SIGKILL was needed.
- **#20** — Reader isolate treats every negative `read()` return that isn`t EINTR as EOF. Distinguish EBADF/EIO (real EOF) from transient EAGAIN (recoverable) and log the latter.
- **#21** — `scm_rights.dart` reads cmsg-data fd without verifying `dataOffset + 4 <= msgControllen`. Bounds check before deref so a malformed peer can`t feed garbage as an fd.
- **#25** — `_gitError` in `lib/src/daemon/git_commands.dart` always reports `tool_error`; push rejections / merge conflicts should map to `IpcExitCode.conflict` when stderr matches known patterns.
- **#27** — `pane.spawn` returns `ok` even when `registry.write(id, bytes)` returned `n == -1`. Distinguish the failure.
- **#28** — `IpcResponse.fromJson` throws `TypeError` on a malformed peer response missing `error`. Graceful degrade.
- **#29** — PATH resolution in `native_pty.dart` uses the first existing match without `X_OK` check; non-executable files shadow valid binaries further along PATH.

Land each as a small focused commit; ticket closes when all items above are merged.

Item status (2026-06-10 sweep): from the T-18 audit, #16 (git error kinds) landed via T-79 and #22 (logging) via T-80. #21 (scm_rights.dart bounds check) is OBSOLETE - fd-passing/recvmsg was removed, the file no longer exists; drop it. Spot-checked still-open: #17 files.read unguarded readAsStringSync (files_commands.dart), #28 IpcResponse.fromJson TypeError (envelope.dart), #29 PATH X_OK check (native_pty.dart). ~7 items remain.', 'Catch-all for the medium-priority items from the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md) that didn`t earn dedicated tickets:

- **#17** — `files.read` `readAsStringSync` is unguarded; UTF-8 errors / permissions / mid-read deletion become 500-style dispatch errors. Wrap in try/catch and emit a clean `IpcResponse.err`.
- **#19** — `PtySession.close` swallows the 500ms timeout silently (`onTimeout: () {}`). Log when the timeout fires so we know SIGKILL was needed.
- **#20** — Reader isolate treats every negative `read()` return that isn`t EINTR as EOF. Distinguish EBADF/EIO (real EOF) from transient EAGAIN (recoverable) and log the latter.
- **#21** — `scm_rights.dart` reads cmsg-data fd without verifying `dataOffset + 4 <= msgControllen`. Bounds check before deref so a malformed peer can`t feed garbage as an fd.
- **#25** — `_gitError` in `lib/src/daemon/git_commands.dart` always reports `tool_error`; push rejections / merge conflicts should map to `IpcExitCode.conflict` when stderr matches known patterns.
- **#27** — `pane.spawn` returns `ok` even when `registry.write(id, bytes)` returned `n == -1`. Distinguish the failure.
- **#28** — `IpcResponse.fromJson` throws `TypeError` on a malformed peer response missing `error`. Graceful degrade.
- **#29** — PATH resolution in `native_pty.dart` uses the first existing match without `X_OK` check; non-executable files shadow valid binaries further along PATH.

Land each as a small focused commit; ticket closes when all items above are merged.

Item status (2026-06-10 sweep): from the T-18 audit, #16 (git error kinds) landed via T-79 and #22 (logging) via T-80. #21 (scm_rights.dart bounds check) is OBSOLETE - fd-passing/recvmsg was removed, the file no longer exists; drop it. Spot-checked still-open: #17 files.read unguarded readAsStringSync (files_commands.dart), #28 IpcResponse.fromJson TypeError (envelope.dart), #29 PATH X_OK check (native_pty.dart). ~7 items remain.

Partial landing 2026-09-23: items #17 (files.read errors → tool error), #19 (PTY close logs a reader that outlives the 500ms wait, via PtyLog crumb), #28 (malformed IPC failure response → tool_error), #29 (PATH resolution takes the first executable regular file; stat mode bits, not access(2)). Remaining: #20, #25, #27. Ticket stays open.', NULL, '2026-09-23 07:58:38', '2026-09-23 07:58:38.923', '2026-09-23 07:58:38.923', NULL, '8f2937b72df608789ceea2deee8dc1bc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FCDG3T4A7CYPTG535KVAVH6C', 'description', '**Symptom.** The git branch shown in the status bar (bottom-left, next to the `⎇` glyph) sometimes displays the branch of a *different* open clide workspace/window — it "bleeds" across windows. Intermittent ("at times"). Screenshot on the originating session shows `main` while a sibling window was on another branch.

**User hypothesis.** Lack of fencing in the message bus between multiple parallel open sessions/windows — events/state from one window reaching another.

**Why this matters.** Showing the wrong branch in a git-centric IDE is a footgun: the user can believe they are on a branch they are not, and act (commit/checkout) on that false premise. It also *contradicts a documented isolation invariant* — see T-269: "Separate clide WINDOWS are isolated (separate process, per-root IPC socket, per-repo deterministic session id), so parallel repos in separate windows are fine." This bug is evidence that invariant is not actually holding for the status-bar branch.

**Investigation (read-only, 2026-06-14).**
- Status-bar branch widget: `lib/builtin/git/src/git_status_item.dart:8-86` — subscribes to `kernel.events.on<DaemonEvent>()`, fetches branch via `ipc.request(''git.status'')` (sets `_branch = r.data[''branch'']`), and re-fetches on any `git.changed` event.
- Branch fetch path: `lib/src/git/client.dart:23-65` → `lib/src/daemon/git_commands.dart:46-53` (`git.status` handler).
- Event emit: `git_commands.dart:295-296` `_emitChanged()` → kernel `DaemonBus`.
- Kernel bus: `lib/kernel/src/events/bus.dart:5-20` is a single unfiltered `StreamController.broadcast()`; on project open the *same* `daemonBus` instance is reused (`lib/main.dart:110-111, 372-376`). No workspace/window id on events; no per-workspace filtering.
- Per-workspace socket IS correct: `lib/src/ipc/paths.dart:13-16` hashes (FNV-1a64) the workspace root → distinct socket per root (D-70).

**Two candidate mechanisms — fix work must confirm which (they are NOT the same):**
1. *Same-process / in-place bleed* — the global `DaemonBus` is shared across dispatchers, so events are not workspace-scoped. This is the in-memory path and overlaps with the now-closed T-367 ("Project switch leaks the entire previous workspace service set"). Only applies if the two surfaces share one process.
2. *Cross-process / true multi-window bleed* — separate windows are separate processes (per T-269), so an in-memory bus cannot cross them. A process-crossing path is required: most likely the branch widget resolving its IPC endpoint from an **inherited `CLIDE_SOCK`** (see T-215) instead of recomputing the socket from its own workspace root — e.g. window B launched from window A''s integrated terminal inherits A''s `CLIDE_SOCK` and connects to A''s IPC server. Same-root windows sharing one hashed socket is a second possibility.

**Repro info still needed (please confirm):**
- Were the two windows open on the *same* repo or *different* repos?
- Was the second window launched from inside the first window''s integrated terminal (i.e. could it have inherited `CLIDE_SOCK`)?

**Proposed direction.**
- Make the status-bar branch widget resolve its IPC endpoint and filter events strictly by *its own* workspace root, never trusting an ambient/inherited socket.
- Add a workspace/window identity to `DaemonEvent` (or scope the `DaemonBus` per workspace) so events carry provenance and consumers can fence (kernel/src/events/types.dart + bus.dart).
- Add a regression test: two workspace contexts; a `git.changed`/checkout in one must not mutate the other''s displayed branch.

**Related:** T-269 (closed — documents the isolation invariant this breaks), T-367 (closed — shared-bus/service-set leak on in-place switch), T-215 (CLIDE_SOCK/CLIDE_WORKSPACE export), D-70 (per-workspace socket path).

---

**Repro details confirmed (user, 2026-06-14):**
- The two windows were on *different repos* (distinct workspace roots → distinct hashed sockets per D-70; rules out same-socket collision).
- The second window was opened from the **File menu at the top**, not from an integrated terminal.

**Refined root-cause analysis (this changes the leading hypothesis).**

The File menu has two distinct paths (`lib/builtin/menubar/src/file_actions.dart`):
- `openFolder()`/`openPath()` (l.23-63) → `services.project.open()` = *in-place* switch, same process (the T-269/T-367 class). Produces ONE window, so not this report.
- `newWindow()` (l.30-32) → `Process.start(Platform.resolvedExecutable, const [], mode: ProcessStartMode.detached)` = a genuinely **separate detached process**. This matches the "parallel windows" symptom.

Two facts narrow it:
1. `CLIDE_SOCK`/`CLIDE_WORKSPACE` are NOT set in clide''s own process environment — they are a delta overlaid only on spawned Claude/PTY *child* processes (`lib/builtin/claude/src/agent_bootstrap.dart:57-71`, "Process.start keeps the parent environment by default, so this returns only the keys to add/override"). So a clean dock-launched window has no CLIDE_SOCK to leak.
2. `newWindow()` passes **no `environment:` override**, so the detached child inherits the parent clide process''s full environment verbatim.

**Leading hypothesis now:** environment inheritance through `newWindow()` when clide is self-hosted. If window 1 was itself launched from a clide-hosted terminal or as a clide agent, window 1''s process env already carries *that host''s* `CLIDE_SOCK`/`CLIDE_WORKSPACE`. `newWindow()` then spawns window 2 inheriting those vars — so any code in window 2 that resolves its IPC endpoint (or shells out to the `clide` CLI, which keys off `CLIDE_SOCK`) can bind to the wrong workspace''s server and surface its branch. This is consistent with: different repos, opened from the File menu, intermittent.

**Caveat / not yet pinned:** the in-app status widget reportedly resolves IPC via the computed `workspaceSocketPath(root)` (`lib/main.dart:357`), NOT via `CLIDE_SOCK` — so if that holds, inherited CLIDE_SOCK alone shouldn''t mislead the *in-process* status bar. The exact cross-process channel therefore still needs live confirmation. Do NOT assume; instrument.

**First diagnostic step for the fixer:**
1. Reproduce: open window 1, then File → New Window, then open a *different* repo in window 2.
2. Log, in each window at branch-fetch time: the resolved socket path the status client connected to, `Platform.environment[''CLIDE_SOCK'']`, `Platform.environment[''CLIDE_WORKSPACE'']`, and `kernel.project.root`. The window showing the wrong branch will reveal whether it (a) connected to the other window''s socket, (b) read a stale/ambient env var, or (c) received a cross-process event it shouldn''t have.

**Hardening regardless of outcome:** `newWindow()` should spawn the child with an explicit, scrubbed environment — strip `CLIDE_SOCK`/`CLIDE_WORKSPACE` (and not rely on inheriting them) so a fresh window always computes its own per-root socket from its own workspace. A new window must never inherit another workspace''s IPC identity.', '**Symptom.** The git branch shown in the status bar (bottom-left, next to the `⎇` glyph) sometimes displays the branch of a *different* open clide workspace/window — it "bleeds" across windows. Intermittent ("at times"). Screenshot on the originating session shows `main` while a sibling window was on another branch.

**User hypothesis.** Lack of fencing in the message bus between multiple parallel open sessions/windows — events/state from one window reaching another.

**Why this matters.** Showing the wrong branch in a git-centric IDE is a footgun: the user can believe they are on a branch they are not, and act (commit/checkout) on that false premise. It also *contradicts a documented isolation invariant* — see T-269: "Separate clide WINDOWS are isolated (separate process, per-root IPC socket, per-repo deterministic session id), so parallel repos in separate windows are fine." This bug is evidence that invariant is not actually holding for the status-bar branch.

**Investigation (read-only, 2026-06-14).**
- Status-bar branch widget: `lib/builtin/git/src/git_status_item.dart:8-86` — subscribes to `kernel.events.on<DaemonEvent>()`, fetches branch via `ipc.request(''git.status'')` (sets `_branch = r.data[''branch'']`), and re-fetches on any `git.changed` event.
- Branch fetch path: `lib/src/git/client.dart:23-65` → `lib/src/daemon/git_commands.dart:46-53` (`git.status` handler).
- Event emit: `git_commands.dart:295-296` `_emitChanged()` → kernel `DaemonBus`.
- Kernel bus: `lib/kernel/src/events/bus.dart:5-20` is a single unfiltered `StreamController.broadcast()`; on project open the *same* `daemonBus` instance is reused (`lib/main.dart:110-111, 372-376`). No workspace/window id on events; no per-workspace filtering.
- Per-workspace socket IS correct: `lib/src/ipc/paths.dart:13-16` hashes (FNV-1a64) the workspace root → distinct socket per root (D-70).

**Two candidate mechanisms — fix work must confirm which (they are NOT the same):**
1. *Same-process / in-place bleed* — the global `DaemonBus` is shared across dispatchers, so events are not workspace-scoped. This is the in-memory path and overlaps with the now-closed T-367 ("Project switch leaks the entire previous workspace service set"). Only applies if the two surfaces share one process.
2. *Cross-process / true multi-window bleed* — separate windows are separate processes (per T-269), so an in-memory bus cannot cross them. A process-crossing path is required: most likely the branch widget resolving its IPC endpoint from an **inherited `CLIDE_SOCK`** (see T-215) instead of recomputing the socket from its own workspace root — e.g. window B launched from window A''s integrated terminal inherits A''s `CLIDE_SOCK` and connects to A''s IPC server. Same-root windows sharing one hashed socket is a second possibility.

**Repro info still needed (please confirm):**
- Were the two windows open on the *same* repo or *different* repos?
- Was the second window launched from inside the first window''s integrated terminal (i.e. could it have inherited `CLIDE_SOCK`)?

**Proposed direction.**
- Make the status-bar branch widget resolve its IPC endpoint and filter events strictly by *its own* workspace root, never trusting an ambient/inherited socket.
- Add a workspace/window identity to `DaemonEvent` (or scope the `DaemonBus` per workspace) so events carry provenance and consumers can fence (kernel/src/events/types.dart + bus.dart).
- Add a regression test: two workspace contexts; a `git.changed`/checkout in one must not mutate the other''s displayed branch.

**Related:** T-269 (closed — documents the isolation invariant this breaks), T-367 (closed — shared-bus/service-set leak on in-place switch), T-215 (CLIDE_SOCK/CLIDE_WORKSPACE export), D-70 (per-workspace socket path).

---

**Repro details confirmed (user, 2026-06-14):**
- The two windows were on *different repos* (distinct workspace roots → distinct hashed sockets per D-70; rules out same-socket collision).
- The second window was opened from the **File menu at the top**, not from an integrated terminal.

**Refined root-cause analysis (this changes the leading hypothesis).**

The File menu has two distinct paths (`lib/builtin/menubar/src/file_actions.dart`):
- `openFolder()`/`openPath()` (l.23-63) → `services.project.open()` = *in-place* switch, same process (the T-269/T-367 class). Produces ONE window, so not this report.
- `newWindow()` (l.30-32) → `Process.start(Platform.resolvedExecutable, const [], mode: ProcessStartMode.detached)` = a genuinely **separate detached process**. This matches the "parallel windows" symptom.

Two facts narrow it:
1. `CLIDE_SOCK`/`CLIDE_WORKSPACE` are NOT set in clide''s own process environment — they are a delta overlaid only on spawned Claude/PTY *child* processes (`lib/builtin/claude/src/agent_bootstrap.dart:57-71`, "Process.start keeps the parent environment by default, so this returns only the keys to add/override"). So a clean dock-launched window has no CLIDE_SOCK to leak.
2. `newWindow()` passes **no `environment:` override**, so the detached child inherits the parent clide process''s full environment verbatim.

**Leading hypothesis now:** environment inheritance through `newWindow()` when clide is self-hosted. If window 1 was itself launched from a clide-hosted terminal or as a clide agent, window 1''s process env already carries *that host''s* `CLIDE_SOCK`/`CLIDE_WORKSPACE`. `newWindow()` then spawns window 2 inheriting those vars — so any code in window 2 that resolves its IPC endpoint (or shells out to the `clide` CLI, which keys off `CLIDE_SOCK`) can bind to the wrong workspace''s server and surface its branch. This is consistent with: different repos, opened from the File menu, intermittent.

**Caveat / not yet pinned:** the in-app status widget reportedly resolves IPC via the computed `workspaceSocketPath(root)` (`lib/main.dart:357`), NOT via `CLIDE_SOCK` — so if that holds, inherited CLIDE_SOCK alone shouldn''t mislead the *in-process* status bar. The exact cross-process channel therefore still needs live confirmation. Do NOT assume; instrument.

**First diagnostic step for the fixer:**
1. Reproduce: open window 1, then File → New Window, then open a *different* repo in window 2.
2. Log, in each window at branch-fetch time: the resolved socket path the status client connected to, `Platform.environment[''CLIDE_SOCK'']`, `Platform.environment[''CLIDE_WORKSPACE'']`, and `kernel.project.root`. The window showing the wrong branch will reveal whether it (a) connected to the other window''s socket, (b) read a stale/ambient env var, or (c) received a cross-process event it shouldn''t have.

**Hardening regardless of outcome:** `newWindow()` should spawn the child with an explicit, scrubbed environment — strip `CLIDE_SOCK`/`CLIDE_WORKSPACE` (and not rely on inheriting them) so a fresh window always computes its own per-root socket from its own workspace. A new window must never inherit another workspace''s IPC identity.

Hardening slice landed 2026-09-23: File → New Window now spawns with CLIDE_SOCK / CLIDE_WORKSPACE stripped from the environment (FileActions.newWindowEnvironment, case-insensitive). The root cause of the branch bleed is still unconfirmed; ticket stays open.', NULL, '2026-09-23 07:59:12', '2026-09-23 07:59:12.311', '2026-09-23 07:59:12.311', NULL, 'a9c89fa6f58f5032f84a7139eb40135b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7K1FN7KD8S5ZVX2VM', 'description', 'Salvaged from gemini-report.md (external code-analysis). Today supply-chain checks are MANUAL — Makefile ''security'' target just prints ''Dart advisories reviewed manually before pubspec.yaml bumps''; there is no automated vuln scan or native-artifact integrity check. Automate both to harden the chain as we move to automated CI, complementing the existing prefer-zero-deps / exact-pin / licenses.yaml discipline (D-31, D-61, D-63).

1. Automate Dart dependency vulnerability scanning:
   - Run an automated scanner (e.g. Google osv-scanner) against pubspec.lock on every push/PR.
   - Wire into the CI workflow and/or the Makefile ''security'' target so it runs in push-check.
   - Fail the gate on known advisories; keep it quiet/zero-noise otherwise.

2. Automate native/vendored dependency SHA256 verification (D-63):
   - CI step / pre-push script that parses assets/licenses.yaml (+ relevant BUILD.md) for declared native artifacts (dugite-native, libtree-sitter.so), and verifies the SHA256 of the vendored binaries against the committed/expected hashes.
   - Guards against silent corruption or tampering of vendored binaries; ensures they match the audited sources.

Notes:
- Both should be low-noise, runnable locally and in CI (candidate home: ci/security.sh + a Makefile target, surfaced via push-check).
- Scope is automation only — the manual review discipline already exists; this makes it enforced rather than convention.
- Source report (gemini-report.md) is being removed from the repo once this ticket captures its only actionable content.', 'Salvaged from gemini-report.md (external code-analysis). Today supply-chain checks are MANUAL — Makefile ''security'' target just prints ''Dart advisories reviewed manually before pubspec.yaml bumps''; there is no automated vuln scan or native-artifact integrity check. Automate both to harden the chain as we move to automated CI, complementing the existing prefer-zero-deps / exact-pin / licenses.yaml discipline (D-31, D-61, D-63).

1. Automate Dart dependency vulnerability scanning:
   - Run an automated scanner (e.g. Google osv-scanner) against pubspec.lock on every push/PR.
   - Wire into the CI workflow and/or the Makefile ''security'' target so it runs in push-check.
   - Fail the gate on known advisories; keep it quiet/zero-noise otherwise.

2. Automate native/vendored dependency SHA256 verification (D-63):
   - CI step / pre-push script that parses assets/licenses.yaml (+ relevant BUILD.md) for declared native artifacts (dugite-native, libtree-sitter.so), and verifies the SHA256 of the vendored binaries against the committed/expected hashes.
   - Guards against silent corruption or tampering of vendored binaries; ensures they match the audited sources.

Notes:
- Both should be low-noise, runnable locally and in CI (candidate home: ci/security.sh + a Makefile target, surfaced via push-check).
- Scope is automation only — the manual review discipline already exists; this makes it enforced rather than convention.
- Source report (gemini-report.md) is being removed from the repo once this ticket captures its only actionable content.

SHA half landed 2026-09-23: native/linux-x64/SHA256SUMS + ci/verify_native.sh + make native-verify (sha256sum --check --strict over native/*/SHA256SUMS). Not yet wired into push-check / CI — open question for the user. Stays open until the gate is enforced.', NULL, '2026-09-23 07:59:39', '2026-09-23 07:59:39.817', '2026-09-23 07:59:39.817', NULL, '69ef2676a88ee14694396dbdcbe5b029', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4DAQ2CEFESG9JGMZ8', 'description', 'The pre-push gate (make push-check) and the inner-loop make test are slow; cost is dominated by ''flutter test --coverage --exclude-tags pty'' running the whole flutter suite WITH coverage instrumentation (ci/test.sh). Two concrete levers found by reading the pipeline: (1) FREE WIN — a11y tests run TWICE in push-check: the coverage run in ci/test.sh has no path filter so it already includes test/a11y/, then ci/test_a11y.sh (''flutter test test/a11y/'') runs them again in a separate flutter invocation, chained AFTER test (so not even fast-fail). Drop test-a11y from the push-check chain (keep ''make test-a11y'' as a standalone dev target) to remove a whole redundant flutter compile+boot+run; same tests still execute under test. (2) Coverage is on the dev inner loop — make test always runs --coverage, which is only needed where coverage-gate reads lcov (push-check/CI). Split a fast no-coverage ''make test'' for the edit loop from a coverage run used by push-check/CI; the script even claims <60s warm but coverage blows past that. MEASURE FIRST (cheap): time each ci/*.sh step, check ''flutter test --concurrency'' vs nproc, and look at per-file timing for golden/alchemist tests before further changes. Acceptance: dev ''make test'' runs without coverage and is meaningfully faster; push-check no longer double-runs the a11y suite; coverage is still gated (coverage-gate unchanged, floor 95); all gates stay green; the fast-vs-coverage split is documented in the Makefile/CONTRIBUTING. Domain: tooling/CI. Raised 2026-05-31 while the push gate kept interrupting flow.

Add a per-test timeout to the gate''s flutter test (e.g. ci/test.sh: ''flutter test --coverage --timeout 60s''). Motivation discovered 2026-05-31: a hung pumpAndSettle has a 10-MINUTE default timeout, so a few hanging widget tests wedge make push-check for 30+ minutes — which is almost certainly why a MacBook session resorted to ''git push --no-verify'' (the gate never returned; it was not disabled, it was hung). A tight per-test timeout makes any future hang fail fast (60s) instead of wedging a pre-push, so the gate stays usable and nobody is tempted to bypass it. Pair with: keep writing pump()-bounded tests instead of pumpAndSettle() where a view has overlapping async loads (see the T-188 decision_reader_test hang).

Measured 2026-05-31 (16-core box, warm cache, full flutter suite --exclude-tags pty): coverage default-concurrency = ~36s; coverage --concurrency=12 = ~37s (NO improvement — coverage runs are concurrency-insensitive, the instrumentation/collection dominates); NO-coverage --concurrency=12 = ~21s. Conclusions: (1) Concurrency only helps the NON-coverage path — do NOT bother adding --concurrency to the coverage gate, it buys nothing. (2) The dev inner-loop win is concrete: a no-coverage ''make test'' with --concurrency=12 runs ~21s vs ~36s today (~40% faster) — this is how we ''beat 40s'' for the edit loop. (3) The push-check coverage run is floored at ~36s by coverage itself; getting below that needs a different coverage approach (package:coverage via VM service, or coverage-on-changed-files) — out of scope for the quick win. So the actionable set is unchanged: no-coverage+concurrency dev target, coverage-only-in-push, drop the redundant a11y pass, add a per-test --timeout for hang-safety.', 'The pre-push gate (make push-check) and the inner-loop make test are slow; cost is dominated by ''flutter test --coverage --exclude-tags pty'' running the whole flutter suite WITH coverage instrumentation (ci/test.sh). Two concrete levers found by reading the pipeline: (1) FREE WIN — a11y tests run TWICE in push-check: the coverage run in ci/test.sh has no path filter so it already includes test/a11y/, then ci/test_a11y.sh (''flutter test test/a11y/'') runs them again in a separate flutter invocation, chained AFTER test (so not even fast-fail). Drop test-a11y from the push-check chain (keep ''make test-a11y'' as a standalone dev target) to remove a whole redundant flutter compile+boot+run; same tests still execute under test. (2) Coverage is on the dev inner loop — make test always runs --coverage, which is only needed where coverage-gate reads lcov (push-check/CI). Split a fast no-coverage ''make test'' for the edit loop from a coverage run used by push-check/CI; the script even claims <60s warm but coverage blows past that. MEASURE FIRST (cheap): time each ci/*.sh step, check ''flutter test --concurrency'' vs nproc, and look at per-file timing for golden/alchemist tests before further changes. Acceptance: dev ''make test'' runs without coverage and is meaningfully faster; push-check no longer double-runs the a11y suite; coverage is still gated (coverage-gate unchanged, floor 95); all gates stay green; the fast-vs-coverage split is documented in the Makefile/CONTRIBUTING. Domain: tooling/CI. Raised 2026-05-31 while the push gate kept interrupting flow.

Add a per-test timeout to the gate''s flutter test (e.g. ci/test.sh: ''flutter test --coverage --timeout 60s''). Motivation discovered 2026-05-31: a hung pumpAndSettle has a 10-MINUTE default timeout, so a few hanging widget tests wedge make push-check for 30+ minutes — which is almost certainly why a MacBook session resorted to ''git push --no-verify'' (the gate never returned; it was not disabled, it was hung). A tight per-test timeout makes any future hang fail fast (60s) instead of wedging a pre-push, so the gate stays usable and nobody is tempted to bypass it. Pair with: keep writing pump()-bounded tests instead of pumpAndSettle() where a view has overlapping async loads (see the T-188 decision_reader_test hang).

Measured 2026-05-31 (16-core box, warm cache, full flutter suite --exclude-tags pty): coverage default-concurrency = ~36s; coverage --concurrency=12 = ~37s (NO improvement — coverage runs are concurrency-insensitive, the instrumentation/collection dominates); NO-coverage --concurrency=12 = ~21s. Conclusions: (1) Concurrency only helps the NON-coverage path — do NOT bother adding --concurrency to the coverage gate, it buys nothing. (2) The dev inner-loop win is concrete: a no-coverage ''make test'' with --concurrency=12 runs ~21s vs ~36s today (~40% faster) — this is how we ''beat 40s'' for the edit loop. (3) The push-check coverage run is floored at ~36s by coverage itself; getting below that needs a different coverage approach (package:coverage via VM service, or coverage-on-changed-files) — out of scope for the quick win. So the actionable set is unchanged: no-coverage+concurrency dev target, coverage-only-in-push, drop the redundant a11y pass, add a per-test --timeout for hang-safety.

Verified 2026-09-23 against ci/test.sh + Makefile: dev make test runs without coverage at --concurrency=12; test-coverage is separate and only push-check uses it; push-check no longer runs test-a11y separately (test-coverage covers test/a11y); every flutter/dart test line passes --timeout 60s. All acceptance items met. Closing.', NULL, '2026-09-23 08:01:29', '2026-09-23 08:01:29.242', '2026-09-23 08:01:29.242', NULL, '0314d1cc7bb26078b3037efb6d3ba573', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDC7B2MFQZVR1K9E30FXDR', 'description', 'CLAUDE.md and README still say "tmux owns Claude session persistence (D-41)" — superseded by D-75/D-77 per docs/architecture.md. README says "Pre-v2.0 (2.0.0-dev)" while pubspec is at v2.3.3, and headlines "canvas and graph surfaces" that are a 17-line stub and a flat ListView respectively (T-7 epic was cancelled).

Fix: rewrite the stale paragraphs in both files to match current architecture (clide-managed stream-json sessions); fix the README version line (or derive it); demote canvas/graph to roadmap wording or drop them. The repo''s honesty is its brand; the README is the one off-brand surface.

Acceptance: no tmux-persistence claim outside historical D-records; README version matches pubspec; every README feature claim maps to shipped behavior.

Board sweep 2026-08-12: the same superseded claim is also sitting in TICKET BODIES, not just CLAUDE.md and the README.

Roughly seven mentions of tmux-as-current-fact survive across open tickets. Confirmed by reading: T-47 ("tmux owns Claude session persistence (D-41); the app re-attaches on restart") and T-46. Both are installer/self-update tickets whose reasoning partly RESTS on that claim — T-47 argues an in-place update won''t lose sessions because they live in tmux outside the bundle. Under D-77 that argument no longer holds as written, so this is a stale premise, not just a stale sentence.

Not folded into this ticket''s scope unilaterally — T-392 is scoped to the front-door docs. Flagged here because whoever fixes the docs drift is the person holding the context to judge the ticket bodies too, and because a wrong premise inside a ticket is worse than a wrong sentence in a README: it survives into whatever gets built from it.', 'CLAUDE.md and README still say "tmux owns Claude session persistence (D-41)" — superseded by D-75/D-77 per docs/architecture.md. README says "Pre-v2.0 (2.0.0-dev)" while pubspec is at v2.3.3, and headlines "canvas and graph surfaces" that are a 17-line stub and a flat ListView respectively (T-7 epic was cancelled).

Fix: rewrite the stale paragraphs in both files to match current architecture (clide-managed stream-json sessions); fix the README version line (or derive it); demote canvas/graph to roadmap wording or drop them. The repo''s honesty is its brand; the README is the one off-brand surface.

Acceptance: no tmux-persistence claim outside historical D-records; README version matches pubspec; every README feature claim maps to shipped behavior.

Board sweep 2026-08-12: the same superseded claim is also sitting in TICKET BODIES, not just CLAUDE.md and the README.

Roughly seven mentions of tmux-as-current-fact survive across open tickets. Confirmed by reading: T-47 ("tmux owns Claude session persistence (D-41); the app re-attaches on restart") and T-46. Both are installer/self-update tickets whose reasoning partly RESTS on that claim — T-47 argues an in-place update won''t lose sessions because they live in tmux outside the bundle. Under D-77 that argument no longer holds as written, so this is a stale premise, not just a stale sentence.

Not folded into this ticket''s scope unilaterally — T-392 is scoped to the front-door docs. Flagged here because whoever fixes the docs drift is the person holding the context to judge the ticket bodies too, and because a wrong premise inside a ticket is worse than a wrong sentence in a README: it survives into whatever gets built from it.

Verified 2026-09-23: README and CLAUDE.md now describe --resume (D-77) persistence with no tmux claim; README has no version line to drift; the canvas (editable CanvasView) and graph (GraphPainter) surfaces README line 3 names are real now. Front-door scope done. The stale tmux premise in T-46/T-47 bodies was explicitly out of scope here — judge it when those tickets are picked up. Closing.', NULL, '2026-09-23 08:01:31', '2026-09-23 08:01:31.069', '2026-09-23 08:01:31.069', NULL, '20b5e53f6b80224424e8164c660addc5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4DAQ2CEFESG9JGMZ8', 'status', 'backlog', 'done', NULL, '2026-09-23 08:01:32', '2026-09-23 08:01:32.576', '2026-09-23 08:01:32.576', NULL, '5aeee5fc61a9e7cd5037303b4aa1cc03', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDC7B2MFQZVR1K9E30FXDR', 'status', 'backlog', 'done', NULL, '2026-09-23 08:01:32', '2026-09-23 08:01:32.583', '2026-09-23 08:01:32.583', NULL, '40fd8fe9cef1ff4c58f02ebc791f6278', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7K1FN7KD8S5ZVX2VM', 'description', 'Salvaged from gemini-report.md (external code-analysis). Today supply-chain checks are MANUAL — Makefile ''security'' target just prints ''Dart advisories reviewed manually before pubspec.yaml bumps''; there is no automated vuln scan or native-artifact integrity check. Automate both to harden the chain as we move to automated CI, complementing the existing prefer-zero-deps / exact-pin / licenses.yaml discipline (D-31, D-61, D-63).

1. Automate Dart dependency vulnerability scanning:
   - Run an automated scanner (e.g. Google osv-scanner) against pubspec.lock on every push/PR.
   - Wire into the CI workflow and/or the Makefile ''security'' target so it runs in push-check.
   - Fail the gate on known advisories; keep it quiet/zero-noise otherwise.

2. Automate native/vendored dependency SHA256 verification (D-63):
   - CI step / pre-push script that parses assets/licenses.yaml (+ relevant BUILD.md) for declared native artifacts (dugite-native, libtree-sitter.so), and verifies the SHA256 of the vendored binaries against the committed/expected hashes.
   - Guards against silent corruption or tampering of vendored binaries; ensures they match the audited sources.

Notes:
- Both should be low-noise, runnable locally and in CI (candidate home: ci/security.sh + a Makefile target, surfaced via push-check).
- Scope is automation only — the manual review discipline already exists; this makes it enforced rather than convention.
- Source report (gemini-report.md) is being removed from the repo once this ticket captures its only actionable content.

SHA half landed 2026-09-23: native/linux-x64/SHA256SUMS + ci/verify_native.sh + make native-verify (sha256sum --check --strict over native/*/SHA256SUMS). Not yet wired into push-check / CI — open question for the user. Stays open until the gate is enforced.', 'Salvaged from gemini-report.md (external code-analysis). Today supply-chain checks are MANUAL — Makefile ''security'' target just prints ''Dart advisories reviewed manually before pubspec.yaml bumps''; there is no automated vuln scan or native-artifact integrity check. Automate both to harden the chain as we move to automated CI, complementing the existing prefer-zero-deps / exact-pin / licenses.yaml discipline (D-31, D-61, D-63).

1. Automate Dart dependency vulnerability scanning:
   - Run an automated scanner (e.g. Google osv-scanner) against pubspec.lock on every push/PR.
   - Wire into the CI workflow and/or the Makefile ''security'' target so it runs in push-check.
   - Fail the gate on known advisories; keep it quiet/zero-noise otherwise.

2. Automate native/vendored dependency SHA256 verification (D-63):
   - CI step / pre-push script that parses assets/licenses.yaml (+ relevant BUILD.md) for declared native artifacts (dugite-native, libtree-sitter.so), and verifies the SHA256 of the vendored binaries against the committed/expected hashes.
   - Guards against silent corruption or tampering of vendored binaries; ensures they match the audited sources.

Notes:
- Both should be low-noise, runnable locally and in CI (candidate home: ci/security.sh + a Makefile target, surfaced via push-check).
- Scope is automation only — the manual review discipline already exists; this makes it enforced rather than convention.
- Source report (gemini-report.md) is being removed from the repo once this ticket captures its only actionable content.

SHA half landed 2026-09-23: native/linux-x64/SHA256SUMS + ci/verify_native.sh + make native-verify (sha256sum --check --strict over native/*/SHA256SUMS). Not yet wired into push-check / CI — open question for the user. Stays open until the gate is enforced.

Enforced 2026-09-23: native-verify now runs in make push-check (with the instant gates) and in the pre-push hook''s fast path, so a push that only touches native/ is still verified. osv half was already done. Both halves complete.', NULL, '2026-09-23 08:05:10', '2026-09-23 08:05:10.165', '2026-09-23 08:05:10.165', NULL, 'ddd59375af5c41de86184b1e054e4b09', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7K1FN7KD8S5ZVX2VM', 'status', 'backlog', 'review', NULL, '2026-09-23 08:05:10', '2026-09-23 08:05:10.262', '2026-09-23 08:05:10.262', NULL, '3aaf37909dae18f724be787e0311131a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'description', 'After an app reload the primary Claude pane continues its conversation (`--resume`, D-77), but secondary panes disappear. By design today: D-41 made secondaries ephemeral — each spawn gets a random id (`freshSessionId()`, claude_pane.dart) and the open secondary tabs are not persisted. The transcripts survive on disk (reachable via `/resume`), so nothing is lost; the tabs just don''t come back.

User report 2026-09-23: resume "works well … the main conversation seems to reliably continue after an app reload. Only thing is that conversations in secondary panels disappear."

Want: on relaunch, restore the workspace''s open secondary panes, each resuming its own session, in their previous order.

Shape: persist the ordered list of secondary session ids per workspace in user-scope state (D-93/D-53 — not in the repo); on boot, spawn a secondary per entry with `resume: true` when its transcript exists (skip entries whose transcript is gone). Closing a secondary removes it from the list. Forks (`--fork-session`) persist their resolved claude session id, not the fork source.

Needs a D-41 amendment: "secondaries are ephemeral" → "secondaries persist until closed".

Acceptance: open two secondaries, talk in each, restart clide → both tabs return with their conversations; a closed secondary does not come back; a secondary whose transcript was deleted is dropped silently.', 'After an app reload the primary Claude pane continues its conversation (`--resume`, D-77), but secondary panes disappear. By design today: D-41 made secondaries ephemeral — each spawn gets a random id (`freshSessionId()`, claude_pane.dart) and the open secondary tabs are not persisted. The transcripts survive on disk (reachable via `/resume`), so nothing is lost; the tabs just don''t come back.

User report 2026-09-23: resume "works well … the main conversation seems to reliably continue after an app reload. Only thing is that conversations in secondary panels disappear."

Want: on relaunch, restore the workspace''s open secondary panes, each resuming its own session, in their previous order.

Shape: persist the ordered list of secondary session ids per workspace in user-scope state (D-93/D-53 — not in the repo); on boot, spawn a secondary per entry with `resume: true` when its transcript exists (skip entries whose transcript is gone). Closing a secondary removes it from the list. Forks (`--fork-session`) persist their resolved claude session id, not the fork source.

Needs a D-41 amendment: "secondaries are ephemeral" → "secondaries persist until closed".

Acceptance: open two secondaries, talk in each, restart clide → both tabs return with their conversations; a closed secondary does not come back; a secondary whose transcript was deleted is dropped silently.

Decision 2026-09-23 (user): NOT automatic restore. Reopen on demand instead — secondaries stay ephemeral across relaunch (D-41 unchanged), but clide remembers the workspace''s last set of open secondary session ids (user-scope state, not the repo) and offers a ''Reopen last session''s tabs'' command (+ D-6 CLI verb), which re-spawns each with resume where the transcript still exists, in the previous order. Acceptance changes accordingly: after restart the tabs are NOT back; invoking the command brings them back with their conversations; a deleted transcript is skipped silently.', NULL, '2026-09-23 08:23:28', '2026-09-23 08:23:28.566', '2026-09-23 08:23:28.566', NULL, '58b219361d2250c0559a5309014cd931', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FYEH0XC2WK9S7333BGH7C898', 'description', 'The backlog section of the tickets pane has **112 tickets** in it and is
effectively unbrowsable. Raised while working the companion initiative, which
added ~40 of them in a day.

Deliberately framed as *consider*: the obvious fix is newest-first, and it may
well be right, but it is worth a moment''s thought before it becomes the answer —
recency is not the same as relevance, and an ordering that hides old work is a
different failure from one that buries new work.

## What it does today

`tickets_view.dart` groups by status into collapsible sections and renders each
group in whatever order `pql.tickets.list` returns. There is no client-side sort
at all, so the order is pql''s — and the pane inherits it silently.

So step one is to find out what that order actually is before changing anything:
if pql already returns newest-first, the problem is length, not sequence, and
sorting fixes nothing.

## Options worth weighing

- **Newest first.** What was asked for, and the cheapest. Matches how the list is
  used in practice — the thing you filed ten minutes ago is the thing you want.
  Cost: long-lived tickets sink permanently, which is how a backlog quietly turns
  into a graveyard.
- **Group by epic/parent inside the section.** The companion work is ~40 tickets
  across five epics; as a flat list that is noise, as five collapsed groups it is
  five lines. Probably the bigger win, and it composes with any sort.
- **Collapse the section by default past a threshold**, or cap it with a "show
  all" — the pane already has expand/collapse machinery per section
  (`_isSectionExpanded`).
- **Filter to the active initiative.** The strongest reduction and the most
  opinionated; the filter chips (T-343) are the existing precedent.

## Worth checking first

- Whether the ordering should be a **setting** rather than a decision. It is the
  kind of preference that splits people, and the pane has no ordering controls at
  all today.
- Whether `pql.tickets.list` can sort server-side. Sorting 112 rows client-side
  is free, but the CLI parity surface (D-6) should agree with the pane, and a
  pane-only sort would make `clide` and the UI disagree about "the list".
- The board view (`pql ticket board`) is a separate surface with the same
  pressure; whatever is decided here should not leave the two contradicting each
  other.

**Order confirmed empirically (2026-08-09), and it makes this smaller.**

`pql.tickets.list` returns backlog **strictly ascending by numeric ticket id** — T-8 first through T-559 last. Checked all 113: no lexicographic breakage, T-99 correctly precedes T-100. Ids are chronological, so id order *is* filing order.

So there is no sorting bug and no comparator to fix. ''Newest first'' is a reverse, and it is close to a one-liner wherever the list is materialised.

That leaves the real question, which is not order:

- Reversing gives a browsable **top** and an unreachable **bottom**. For 112 items that is an improvement, not a solution — the old-but-live tickets simply move from ''buried at the end'' to ''buried at the end'' with different neighbours.
- **Grouping by epic/parent** is the change that makes the count stop mattering, and it composes with either direction.
- Reversing also **inverts the implicit priority signal** the list currently carries: oldest-first reads as a queue. Worth being deliberate about, since nobody chose the current order either.

If this is picked up as just the reverse, say so on the ticket and split the grouping out rather than leaving it implied — the reverse alone will feel like a fix for about a week.', 'The backlog section of the tickets pane has **112 tickets** in it and is
effectively unbrowsable. Raised while working the companion initiative, which
added ~40 of them in a day.

Deliberately framed as *consider*: the obvious fix is newest-first, and it may
well be right, but it is worth a moment''s thought before it becomes the answer —
recency is not the same as relevance, and an ordering that hides old work is a
different failure from one that buries new work.

## What it does today

`tickets_view.dart` groups by status into collapsible sections and renders each
group in whatever order `pql.tickets.list` returns. There is no client-side sort
at all, so the order is pql''s — and the pane inherits it silently.

So step one is to find out what that order actually is before changing anything:
if pql already returns newest-first, the problem is length, not sequence, and
sorting fixes nothing.

## Options worth weighing

- **Newest first.** What was asked for, and the cheapest. Matches how the list is
  used in practice — the thing you filed ten minutes ago is the thing you want.
  Cost: long-lived tickets sink permanently, which is how a backlog quietly turns
  into a graveyard.
- **Group by epic/parent inside the section.** The companion work is ~40 tickets
  across five epics; as a flat list that is noise, as five collapsed groups it is
  five lines. Probably the bigger win, and it composes with any sort.
- **Collapse the section by default past a threshold**, or cap it with a "show
  all" — the pane already has expand/collapse machinery per section
  (`_isSectionExpanded`).
- **Filter to the active initiative.** The strongest reduction and the most
  opinionated; the filter chips (T-343) are the existing precedent.

## Worth checking first

- Whether the ordering should be a **setting** rather than a decision. It is the
  kind of preference that splits people, and the pane has no ordering controls at
  all today.
- Whether `pql.tickets.list` can sort server-side. Sorting 112 rows client-side
  is free, but the CLI parity surface (D-6) should agree with the pane, and a
  pane-only sort would make `clide` and the UI disagree about "the list".
- The board view (`pql ticket board`) is a separate surface with the same
  pressure; whatever is decided here should not leave the two contradicting each
  other.

**Order confirmed empirically (2026-08-09), and it makes this smaller.**

`pql.tickets.list` returns backlog **strictly ascending by numeric ticket id** — T-8 first through T-559 last. Checked all 113: no lexicographic breakage, T-99 correctly precedes T-100. Ids are chronological, so id order *is* filing order.

So there is no sorting bug and no comparator to fix. ''Newest first'' is a reverse, and it is close to a one-liner wherever the list is materialised.

That leaves the real question, which is not order:

- Reversing gives a browsable **top** and an unreachable **bottom**. For 112 items that is an improvement, not a solution — the old-but-live tickets simply move from ''buried at the end'' to ''buried at the end'' with different neighbours.
- **Grouping by epic/parent** is the change that makes the count stop mattering, and it composes with either direction.
- Reversing also **inverts the implicit priority signal** the list currently carries: oldest-first reads as a queue. Worth being deliberate about, since nobody chose the current order either.

If this is picked up as just the reverse, say so on the ticket and split the grouping out rather than leaving it implied — the reverse alone will feel like a fix for about a week.

Decision 2026-09-23 (user): group + newest first. Inside each status section, group tickets under their epic/parent as collapsible groups (collapsed by default), newest first within a group and groups ordered by their newest member; parentless tickets go in an ''Other'' group. Keep D-6 parity in mind: the CLI list should be able to return the same order/grouping (server-side sort in pql if available, otherwise a clide-side view contract both surfaces share).', NULL, '2026-09-23 08:23:30', '2026-09-23 08:23:30.461', '2026-09-23 08:23:30.461', NULL, 'b39e89cf10107e5b237b2a718bce27d2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6048VEGFDNEBHFMM4', 'description', 'When file paths to files inside the current repo appear in the Claude conversation, show them relative to the repo root rather than as absolute paths.

**DESIGN OPEN — needs discussion before implementation.** The exact presentation is undecided.

**Intent**
- Paths that resolve inside the workspace (CLIDE_WORKSPACE / git repo root) should read as repo-relative (e.g. `lib/app.dart` instead of `/var/mnt/data/projects/clide/lib/app.dart`).
- Goal is readability — strip the absolute prefix that''s noise for in-repo files.

**Open questions to settle in discussion**
- Visual treatment: silently rewrite the displayed text? show relative with the absolute available on hover/tooltip? a leading marker (e.g. `./` or a repo-root glyph)?
- Scope: only linkified/recognized refs (ties to T-300), or any path-looking token in the rendered output?
- Out-of-repo / absolute paths: leave untouched, or abbreviate (e.g. `~`)?
- Interaction with copy: does copying yield the relative or the original absolute path?
- Does this happen at render time only, or is the underlying text also normalized?

**Related**
- Pairs with T-300 (clickable file references) — same conversation/markdown render path; likely share path-detection + workspace-root resolution.', 'When file paths to files inside the current repo appear in the Claude conversation, show them relative to the repo root rather than as absolute paths.

**DESIGN OPEN — needs discussion before implementation.** The exact presentation is undecided.

**Intent**
- Paths that resolve inside the workspace (CLIDE_WORKSPACE / git repo root) should read as repo-relative (e.g. `lib/app.dart` instead of `/var/mnt/data/projects/clide/lib/app.dart`).
- Goal is readability — strip the absolute prefix that''s noise for in-repo files.

**Open questions to settle in discussion**
- Visual treatment: silently rewrite the displayed text? show relative with the absolute available on hover/tooltip? a leading marker (e.g. `./` or a repo-root glyph)?
- Scope: only linkified/recognized refs (ties to T-300), or any path-looking token in the rendered output?
- Out-of-repo / absolute paths: leave untouched, or abbreviate (e.g. `~`)?
- Interaction with copy: does copying yield the relative or the original absolute path?
- Does this happen at render time only, or is the underlying text also normalized?

**Related**
- Pairs with T-300 (clickable file references) — same conversation/markdown render path; likely share path-detection + workspace-root resolution.

Decision 2026-09-23 (user): render-time only. In-repo paths display repo-relative (lib/app.dart); hover/tooltip shows the absolute path; copy yields the ABSOLUTE path so pastes work anywhere. Out-of-repo paths under $HOME display as ~/...; others untouched. The underlying text (what Claude sees, the transcript) is never rewritten. Share path detection + workspace-root resolution with T-300.', NULL, '2026-09-23 08:23:32', '2026-09-23 08:23:32.119', '2026-09-23 08:23:32.119', NULL, 'd2a2746b2de8ea737b2130e71f0de34c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67JSC5RKS6M9182KG', 'description', 'Spec lists images as a right-panel section. No extension exists yet.

Relevance note (2026-06-10 sweep): likely superseded. The image card + full-screen lightbox shipped (T-249/T-252) and the canvas epic (T-317, D-91) folds image display into the unified drawing-card renderer rather than a separate context-panel tab. Confirm whether a distinct images rail section is still wanted; otherwise close in favor of the canvas path.', 'Spec lists images as a right-panel section. No extension exists yet.

Relevance note (2026-06-10 sweep): likely superseded. The image card + full-screen lightbox shipped (T-249/T-252) and the canvas epic (T-317, D-91) folds image display into the unified drawing-card renderer rather than a separate context-panel tab. Confirm whether a distinct images rail section is still wanted; otherwise close in favor of the canvas path.

Decision 2026-09-23 (user): keep and build, re-scoped. The Images tab is the target for image files opened from the FILE TREE (click an image in the tree → it opens in the Images tab of the context panel). It is not a gallery of conversation images — conversation images keep the inline image/drawing card + lightbox system, which is the preferred flow there.', NULL, '2026-09-23 08:23:33', '2026-09-23 08:23:33.599', '2026-09-23 08:23:33.599', NULL, 'b8fc5f91985aefacd125e9d7cb99a363', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6WZ7DKVDFAGQ4QDMG', 'description', 'Spun off from the T-54 dock design (D-87), which scoped the bottom dock to read-only output (logs + problems) and explicitly kept the terminal OUT of it. Terminals are core functionality, not an afterthought: the terminal should live in the editor pane (above Claude, D-49 editor-mode) as a first-class peer of editor and diff — not in a read-only log strip.

First-class means: reachable by a dedicated keybinding (e.g. Ctrl+`), multiple terminals, and tmux-backed persistence (D-41/D-75) so swapping away never stops a running terminal — you swap back and the build is still streaming. Today the terminal is a generic workspace tab; this moves it into the editor-mode family.

OPEN QUESTION (decide here): clide''s editor-mode is swap (one surface above Claude at a time), so you cannot currently watch a terminal AND edit a file side-by-side. Options: (a) swap-only, leaning on tmux persistence + a fast toggle; or (b) allow the editor pane to split so a terminal can sit beside editor/diff. This is a facet of Q-27 (two-editor split) — resolve them together. Relates to D-47 (Claude-is-home), D-48 (chrome budget), D-49 (editor-mode), D-84 (diff placement, the existing editor-mode peer).', 'Spun off from the T-54 dock design (D-87), which scoped the bottom dock to read-only output (logs + problems) and explicitly kept the terminal OUT of it. Terminals are core functionality, not an afterthought: the terminal should live in the editor pane (above Claude, D-49 editor-mode) as a first-class peer of editor and diff — not in a read-only log strip.

First-class means: reachable by a dedicated keybinding (e.g. Ctrl+`), multiple terminals, and tmux-backed persistence (D-41/D-75) so swapping away never stops a running terminal — you swap back and the build is still streaming. Today the terminal is a generic workspace tab; this moves it into the editor-mode family.

OPEN QUESTION (decide here): clide''s editor-mode is swap (one surface above Claude at a time), so you cannot currently watch a terminal AND edit a file side-by-side. Options: (a) swap-only, leaning on tmux persistence + a fast toggle; or (b) allow the editor pane to split so a terminal can sit beside editor/diff. This is a facet of Q-27 (two-editor split) — resolve them together. Relates to D-47 (Claude-is-home), D-48 (chrome budget), D-49 (editor-mode), D-84 (diff placement, the existing editor-mode peer).

Decision 2026-09-23 (user): SPLIT NOW. Build editor-pane splitting as part of this ticket so a terminal can sit beside an editor or diff (not swap-only). This effectively answers Q-27 (two-editor split) in favour of splitting — record a D-record resolving Q-27 when implementing. Note: the ''tmux-backed persistence'' premise above is stale (D-77); terminals persist because their PTYs live in the window process and keep running while hidden, and D-110 keeps the process alive when the window closes.', NULL, '2026-09-23 08:23:37', '2026-09-23 08:23:37.357', '2026-09-23 08:23:37.357', NULL, 'bf76145b0beee322d1c80247212f68f0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4XBRZJ6DEHFWREWC0', 'description', 'Deferred from T-48 v1. Adds the Edit top-level menu to the hat-bar application menu (T-48). Items (undo, redo, cut, copy, paste, select-all, find/replace) reference registered command ids and route to the focused surface; inapplicable items render disabled (greyed), per T-48''s show-but-disable context behavior. Depends on focused-surface command routing so the menu reflects the active editor/pane. Reuses T-48''s menu widgets, command->item mapping, and keyboard/a11y model.', 'Deferred from T-48 v1. Adds the Edit top-level menu to the hat-bar application menu (T-48). Items (undo, redo, cut, copy, paste, select-all, find/replace) reference registered command ids and route to the focused surface; inapplicable items render disabled (greyed), per T-48''s show-but-disable context behavior. Depends on focused-surface command routing so the menu reflects the active editor/pane. Reuses T-48''s menu widgets, command->item mapping, and keyboard/a11y model.

Decision 2026-09-23 (user): build the Edit menu (routed to the focused surface, inapplicable items greyed). The Selection menu (T-272) is dropped.', NULL, '2026-09-23 08:23:38', '2026-09-23 08:23:38.315', '2026-09-23 08:23:38.315', NULL, 'c9e09d452e503328123ea09539ec8a12', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67PDXAFTPPW7B1WDR', 'description', 'Deferred from T-48 v1. Adds the Selection top-level menu to the hat-bar application menu (T-48). Selection operations reference registered command ids and route to the focused surface; inapplicable items render disabled per T-48''s show-but-disable context behavior. Depends on focused-surface command routing. Reuses T-48''s menu widgets, command->item mapping, and keyboard/a11y model.', 'Deferred from T-48 v1. Adds the Selection top-level menu to the hat-bar application menu (T-48). Selection operations reference registered command ids and route to the focused surface; inapplicable items render disabled per T-48''s show-but-disable context behavior. Depends on focused-surface command routing. Reuses T-48''s menu widgets, command->item mapping, and keyboard/a11y model.

Decision 2026-09-23 (user): dropped. Selection operations are editor-only and already reachable via keybindings and the context menu; only the Edit menu (T-271) is built. Closing.', NULL, '2026-09-23 08:23:39', '2026-09-23 08:23:39.346', '2026-09-23 08:23:39.346', NULL, 'f26e3db18589bc9931b6f286c0d4efd0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FCDM61KAA3GV3CVTE8PAZ8N0', 'description', NULL, 'Decision 2026-09-23 (user): D-111 — one window process per workspace; in-place switching is retired. WorkspaceService.open(root, {target}) is the sole primitive: newWindow spawns Process.start(exe, [''--workspace'', root]) with a scrubbed env (via the D-110 loader when running); ''open here'' spawns the new process then closes the current one (busy-turn guard applies), carrying window geometry across. project.open''s in-place service rebuild is removed. Q-51 resolved.', NULL, '2026-09-23 08:23:41', '2026-09-23 08:23:41.261', '2026-09-23 08:23:41.261', NULL, 'c334346c62008f2bd7baf3ea52b786e4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGVCY4M0ZK72HZT2FSZF968W', 'description', 'GitHub Releases exist but carry no downloadable packages — no per-platform bundles are attached. clide''s self-update download/apply (T-47 P2/P3) and any future binary install need signed, checksummed artifacts on each Release. `.github/workflows` is empty today; this stands up the release channel.

## Scope
1. CI workflow (.github/workflows) triggered on a release — the `release vX.Y.Z` tag (T-393 already wires `make release` + back-tags + the pre-push regex) or the GitHub ''release published'' event — that builds the per-platform bundles:
   - Linux: `make build-linux` -> a bundle matching the `make install` layout (~/.local/lib/clide + the `clide` C client).
   - macOS: `make build-macos` -> clide.app + the C client. Notarization/quarantine is a known wrinkle (see T-47 P4) — v1 may ship unnotarized with a documented Gatekeeper step, or notarize if signing creds are available.
   - Windows: out of scope until it ships.
2. Package each into a versioned archive (tar.gz / zip) + a SHA-256 checksum.
3. SIGN each artifact (POLICY.md: ''behavior is determined by the SIGNED release artifact''). Scheme TBD — minisign or cosign; the public key is vendored in-repo for provenance. Key custody (a CI secret for the private key) + the vendored-pubkey location are decisions to make.
4. Attach the archives + .sha256 + signatures to the GitHub Release as assets.
5. (Optional) a machine-readable latest manifest — though the GitHub Releases API (/releases/latest) already returns the latest version + its asset list, which the T-47 check consumes.

## Acceptance
1. Cutting a release (the `release vX.Y.Z` tag / `make release`) triggers CI that builds the Linux + macOS bundles.
2. Each GitHub Release carries, per platform: the archive, its .sha256, and its signature.
3. The signature verifies against the vendored public key; a tampered artifact fails verification.
4. The packaged layout matches `make install` so the updater (T-47 P2/P3) can swap it in place.

## Decisions to surface
- Signing scheme: minisign vs cosign (lean minisign — tiny, no infra, vendored pubkey).
- Key custody: private key as a CI secret; public key committed in-repo (provenance).
- macOS notarization for v1: notarize vs documented-Gatekeeper-step.

## Relationship to T-47
This is the P0 release-channel prerequisite called out in T-47. T-47 P1 (the manual ''Check for updates'' About button) does NOT depend on this — Releases already exist for the version check. T-47 P2 (download + verify) and P3 (apply + relaunch) DO depend on signed package assets, so block those on this story. Also unblocks the cross-platform installer epic (T-46).', 'GitHub Releases exist but carry no downloadable packages — no per-platform bundles are attached. clide''s self-update download/apply (T-47 P2/P3) and any future binary install need signed, checksummed artifacts on each Release. `.github/workflows` is empty today; this stands up the release channel.

## Scope
1. CI workflow (.github/workflows) triggered on a release — the `release vX.Y.Z` tag (T-393 already wires `make release` + back-tags + the pre-push regex) or the GitHub ''release published'' event — that builds the per-platform bundles:
   - Linux: `make build-linux` -> a bundle matching the `make install` layout (~/.local/lib/clide + the `clide` C client).
   - macOS: `make build-macos` -> clide.app + the C client. Notarization/quarantine is a known wrinkle (see T-47 P4) — v1 may ship unnotarized with a documented Gatekeeper step, or notarize if signing creds are available.
   - Windows: out of scope until it ships.
2. Package each into a versioned archive (tar.gz / zip) + a SHA-256 checksum.
3. SIGN each artifact (POLICY.md: ''behavior is determined by the SIGNED release artifact''). Scheme TBD — minisign or cosign; the public key is vendored in-repo for provenance. Key custody (a CI secret for the private key) + the vendored-pubkey location are decisions to make.
4. Attach the archives + .sha256 + signatures to the GitHub Release as assets.
5. (Optional) a machine-readable latest manifest — though the GitHub Releases API (/releases/latest) already returns the latest version + its asset list, which the T-47 check consumes.

## Acceptance
1. Cutting a release (the `release vX.Y.Z` tag / `make release`) triggers CI that builds the Linux + macOS bundles.
2. Each GitHub Release carries, per platform: the archive, its .sha256, and its signature.
3. The signature verifies against the vendored public key; a tampered artifact fails verification.
4. The packaged layout matches `make install` so the updater (T-47 P2/P3) can swap it in place.

## Decisions to surface
- Signing scheme: minisign vs cosign (lean minisign — tiny, no infra, vendored pubkey).
- Key custody: private key as a CI secret; public key committed in-repo (provenance).
- macOS notarization for v1: notarize vs documented-Gatekeeper-step.

## Relationship to T-47
This is the P0 release-channel prerequisite called out in T-47. T-47 P1 (the manual ''Check for updates'' About button) does NOT depend on this — Releases already exist for the version check. T-47 P2 (download + verify) and P3 (apply + relaunch) DO depend on signed package assets, so block those on this story. Also unblocks the cross-platform installer epic (T-46).

Decision 2026-09-23 (user): minisign; macOS ships unnotarized with a documented right-click → Open step for v1. Private key as a CI secret, public key committed in-repo. Implementation note: the updater (T-47 P2) must verify ed25519 minisign signatures — check whether that needs a new dependency (D-42/prefer-zero-deps) or a small in-house verifier before committing to it.', NULL, '2026-09-23 08:23:43', '2026-09-23 08:23:43.095', '2026-09-23 08:23:43.095', NULL, 'e8b994568ca6f63cdafd70b2b5de7767', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGZKEHPT1TMFMR0KYFGR087W', 'description', '## Epic A: LLMDriver abstraction + per-repo config schema

**Goal:** Define the abstraction layer and configuration schema.

**Tasks:**
1. Define `LLMDriver` interface:
   - `spawn(sessionId)` → Process
   - `send(message)` → void
   - `receive()` → Stream<Event>
   - `capabilities()` → List<String>
   - `healthCheck()` → bool
2. Implement `ClaudeDriver` (refactor existing `ClaudeStreamJsonProcess`)
3. Implement `VibeDriver` (new)
4. Design per-repo config schema:
   - `llm.driver` (enum: claude, mistral)
   - `llm.model` (optional, for mistral)
   - `llm.local` (optional, bool)
   - `llm.timeout` (optional, duration)
5. Update `ClaudeConfig` to become `LLMConfig` (backward-compat)

**Acceptance:**
- `LLMDriver` interface defined and documented
- Both drivers implement interface
- Config schema validated with users
', '## Epic A: LLMDriver abstraction + per-repo config schema

**Goal:** Define the abstraction layer and configuration schema.

**Tasks:**
1. Define `LLMDriver` interface:
   - `spawn(sessionId)` → Process
   - `send(message)` → void
   - `receive()` → Stream<Event>
   - `capabilities()` → List<String>
   - `healthCheck()` → bool
2. Implement `ClaudeDriver` (refactor existing `ClaudeStreamJsonProcess`)
3. Implement `VibeDriver` (new)
4. Design per-repo config schema:
   - `llm.driver` (enum: claude, mistral)
   - `llm.model` (optional, for mistral)
   - `llm.local` (optional, bool)
   - `llm.timeout` (optional, duration)
5. Update `ClaudeConfig` to become `LLMConfig` (backward-compat)

**Acceptance:**
- `LLMDriver` interface defined and documented
- Both drivers implement interface
- Config schema validated with users


Decision 2026-09-23 (user): build when vibe support actually lands — the driver refactor is the first step of that work, shaped by a real second driver. Make the plumbing generic, not Claude+Mistral only: Gemini CLI is a likely third driver (the user uses it occasionally), and OpenAI/ChatGPT-style CLIs should be possible for other users. So llm.driver is an open set, and capabilities() must express what a driver lacks (control protocol, permission modes, resume) so the UI degrades instead of assuming Claude features. Priority lowered to medium.', NULL, '2026-09-23 08:23:45', '2026-09-23 08:23:45.483', '2026-09-23 08:23:45.483', NULL, 'f5405453d02e6114b0f9aaa3cda75038', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FJ4D1M6ESSSQ1ZERTH4V9YN4', 'description', 'Estate review 2026-07-02: the clide skill is repo-agnostic and hand-copied into other repos (settled-reach), drifting. Long-term story: clide installs the skill into each workspace''s .claude/skills/ with a .pql-install.json-style marker (version + sha256) so staleness is detectable, following pql''s clean-house precedent. Until then the canonical copy lives in the clide repo.', 'Estate review 2026-07-02: the clide skill is repo-agnostic and hand-copied into other repos (settled-reach), drifting. Long-term story: clide installs the skill into each workspace''s .claude/skills/ with a .pql-install.json-style marker (version + sha256) so staleness is detectable, following pql''s clean-house precedent. Until then the canonical copy lives in the clide repo.

Decision 2026-09-23 (user): user scope with auto-refresh. clide installs the skill once into ~/.claude/skills/clide with a marker (version + sha256) and refreshes it when the app''s bundled copy is newer (never overwrite a copy whose hash doesn''t match the marker — the user edited it; warn instead). No per-repo copies; the hand-copied one in settled-reach can be removed once this ships. The skill already no-ops outside clide (no CLIDE_SOCK).', NULL, '2026-09-23 08:23:47', '2026-09-23 08:23:47.341', '2026-09-23 08:23:47.341', NULL, '524da0067e3d7f4934d904c3c56f8633', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD4QYHYRTK0SGRZCBSHSQ0', 'description', 'The single-isolate app does sync I/O inside async IPC handlers: files.read does a sync 10MB read; the replace engine reads and rewrites workspace files synchronously — while grep right next to it fans out to isolates per D-79. There is no recorded rule, so each new handler guesses.

Work: claim a D-record (pql decisions claim D architecture "sync I/O policy in IPC handlers") deciding the rule — suggested: async File APIs by default in handlers; offload to an isolate above N KB (align N with the D-79 grep design); sync allowed only in pure-Dart test seams. Then apply it to files.read and replace_engine, citing the new D-NNN at each site.

Acceptance: D-record confirmed; files.read and search.replace no longer block the UI isolate on large files (test with a multi-MB fixture asserting the event loop stays responsive, e.g. a timer keeps firing).', 'The single-isolate app does sync I/O inside async IPC handlers: files.read does a sync 10MB read; the replace engine reads and rewrites workspace files synchronously — while grep right next to it fans out to isolates per D-79. There is no recorded rule, so each new handler guesses.

Work: claim a D-record (pql decisions claim D architecture "sync I/O policy in IPC handlers") deciding the rule — suggested: async File APIs by default in handlers; offload to an isolate above N KB (align N with the D-79 grep design); sync allowed only in pure-Dart test seams. Then apply it to files.read and replace_engine, citing the new D-NNN at each site.

Acceptance: D-record confirmed; files.read and search.replace no longer block the UI isolate on large files (test with a multi-MB fixture asserting the event loop stays responsive, e.g. a timer keeps firing).

Decision 2026-09-23 (user): D-112 — async file I/O in IPC handlers by default; offload to an isolate above a size threshold (default 1 MiB, one named constant per subsystem) or for many-file walks; operations that may exceed ~1s emit throttled progress events as a sign of life (user addition). Apply to files.read and search.replace first.', NULL, '2026-09-23 08:23:48', '2026-09-23 08:23:48.717', '2026-09-23 08:23:48.717', NULL, '60036f996c2896b04febf6454dc4cc95', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67PDXAFTPPW7B1WDR', 'status', 'backlog', 'cancelled', NULL, '2026-09-23 08:23:54', '2026-09-23 08:23:54.958', '2026-09-23 08:23:54.958', NULL, '942192da11c64e3aeaafcd29ff772057', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGZKEHPT1TMFMR0KYFGR087W', 'priority', 'high', 'medium', NULL, '2026-09-23 08:23:55', '2026-09-23 08:23:55.536', '2026-09-23 08:23:55.536', NULL, '544551d58e5afdee5f0ffd304313bb34', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'title', 'Restore secondary Claude panes (and their conversations) after relaunch', 'Reopen last session''s secondary Claude tabs on demand', NULL, '2026-09-23 08:23:56', '2026-09-23 08:23:56.461', '2026-09-23 08:23:56.461', NULL, '6317da5a04710c53eb22bd87fc66895e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67JSC5RKS6M9182KG', 'title', 'Add images tab to context panel', 'Images tab in the context panel for images opened from the file tree', NULL, '2026-09-23 08:23:57', '2026-09-23 08:23:57.037', '2026-09-23 08:23:57.037', NULL, '02be7665c6230ffc4e8e2f1933c1f8d8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6WZ7DKVDFAGQ4QDMG', 'title', 'Terminal as a first-class editor-pane surface (swap vs split)', 'Terminal as a first-class editor-pane surface, with editor-pane split', NULL, '2026-09-23 08:23:57', '2026-09-23 08:23:57.769', '2026-09-23 08:23:57.769', NULL, 'd17148b2767ffc152503932b061f2b61', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FCDM61KAA3GV3CVTE8PAZ8N0', 'decision_ref', NULL, 'D-111', NULL, '2026-09-23 08:23:58', '2026-09-23 08:23:58.310', '2026-09-23 08:23:58.310', NULL, 'df476fd95eeb05a69e91e1f26e8f25a5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD4QYHYRTK0SGRZCBSHSQ0', 'decision_ref', NULL, 'D-112', NULL, '2026-09-23 08:23:58', '2026-09-23 08:23:58.743', '2026-09-23 08:23:58.743', NULL, '0b9038377acf1c0fe97960b4e259eeba', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FJ4D1M6ESSSQ1ZERTH4V9YN4', 'title', 'Distribute the clide skill per-workspace with an install marker', 'Install the clide skill at user scope with a version marker and auto-refresh', NULL, '2026-09-23 08:24:01', '2026-09-23 08:24:01.330', '2026-09-23 08:24:01.330', NULL, '3fa40dd482b71e4000f1dac7d6ba7ca1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTQHQWRQ139050EF6CVVCHR', 'description', 'placeholder', NULL, NULL, '2026-09-23 08:25:02', '2026-09-23 08:25:02.109', '2026-09-23 08:25:02.109', NULL, 'cfa04e6996d8fb8e7d3c58a2ed35a6db', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTQHQWRQ139050EF6CVVCHR', 'description', NULL, 'The queued-message rows above the composer (T-587) are misaligned. Screenshot 2026-09-23: the "queued" tag sits visibly lower than the message text next to it and reads as a different size, and the edit / dismiss icons don''t line up with either.

Cause, in `lib/builtin/claude/src/queued_messages_dock.dart` `_row()`:
- The Row uses `CrossAxisAlignment.start`, and the tag is nudged with a hand-tuned `Padding(top: 1)`. The tag (`clideFontCaption`) and the message (`clideFontSmall`) have different font sizes and line heights, so top alignment can''t put their text on one line. The 1px nudge fixes nothing.
- The icon buttons also sit top-aligned, so their centre doesn''t match the first text line.

Fix direction:
- Align the tag and the message''s first line on a shared text baseline: `CrossAxisAlignment.baseline` with `TextBaseline.alphabetic`, or wrap both in one `Text.rich`. Drop the `top: 1` hack.
- Decide whether the tag should be the same size as the message, or a small chip (a muted pill with padding) that''s deliberately set apart. Either way, it must share the first line''s baseline.
- Centre the edit / dismiss buttons vertically on the first text line, not on the row top. This must still hold for a 3-line message and while the inline editor is open.
- Check the "editing" state too, where the tag reads "editing" and the ClideEditable replaces the text.

Follow the ui-design skill for control geometry and tokens. Add a golden for a 1-line and a 3-line queued row.

Acceptance: in a 1-line row, the tag, the text and the icon centres sit on one line; in a 3-line row they align with the first line; the editing state keeps the same alignment.', NULL, '2026-09-23 08:25:02', '2026-09-23 08:25:02.345', '2026-09-23 08:25:02.345', NULL, '3ff8054a1fed5105bf87661033e63109', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR7FJJV64Z9V3VFCV4ZK3C', 'description', 'Scan findings L1–L16 (L3 → T-613, L12/L17 → T-608), one small fix each; see the local report for detail. L1 MCP lock file: create 0600 atomically, constant-time token compare, fail closed. L2 IPC input bounds: max line/body size, cap connections, drop slow subscribers. L4 confine image show / icon show / draw --file / SVG image href to the workspace; decode with a size cap. L5 pass -- (or reject leading dashes) on pql arguments. L6 chmod via fchmod or /bin/chmod, not PATH. L7 C client: error instead of silently truncating large args/stdin. L8 Windows path normalisation must handle forward slashes (bash_tail_source.dart). L9 Windows socket dir: fail closed when LOCALAPPDATA/USERPROFILE are unset. L10 SVG parser: invalid code points → U+FFFD, depth cap, parse once. L11 canvas parser: type-check JSON, never stuck loading. L13 Windows dev-VM scripts: verify downloads. L14 add SECURITY.md + enable GitHub private vulnerability reporting. L15 licenses.yaml: transitive runtime Dart packages + bundle font OFL texts. L16 .githooks: guard sourcing .pql/hooks/* on existence. Info items worth folding in: Lua loader sandbox requirements when it lands (manifest entry validation, stripped loaders, limits); d2 spawn timeout + cwd; check whether flutter_widget_from_html_core is unused and drop it.', 'Scan findings L1–L16 (L3 → T-615, L12/L17 → T-608), one small fix each; see the local report for detail. L1 MCP lock file: create 0600 atomically, constant-time token compare, fail closed. L2 IPC input bounds: max line/body size, cap connections, drop slow subscribers. L4 confine image show / icon show / draw --file / SVG image href to the workspace; decode with a size cap. L5 pass -- (or reject leading dashes) on pql arguments. L6 chmod via fchmod or /bin/chmod, not PATH. L7 C client: error instead of silently truncating large args/stdin. L8 Windows path normalisation must handle forward slashes (bash_tail_source.dart). L9 Windows socket dir: fail closed when LOCALAPPDATA/USERPROFILE are unset. L10 SVG parser: invalid code points → U+FFFD, depth cap, parse once. L11 canvas parser: type-check JSON, never stuck loading. L13 Windows dev-VM scripts: verify downloads. L14 add SECURITY.md + enable GitHub private vulnerability reporting. L15 licenses.yaml: transitive runtime Dart packages + bundle font OFL texts. L16 .githooks: guard sourcing .pql/hooks/* on existence. Info items worth folding in: Lua loader sandbox requirements when it lands (manifest entry validation, stripped loaders, limits); d2 spawn timeout + cwd; check whether flutter_widget_from_html_core is unused and drop it.', NULL, '2026-09-23 08:28:06', '2026-09-23 08:28:06.439', '2026-09-23 08:28:06.439', NULL, '320d9925271a97d319dfb4dd898635bb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FGVCY4M0ZK72HZT2FSZF968W', 'description', 'GitHub Releases exist but carry no downloadable packages — no per-platform bundles are attached. clide''s self-update download/apply (T-47 P2/P3) and any future binary install need signed, checksummed artifacts on each Release. `.github/workflows` is empty today; this stands up the release channel.

## Scope
1. CI workflow (.github/workflows) triggered on a release — the `release vX.Y.Z` tag (T-393 already wires `make release` + back-tags + the pre-push regex) or the GitHub ''release published'' event — that builds the per-platform bundles:
   - Linux: `make build-linux` -> a bundle matching the `make install` layout (~/.local/lib/clide + the `clide` C client).
   - macOS: `make build-macos` -> clide.app + the C client. Notarization/quarantine is a known wrinkle (see T-47 P4) — v1 may ship unnotarized with a documented Gatekeeper step, or notarize if signing creds are available.
   - Windows: out of scope until it ships.
2. Package each into a versioned archive (tar.gz / zip) + a SHA-256 checksum.
3. SIGN each artifact (POLICY.md: ''behavior is determined by the SIGNED release artifact''). Scheme TBD — minisign or cosign; the public key is vendored in-repo for provenance. Key custody (a CI secret for the private key) + the vendored-pubkey location are decisions to make.
4. Attach the archives + .sha256 + signatures to the GitHub Release as assets.
5. (Optional) a machine-readable latest manifest — though the GitHub Releases API (/releases/latest) already returns the latest version + its asset list, which the T-47 check consumes.

## Acceptance
1. Cutting a release (the `release vX.Y.Z` tag / `make release`) triggers CI that builds the Linux + macOS bundles.
2. Each GitHub Release carries, per platform: the archive, its .sha256, and its signature.
3. The signature verifies against the vendored public key; a tampered artifact fails verification.
4. The packaged layout matches `make install` so the updater (T-47 P2/P3) can swap it in place.

## Decisions to surface
- Signing scheme: minisign vs cosign (lean minisign — tiny, no infra, vendored pubkey).
- Key custody: private key as a CI secret; public key committed in-repo (provenance).
- macOS notarization for v1: notarize vs documented-Gatekeeper-step.

## Relationship to T-47
This is the P0 release-channel prerequisite called out in T-47. T-47 P1 (the manual ''Check for updates'' About button) does NOT depend on this — Releases already exist for the version check. T-47 P2 (download + verify) and P3 (apply + relaunch) DO depend on signed package assets, so block those on this story. Also unblocks the cross-platform installer epic (T-46).

Decision 2026-09-23 (user): minisign; macOS ships unnotarized with a documented right-click → Open step for v1. Private key as a CI secret, public key committed in-repo. Implementation note: the updater (T-47 P2) must verify ed25519 minisign signatures — check whether that needs a new dependency (D-42/prefer-zero-deps) or a small in-house verifier before committing to it.', 'GitHub Releases exist but carry no downloadable packages — no per-platform bundles are attached. clide''s self-update download/apply (T-47 P2/P3) and any future binary install need signed, checksummed artifacts on each Release. `.github/workflows` is empty today; this stands up the release channel.

## Scope
1. CI workflow (.github/workflows) triggered on a release — the `release vX.Y.Z` tag (T-393 already wires `make release` + back-tags + the pre-push regex) or the GitHub ''release published'' event — that builds the per-platform bundles:
   - Linux: `make build-linux` -> a bundle matching the `make install` layout (~/.local/lib/clide + the `clide` C client).
   - macOS: `make build-macos` -> clide.app + the C client. Notarization/quarantine is a known wrinkle (see T-47 P4) — v1 may ship unnotarized with a documented Gatekeeper step, or notarize if signing creds are available.
   - Windows: out of scope until it ships.
2. Package each into a versioned archive (tar.gz / zip) + a SHA-256 checksum.
3. SIGN each artifact (POLICY.md: ''behavior is determined by the SIGNED release artifact''). Scheme TBD — minisign or cosign; the public key is vendored in-repo for provenance. Key custody (a CI secret for the private key) + the vendored-pubkey location are decisions to make.
4. Attach the archives + .sha256 + signatures to the GitHub Release as assets.
5. (Optional) a machine-readable latest manifest — though the GitHub Releases API (/releases/latest) already returns the latest version + its asset list, which the T-47 check consumes.

## Acceptance
1. Cutting a release (the `release vX.Y.Z` tag / `make release`) triggers CI that builds the Linux + macOS bundles.
2. Each GitHub Release carries, per platform: the archive, its .sha256, and its signature.
3. The signature verifies against the vendored public key; a tampered artifact fails verification.
4. The packaged layout matches `make install` so the updater (T-47 P2/P3) can swap it in place.

## Decisions to surface
- Signing scheme: minisign vs cosign (lean minisign — tiny, no infra, vendored pubkey).
- Key custody: private key as a CI secret; public key committed in-repo (provenance).
- macOS notarization for v1: notarize vs documented-Gatekeeper-step.

## Relationship to T-47
This is the P0 release-channel prerequisite called out in T-47. T-47 P1 (the manual ''Check for updates'' About button) does NOT depend on this — Releases already exist for the version check. T-47 P2 (download + verify) and P3 (apply + relaunch) DO depend on signed package assets, so block those on this story. Also unblocks the cross-platform installer epic (T-46).

Decision 2026-09-23 (user): minisign; macOS ships unnotarized with a documented right-click → Open step for v1. Private key as a CI secret, public key committed in-repo. Implementation note: the updater (T-47 P2) must verify ed25519 minisign signatures — check whether that needs a new dependency (D-42/prefer-zero-deps) or a small in-house verifier before committing to it.

Security scan 2026-09-23 (H7, see T-601/T-608): correction — .github/workflows is NOT empty; release.yml already builds and publishes, just unsigned and without checksums. Build signing onto the existing workflow. Workflow hardening (pinned Flutter, tests gate releases, SHA256SUMS, least privilege) is T-608.', NULL, '2026-09-23 08:28:08', '2026-09-23 08:28:08.100', '2026-09-23 08:28:08.100', NULL, '5c24b2bdc62c55dd9c7f77312e1e48d3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTRADYM8J1D4XKA81PAE5X8', 'description', 'placeholder', NULL, NULL, '2026-09-23 08:28:23', '2026-09-23 08:28:23.841', '2026-09-23 08:28:23.841', NULL, 'a3855a92c3aa56308544e9f3391ab3a6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTRADYM8J1D4XKA81PAE5X8', 'description', NULL, 'User request 2026-09-23: queued messages take very long to arrive. A message typed while Claude works waits until the whole turn ends, and with long agentic turns that can be many minutes. The user wants their message woven into the running work, like an inline "also, the user messaged this:" note, instead of waiting for the end or interrupting.

## Today

`StreamJsonSession.send` (T-587) holds a message in clide''s own queue while a turn is busy, and `_flushQueued()` writes it to claude''s stdin only once the turn''s `result` arrives. So clide adds the whole remaining turn as latency.

## Direction

Claude Code''s own TUI already does what''s asked. Input typed during a turn is queued inside the CLI and attached at the next tool-call boundary as a "the user sent a message while you were working" note, so the model sees it mid-turn and can adjust without being stopped. So the likely fix is to stop holding: write the message to stdin right away and let the CLI inject it at its next step.

Step 1 is a probe, because stream-json headless mode may behave differently from the TUI. Start `claude -p --input-format stream-json --output-format stream-json`, send a prompt that runs a few slow tool calls, and write a second user message on stdin partway through. Record whether:
- (a) the second message reaches the model inside the same turn (before `result`; visible in the transcript as a queued-command attachment or system-reminder), or
- (b) it''s processed as a separate turn afterwards, or
- (c) it breaks the turn.

- **If (a):** send immediately by default. The queue dock changes meaning. A message stays editable and dismissable only until it''s written; after that it shows "delivered, reaches Claude at its next step" until it appears in the conversation. Keep today''s hold-until-turn-end as a per-message or setting option ("hold for the next turn").
- **If (b) or (c):** the CLI won''t do it headless. Then weigh having clide deliver it itself, for example through a PostToolUse/UserPromptSubmit-style hook that reads a clide-owned inbox and returns the note as additionalContext. Hooks are the documented way to inject context mid-turn. This needs a D-record because it puts clide into Claude''s hook chain.

## Notes

- Mid-turn delivery only happens at tool boundaries. A turn that is one long text generation still delivers at its end.
- Interaction with T-587''s edit-pauses-sending: editing must still stop delivery, but once a message is written to stdin it can''t be pulled back. The UI must make that moment visible.
- D-6: `clide claude queue` verbs (T-588) must reflect the new states.

Acceptance: a message sent during a long multi-tool turn reaches Claude within one tool step (not at turn end) and shows up in the conversation where it was delivered; the user can still choose to hold a message for the next turn.', NULL, '2026-09-23 08:28:24', '2026-09-23 08:28:24.218', '2026-09-23 08:28:24.218', NULL, '7791aacc54038a90836e81e626021adb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTRADYM8J1D4XKA81PAE5X8', 'description', 'User request 2026-09-23: queued messages take very long to arrive. A message typed while Claude works waits until the whole turn ends, and with long agentic turns that can be many minutes. The user wants their message woven into the running work, like an inline "also, the user messaged this:" note, instead of waiting for the end or interrupting.

## Today

`StreamJsonSession.send` (T-587) holds a message in clide''s own queue while a turn is busy, and `_flushQueued()` writes it to claude''s stdin only once the turn''s `result` arrives. So clide adds the whole remaining turn as latency.

## Direction

Claude Code''s own TUI already does what''s asked. Input typed during a turn is queued inside the CLI and attached at the next tool-call boundary as a "the user sent a message while you were working" note, so the model sees it mid-turn and can adjust without being stopped. So the likely fix is to stop holding: write the message to stdin right away and let the CLI inject it at its next step.

Step 1 is a probe, because stream-json headless mode may behave differently from the TUI. Start `claude -p --input-format stream-json --output-format stream-json`, send a prompt that runs a few slow tool calls, and write a second user message on stdin partway through. Record whether:
- (a) the second message reaches the model inside the same turn (before `result`; visible in the transcript as a queued-command attachment or system-reminder), or
- (b) it''s processed as a separate turn afterwards, or
- (c) it breaks the turn.

- **If (a):** send immediately by default. The queue dock changes meaning. A message stays editable and dismissable only until it''s written; after that it shows "delivered, reaches Claude at its next step" until it appears in the conversation. Keep today''s hold-until-turn-end as a per-message or setting option ("hold for the next turn").
- **If (b) or (c):** the CLI won''t do it headless. Then weigh having clide deliver it itself, for example through a PostToolUse/UserPromptSubmit-style hook that reads a clide-owned inbox and returns the note as additionalContext. Hooks are the documented way to inject context mid-turn. This needs a D-record because it puts clide into Claude''s hook chain.

## Notes

- Mid-turn delivery only happens at tool boundaries. A turn that is one long text generation still delivers at its end.
- Interaction with T-587''s edit-pauses-sending: editing must still stop delivery, but once a message is written to stdin it can''t be pulled back. The UI must make that moment visible.
- D-6: `clide claude queue` verbs (T-588) must reflect the new states.

Acceptance: a message sent during a long multi-tool turn reaches Claude within one tool step (not at turn end) and shows up in the conversation where it was delivered; the user can still choose to hold a message for the next turn.', 'User request 2026-09-23: queued messages take very long to arrive. A message typed while Claude works waits until the whole turn ends, and with long agentic turns that can be many minutes. The user wants their message woven into the running work, like an inline "also, the user messaged this:" note, instead of waiting for the end or interrupting.

## Today

`StreamJsonSession.send` (T-587) holds a message in clide''s own queue while a turn is busy, and `_flushQueued()` writes it to claude''s stdin only once the turn''s `result` arrives. So clide adds the whole remaining turn as latency.

## Direction

Claude Code''s own TUI already does what''s asked. Input typed during a turn is queued inside the CLI and attached at the next tool-call boundary as a "the user sent a message while you were working" note, so the model sees it mid-turn and can adjust without being stopped. So the likely fix is to stop holding: write the message to stdin right away and let the CLI inject it at its next step.

Step 1 is a probe, because stream-json headless mode may behave differently from the TUI. Start `claude -p --input-format stream-json --output-format stream-json`, send a prompt that runs a few slow tool calls, and write a second user message on stdin partway through. Record whether:
- (a) the second message reaches the model inside the same turn (before `result`; visible in the transcript as a queued-command attachment or system-reminder), or
- (b) it''s processed as a separate turn afterwards, or
- (c) it breaks the turn.

- **If (a):** send immediately by default. The queue dock changes meaning. A message stays editable and dismissable only until it''s written; after that it shows "delivered, reaches Claude at its next step" until it appears in the conversation. Keep today''s hold-until-turn-end as a per-message or setting option ("hold for the next turn").
- **If (b) or (c):** the CLI won''t do it headless. Then weigh having clide deliver it itself, for example through a PostToolUse/UserPromptSubmit-style hook that reads a clide-owned inbox and returns the note as additionalContext. Hooks are the documented way to inject context mid-turn. This needs a D-record because it puts clide into Claude''s hook chain.

## Notes

- Mid-turn delivery only happens at tool boundaries. A turn that is one long text generation still delivers at its end.
- Interaction with T-587''s edit-pauses-sending: editing must still stop delivery, but once a message is written to stdin it can''t be pulled back. The UI must make that moment visible.
- D-6: `clide claude queue` verbs (T-588) must reflect the new states.

Acceptance: a message sent during a long multi-tool turn reaches Claude within one tool step (not at turn end) and shows up in the conversation where it was delivered; the user can still choose to hold a message for the next turn.

Probe result 2026-09-23 (claude -p stream-json, haiku, three sequential ''sleep 4'' Bash calls, second user message written to stdin 20 ms after the first tool_use): CASE (a) — the CLI does it natively. The second message was queued by the CLI (transcript: queue-operation + a queued_command attachment) and delivered right after the first tool_result, i.e. at the next tool step (~4 s after sending, not at turn end). The model acted on it within the same turn: ONE result, num_turns=4, reply ended with the requested word. Without --replay-user-messages there is NO stdout event for the injection. WITH --replay-user-messages, the CLI emits {type:user, isReplay:true, message.content:<text>} at the moment of injection (8.2 s, right after tool_result #1), and also echoes the turn''s opening prompt. So the design is: (1) add --replay-user-messages to the stream-json spawn; (2) send() writes to stdin immediately even while busy; (3) the dock shows the message as ''waiting for Claude''s next step'' until the matching isReplay echo arrives, then it moves into the conversation at that position; (4) edit/dismiss are only possible while it''s still in clide''s hold (the explicit ''hold for next turn'' option) — once written to stdin it can''t be recalled; (5) the conversation renderer must de-duplicate the replay echo of messages clide already rendered on send (match by text/uuid order). Probe script: tmp/midturn_probe.dart (local).', NULL, '2026-09-23 08:35:14', '2026-09-23 08:35:14.229', '2026-09-23 08:35:14.229', NULL, '28fcce3abe2dfe6c80356afddd7f4a3d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTRADYM8J1D4XKA81PAE5X8', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 08:36:17', '2026-09-23 08:36:17.691', '2026-09-23 08:36:17.691', NULL, 'fabdf85fd94b5ac53ba3d8b5153c2996', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTRADYM8J1D4XKA81PAE5X8', 'status', 'in_progress', 'review', NULL, '2026-09-23 08:45:06', '2026-09-23 08:45:06.158', '2026-09-23 08:45:06.158', NULL, '2af8be32384506c922b9df3c1c72cf4e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTX02PAQWE2XVTCGBDB78T8', 'status', 'backlog', 'review', NULL, '2026-09-23 08:48:56', '2026-09-23 08:48:56.037', '2026-09-23 08:48:56.037', NULL, '34f4dc47deced0b26a33250a0a2bce9f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR4K7V2NNTSGE89K0YAAXG', 'description', 'Scan findings H7 (non-signing part), M9, M10, M11, L12, L17. release.yml publishes without depending on the test jobs and builds on the floating stable channel. Pin Flutter to .fvmrc in release.yml and test.yml; release requires the tests; publish SHA256SUMS (signing itself is T-491, minisign); pin every action by full SHA; add permissions: contents: read at the top of every workflow and scope write to the publish job; pin the pql download to a tag + checksum; pass windows-soak inputs through env: instead of inline expressions. Note T-491''s description (''workflows empty'') is stale — build on the existing release.yml.', 'Scan findings H7 (non-signing part), M9, M10, M11, L12, L17. release.yml publishes without depending on the test jobs and builds on the floating stable channel. Pin Flutter to .fvmrc in release.yml and test.yml; release requires the tests; publish SHA256SUMS (signing itself is T-491, minisign); pin every action by full SHA; add permissions: contents: read at the top of every workflow and scope write to the publish job; pin the pql download to a tag + checksum; pass windows-soak inputs through env: instead of inline expressions. Note T-491''s description (''workflows empty'') is stale — build on the existing release.yml.

Partial 2026-09-23 (with T-619): every workflow (test, release, windows, windows-soak) now installs the Flutter version pinned in .fvmrc instead of floating on stable. Floating had broken CI since at least v2.14.1: Flutter 3.47.5''s flutter_test pins test_api 0.7.12, incompatible with clide''s exact test 1.31.0 pin, so pub get failed in every job. Remaining here: tests gate releases, SHA256SUMS, SHA-pinned actions, least-privilege permissions, pql download pinning, windows-soak inputs via env.', NULL, '2026-09-23 08:53:59', '2026-09-23 08:53:59.279', '2026-09-23 08:53:59.279', NULL, '1a5c01099b734e78727569b05905a7c2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV26X6YZG8T62EFW0J3J5XG', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 09:11:34', '2026-09-23 09:11:34.835', '2026-09-23 09:11:34.835', NULL, '518087445796aee739db0bc3804019a8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV26X6YZG8T62EFW0J3J5XG', 'status', 'in_progress', 'review', NULL, '2026-09-23 09:22:37', '2026-09-23 09:22:37.659', '2026-09-23 09:22:37.659', NULL, '8d0505ad6ca6ec14ac94836471db31d2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV26X6YZG8T62EFW0J3J5XG', 'description', 'T-47 P2+P3 for Linux, user request 2026-09-23 (''no button to install it … if the trayicon process is not updated, can we make it swap the windows for the new version''). Install button next to the update check + D-6 verb. Download the release''s linux tarball, verify against the SHA-256 digest GitHub records for the asset (interim, user decision 2026-09-23 — minisign verification replaces/extends it when T-491 lands), extract beside the install dir, swap by rename (old kept as .old), refresh the ~/.local/bin/clide client, then relaunch every open window on the new binary. The tray loader keeps running (protocol-compatible); it''s replaced naturally when the last old window exits. New windows wait for the old window''s socket to free before binding. Only offered for an installed bundle (not dev/build runs).', 'T-47 P2+P3 for Linux, user request 2026-09-23 (''no button to install it … if the trayicon process is not updated, can we make it swap the windows for the new version''). Install button next to the update check + D-6 verb. Download the release''s linux tarball, verify against the SHA-256 digest GitHub records for the asset (interim, user decision 2026-09-23 — minisign verification replaces/extends it when T-491 lands), extract beside the install dir, swap by rename (old kept as .old), refresh the ~/.local/bin/clide client, then relaunch every open window on the new binary. The tray loader keeps running (protocol-compatible); it''s replaced naturally when the last old window exits. New windows wait for the old window''s socket to free before binding. Only offered for an installed bundle (not dev/build runs).

User test 2026-09-23 (2.16.0-labelled installer build → v2.17.0): the install and restart worked end to end. Follow-up fixed: the restarted window opened on the welcome page — the IPC side follows the cwd, but the UI''s startup only auto-opens a sticky recent (T-115). A relaunched window now reopens its working directory''s repo. The signal became a --relaunch argument, so terminals and Claude sessions don''t inherit it; CLIDE_RELAUNCH=1, which 2.17.0 sent, is still honoured.', NULL, '2026-09-23 09:37:01', '2026-09-23 09:37:01.630', '2026-09-23 09:37:01.630', NULL, 'b61b559918b53a57e089621d1efb66be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV81K7V49V6HT370EBB4HP0', 'status', 'backlog', 'review', NULL, '2026-09-23 09:37:05', '2026-09-23 09:37:05.218', '2026-09-23 09:37:05.218', NULL, '8b5e995110b41a3a8309491b97a2e0c3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 09:44:20', '2026-09-23 09:44:20.082', '2026-09-23 09:44:20.082', NULL, 'e0ee2394a5949e188dfc4afd82056ac6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'title', 'Reopen last session''s secondary Claude tabs on demand', 'Restore open sessions after a restart: files always, secondary Claude sessions on a prompt', NULL, '2026-09-23 09:54:30', '2026-09-23 09:54:30.043', '2026-09-23 09:54:30.043', NULL, 'e5108649cac395f86a60cb35908cb77e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'description', 'After an app reload the primary Claude pane continues its conversation (`--resume`, D-77), but secondary panes disappear. By design today: D-41 made secondaries ephemeral — each spawn gets a random id (`freshSessionId()`, claude_pane.dart) and the open secondary tabs are not persisted. The transcripts survive on disk (reachable via `/resume`), so nothing is lost; the tabs just don''t come back.

User report 2026-09-23: resume "works well … the main conversation seems to reliably continue after an app reload. Only thing is that conversations in secondary panels disappear."

Want: on relaunch, restore the workspace''s open secondary panes, each resuming its own session, in their previous order.

Shape: persist the ordered list of secondary session ids per workspace in user-scope state (D-93/D-53 — not in the repo); on boot, spawn a secondary per entry with `resume: true` when its transcript exists (skip entries whose transcript is gone). Closing a secondary removes it from the list. Forks (`--fork-session`) persist their resolved claude session id, not the fork source.

Needs a D-41 amendment: "secondaries are ephemeral" → "secondaries persist until closed".

Acceptance: open two secondaries, talk in each, restart clide → both tabs return with their conversations; a closed secondary does not come back; a secondary whose transcript was deleted is dropped silently.

Decision 2026-09-23 (user): NOT automatic restore. Reopen on demand instead — secondaries stay ephemeral across relaunch (D-41 unchanged), but clide remembers the workspace''s last set of open secondary session ids (user-scope state, not the repo) and offers a ''Reopen last session''s tabs'' command (+ D-6 CLI verb), which re-spawns each with resume where the transcript still exists, in the previous order. Acceptance changes accordingly: after restart the tabs are NOT back; invoking the command brings them back with their conversations; a deleted transcript is skipped silently.', 'After an app reload the primary Claude pane continues its conversation (`--resume`, D-77), but secondary panes disappear. By design today: D-41 made secondaries ephemeral — each spawn gets a random id (`freshSessionId()`, claude_pane.dart) and the open secondary tabs are not persisted. The transcripts survive on disk (reachable via `/resume`), so nothing is lost; the tabs just don''t come back.

User report 2026-09-23: resume "works well … the main conversation seems to reliably continue after an app reload. Only thing is that conversations in secondary panels disappear."

Want: on relaunch, restore the workspace''s open secondary panes, each resuming its own session, in their previous order.

Shape: persist the ordered list of secondary session ids per workspace in user-scope state (D-93/D-53 — not in the repo); on boot, spawn a secondary per entry with `resume: true` when its transcript exists (skip entries whose transcript is gone). Closing a secondary removes it from the list. Forks (`--fork-session`) persist their resolved claude session id, not the fork source.

Needs a D-41 amendment: "secondaries are ephemeral" → "secondaries persist until closed".

Acceptance: open two secondaries, talk in each, restart clide → both tabs return with their conversations; a closed secondary does not come back; a secondary whose transcript was deleted is dropped silently.

Decision 2026-09-23 (user): NOT automatic restore. Reopen on demand instead — secondaries stay ephemeral across relaunch (D-41 unchanged), but clide remembers the workspace''s last set of open secondary session ids (user-scope state, not the repo) and offers a ''Reopen last session''s tabs'' command (+ D-6 CLI verb), which re-spawns each with resume where the transcript still exists, in the previous order. Acceptance changes accordingly: after restart the tabs are NOT back; invoking the command brings them back with their conversations; a deleted transcript is skipped silently.

Decision revised 2026-09-23 (user, after the first self-update): restore everything, asking about secondary sessions — ''restore everything with a prompt do you want to restore secondary sessions''; after an update restart everything comes back unasked. Recorded as D-114 (amends D-41). Built: secondary tab session ids (resolved fork ids, /clear and /resume rebinds) and editor open files + active + split visibility, remembered in app scope per workspace as they change; files reopen on every open; secondaries offered via a Restore / Not now strip above the Claude tabs, plus the palette command ''Claude: restore last time''s sessions'' and ''clide claude restore''; a --relaunch window restores everything without asking. Terminals need nothing (the single terminal tab starts a fresh shell in the project root).', NULL, '2026-09-23 09:54:32', '2026-09-23 09:54:32.799', '2026-09-23 09:54:32.799', NULL, '15eb79bfb2599444f68afbd60c246b30', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'decision_ref', 'D-41', 'D-114', NULL, '2026-09-23 09:54:33', '2026-09-23 09:54:33.383', '2026-09-23 09:54:33.383', NULL, '7ef89d55c9453b0ec14abd8c598c2916', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCSZV180Z4QKE0971S4MW8SC', 'status', 'in_progress', 'review', NULL, '2026-09-23 09:57:46', '2026-09-23 09:57:46.021', '2026-09-23 09:57:46.021', NULL, '77d05f273dacf194cd4400abb4fdbfe9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVGB53739CMFF7CTZMSDJ8W', 'status', 'backlog', 'review', NULL, '2026-09-23 10:14:58', '2026-09-23 10:14:58.922', '2026-09-23 10:14:58.922', NULL, '06072f17d444c027b553ba785fa20a78', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV14SK05CKCT9SMX201JHHR', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:24:54', '2026-09-23 10:24:54.083', '2026-09-23 10:24:54.083', NULL, '1dd84359463e192b7d52b7491889ee29', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV14SK05CKCT9SMX201JHHR', 'description', 'Once CI installed the .fvmrc Flutter (T-608/T-619), pub get works again and the jobs get far enough to show three failures that the dependency error had hidden since at least v2.14.1. unit+coverage and bundle smoke pass. (1) dart doc: ~30 dartdoc warnings fail the --validate-links gate: unresolved doc references ([onChanged], [onEditStart]/[onEditEnd] in queued_messages_dock, [layoutSize], [D-43], bracketed prose like [Auto, when available], file-name refs like [tree_sitter_service_stub.dart]) plus an ambiguous re-export of shell_env via kernel/toolchain/toolchain_paths. Fix each ref (backticks for non-symbols) and settle the canonical export. Consider running dartdoc in make push-check so it can''t drift locally again. (2) web build (wasm compile gate): runs 
┌─ New feature ────────────────────────────────────────────────────────────────────────────┐
│   WebAssembly compilation is new. Understand the details before deploying to production. │
│   See https://flutter.dev/to/wasm for more information.                                  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
Compiling lib/main.dart for the Web...                          
Expected to find fonts for (packages/cupertino_icons/CupertinoIcons, MaterialIcons), but found (). This usually means you are referring to font families in an IconData class but not including them in the assets section of your pubspec.yaml, are missing the package that would include them, or are missing "uses-material-design: true".
Compiling lib/main.dart for the Web...                             45.0s
✓ Built build/web directly, so lib/src/build_info.g.dart (gitignored, written by make gen-build-info) is missing. Run make gen-build-info first, or a make target. (3) integration_test companion_process_test ''turning the companion off leaves no claude process behind'' expects exactly one claude process, but CI has no claude binary, so it sees zero. Skip (with a reason) when claude isn''t on PATH, or give the test a fake claude. Acceptance: the test workflow is green on main.', 'Once CI installed the .fvmrc Flutter (T-608/T-619), pub get works again and the jobs get far enough to show three failures that the dependency error had hidden since at least v2.14.1. unit+coverage and bundle smoke pass.

(1) dart doc: ~35 dartdoc warnings fail the --validate-links gate: unresolved doc references ([onChanged], [onEditStart]/[onEditEnd] in queued_messages_dock, [layoutSize], [D-43], bracketed prose like [Auto, when available], file-name refs like [tree_sitter_service_stub.dart]) plus an ambiguous re-export of shell_env via kernel/toolchain/toolchain_paths. Fix each ref (backticks for non-symbols) and settle the canonical export. Consider running dartdoc in make push-check so it can''t drift locally again.

(2) web build (wasm compile gate): the job runs ''flutter build web --wasm'' directly, so lib/src/build_info.g.dart (gitignored, written by make gen-build-info) is missing. Run make gen-build-info first.

(3) integration_test companion_process_test ''turning the companion off leaves no claude process behind'' expects exactly one claude process, but CI has no claude binary, so it sees zero. Skip (with a reason) when claude isn''t on PATH, or give the test a fake claude.

Acceptance: the test workflow is green on main.

Note 2026-09-23: this description was first filed through a shell command whose backticks were executed (command substitution), which pasted flutter build output into it; rewritten from a file.', NULL, '2026-09-23 10:25:42', '2026-09-23 10:25:42.404', '2026-09-23 10:25:42.404', NULL, 'f4d75ee263a02bdc76dac1b8c39ce8e5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR572MH8PSQ8CZXQGCKEKR', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:32:33', '2026-09-23 10:32:33.465', '2026-09-23 10:32:33.465', NULL, '5d711448b2d4bc66a118298c481bec91', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR572MH8PSQ8CZXQGCKEKR', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:33:03', '2026-09-23 10:33:03.448', '2026-09-23 10:33:03.448', NULL, '4df1b678662864fbb3c63d15d1d5206d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR360YN0X13FHBNGYWN05C', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:33:11', '2026-09-23 10:33:11.087', '2026-09-23 10:33:11.087', NULL, 'adca09e76a36e64f93c8b4f600c0e935', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR360YN0X13FHBNGYWN05C', 'description', 'Scan finding H2. agent_bootstrap.dart builds the clide-CLI candidate list with $workspaceRoot/native/<abi> and then prepends the whole chosen directory to the hosted session''s PATH. Drop the workspace candidate (or gate it behind an explicit dev opt-in for the clide source tree only), and expose just the single clide binary (e.g. a symlink in a private per-session dir) rather than a whole directory. Spawn claude from its resolved absolute path (D-104). Same class as T-98 (dugite from the workspace). Test: a workspace native/ dir containing executables never reaches the agent PATH.', 'Scan finding H2. agent_bootstrap.dart builds the clide-CLI candidate list with $workspaceRoot/native/<abi> and then prepends the whole chosen directory to the hosted session''s PATH. Drop the workspace candidate (or gate it behind an explicit dev opt-in for the clide source tree only), and expose just the single clide binary (e.g. a symlink in a private per-session dir) rather than a whole directory. Spawn claude from its resolved absolute path (D-104). Same class as T-98 (dugite from the workspace). Test: a workspace native/ dir containing executables never reaches the agent PATH.

Done 2026-09-23: the CLI candidates are ~/.local/bin/clide, the bundle''s clide-cli, and (only when the app runs from a clide source tree''s build/ dir) that tree''s native/<abi>/clide — never the opened workspace. Whatever is chosen is exposed as a single ''clide'' symlink in <socket dir>/bin (0700, D-71), so no other executable reaches the agent''s PATH. Also fixed on the way: the old last candidate was the bundle dir, whose ''clide'' is the GUI binary, so a CLI-less install pointed agents at a new window. Not done here: spawning claude by resolved absolute path (D-104) — with only the single-link dir prepended, the workspace can no longer shadow claude via this path; the remaining vector is the user''s own app-scope PATH preset (D-106), which is user-controlled.', NULL, '2026-09-23 10:34:26', '2026-09-23 10:34:26.060', '2026-09-23 10:34:26.060', NULL, '732fa5bc8bc20a2558ace54340ecaa90', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR360YN0X13FHBNGYWN05C', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:34:26', '2026-09-23 10:34:26.564', '2026-09-23 10:34:26.564', NULL, 'fad8a3b2237913c6f5ef347ea69afff0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR5F1Y04R85SFPQPME824M', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:34:35', '2026-09-23 10:34:35.005', '2026-09-23 10:34:35.005', NULL, '92c01448f067c68673036a8888277e1e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR5F1Y04R85SFPQPME824M', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:35:36', '2026-09-23 10:35:36.407', '2026-09-23 10:35:36.407', NULL, '8dce4dce848531f35fdd4708aebe6551', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVQBYF1VTGGABEG815GT3R0', 'description', 'see body', NULL, NULL, '2026-09-23 10:44:03', '2026-09-23 10:44:03.111', '2026-09-23 10:44:03.111', NULL, 'a7b03fbc3df12e78a76450e431e5ca0e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVQBYF1VTGGABEG815GT3R0', 'description', NULL, 'Test audit 2026-09-23, bug #8 (verified). The settings YAML emitter (lib/kernel/src/settings.dart, _needsQuoting) didn''t quote strings that start with a YAML indicator character (- ? : , [ ] { } # & * ! | > '' " % @ and the backtick). A value like `*.dart` or `[wip] x` wrote invalid YAML, and the next load moved the whole settings file aside as `.broken`.

It also bit T-589 in 2.18.x. The secondary-session list is stored as a JSON string such as `["id"]`, which was written unquoted and reloaded as a YAML sequence, so `get<String>` returned null. The "Restore Claude sessions" offer therefore never appeared after a real restart. The tests missed it because they never reloaded from disk. The editor store escaped only because its JSON always contains a `:`, which already triggered quoting.

Fix: quote any string with a leading indicator. The session store also accepts the list form, so lists 2.18.x already wrote still restore. New tests: settings round-trip for every indicator character via a real reload, and a session-store reload test.', NULL, '2026-09-23 10:44:03', '2026-09-23 10:44:03.652', '2026-09-23 10:44:03.652', NULL, '1e558dc75624bd2e42830a37cc1ee1a9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVQBYF1VTGGABEG815GT3R0', 'status', 'backlog', 'review', NULL, '2026-09-23 10:44:03', '2026-09-23 10:44:03.774', '2026-09-23 10:44:03.774', NULL, '5898079583fe5eb62886ecd656cf0e55', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCV14SK05CKCT9SMX201JHHR', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:44:15', '2026-09-23 10:44:15.070', '2026-09-23 10:44:15.070', NULL, 'f5c5d443c9fdb18b55d4c4c4ce221571', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR4K7V2NNTSGE89K0YAAXG', 'description', 'Scan findings H7 (non-signing part), M9, M10, M11, L12, L17. release.yml publishes without depending on the test jobs and builds on the floating stable channel. Pin Flutter to .fvmrc in release.yml and test.yml; release requires the tests; publish SHA256SUMS (signing itself is T-491, minisign); pin every action by full SHA; add permissions: contents: read at the top of every workflow and scope write to the publish job; pin the pql download to a tag + checksum; pass windows-soak inputs through env: instead of inline expressions. Note T-491''s description (''workflows empty'') is stale — build on the existing release.yml.

Partial 2026-09-23 (with T-619): every workflow (test, release, windows, windows-soak) now installs the Flutter version pinned in .fvmrc instead of floating on stable. Floating had broken CI since at least v2.14.1: Flutter 3.47.5''s flutter_test pins test_api 0.7.12, incompatible with clide''s exact test 1.31.0 pin, so pub get failed in every job. Remaining here: tests gate releases, SHA256SUMS, SHA-pinned actions, least-privilege permissions, pql download pinning, windows-soak inputs via env.', 'Scan findings H7 (non-signing part), M9, M10, M11, L12, L17. release.yml publishes without depending on the test jobs and builds on the floating stable channel. Pin Flutter to .fvmrc in release.yml and test.yml; release requires the tests; publish SHA256SUMS (signing itself is T-491, minisign); pin every action by full SHA; add permissions: contents: read at the top of every workflow and scope write to the publish job; pin the pql download to a tag + checksum; pass windows-soak inputs through env: instead of inline expressions. Note T-491''s description (''workflows empty'') is stale — build on the existing release.yml.

Partial 2026-09-23 (with T-619): every workflow (test, release, windows, windows-soak) now installs the Flutter version pinned in .fvmrc instead of floating on stable. Floating had broken CI since at least v2.14.1: Flutter 3.47.5''s flutter_test pins test_api 0.7.12, incompatible with clide''s exact test 1.31.0 pin, so pub get failed in every job. Remaining here: tests gate releases, SHA256SUMS, SHA-pinned actions, least-privilege permissions, pql download pinning, windows-soak inputs via env.

Partial 2026-09-23: releases are now gated on the tests — release.yml runs on workflow_run of ''test'' (completed, success, push to main) and builds that run''s head_sha, publishing only when its version has no GitHub Release yet. A release commit whose tests fail is never published. Manual workflow_dispatch (tag backfill) stays ungated by design. Test workflow green on main since c9e080a7 (T-620). Remaining: SHA256SUMS, SHA-pinned actions, least-privilege permissions, pql download pinning, windows-soak inputs via env.', NULL, '2026-09-23 10:44:17', '2026-09-23 10:44:17.020', '2026-09-23 10:44:17.020', NULL, '982ae1b4ace572fc97a5cb484ddaa9bc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS67D7RBKA0PJDE6GHNCMR', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:52:49', '2026-09-23 10:52:49.298', '2026-09-23 10:52:49.298', NULL, '72ae6cf253534bb4f4ed0316a28cf7f2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6DZP344T472TCRE7XN4G', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:52:49', '2026-09-23 10:52:49.307', '2026-09-23 10:52:49.307', NULL, 'eb2f1266c587e15f8c9c2a5239da5541', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS67D7RBKA0PJDE6GHNCMR', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:53:44', '2026-09-23 10:53:44.292', '2026-09-23 10:53:44.292', NULL, 'a3bd93e58cafedee351c92d607c67e29', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6DZP344T472TCRE7XN4G', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:53:44', '2026-09-23 10:53:44.304', '2026-09-23 10:53:44.304', NULL, '1f14f3996cd29561c67e24fde0c2d780', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS716CQQS0TCFR1NYBFBPG', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:53:52', '2026-09-23 10:53:52.732', '2026-09-23 10:53:52.732', NULL, '0be3f5ba687e5131e90613e7489eb5ab', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS716CQQS0TCFR1NYBFBPG', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:54:24', '2026-09-23 10:54:24.729', '2026-09-23 10:54:24.729', NULL, '86ae09bc60fe7c0012c38c7986f9fd40', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6188ZN35KEPY6S8EWC2W', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:54:32', '2026-09-23 10:54:32.160', '2026-09-23 10:54:32.160', NULL, 'eb24a7ca423af642d0f99db30ec3291f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6JNWSMWFJN0S6SEMWFZ8', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:54:32', '2026-09-23 10:54:32.169', '2026-09-23 10:54:32.169', NULL, '302457ff3aa66467c4e78c63ef1f1921', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6188ZN35KEPY6S8EWC2W', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:55:23', '2026-09-23 10:55:23.312', '2026-09-23 10:55:23.312', NULL, 'e9ff046d9b59928eade98a44a73eca2d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6JNWSMWFJN0S6SEMWFZ8', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:55:23', '2026-09-23 10:55:23.319', '2026-09-23 10:55:23.319', NULL, 'cd3de1a3f5d1d632f159fa6708295701', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6TDDJAHYJZVPHYPP931G', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:55:31', '2026-09-23 10:55:31.078', '2026-09-23 10:55:31.078', NULL, '96c9dc0dde5d9e0e4341b77fb6f99228', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS6TDDJAHYJZVPHYPP931G', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:55:59', '2026-09-23 10:55:59.453', '2026-09-23 10:55:59.453', NULL, '2361bcc1b770833d4dc62066bf913263', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS773CTD84YD95SBYBD9W8', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:56:06', '2026-09-23 10:56:06.707', '2026-09-23 10:56:06.707', NULL, '519b7054900dbecd81a35b260936e8a7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS773CTD84YD95SBYBD9W8', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:56:49', '2026-09-23 10:56:49.040', '2026-09-23 10:56:49.040', NULL, '51a6bcede8205a30a635f8a0eb037380', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7KTWH1BYEGJK6GYV8AGG', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:56:56', '2026-09-23 10:56:56.354', '2026-09-23 10:56:56.354', NULL, '450034881461ff9d2977670966d15d46', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7KTWH1BYEGJK6GYV8AGG', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:57:47', '2026-09-23 10:57:47.054', '2026-09-23 10:57:47.054', NULL, 'feb00c5b4852ad3655cce1c0cc530fe6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7TCSD4K8NS65TTFB9564', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:57:54', '2026-09-23 10:57:54.254', '2026-09-23 10:57:54.254', NULL, '6bb44304c093e29f762cc66a9acb4979', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7TCSD4K8NS65TTFB9564', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:59:09', '2026-09-23 10:59:09.534', '2026-09-23 10:59:09.534', NULL, '25acb961f952492ee2c11e12844d4ff3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7CWH6V9W6B5CWCV9WMC0', 'status', 'backlog', 'in_progress', NULL, '2026-09-23 10:59:18', '2026-09-23 10:59:18.585', '2026-09-23 10:59:18.585', NULL, '8298473c4288631de473f874e41cf87e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS7CWH6V9W6B5CWCV9WMC0', 'status', 'in_progress', 'review', NULL, '2026-09-23 10:59:58', '2026-09-23 10:59:58.937', '2026-09-23 10:59:58.937', NULL, '99740bd37a2a077e9e081f98f53cab86', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCVS87HRPVQ7W4MENAAK6GD4', 'status', 'backlog', 'review', NULL, '2026-09-23 11:16:11', '2026-09-23 11:16:11.031', '2026-09-23 11:16:11.031', NULL, 'c606b503f78a671e98a5677417714f17', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06GCTR5QEKXZ0VTVWRWKS1M28G', 'status', 'backlog', 'review', NULL, '2026-09-23 11:16:11', '2026-09-23 11:16:11.038', '2026-09-23 11:16:11.038', NULL, '99d139920fbc9b7011862cf3a66b530c', 2) ON CONFLICT(hash) DO NOTHING;
