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
