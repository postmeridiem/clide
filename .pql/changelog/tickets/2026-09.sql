INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G64PCW3KDVCV1X83543FA5JC', 'bug', '06FB0TNQM5TWC00GW0P3X02HZW', 'Web target: fence has runtime holes the wasm compile gate can''t see', NULL, 'backlog', 'medium', NULL, NULL, NULL, '2026-09-02 13:40:34.972', '2026-09-02 13:40:34.972', NULL, 'f30f4a809ea2644754c1d33445ed7520', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
INSERT INTO tickets (record_id, type, parent_record_id, title, description, status, priority, assigned_to, team, decision_ref, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06G64PCW3KDVCV1X83543FA5JC', 'bug', '06FB0TNQM5TWC00GW0P3X02HZW', 'Web target: fence has runtime holes the wasm compile gate can''t see', 'Spike write-up: `docs/spikes/web-target-2026-09-02.md`. Built `flutter build web --wasm` at v2.12.0, served it, loaded it in Chrome, read the console and access log.

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

Note also that with such a seam the terminal is NOT a blocker: xterm.dart renders fine in a browser, and only the *spawn* is native. D-100''s "no PTY/terminal on web" is true of a standalone build, not of a front end to a host that owns the pty.', 'backlog', 'medium', NULL, NULL, NULL, '2026-09-02 13:40:34.972', '2026-09-02 13:40:57.132', NULL, '08d7bc3ddb30bdfdefa5bbf1ad5699b3', 2) ON CONFLICT(record_id) DO UPDATE SET type=excluded.type, parent_record_id=excluded.parent_record_id, title=excluded.title, description=excluded.description, status=excluded.status, priority=excluded.priority, assigned_to=excluded.assigned_to, team=excluded.team, decision_ref=excluded.decision_ref, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, hash=excluded.hash, canonical_version=excluded.canonical_version WHERE excluded.updated_at >= tickets.updated_at;
