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
