# Changelog

All notable changes to clide are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This changelog tracks the Flutter rebuild at the repo root. The Python
Textual implementation's changelog is preserved under
[`legacy/CHANGELOG.md`](legacy/CHANGELOG.md).

Versions are tracked in [`pubspec.yaml`](pubspec.yaml) under `version:`,
which is the single source of truth. Cutting a release means (a) moving
the entries below from `## [Unreleased]` under a new dated version
heading, and (b) bumping `pubspec.yaml` `version:` in the same commit.

## [Unreleased]

### Added

### Changed

### Fixed

## [2.11.0] — 2026-08-12

### Added

- **`clide version` and `clide instance` report the build**, not just the
  release — commit and build time alongside the version, so a running app can
  be told apart from the one you just built. (T-247)

- **Clide companion strip.** A glyph face sits at the bottom of the context
  panel, with a falling-glyph field behind it whose density shows how hard the
  session is working. Silent, motion-gated, and dropped to face-only on a narrow
  panel. (D-107, T-526, T-533)

- **Clide settings.** Settings → Clide turns the companion on or off per
  repository, tunes how often it speaks, and suspends it while the window is
  minimised. Off removes it entirely — no session, no strip. (D-107, T-527)

- **Minimise Clide.** A toggle at the end of the context panel's bottom rail
  hides the strip and gives the detail view its height back; the state persists
  per repository. (T-528)

- **The strip tracks your session.** Clide's rain thickens while Claude is
  working and thins when it stops, with a counter for how long the current turn
  has run. (D-107, T-537, T-538, T-539)

- **Clide goes to sleep.** After ten quiet minutes the strip drains, settles to
  a still frame and stops redrawing entirely; anything happening wakes it.
  (D-107, T-540)

- **Clide has a voice.** A senior engineer who watches, stays quiet, and speaks
  up when a step gets skipped or the same fix is tried a third time. Settings →
  Clide takes your name, a line about yourself, and whether he picks his own
  expression. (D-107, T-532)

- **Ask Clide.** An input box on the strip puts a question straight to him —
  "what did that mean?" about what Claude just said. Always answered, and his
  face turns to you while you type. (D-107, T-564)

- **The Clide strip is scriptable.** `companion.show` / `hide`, `enable` /
  `disable`, `frequency` and `status` — the rail button, the kill switch and
  the frequency selector, all addressable, plus a way to read the state back.
  (D-6, T-529)

- **Clide from the keyboard and the CLI.** `companion.ask`, `companion.say`,
  `companion.open` and `companion.focus` — ask him, read his last remark, open
  his conversation, or jump to his input without touching the mouse. (D-6,
  D-20, T-567)

- **Clide's conversation.** Expand the strip to read his side in full — his
  remarks and your questions, newest first, with a box to keep talking. Esc or
  a click outside closes it, and a half-typed question survives. (D-107, T-566)

- **Clide runs a session.** A headless Haiku session starts with the workspace
  and follows it: the settings switch tears the process down, minimising only
  pauses it, and clearing the main pane clears Clide with it. His own
  transcripts are kept out of `/resume`. (D-107, T-545)

- **Nothing animates while the window is minimised.** Settings → Clide → Power
  turns the behaviour off if you'd rather it kept running. (D-107, T-541)

- **Clide speaks Dutch.** All of his chrome — settings, commands, and what a
  screen reader announces for the face — resolves through the catalog, in
  `en_US` and `nl_NL`. (D-21, D-102, T-530)

### Changed

- Clide's rain draws in the theme's code green rather than muted body text, so
  it reads as falling code instead of dimmed text; his speech bubble takes the
  same green on its edge. (T-535, T-536)

### Fixed

- Settings controls bound to a per-project key no longer throw when no workspace
  is open; they explain instead. (T-527)
- `clide` no longer hangs forever when an instance accepts a request but never
  answers — it times out with a readable message. `CLIDE_TIMEOUT_MS` overrides
  the 30s default. (T-542)

## [2.10.0] — 2026-07-13

### Added

- **Canvas pane.** `.canvas` (Obsidian JSONCanvas) files now open in an
  interactive workspace pane — each document a sub-tab, with pan, zoom, and
  node selection. Routed from the file tree, quick-open, and
  `clide ui open canvas <path>`. (T-322)
- **Vault graph view.** A force-directed link graph of the whole vault in the
  context panel — notes are nodes, wikilinks edges. Hover highlights a note's
  neighbourhood; click opens it. Scroll to zoom, drag to pan; filter by path
  glob, tag include/exclude, or depth from the active note. (T-323)
- **Per-workspace PATH preset.** Directories prepended to the PATH of every
  shell clide spawns for a repo — Claude sessions and terminal panes. Settings
  → Tools → Workspace PATH, or `clide env path …` with capture-from-login-shell
  suggestions. Worktrees share their repo's preset; stored machine-local, never
  committed. (D-106, T-511)

### Changed

- Permission mode: Ctrl/Cmd+Shift+M cycles the full list including
  bypassPermissions, and the composer menu's bypass row unlocks via
  shift-click — plain Ctrl/Cmd+M and plain clicks stay safe-trio only (T-510).
- Bundled Claude skills pruned to clide-specific ones (T-507): broken/duplicate
  skills removed, repo-agnostic ones moved to user scope, and stale guidance in
  the remaining five (paths, commands, icon API) brought back in line with the
  repo.
- The `clide` skill description now leads with the hosting mechanics (`clide`
  on PATH, `CLIDE_SOCK`) and `clide capabilities` as the entry action, so an
  agent deciding whether to invoke it sees the first move up front (T-512).

### Fixed

- Hash-keyed settings (per-workspace PATH presets, Claude account bindings)
  with a number-shaped hash suffix were silently lost on restart — YAML map
  keys are now quoted on write.

## [2.9.0] — 2026-06-30

### Added

- **Graph cards.** `clide draw --file graph.json` (template `graph`) renders a
  nodes/edges graph in the conversation as a circular layout — labelled nodes,
  lines between them. Honest error on a duplicate id or an edge to an unknown
  node. (T-321)
- **Piped `--stdin` payloads.** `cat icons.json | clide icon show --stdin` (and
  `image show`) accept a JSON payload on stdin — the ergonomic peer of `--file`
  for structured commands. (T-315)
- **Before/after compare cards.** `clide draw --file compare.json` (template
  `compare`) renders two or more images side by side, each with its own
  label/description and tap-to-zoom; images aspect-fit so differing shapes
  don't distort. (T-319)
- **Phosphor glyph cards.** `clide icon show gear folder` (or `--file` entries
  with label/description/color) renders glyphs in the conversation at a hero
  size plus a real-UI-size strip (10–48), for previewing and comparing icons.
  Resolves by name or 0xNNNN codepoint; honest error on an unknown glyph. (T-313)
- **Annotated image cards.** `clide image show --file meta.json` attaches a
  title/label and a longer description to an image card (alongside the existing
  one-line caption); the bare `image show <path> --caption` form is unchanged.
  Visual marker overlays remain a follow-up. (T-316)
- **D2 diagram cards.** `clide draw --file diagram.d2` compiles a d2 diagram to
  SVG (via the `d2` binary) and renders it in the conversation; `template:"d2"`
  with inline source works too, and a `.svg` file renders directly. Honest error
  if d2 isn't installed or the source doesn't compile. (T-494, D-103)
- **Tool path resolution + settings.** clide resolves supporter binaries (claude,
  d2) via an explicit per-tool path, else PATH and the common install dirs — now
  including Homebrew-on-Linux. A Tools settings category edits the paths and
  re-detects; a broken path shows in Problems. (T-495, D-104)
- **Check for updates (About box).** Help → About has a manual "Check for
  updates" button that compares your version to the latest GitHub release and
  links to the notes — explicit and user-initiated, no background polling (the
  first and only outbound call clide makes, on your action). (T-47)
- **Live-sync markdown read-mirror.** Editing a `.md` in the editor auto-opens a
  read-only preview in the context panel that mirrors the buffer and re-renders
  as you type; non-renderable files get no auto-viewer. (T-36, D-50)
- **New project flow.** A "New project…" action in the welcome view creates +
  opens a project, then prompts for the Claude account to bind it to — the
  per-repo account roadblock fires only for freshly-created projects. (T-488,
  story T-486)
- **Initialize a non-repo folder.** Opening a folder that isn't a git repo now
  offers to initialize it as a clide project (`git init` + scaffold + the
  account roadblock) instead of dead-ending. Also `clide project init`. (T-489)
- **`clide project new <name> [--dir <parent>]`.** Create a new clide project —
  a fresh dir, `git init`, and a minimal scaffold. `--dir` defaults to the
  current workspace's parent. (T-487, story T-486)
- **Claude account login pane.** `account login` (and the UI add/re-login
  affordances) open a modal terminal running `CLAUDE_CONFIG_DIR=<dir> claude
  login`; the CLI owns the OAuth flow, credentials land in that account's dir.
  (T-485, epic T-476)
- **Claude pane account badge.** The pane header shows which account this repo
  is bound to (colour-tinted per account); tap to switch. Hidden when no
  accounts are registered. (T-481, epic T-476)
- **Settings → Claude → Accounts.** A registry list (sign-in status, dir,
  re-login / remove, add) plus a per-workspace picker that binds this repo to an
  account (or Default); switching respawns the pane onto it. (T-482, epic T-476)
- **Per-repo Claude accounts — `clide claude account` verbs.** Manage named
  Claude config dirs and bind one per workspace: `add`/`list`/`set`/`unset`/
  `remove [--purge]`. `set`/`unset` respawn the workspace's Claude pane(s) onto
  the bound account (resuming the conversation under its `CLAUDE_CONFIG_DIR`).
  (T-480, epic T-476)
- **`clide instances` / `clide instance` CLI verbs.** `instances` lists every
  live clide on the machine with its version, pid, workspace, and socket path
  (probing the runtime dir); `instance` reports the one you're connected to — so
  you can find and target a specific instance via `CLIDE_SOCK`. (T-247)
- **Summer Night theme + high-contrast sibling.** The legacy v1.2 palette is
  fleshed out to full token + syntax coverage and ships alongside a
  contrast-hardened `summer-night-hc`, both selectable in Settings → Appearance.
  (T-478)

### Changed

- **Fresh Claude sessions are nudged to use the bundled skills.** New tabs and
  post-`/clear` respawns get a one-line prompt to load the `pql` + `clide`
  skills from the first turn; resumed/forked sessions are left alone. (T-490)
- **Claude meta sidebar facelift.** The Activity, Team, and Config tabs render
  their sections as elevated cards with small-caps headers, matching the
  settings overlay's card design. (T-158)
- **Bundled themes and Tier-0 i18n namespaces resolve from one canonical list
  each.** The app, testmode harness, and contrast/i18n gates iterate the shared
  lists instead of drifting copies; a new theme or catalog is validated
  automatically, and the i18n gate now checks every catalog for en/nl parity.
  (T-371)

### Fixed

- **No more i18n "missing key" log spam for tool names.** Proper-name tools
  (Bash, ScheduleWakeup, MCP tools, …) intentionally have no catalog entry and
  fall back to the raw name; the conversation pane no longer logs a warning for
  each. (T-493)
- **`clide` CLI honors `CLIDE_SOCK`.** The shell client now connects to the
  socket named by `CLIDE_SOCK` when set — an explicit target (e.g. a spawned
  agent pinning its parent instance) that beats workspace auto-discovery — and
  fails loudly if that socket is dead instead of silently driving a different
  instance. (T-247)
- **Orphaned IPC sockets are swept on startup.** The app probes the runtime
  socket dir on launch and unlinks dead `*.sock` nodes left by crashed
  instances (live instances are left untouched), so the dir no longer
  accumulates stale sockets. (T-247)
- **Default window opens larger (1600×900) on Linux.** 720p was short enough
  that the welcome screen's version/theme footer overlapped the tips card;
  the taller default clears it, matching the macOS default. (T-477)
- **Editor split collapses when the last buffer closes.** Closing the final
  editor buffer left the top split orphaned over the Claude pane; the daemon
  now emits the buffer-cleared event it was suppressing, so the split drops
  out and the primary pane fills the column. (T-459)

## [2.8.0] — 2026-06-19

### Added

- **Language selector + Dutch (nl-NL).** Settings → Appearance → Language
  switches the UI language live (persisted as `app.locale`); a full Dutch
  translation ships. English (en-US) stays the default. (T-462)

### Changed

- **App is fully localizable (i18n everywhere).** Every user-facing label —
  panels, dialogs, command palette, menus, and settings — now resolves through
  the i18n catalog instead of a hardcoded string; catalogs are bundled per
  locale under `assets/i18n/<locale>/`. A new language is a drop-in folder;
  en_US behaviour is unchanged. (T-462)

## [2.8.1] — 2026-06-22

### Fixed

- **Localized the remaining Claude-pane strings.** Running-indicator verbs, the
  primary/secondary session titles and banner role, tool-card titles, the
  step/edit/agent counters, and the folded-activity ticker now resolve through
  the catalog — completing i18n coverage of the conversation surface. (T-462)

## [2.7.1] — 2026-06-18

### Changed

- **Josefin Sans is the default UI font again.** Reverts the Inter default from
  2.7.0; Inter stays bundled and selectable in Settings → Appearance. JetBrains
  Mono remains the default monospace face (Fira Mono selectable). (T-460)

### Fixed

- **Markdown prose honours the UI-font setting.** Claude's conversation prose
  and inline links render through the markdown engine, which pinned the bundled
  UI face and ignored the Appearance UI-font pick; it now follows the setting
  live, like the rest of the app. (T-475)

## [2.7.0] — 2026-06-17

### Added

- **Settings panel shell.** A new `settings.open` command (⌘`,`, plus a File
  menu and command-palette entry) opens a centered Settings modal over the
  dimmed app — the foundation of the schema-driven settings UI. It frames the
  category rail and scrolling carded panel that later work fills in; closes on
  ✕, Esc, or a barrier tap. (T-445)

- **Schema-driven settings engine.** Subsystems register a `SettingsCategory`
  (via `SettingsCategoryContribution` → the kernel `SettingsRegistry`); the
  panel renders it as carded sections of toggle/select/text/number/file rows,
  each bound to a `SettingsStore` key with help and reset-to-default.
  Registering a category surfaces a new tab. (T-448)

- **Settings category rail.** The modal's left rail lists the registered
  categories (icon + title, data-driven from the registry) with an accent
  left-stripe + surfaceHi selection; picking one swaps the panel. (T-447)

- **Per-field scope tags.** Each field shows where its value lives — folder =
  Project (`.clide`), globe = Always (`~/.clide`), circle-dashed =
  Default/unset — with a tooltip and a menu to move the value between scopes or
  reset it. Backed by scope-explicit `SettingsStore` access. (T-449)

- **Cross-category settings search.** A search box atop the rail filters fields
  across every category; the panel shows the matches grouped under category
  subheaders (editable inline), and each rail row shows its match count with
  zero-match categories dimmed. (T-450)

- **Settings → Activity category.** The first real settings tab: the
  conversation fold level (none / tools / thinking / everything) as a schema
  field; picking a level applies live to the activity stream. (T-453)

- **Settings → Keymap category.** A preset select (Default / Vim / VS Code /
  JetBrains); picking one switches the active keymap live via the preset
  command. (T-451)

- **Settings → Appearance category.** A theme picker in the panel — base-theme
  chips + a high-contrast toggle, applied live. Adds the engine's custom-control
  escape hatch (`SettingsControlContribution` / `SettingsControlRegistry`) for
  one-off controls the generic field kinds can't express. (T-452)

- **Settings → Extensions tab.** A "watch this space" notice — installing and
  toggling extensions arrives with third-party (Lua) support; built-ins stay
  always-on for now. (T-456)

- **Settings → Claude category.** New-session defaults — model, effort, and
  permission mode — seed fresh sessions (effort via `--effort` at spawn;
  model and permission applied right after start). (T-457)

- **Inter is the default UI font + a UI-font picker.** Bundled Inter (variable)
  as the default interface typeface — Josefin Sans stays selectable — and
  Settings → Appearance gains a UI-font picker that applies live. (T-460)

- **Monospace font picker.** Settings → Appearance adds a monospace font select
  (JetBrains Mono / Fira Mono) that applies live to the terminal, diffs, code,
  and IDs. Bundles Fira Mono. (T-471)

### Changed

- **Theme picker relabelled "Theme…".** The ⌘K theme picker's command title
  changed from "Settings…" to "Theme…" so it no longer collides with the new
  Settings panel in the palette; behaviour is unchanged. (T-445)

### Fixed

- **Monospace setting now applies everywhere.** Eleven context-free render
  helpers (Claude tool bodies + results, inline markdown code/refs, search
  previews, welcome tips) hard-coded JetBrains Mono and ignored the Monospace
  font setting; they now honour it live. (T-472)

## [2.6.0] — 2026-06-16

### Added

- **Vim `gt` / `gT` tab motions.** Under the Vim preset, `gt`/`gT` cycle the
  workspace tab strip (the same `workspace.tab.*` commands as `ctrl+pagedown`/
  `ctrl+pageup`), resolved by the focused editor or pane and sharing the `g`
  prefix with `gg`. Completes the T-403 cross-pane vim layer. (T-405)

- **Vim ex command-line (`:`).** Under the Vim preset, `:` opens a transient
  one-line overlay running a fixed table — `:w` save, `:q` close the active tab
  (the split self-collapses on the last one), `:wq`/`:x` and `ZZ` save+close,
  `:e <path>` jump to quick-open seeded with the path, `:<n>` goto-line. Unknown
  commands flash and stay open; with no active buffer it no-ops. Opens from the
  editor or a focused pane; Esc dismisses. Adds the `editor.goto-line` CLI/IPC
  verb. (T-407)

- **Crash-survivable logging.** clide writes a durable JSON-lines log to a
  persistent per-platform dir (Windows `%LOCALAPPDATA%`, macOS `~/Library/Logs`,
  Linux `$XDG_STATE_HOME`), fsyncing warn/error + pty/ffi records immediately so
  a freeze leaves on-disk evidence. `CLIDE_LOG` (dart-define / env) or the
  `app.log.level` setting sets verbosity (warn in release, info in debug);
  `CLIDE_LOG_DIR` redirects where the logs land. (T-432, T-436)
- **PTY FFI breadcrumbs.** Each PTY backend drops a breadcrumb before/after
  every risky syscall (`CreatePseudoConsole`/`CreateProcessW`/`ReadFile`,
  `posix_spawn`/`read`); the reader/waiter isolates fsync their OWN file handle
  so a wedged isolate's last crumb survives a freeze that also froze the main
  isolate — naming the wedge after the fact. Per-syscall crumbs at debug level.
  (T-434)
- **Crash-diagnostic watchdog.** A dedicated isolate fsyncs a heartbeat every
  ~500ms (bounding a freeze to ~500ms) and every ~2s samples this process's
  thread / handle / child-host / RSS counts to `clide-watchdog.log` — a climbing
  child or thread count is the leak signature. Survives a frozen main isolate;
  spawn failure is non-fatal. (T-435)
- **Live log-verbosity toggle.** The output dock's Level chip now sets the
  running logger's level and persists `app.log.level` (not just a view filter),
  and `clide log level [<level>]` does the same from the CLI — D-6 parity. The
  choice survives restart. (T-433)

### Fixed

- **`/clear` no longer kills the Claude pane.** Clearing the primary pane tore
  the session down and respawned on the same deterministic `--session-id`
  *before the old `claude` process had actually exited*, so claude 2.1.177
  rejected the id as "already in use" and the respawn exited 1. The session
  teardown now awaits the process's real death (SIGTERM, escalating to SIGKILL)
  before clearing the transcript and respawning. A dead pane also now shows the
  CLI's own reason instead of a bare "exited (code 1)". (T-437)
- **Web/WASM build compiles again.** `flutter build web --wasm` (and the
  `test-e2e` / `ui-dev` / `ui-smoke` harness) had been broken since the
  tree-sitter/PTY `dart:ffi` pivot. Every native binding (PTY, tree-sitter, the
  Lua host, the Windows watchdog, the ABI/fd-inheritance probes) now sits behind
  a `dart.library.ffi` conditional import with a graceful web stub, and the FNV
  hash constants are dart2js-safe. A `flutter build web --wasm` compile gate was
  added to CI so the fence can't silently rot. Desktop builds are unchanged — the
  web target degrades (no terminal, no native git, no syntax highlighting), it
  does not compromise desktop fidelity. (T-438, D-100, Q-50)
- **Desktop-launched clide finds your installed tools.** A dock/launcher start
  inherits a sparse `PATH` (no `~/.local/bin`, brew, nvm, …), so pql/git/claude
  and terminal tools could go missing. clide now resolves the real login-shell
  `PATH` once at startup (`$SHELL -l -c`, bounded + graceful fallback) and routes
  every spawn site — PTY children, git, the toolchain probe, hosted claude —
  through one shared resolver, replacing three divergent (and partly macOS-only)
  PATH expanders. (T-439, follows T-347)

## [2.5.0] — 2026-06-14

### Added

- **Experimental Windows desktop support.** clide builds and runs on Windows —
  ConPTY-backed terminals, an AF_UNIX `clide` CLI client, PowerShell as the
  default shell, and a `make build-windows` target. Preview quality: ConPTY
  child-process reaping under sustained use is still being hardened. (T-424)
- **Vim `ctrl+w` window commands.** Under the vim preset, `ctrl+w` followed by
  h/l (focus left/right panel), j (toggle dock), w / ctrl+w (cycle panels),
  shift+w (cycle back), o (focus mode), or q/c (close editor). A new global
  multi-chord matcher in the shell resolves these from any focus; bare `ctrl+w`
  still closes the editor after the ambiguity timeout. (T-404)
- **Workspace tab cycling with ctrl+pagedown / ctrl+pageup.** New
  `workspace.tab.next` / `workspace.tab.previous` commands cycle the workspace
  tab strip with wraparound, bound across every preset. (T-405)
- **Vim normal-mode navigation works outside the editor.** Under the vim preset,
  a focused file tree or conversation now responds to j/k, ctrl+d/ctrl+u, gg/G,
  and (tree) h/l/o — a selection cursor in the tree, scrolling in the
  conversation. Each pane runs its own sequence matcher; an `editor.focused`
  flag keeps these keys as buffer motions while the editor holds focus. (T-406)
- **Claude Code Workflow runs surface in the conversation and sidebar.** A
  `Workflow` tool-use renders a dedicated run card — phase groups, per-agent
  rows with live spinner/check status, usage, and the script — driven by the
  harness's out-of-band progress events. The Activity tab adds a WORKFLOWS
  section showing each run's done/total agent count. (T-416)
- **Session controls and live usage in the Claude sidebar Activity tab.** A
  SESSION strip offers clear/compact/fork/resume buttons (same code path as the
  typed commands), and a refresh control fetches `/usage` — plan usage renders
  as a USAGE block (session and weekly percentages). The runtime row now also
  shows the session's effort level. (T-415)
- **The Claude sidebar Config tab is a live control panel.** Model, effort, and
  permission mode are popover controls showing the running session's values;
  picking an option drives the session through the same path as the typed slash
  command. The sidebar tables also got a visual pass — larger type, accent
  section headers, more breathing room. (T-414)
- **The TUI command family opens clide surfaces.** `/permissions` sets the mode
  directly or opens a picker; `/status`, `/config`, `/mcp`, `/agents`, `/hooks`
  jump to the matching Claude sidebar tab; `/memory` opens CLAUDE.md in the
  editor; `/help` shows clide's own command summary. (T-413)
- **`/effort` works in the Claude pane.** With a level (`/effort xhigh`) the
  session restarts in place carrying `--effort` — resume keeps the
  conversation; bare `/effort` opens a picker with the five levels and the
  current one marked. The active effort shows in the session status. (T-412)
- **TUI-only slash commands get a helpful notice instead of failing.** A typed
  `/cost` or `/doctor` no longer errors raw from the CLI or leaks to the model
  as literal text — known TUI-only commands route to a muted notice card with
  the clide-native way. CLI-local output (like `/usage`) renders as a "clide"
  card, never fake Claude prose. (T-411)
- **`/model` works in the Claude pane.** With a name (`/model sonnet`) it
  switches the live session's model over the control channel; bare `/model`
  opens a picker in the interaction zone with the CLI's model list and the
  current model marked. A rejected name rolls back and raises a toast. (T-408)

### Removed

- **tmux is no longer a required tool.** clide stopped spawning tmux when Claude
  session persistence moved to `--resume` (D-77); the toolchain no longer probes
  for it or warns when it's absent, on any platform.

### Fixed

- **`ClaudeConfig` no longer crashes on a project switch that races teardown.**
  `setProjectDir` / `refresh` / `ensureProbe` now skip `notifyListeners()` if the
  config was disposed during their async load (the guard `load()` already had).

## [2.4.1] — 2026-06-12

### Fixed

- **`Shift+;` types a colon again — double-Shift no longer fires on chorded
  Shift.** The double-tap detector counted any Shift press as a tap, even
  mid-chord, and never saw keys the focused editor consumed; a tap now
  requires a clean press-and-release, observed at the raw-keyboard level.
  (T-409)

## [2.4.0] — 2026-06-12

### Added

- **Live tail inside expanded Bash activity cards.** A Bash card that follows a
  file (`tail -f …`) now shows a live, scrolling read-only tail of that file
  below the result — connected only while the card is expanded. Commands with no
  followable file show a muted "nothing to follow" note. (T-325)

- **Double-tap-modifier shortcuts (e.g. double-Shift "Search Everywhere").**
  The keymap can now bind a bare modifier and a double-tap sequence
  (`shift shift`). All four presets (default, vim, vscode, jetbrains) map
  double-Shift to the quick-open finder — JetBrains' "Search Everywhere"
  gesture, aliased to clide's existing fuzzy file finder. (T-341)

### Changed

- **Each spawned subagent gets its own collapsing activity card.** A fan-out of
  N agents no longer merges into one "Activity / N steps" cluster — each spawn is
  its own card with its prompt and nested run. Non-agent tool calls still group
  as before. (T-342)

### Removed

- **Dead-code sweep.** The legacy free-function git API (with its latent
  pipe deadlock), ToolCheck, the fd-passing-era libc bindings, the GraphView
  placeholder, the superseded ColumnHat widget, the tmux-era
  TranscriptPublisher, the committed `ptyc` binary, and the unused
  `mocktail` dev-dependency (D-25 amended) are gone. (T-385)

- **Dead welcome-screen tiles.** "Clone from git…" and "Start a Claude
  session" did nothing on tap and advertised shortcuts that were never
  registered; the tips card now lists only shortcuts that exist in the
  default keymap. Each tile returns when its flow ships. (T-383)

### Fixed

- **Terminal CSI sequences with intermediate bytes no longer mis-dispatch.**
  The parser dropped intermediates, so e.g. VT420 scroll-left (`CSI 5 SP @`)
  executed as "insert 5 blank characters"; such sequences are now reported
  as unknown instead. (T-123)

- **PTY master fd no longer leaks when a child exits on its own.** Every
  terminal or Claude pane whose process ended naturally left its pty device
  open for the life of the app; natural exit now releases the fd. (T-360)

- **Closing a terminal pane now closes its shell.** Pane disposal looked up
  the kernel illegally and swallowed the failure, so `pane.close` was never
  sent — the backend PTY and daemon pane leaked on every closed terminal
  pane, and Claude panes leaked a settings listener the same way. (T-366)

- **Scrolling up during a streaming reply no longer fights the auto-scroll.**
  The conversation followed the tail on every streamed token regardless of
  scroll position, dragging a reader back to the bottom; it now follows only
  while already pinned there. (T-368)

- **The terminal no longer crashes on truncated SGR color sequences.**
  `ESC[38m` and friends threw a RangeError inside the emulator; incomplete
  38/48 sequences are now ignored, and colon-form truecolor/256-color
  sub-parameters (`38:2:r:g:b`, ITU T.416) parse like the semicolon form
  instead of being mangled. (T-369)

- **File listing flags symlinks again and the workspace walk no longer
  follows them.** Symlink detection was dead code, so `files.walk` (and the
  search engine on top of it) silently descended symlinked directories —
  including ones pointing outside the workspace. (T-365)

- **Search-and-replace now honors its include/exclude globs.** The filters
  were accepted but never applied, so replace could rewrite files outside
  the scope the user typed; replace now uses the same glob filtering as
  search. (T-364)

- **Switching projects releases the previous workspace's services.** The old
  file watcher, pane PTYs, in-flight searches, and editor buffers were left
  alive on every project switch, with stale watcher events leaking into the
  new workspace. (T-367)

- **Expanded activity cards are readable by screen readers again.** The
  collapser's summarized button semantics excluded the whole card, so
  expanding a run announced nothing inside it; the exclusion is now scoped
  to the header and the inner cards stay in the a11y tree. (T-370)

- **A crashed Claude process no longer looks like it's still thinking.**
  stderr is now drained continuously (an undrained pipe could block the
  child mid-turn) and the exit code is watched: when the process dies the
  pane stops spinning, clears any unanswerable permission prompt, reports
  the exit in the status line, and logs the stderr tail. (T-361)

- **The Claude status bar populates reliably after a session starts.** The
  session's init event often fired before the pane subscribed and the plain
  broadcast stream dropped it, leaving the model/mode/context line blank;
  session state streams now replay their latest value to late subscribers.
  (T-274, T-386)

- **New terminal panes open in the project root.** The shell spawned in the
  app process's working directory — `$HOME` for desktop launches, and the
  wrong repo after a project switch. (T-381)

- **Two simultaneous spawns of the same Claude session no longer leak a
  process.** Concurrent spawn calls for one pane id both passed the registry
  check and the loser's live process was orphaned; spawns for an id are now
  coalesced onto one in-flight future. (T-374)

- **`/clear` in a fork pane clears instead of re-forking.** The fork source
  took precedence on every respawn, so clearing a fork tab silently branched
  the original conversation again; the source now seeds only the first
  bind. (T-375)

- **Pipelined IPC requests are now truly serial and framing-safe.** The
  server's read handler could interleave concurrent requests (against
  D-72's contract), drop or double frames split across reads, and corrupt
  multi-byte characters split across chunks. (T-372)

- **Settings survive nested structures, crashes, and corruption.** Maps
  inside lists (the keymap overlay shape) were corrupted on save; writes
  are now atomic (temp file + rename), and a file that fails to parse is
  preserved as `.broken` with a logged warning instead of being silently
  reset. (T-376)

- **Markdown hard breaks break lines and images leave a visible trace.**
  Both rendered as empty text — words on either side of a hard break glued
  together and images vanished; breaks now emit a newline and images render
  an italic `[image: alt]` placeholder. (T-379)

- **Extension notifications actually appear on screen.** Messages pushed
  through the kernel Notifications service (e.g. the CLI-install dogfood
  warnings) accumulated in a list no surface rendered; they now raise
  toasts with matching severity. (T-382)

- **Failed `clide claude.*` commands now exit non-zero.** Sixteen handlers
  reported success with an error message buried in the payload, so scripts
  could not detect failures like an unknown permission mode; they now
  return proper error envelopes per the D-6 contract. (T-391)

- **Terminal output no longer garbles multi-byte characters split across
  reads.** PTY output and live-tail bytes were decoded per chunk, turning a
  rune split across reads into replacement-character noise; the terminal
  now ingests bytes through a persistent decoder. (T-373)

- **Extension lifecycle is transactional.** A throw mid-activation now
  unwinds every contribution it had mounted (a retry no longer
  double-applies), deactivating an extension is refused while active
  extensions depend on it, and duplicate contribution/command ids are
  rejected instead of silently clobbering. (T-377)

- **Accepting ExitPlanMode now leaves plan mode in the conversation panel.**
  Approving Claude's plan (the ExitPlanMode tool) transitioned the underlying
  session out of plan mode, but clide's tracked permission mode didn't follow,
  so the mode indicator and composer stayed stuck on "plan". The approval now
  syncs the tracked mode to `default`. (T-337)

### Security

- **The MCP HTTP server now requires a per-start auth token.** The localhost
  SSE port served the entire clide command surface unauthenticated,
  bypassing the unix socket's 0600 gate; requests must now present the
  token published in the 0600 `/ide` lock file. (T-362)

- **`editor.open` / `editor.save` are now workspace-confined.** Both verbs
  accepted absolute paths and `..` traversal verbatim — an unconfined read
  and write primitive over IPC. They now pass the same path-safety guard as
  `files.read`, including a symlink re-check at save time. (T-363)

## [2.3.3] — 2026-06-11

### Fixed

- **Ticket/decision sidebars load on first open after a desktop launch.** A
  desktop launch starts in HOME (not a git repo), and the daemon booted its
  pql/git/files workspace there — so pql ran in HOME, hit a stale
  `~/.pql/pql.db`, and the sidebars showed "pql … failed" until the project was
  reopened (a manual refresh worked once the workspace had swapped to the repo).
  The daemon now boots at the last opened project when the launch directory
  isn't itself a repo, so pql targets the real workspace from the first request.
  (T-352)

### Changed

- **Minimum toolchain raised to honest values.** `pubspec.yaml` now declares
  Flutter `>=3.35.0` / Dart `>=3.9.0` (was `3.19.0` / `3.5.0`) — the real
  minimums our deps already required (`alchemist` needs Flutter 3.32; Dart 3.9
  ships in Flutter 3.35). The exact build toolchain is pinned in `.fvmrc`
  (Flutter 3.44.1). Moving to the Dart 3.9 language level reformatted the tree
  to the new "tall" style and adopted two new lints (`unnecessary_underscores`,
  `use_null_aware_elements`). (T-353)

### Security

- **Dependency audit + refresh.** Reviewed every pinned and transitive
  dependency against the GitHub Advisory Database / OSV (Pub ecosystem) — no
  advisory affects any current or candidate version. Refreshed the safe pins:
  `ffi` 2.1.3→2.2.0, `jovial_svg` 1.1.26→1.1.30 (pulls `jovial_misc` 0.10.0 +
  `xml` 7.0.1), `mocktail` 1.0.4→1.0.5, and `markdown` 7.2.2→7.3.1 (unblocked by
  the Dart 3.9 floor below). Deliberately held with reasons in `pubspec.yaml`:
  `alchemist` (0.13 golden churn), `test` (Flutter-SDK locked). (T-353)
- **Supply-chain gate (`make security`).** A new `security` target runs
  `osv-scanner` over `pubspec.lock` and fails if any resolved dependency has a
  known advisory — a hard gate on top of `dart pub`'s passive, non-failing
  advisory print. Intended for the CI PR-merge pipeline (kept out of
  `push-check` so dev machines don't need the scanner installed); run locally
  any time with `make security`. (T-353)

## [2.3.2] — 2026-06-11

### Fixed

- **Ticket and decision sidebars reliably load on first open (real fix).** The
  2.3.1 re-fetch-on-open helped only when a project is picked *after* the window
  is up; with sticky-startup the project opens during boot, before the panes
  mount, so they never saw the event. The underlying cause was a race: the boot
  IPC-server swap (to the launch CWD) and the project-open swap (to the repo)
  ran concurrently, and the late-finishing boot swap could clobber the repo
  bind — leaving the daemon's pql/git/files pointed at the launch directory
  (HOME) and the sidebars erroring on a stale/global pql.db. Swaps are now
  serialized so the repo bind always wins. (T-352)

## [2.3.1] — 2026-06-10

### Fixed

- **Frameless window chrome works on KDE Plasma 6 / KWin 6.** The Wayland
  server-decoration request fired on `realize`, before GTK created the
  surface, so it bailed and KWin (which defaults to server-side decorations)
  kept drawing its own title bar. It now also fires on `map`. (T-351)
- **pql sidebar panes no longer stick on a transient startup error.** A
  too-early or db-busy pql failure (the planning DB still settling, or a
  SQLite lock under concurrent writes) is now retried a few times before
  surfacing, instead of leaving the pane on "pql … failed" until a manual
  refresh. (T-350)
- **Ticket and decision sidebars load on first open, not just after a manual
  refresh.** On a desktop launch the daemon's pql workspace starts as the
  launch directory, not the repo, so the panes' first fetch ran against the
  wrong (or a stale-schema) DB and errored. They now re-fetch when the
  workspace actually opens, by which point the pql workspace is the repo. (T-352)

## [2.3.0] — 2026-06-10

### Fixed

- **Tools like `pql` resolve when clide is launched from the desktop on Linux.**
  A desktop launch inherits a minimal PATH without `~/.local/bin`, so the pql
  pane (and other PATH-resolved tools) failed — the PATH expansion that fixes
  this previously ran on macOS only. It now also runs on Linux. (T-347)
- **Consistent card font sizes in the Claude conversation.** Tool/result cards
  and the Activity/run collapser cards now share the same header-label (14) and
  collapsed-summary (13) sizes, so neighbouring cards in the stream no longer
  render 1–2px apart. (T-344)
- **"Deny & simplify" no longer shows a loud red error.** A denial the user
  deliberately chose (Deny & simplify) folds into a muted, collapsed "denied"
  card instead of the prominent expanded-red block reserved for genuine tool
  failures — which still render expanded. Driven by a reusable per-result
  "quiet error" flag, not by matching the note text. (T-340)
- **Sub-agent prompts no longer render as a blue "you" card.** In live
  (stream-json) sessions the spawning prompt is tagged with `parent_tool_use_id`,
  not the transcript's `isSidechain`/`parentUuid`, so it slipped past the
  sidechain fold. The parser now treats that field as a sidechain marker and
  folds the prompt into its Agent card. (T-338)

### Added

- **Per-type filter chips on the tickets panel.** A row of toggle chips
  (Initiative · Epic · Story · Task · Bug, large→small) below the filter box.
  Click a chip to toggle that type; double-click to isolate it (chart-legend
  solo); disabling the last one snaps all back on. ANDed with the text filter.
  All on by default. (T-343)
- **VS Code keybinding preset.** A `vscode` keymap mapping VS Code's default
  shortcuts (Ctrl+P, Ctrl+Shift+P, Ctrl+B, Ctrl+J, Ctrl+`, zoom, …) to clide.
  Activate via the "Keymap: VS Code" command or `app.keymap.preset = vscode`. (T-64)
- **JetBrains keybinding preset.** A `jetbrains` keymap mapping IntelliJ's
  defaults (Find Action, Go to File, tool windows, …). Double-Shift "Search
  Everywhere" isn't expressible by the chord matcher yet (T-341), so Go to File
  stands in for quick-open. (T-66)
- **Picking up a ticket now starts it.** Handing a ticket to a live Claude pane
  (sidebar pick-up) also moves it to `in_progress` and refreshes the sidebar —
  but only on acceptance and only from a not-yet-started status, so a pick-up
  with no live pane is a quiet no-op and a re-pick-up never moves a ticket
  backwards. (T-339)
- **Clickable file references in the Claude conversation.** Workspace file paths
  mentioned by Claude — bare (`lib/app.dart`), with a line (`lib/app.dart:42`),
  backticked, or as markdown links — are now clickable and open in the editor,
  jumping to the line when present. Only paths that actually exist in the repo
  linkify, so prose like version numbers stays literal. (T-300)
- **Hand a ticket to Claude from the sidebar.** Hovering a ticket card reveals a
  run icon; clicking it hands the full ticket to the active Claude pane as a
  "pick this up and start" prompt. Routed over the message bus, so the sidebar
  stays decoupled from the session internals. (T-327)
- **Claude's task list is now visible, docked above the composer.** When Claude
  is tracking a TodoWrite checklist, a compact display-only strip shows it pinned
  above the input — collapsed to `N tasks · M done` + the current in-progress
  item, expandable to the full list with per-item status glyphs. Hidden when
  there are no tasks. (T-308)
- **A "Deny & simplify" option on the permission card.** A fourth button
  (alongside Allow / Allow-and-remember / Deny) denies the action with a
  preformatted note telling Claude it was too complex and to retry simpler —
  without writing a memory or changing settings. A typed note is appended;
  addressable by number key (4, or 3 without remember). (T-311)

### Fixed

- **Clicking outside the image in the lightbox now closes it.** Previously only
  the thin margin dismissed — a click on the dimmed canvas beside a letterboxed
  image hit the viewer and did nothing. A single tap outside the painted image
  now closes it (matching Esc / the × button); tapping, dragging, or zooming the
  image still doesn't. (T-309)
- **Run-status indicators no longer crash on rapid flips.** Switching status
  back and forth within the 200ms cross-fade (e.g. running → success → running
  across two bound Claude panes) tripped an AnimatedSwitcher duplicate-key
  assertion and a cascade of follow-on errors. Each glyph now carries a key
  unique per change, so an exiting and entering glyph never collide. (T-326)
- **The activity-card run-status spinner is now legible.** At 12px the spinning
  logo mark read as a static speck; the run-status indicator on collapsible
  cards is bumped to a `clideIconHero` (26) so the running state is clear at a
  glance. The check / cross share the size, so the card doesn't jump on settle.
  (T-304)

## [2.2.0] — 2026-06-10

### Added

- **`clide://` deep links open files, safely.**
  `clide://open?path=/repo/file.dart&line=42` opens the file at that line (CI
  links, error reports), routed through the CLI→IPC path into the running
  window. As an untrusted external vector it's gated by a default-deny allowlist
  (navigation only) and a confirmation prompt before any action. Registered on
  Linux + macOS. (T-56, D-90)
- **Number keys pick prompt buttons (CLI muscle memory).** In a permission or
  AskUserQuestion prompt, `1`/`2`/`3`… select the matching button or option
  (labels are now numbered), and Enter confirms the primary action. Typing in a
  note field is unaffected — digits only act while the card itself holds focus.
  (T-240)
- **Links in the Claude conversation are clickable.** An http(s) link (typed or
  autolinked) now opens in your default browser on click — with a hover
  underline + pointer — across prose, lists, tables, and headings. Non-http
  schemes stay inert. (T-253)
- **The activity-card fold level is now adjustable and persists.** A
  `claude.activity.fold-level` command cycles how aggressively meta steps fold
  (none → tools → thinking → everything); the choice is saved app-wide and the
  Claude pane and team tiles re-fold live. (T-235)
- **Consecutive edits to one file fold into a single card.** A run of same-file
  edits collapses to one `# edits` holder instead of a stack — every edit
  reachable on expand; a different file or an interleaving step splits it. The
  card shows an aggregate live status: a logo-mark spinner while editing,
  settling to a check or cross. (T-296)
- **Collapse toggles in the status bar.** A small caret-line button bookends
  each end of the bottom status bar — left collapses/expands the sidebar, right
  the context pane. The chevron points inward to collapse, outward to expand,
  and fires the existing `sidebar.collapse` / `context.collapse` commands
  (`Ctrl+Shift+1` / `Ctrl+Shift+3`), so it's the mouse affordance for an
  already keyboard/CLI-addressable action. (T-294)
- **Pasted images render inline in the Claude conversation.** A pasted-image
  `@<path>` reference shows as a bounded thumbnail instead of the raw path;
  clicking it (or Enter when focused) opens it in the lightbox. The composer's
  attachment previews use the same larger thumbnail. A missing file degrades to
  a placeholder; the sent text is unchanged. (T-236, T-254, D-89)
- **The editor honours `.editorconfig`.** Opening a file resolves the
  workspace rules into a source-agnostic `EditorSettings` (own INI parser +
  glob matcher, `root`/nearest-wins precedence — no new dependency). The editor
  indents with Tab/Shift+Tab and draws a `max_line_length` ruler; saving applies
  `end_of_line`, `trim_trailing_whitespace`, and `insert_final_newline`. Saving
  the `.editorconfig` re-resolves open buffers live. (T-29)
- **Permission-mode control beside the Claude composer.** An icon-only,
  per-mode-coloured button opens a menu of the safe modes (default ·
  accept-edits · plan); `bypass` shows disabled. The status-bar mode is now a
  passive colour-coded indicator — switching lives in the control and
  `Ctrl/Cmd+M`. (T-275)
- **Clickable T/D/Q/R cross-refs in the Claude conversation.** Bare ticket and
  governance references (`T-281`, `D-77`, `Q-5`, `R-2`) in rendered messages are
  now links that open the record in its context-pane reader — tickets for `T-`,
  decisions for `D`/`Q`/`R`. Refs inside code stay literal. (T-279)
- A Zed-style **application menu bar** in the hat — **File / View / Help**
  menus built from custom widgets (no native menu, D-7), populated from the
  command registry with inline keybindings. Full keyboard nav (`Alt`+mnemonic,
  arrows, Enter, Esc). Help → About shows version + bundled licenses. `Ctrl+O`
  and `Ctrl+Shift+N` are now real keybindings. (T-48)
- The sidebar/dock **filter boxes are now CLI-addressable** (D-6 parity): `clide
  ui filter <address> <text>` drives a pane's filter as typing would, and `clide
  ui filter <address>` reads it back. Addresses are box ids from `clide pane
  list` (e.g. `decisions.panel`, `files.tree`). Routed through the MessageBus, so
  a click and the CLI behave identically. (T-270)
- Click an inline image card to open it in a full-screen **lightbox** — zoom
  (scroll/pinch), pan, double-click to reset, `Esc`/backdrop to dismiss — since
  the cards are often too small to read. `clide image show <path> --fullscreen`
  opens straight into it. The lightbox is a reusable `ClideLightbox` primitive.
  (T-252)
- A bottom **output dock**: toggle it from a status-bar widget (or `⌘J`/`Ctrl+J`)
  to see logs (Output) and diagnostics (Problems) as tabs — filterable by
  source/level/text, auto-scrolling. The status widget doubles as a health
  badge (green `✓` clean, `⚠`/`✕` counts otherwise) and replaces the old
  app-status item; Problems moved here from the sidebar. (T-54, D-87)
- External MCP clients (Cursor, Windsurf, Copilot, …) can now drive clide: the
  MCP server exposes the full `mcp__clide__*` tool surface, generated from the
  command registry that already feeds the CLI + palette (D-86), with a
  per-command opt-out. The two `/ide` tools remain stubs. (T-225)
- `clide events --since <cursor> [--filter X]` reads events after a cursor and
  returns them plus a next-cursor — the pull-based complement to the
  `tail --events` stream, made for agent poll loops. Reports `gap: true` when
  the cursor has aged out of the in-memory ring (D-85). (T-223)
- "Install 'clide' command in PATH" command (`clide.installCli`) copies the
  bundled C client to `~/.local/bin`, VS Code style. On launch clide warns when
  `clide` is missing from PATH or points at the GUI bundle instead of the CLI
  client. (T-212)
- `clide ui open diff <path>` reveals the diff in a split above the Claude
  conversation, scrolls to that file and highlights its header — the
  diff-panel arm of `ui open`. Workspace tabs other than Claude/editor now
  reveal alongside the conversation with a close affordance (T-233).
- Image cards in the Claude conversation log: `clide image show <path>
  [--caption …]` renders an image inline (PNG/JPG/JPEG/GIF/WebP/BMP),
  clide-owned and display-only (D-78). The path is resolved workspace-relative
  and must exist; the verb registers in the dispatcher so it shows up in `clide
  capabilities`. (T-249)
- `clide capabilities` lists the live command surface as JSON (every verb with
  its subsystem + argument schema), reflected from the dispatcher so it never
  drifts. A new `/clide` skill points Claude at it for discovery. (T-248)
- Toast notifications for operation feedback: non-modal cards slide in
  bottom-right, auto-dismiss (errors linger), stack, and are manually
  dismissable, with success/warning/error/info severities. Components raise
  them by publishing to the kernel MessageBus — git push/pull show the first
  ones. (T-50)
- `clide ui toast "message" [--severity …] [--duration MS]` raises a toast in
  the live GUI from the CLI — so an agent or script can surface "done/failed"
  on your screen. The drive-half complement to the toast system. (T-245)
- Claude pane folds runs of tool calls/results into a collapsible "activity
  card" so prose isn't buried: collapsed by default with a live one-line ticker
  + step count, click/Enter to expand. Claude prose, user messages, and failed
  results stay first-class; diffs and thinking stay visible at the default
  level. (T-230)
- Theme switcher in the status bar: a far-right control showing the current
  theme that opens a popover to switch live — click or keyboard (arrows/Enter,
  Esc to dismiss). The `theme.pick` palette command is unchanged. (T-234)
- Catppuccin Mocha theme, plus a high-contrast `catppuccin-mocha-hc` sibling,
  added to the bundled themes — switchable from the theme picker. Faithful to
  the official palette (D-69). (T-82)
- `clide ui open <reader> <id|path>` opens a doc in a GUI reader from the CLI —
  `tickets`/`decisions` by id, `markdown` by path — so an agent can surface what
  it's looking at on your screen. The drive-half complement to `clide status`. (T-231)
- Cycle Claude's permission mode from the primary pane: Ctrl/Cmd+M while the
  composer is focused, a clickable mode badge in the status line, or the
  "Claude: Cycle permission mode" palette command — steps default → accept-edits
  → plan (bypass stays behind the cockpit's confirm). (T-226)
- `clide status` — a one-shot orientation snapshot for agents: workspace, git
  summary, active editor buffer + selection, viewed reader docs, the live panes
  the user sees, and the layout. Previously an unknown command (exit 3). (T-221)
- `clide pane list` now reflects the live GUI tabs the user sees (Claude, Files,
  Editor, viewers) alongside PTY panes — each with a stable id, slot, title, and
  active/visible state — by snapshotting the kernel panel layout at request time.
  Restores the D-6 "agent sees what the user sees" half of parity. (T-219, D-83)
- Click empty Claude-pane area to focus the composer: a tap on conversation
  dead space lands the cursor in the input. Message controls and transcript
  text-selection are unaffected, and it stays inert while a prompt occupies the
  interaction zone. (T-227)
- Claude composer prompt history (Claude-CLI-style): Up recalls previously-sent
  prompts once the caret reaches the first line, Down steps back to newer ones
  and restores your in-progress draft past the newest. Per session. (T-163)
- clide-hosted Claude sessions are now bootstrapped to drive the IDE: each
  spawned session gets `CLIDE_SOCK`/`CLIDE_WORKSPACE` in its env and `clide` on
  its PATH, a system-prompt note telling it it is inside clide and how to use
  `clide …`, and a `Bash(clide:*)` allow rule so those calls aren't prompted.
  Applies to primary, secondary, fork, and teammate sessions. (T-214, D-83)
- The `clide` CLI now ships on PATH: `make build` and `make install` compile
  the C client by default, and `make install` places it at `~/.local/bin/clide`
  on Linux and macOS (the GUI launches via its desktop entry). Previously no
  build produced the client and `install` symlinked the GUI runner. (T-209)
- Vim keymap preset: a modal editor (normal/insert/visual) with hjkl/w/b/e
  motions, dd/dw/x/D/yy/p/cc/cw edits, counts (`5j`), visual-range d/y/c, and
  a status-bar mode indicator. Switch presets from the palette (`Keymap: Vim`
  / `Keymap: Default`). Built on a new keymap key-sequence layer (D-82). (T-65)
- Search-and-replace across the workspace: enter a replacement in the search
  panel to preview each rewritten line, then Replace all (regex capture groups
  supported). Guarded by a clean-git-tree gate — git is the undo — and a
  confirmation. New `search.replace` command (preview + apply). (T-53)
- Find-in-files sidebar panel (Ctrl/Cmd+Shift+F): search the workspace with
  regex and case toggles plus include/exclude globs; results stream in grouped
  by file and clicking a match opens the editor at that line. (T-52)
- Workspace content-search engine with `search.grep` / `search.cancel` commands:
  a pure-Dart, isolate-parallel grep (literal or regex, case + include/exclude
  glob filters) that streams matches and honours the `ignore_files:` chain. The
  engine is in-process — no ripgrep dependency (D-79). (T-52)
- `editor.open` accepts an optional 1-based `line` to position the initial
  selection on open (backs find-in-files click-to-line). (T-52)
- Quick-open file finder (Ctrl/Cmd+P): a fuzzy file picker overlay over the
  whole workspace, separate from the command palette. Empty query lists recent
  files; Enter opens `.md` in the markdown reader and other files in the editor.
  (T-51)
- Workspace ignore now follows the `ignore_files:` list in `.pql/config.yaml`
  (ordered, later-wins, per D-4) instead of a hardcoded `.gitignore` +
  `.clideignore` pair — the single ignore knob clide owns. (T-52)
- `files.walk` command — a recursive, ignore-pruned, capped flat file listing
  of the workspace, backing quick-open and search. (T-51, T-52)
- Sidebar readers (markdown, decision, ticket) gain chrome: a pin/unpin toggle
  before the title (separate from navigation), plus a right-hand navigator
  (back, forward, jump-to-pin) and edit pencil. The ticket reader also joins the
  shared retained nav. (T-189, T-190, T-191, T-198, T-199)

### Changed

- **Every tool use is now a collapsible card** on one `ClideCollapserCard`
  primitive — activity / edit / sub-agent runs and each tool call (single = a
  one-item list). The collapsed ticker shows the label + echoed last line + a
  fixed-width count; the status tick hugs the right edge, the chevron the left;
  `color` drives the border + label. (T-305)
- The Claude composer's **slash typeahead**, the team-chat **@-mention** list,
  and the status-bar **theme switcher** now ride the shared
  `ClideAnchoredOverlay` + `ClideMenu` popover primitive, alongside the menu
  bar. The @-mention list gains full keyboard nav (arrows/Enter), and both
  typeaheads narrow live as you type. (T-286, D-88)
- Ticket cards now show parentage as a small **tree** — the parent as a muted,
  clickable breadcrumb above and the card's own ticket **bold** under a `└`
  connector — instead of the ambiguous inline `T-1 ← T-9` arrow. (T-281)
- The in-flight **turn indicator** ("Pondering…") now renders in Claude's
  coral-orange brand accent instead of muted grey. (T-273)
- A **sub-agent's prose and thinking** are now attributed to the **`agent`** (a
  muted stripe), not the main-thread coral **`claude`** — so a sub-agent's
  output is no longer presented as if the main Claude said it. Main-thread items
  are unchanged. (T-265)
- A **sub-agent's whole run** — prose, thinking, and tool calls — now nests in
  an **`agent run` holder under its Agent card** instead of spilling loose into
  the main thread. It attaches via `parentUuid` (correct for parallel agents),
  and the redundant returned-result is no longer shown twice. (T-264)
- The folded **activity card** now reads as one **container wrapping its
  sub-cards**, and you can collapse it by clicking anywhere on the holder's own
  background — not a top header that scrolls out of reach as a run streams. Taps
  on a sub-card (and its copy button) still hit that card; a focusable caret
  keeps the control keyboard/AT reachable. (T-266)
- A **sub-agent prompt** is no longer mislabelled as your input: a sidechain
  prompt now reads as a muted **`agent prompt`** (never the blue `you`) and folds
  into its **Agent/Task card**, collapsed by default. The prompt attaches to the
  right card via `parentUuid`, so parallel agents in one turn stay correctly
  paired. The sub-agent's work stays visible after the call. (T-263)
- A successful tool call now renders as **one merged card** instead of a
  separate call + result pair: a green check sits at the header's right edge and
  the output folds in as a colorized code block (Read → file grammar, Bash →
  shell) revealed on expand. Failures keep their prominent red card, now with a
  matching header mark. (T-262)
- The in-flight turn indicator now feels alive: instead of a static gray
  `running…`, it shows a rotating curated status verb (`Pondering…`,
  `Conjuring…`, …) with an animated ellipsis. Respects reduced-motion (static
  verb) and keeps a stable a11y label. (T-255)
- The `clide` CLI launch check now distinguishes a dev-tree build
  (`native/<plat>/clide`) from a packaged install — surfaced as an info note on
  a checkout rather than treated as a clean install or prompting a reinstall.
  (T-256)
- Command palette (⌘⇧P) now fuzzy-matches command titles (subsequence, not
  just substring) and floats recently-used commands to the top. (T-23)
- ⌘K now opens a **Settings** modal instead of a theme-only picker. Its first
  (currently only) section is Appearance — base themes, sorted, with a High
  contrast toggle for `-hc` siblings — matching the status-bar switcher. (T-238)
- The pql search panel merged into the Search tab, which now has modes: Find
  (content grep), Vault (pql ranked search), Query (PQL DSL), and Markdown (the
  synced file listing). The standalone pql sidebar tab is gone; Backlinks stays
  in the context panel. (T-201)

### Fixed

- **Tab strips get a hairline of breathing room.** The tab strip (Claude session
  tabs, slot tabs) butted flush against the chrome above it, reading as cramped;
  it now sits 1px below, the pane surface showing through the gap. (T-324)
- **Re-showing an image after it changes on disk now refreshes.** Image cards,
  thumbnails, the lightbox, and `clide image show` keyed Flutter's image cache by
  path alone, so overwriting a file in place showed the stale render. A new
  `ClideFileImage` folds mtime + size into the key, so an in-place change
  re-decodes. (T-312)
- **The `context` / `thinking` / agent-prompt blocks are now carded like the
  rest.** These muted meta blocks rendered frameless, reading as unfinished
  `> context …` rows between the framed tool cards. They now sit in a bordered
  card — still muted, collapsed by default, with a first-line summary and a left
  chevron. (T-306)
- **Numpad digits now pick permission/question options too.** The prompt card's
  number-key shortcuts only matched the top number row; numpad `1`-`9` now map to
  the same 1-9 selection, so the keypad works for Allow/Deny and question options.
  The note-field guard still lets digits type normally when a note is focused.
  (T-310)
- **The composer no longer jams against the window bottom when the status bar
  is hidden.** With the bar gone, the bottom-most pane content used to run flush
  into the window's resize-drag edge; the layout now reserves that edge so the
  input box bottom-anchors consistently whether or not the status bar shows.
  (T-298)
- **Open Workspace no longer spews `GLib-GIO-CRITICAL` to the console.** The
  folder picker now uses the portal-backed `GtkFileChooserNative` (out-of-process
  in sandboxed/Flatpak builds), and a narrowly-scoped GLib log filter swallows the
  known-benign `g_file_info_get_size … without standard::size` message GTK's
  file-chooser sidebar emits internally on every pick — every other GLib-GIO
  critical still surfaces. (T-287)
- **The conversation re-anchors when the input area resizes.** Opening a
  permission prompt or AskUserQuestion (which grows the bottom zone, D-78) no
  longer hides the last message behind it — when pinned to the tail, the view
  re-scrolls to keep it visible; a scrolled-up reader is left undisturbed.
  (T-297)
- **The chosen theme now persists across restarts**, per repo. Picking a theme
  (status-bar switcher or Settings) writes it to the repo's
  `.clide/settings.yaml` (and a global default), and reopening the repo restores
  it — including the high-contrast variant. A removed theme falls back to the
  default instead of resetting silently. (T-293)
- Folded activity and agent-run cards in the Claude conversation now use the
  same bottom spacing as the prose cards around them, instead of sitting
  cramped 3px below the next card. (T-282)
- The welcome screen no longer overflows on a short or narrow window — its
  content scrolls when it can't fit and stays centred when it can, and a long
  git-branch name on a recent-project row now truncates with an ellipsis. (T-273)
- Bordered conversation cards (tool / Agent calls) now use the same interior
  vertical padding (8) as the stripe cards, so a collapsed tool/Agent card no
  longer reads chunkier — taller box, more trailing space — than its
  neighbours in the conversation log. (T-282)
- Conversation cards no longer **mis-associate their state** when the message
  list reshapes as a tool result streams in. The list items now carry stable
  per-item keys, so a card you expanded (or its hover/cluster state) stays
  pinned to its own message instead of jumping to a neighbour when a read/write
  completes and folds its result in. (T-285)
- The status-bar footer marquee now **honours reduced motion**: when the OS
  reduce-motion setting (`MediaQuery.disableAnimations`) is on, a long status
  line no longer scrolls — it renders statically (clipped) — matching the turn
  indicator, which already obeyed the flag. Unifies the two animations on one
  mechanism and removes a `pumpAndSettle` hang the perpetual ticker caused.
  (T-284)
- Switching the workspace in place (Open Project/Folder) now rebinds the Claude
  pane to the new repo's session instead of keeping the previous repo's
  conversation, and drops the old repo's secondary tabs. Separate windows were
  already isolated — this only affected reusing one window for another repo.
  (T-269)
- `/clear` in the primary Claude pane now clears that session **in place** —
  it empties the pane's deterministic, restart-stable session instead of
  starting a throwaway random one. Previously a cleared primary was orphaned:
  the next launch re-resolved to the deterministic id and resumed the
  pre-clear conversation, so the clear silently didn't stick. Secondary panes
  keep their fresh-session behaviour. (T-268)
- In Vim mode, Esc in insert/visual mode returns to normal mode instead of
  closing the editor. The global "exit focus / close editor" Esc binding now
  stands down while Vim is in insert or visual mode. (T-257)
- The permission-mode badge and Ctrl/Cmd+M now visibly cycle the mode in the
  status line. The mode was changed on the session but never reflected back, so
  both looked dead. (T-250)
- Recent-project rows (welcome screen and the project switcher) now ellipsize a
  long path instead of overflowing the row — a long repo path no longer spills
  past the edge. (T-122)
- CLI commands that take arguments now work: `clide editor open <path>`,
  `clide files read <path>`, `clide pane focus <id>` / `resize <id> <c> <r>`,
  etc. now bind positional/flag argv to the handler's named args (they
  previously returned "X is required" from the CLI). (T-232)
- The Claude composer no longer loses a half-typed message when the UI changes
  under it — e.g. a permission prompt taking the composer's place. The draft
  (text and caret) is kept per session and restored when the composer returns.
  (T-228)
- File watcher no longer emits change events for files inside ignored
  directories (`.dart_tool/`, `build/`, etc.): it now checks ancestor dirs,
  not just the leaf. Most visible on macOS, where FSEvents delivers the nested
  creates that inotify usually drops.
- The Claude sidebar's Activity / Team / Config sub-tabs are now keyboard-
  activatable: they were pointer-only (raw `GestureDetector`), so Tab traversal
  skipped them and Enter/Space did nothing. They now use `ClideTappable`
  (focusable, Enter/Space → activate) and carry button + selected semantics.
  (T-182)
- The default keymap is no longer silently disabled at startup: `default.yaml`
  bound Tab/Shift+Tab to undefined `focus.next`/`focus.previous` intents, which
  made the loader drop the entire preset (palette, quick-open, find-in-files,
  zoom). Those are now real focus-traversal intents, and a test parses every
  shipped preset so a typo fails CI instead. (T-204)
- Opening the editor split no longer floods exceptions: the resize handle's
  slider semantics now carry increased/decreased values, and the Claude pane
  keeps a stable identity across the reparent so its text-selection region
  isn't torn down mid-update. (T-203)
- A `rate_limit_event` whose `resetsAt` is a numeric epoch no longer crashes the
  Claude session — it was cast as a string. (T-202)
- Filter/search inputs show their hint as visible placeholder text, and the
  search-glass icon is now optional — so the Search tab's Find fields (search,
  replace, include/exclude globs) are distinguishable instead of four identical
  empty boxes. (T-201)
- The sidebar icon rail no longer overflows when there are more tabs than fit:
  it centers the icons when they fit and scrolls horizontally otherwise. (T-200)
- The editor pane now opens over the Claude pane when a file is opened — the
  reader's edit pencil, a file-tree click, or a decision's edit all reveal the
  editor tab now (it was contributed but never activated). (T-197)
- Clicking a decision opens it on the first click. The right-pane readers
  (markdown + decisions) now share a retained back/forward nav history that
  survives the tab switch, so the selection that reveals a reader is no longer
  lost before the widget subscribes; back/forward re-emit through that history.
  (T-196)
- The markdown reader can now open user-scope Claude config files (skills /
  agents / commands under `~/.claude`), not just repo-local ones. `files.read`
  gained a read allow-list covering the workspace plus the trusted Claude config
  roots; writes stay repo-confined and off-root paths are still rejected. (T-195,
  D-80)
- The markdown reader opens files given an absolute path again (e.g. a skill's
  `SKILL.md` from the Claude Config tab). `resolveUnderRoot` no longer doubles an
  absolute path onto the workspace root; absolute-under-root resolves, while
  paths outside the root are still rejected. (T-194)
- The composer slash typeahead now lists clide-owned commands — `/resume` and
  `/fork` (and `/clear`) surface even though the CLI probe doesn't advertise
  them, unioned onto whatever command source the composer uses. (T-162)
- Clicking a decision opens it in the decision reader again — the decisions
  extension no longer tears down and re-contributes its panel tab on every
  selection; it activates a static tab and reveals the panel like the ticket
  panel. (T-188)
- Clicking a markdown file opens it in the right-side markdown reader again —
  the files panel, the Claude Config tab, and wiki `.md` links now publish to
  the reader instead of the editor. (T-187)
- A forked Claude session now reports its real session id (captured from the
  branch's `init` event) instead of the placeholder it was spawned with, so a
  fork can itself be resumed/forked. (T-185)
- Claude replies now stream token-by-token. The `--include-partial-messages`
  output arrives as `stream_event` deltas (not `assistant`+`partial:true` as
  first assumed), so the previous handler never fired; the session now reads the
  real shape, growing a placeholder in place and finalizing it from the matching
  `assistant` event. (T-184)
- Claude conversation card actions (copy + custom) are now keyboard-focusable
  and always reachable — revealed on hover or focus, activatable by Tab +
  Enter/Space, with Semantics labels for assistive tech (T-174).
- Status bar no longer overflows when the focused-pane context line is long
  — the in-pane slot now takes a flexible share of the bar and marquee-scrolls
  within it instead of pushing the row past its width.
- Write/Edit permission cards no longer print the file path twice — the
  description line is suppressed when it just repeats `file_path`.
- Resumed Claude session no longer starts with an empty pane — `claude
  --resume` carries Claude's prior context but emits no past turns over
  stream-json, so the orchestrator now seeds the conversation by reading
  the tail (up to 256 KB) of the transcript JSONL on disk.

### Changed

- Claude conversation tool cards are now typed — Edit/Write render a diff,
  Bash shows the command and its output, Read/Grep show the file/query, and
  each tool result pairs back to its call to render the diff or error in
  place instead of an indented JSON dump (T-168).
- Claude status line reflects live session state from stream-json events —
  model, permission mode, context size, and turn cost come straight off the
  init/result events rather than a separate config probe (T-168).
- Claude session persistence now rides on `claude --resume` instead of tmux
  (T-167, amends D-41). A restart resumes the primary session, `/clear`
  starts a fresh one, and `/resume` reopens a picked session — all without
  tmux.
- Permission prompt cards render the tool input in the shape that fits the
  tool — Bash shows the command as a shell code block (with a footer for
  `run_in_background` / `timeout`), Write shows the path plus the content
  highlighted from its extension, Edit shows the path plus before/after
  blocks. Unknown tools fall back to the indented-JSON dump.
- Claude meta sidebar is now tabbed — Activity / Team / Config (T-182).
  Activity shows usage stats plus the primary session's live runtime; Team
  holds the roster and auto-fronts when a team spawns; Config shows the
  environment settings table. Activity and Config share one table geometry so
  switching doesn't jump.

### Removed

- tmux is no longer used for Claude sessions (T-167) — the tmux session
  lifecycle and the tmux-polling team observer are gone, replaced by the
  managed-session orchestrator. tmux is still used for the general-purpose
  terminal pane.

### Added

- Claude team cockpit — the meta sidebar's Team tab gains live controls for
  clide-managed agents: show/hide, mute, close, and inject-a-message per
  roster row, plus a live shared task list with reassign. Each action has a
  matching `clide` command (D-6 parity). (T-171, D-77)
- Per-agent permission-mode badge in the cockpit roster — click cycles the
  safe trio default → acceptEdits → plan and sends `set_permission_mode` to
  that session; Shift-click reaches `bypassPermissions` behind a confirm.
  The badge reflects the live mode. (T-181, D-77)
- Fork a Claude conversation into a new pane — `/fork` (or a roster Fork
  button / `clide.agent.fork`) branches a session via `--resume … --fork-session`,
  opening an independent continuation that leaves the original untouched. (T-172, D-77)
- Team chat inbox — broker traffic renders as a chat timeline (colour-coded
  sender chips), in a compact cockpit widget that pops out to a full pane. The
  user is a first-class participant: post with `@name` routing (or broadcast),
  with an interrupt tickbox that cancels the target's turn before delivery. (T-180, D-77)
- Config sidebar tab — a pinned settings table plus expandable, never-truncated
  sections for skills / agents / commands / hooks / permissions (colour-coded by
  kind) / MCP servers; file-backed entries open their `.md` in the reader. ClaudeConfig
  now also surfaces agents, hooks, MCP servers, and file paths. (T-183, D-76)
- Team coordination broker (T-170, D-77) — clide hosts an in-process MCP
  server (`clide-team`) for managed sessions over the stream-json control
  channel, giving agents tools to message each other, broadcast, see the
  roster, read an inbox, and share a task list. Each agent's role and the
  roster are injected into its system prompt.
- Interrupt a running Claude turn (D-78) — Escape in the composer (when no
  typeahead is open) or a Stop button shown while busy cancels the current
  turn over the stream-json control channel. The escape hatch from a
  runaway turn.
- Native permission & AskUserQuestion prompts (T-166, T-175, T-176, T-179,
  D-78) — the composer becomes a prompt: Allow / Allow-and-don't-ask-again /
  Deny showing the command, or an AskUserQuestion option picker (single or
  stepped, with "Other" free-text and per-choice notes). Closes the tmux
  prompt gap.
- Conversation message cards (T-173) — every turn in the Claude pane now
  renders through one card template with a copy button on hover and a
  collapse/expand caret for tool calls, results, and thinking.
- Collapsed-by-default tool cards (T-177) — multi-line tool calls and
  results start collapsed behind a one-line summary; one-line output stays
  inline so a caret never hides a single line.
- Prompted tool calls are quieter in the log (T-179) — a permission request
  shows the command in the prompt, not as a raw tool-use card; once decided
  it collapses to a one-line summary with a green (approved) or red (denied)
  border, and the result is kept. AskUserQuestion's tool-use + result are
  replaced by the logged answer.
- Harness-injected messages are de-emphasized (T-178) — skill loads,
  slash-command expansions, and system reminders (Claude's `isSynthetic`
  messages) render as a muted, collapsed "context" card instead of a blue
  "you" message, since they weren't typed by the user.
- Claude meta sidebar (T-141, T-157) — an always-pickable left-panel tab
  showing Claude activity (the latest day's messages/sessions/tool-calls
  plus lifetime totals, from `stats-cache.json`) and, when a tmux team is
  running, a roster of its members (colour · name · agent type · model)
  with each member's live permission-mode and context once it's active.
- Claude session storage view (T-148) — the `claude.session-storage`
  command opens a modal listing the workspace's session transcripts with
  their on-disk sizes and a total, each removable with a two-click
  confirm. User-driven only; clide never deletes transcripts on its own.
- Slash-command typeahead in the Claude composer (T-152) — typing `/`
  (anywhere in the message, not just at the start) pops a list of
  matching commands and skills sourced from the Claude environment;
  arrow keys move, Enter/Tab completes, Escape dismisses.
- Claude environment service (T-151) — clide reads skills, commands,
  settings, and permissions from `~/.claude` and the repo's `.claude`
  (layered), and caches the slash-command list per claude version. Backs
  the typeahead and command-aware send.
- Per-session status in the bottom status bar (T-145, T-150, T-154) — the
  active Claude pane shows its model · permission mode (accept-edits /
  plan / …) · context-token count · configured skills count, swapping to
  the focused pane on tab switch and clearing on blur. Long status text
  marquee-scrolls within the slot.
- tmux agent teams surface as native teammate tiles (T-139, T-140) —
  when a Claude team is running, each teammate shows as a live
  conversation tile beside the lead in a grid that wraps 1→2→3 columns,
  with a resizable split. Identity and lifecycle come from the team
  config; per-teammate content streams over the MessageBus.
- Native composer in the Claude pane (T-138) — type below the
  conversation and press Enter to send (Shift+Enter for a newline).
  Submits via the tmux server (bracketed paste + Enter), so input
  reaches Claude even when no tmux client is attached; multi-line goes
  as one message.
- File and image paste in the composer (T-138, T-142) — Ctrl/Cmd+V of a
  copied file or clipboard image adds a removable chip (image thumbnail
  or file icon) above the input; on send its `@path` is appended to the
  message. Plain text pastes inline. Backed by a native `clide/clipboard`
  channel (GTK + macOS).
- Claude pane renders natively from the transcript (T-137, D-75) — the
  conversation shows as native cards (user / assistant markdown /
  thinking / tool-use / result) instead of a terminal, with text
  selection + copy across cards. Claude still runs in tmux; the terminal
  builtin stays for general use.
- Multi-file editor tabs — the editor pane now shows one tab per open
  buffer (filename + a dot when unsaved) via the shared tab strip;
  opening a second file no longer replaces the first. Click a tab to
  switch, × to close. Backed by the daemon's existing multi-buffer
  model.
- Typed IPC command-schema framework (T-119/T-120, D-74) — commands
  register an argument schema beside their handler; the dispatcher
  normalises argv into named args, coerces types, and validates
  (charset, leading-dash, ranges, caps) before the handler runs.
- `clide panel resize <slot>` CLI verb (T-119) — set an absolute size
  with `--to` or nudge with `--by`; `editor` targets the split ratio.
  Completes user/Claude parity (D-6) with T-111's keyboard resize.
- Unix-domain IPC socket server in the Flutter app (T-99 / T-124).
  Per-workspace path (D-70: `$XDG_RUNTIME_DIR/clide/<hash>.sock` on
  Linux, `~/Library/Caches/clide/<hash>.sock` on macOS). 0600 socket
  + 0700 parent (D-71). Multi-connection accept loop with serial
  dispatch through `DaemonDispatcher` (D-72). Foundation for the C
  `clide` client (T-126) and MCP (T-130). No client yet — testable
  via `socat - UNIX-CONNECT:$SOCK`.
- argv→IpcRequest translator (`lib/src/cli/argv_to_request.dart`) —
  parses `clide SUBSYSTEM VERB [pos...] [--flag] [-- passthrough]` and
  the umbrella commands (`status`, `tail`, `version`, `ping`) per D-6
  into the wire envelope. Pure Dart; lets the C client (T-126) stay a
  dumb pipe (T-99 / T-125).
- `DaemonClient.reconnectAt(newPath)` — swap an active client onto a
  different socket without restart (project switch in T-127).
- Event streaming over the IPC socket (T-99 / T-129) — `clide tail
  --events [--filter X]` opens a long-lived subscription, replays up
  to 16 recent matching events per subsystem (D-6), and streams new
  ones as JSON lines. C client loops on `data.streaming` ack. Slow /
  broken subscribers drop themselves without blocking the bus.
- MCP server over HTTP+SSE (T-99 / T-130, per D-68 / D-73). Localhost
  HTTP listener advertises via `$HOME/.claude/ide/<pid>.lock` so
  Claude Code's `/ide` discovers it. JSON-RPC 2.0 with the two
  minimum `/ide` tools shipped as stubs
  (`mcp__ide__getDiagnostics`, `mcp__ide__executeCode`); real
  implementations follow.
- C `clide` shell client at `native/clide-cli/clide.c`. Walks CWD up
  to the git root, hashes to the per-workspace socket (D-70), ships
  argv. `make clide-cli` builds it; on PATH, `clide status` works
  from any clide-workspace directory once the app is up (T-99,
  T-126).
- Startup project picker — clide now opens to the welcome screen by
  default instead of auto-opening the last project. A per-row
  "always open this project on launch" checkbox in welcome's RECENT
  list sets a sticky-startup flag; if exactly one project has it,
  that one opens directly. Two or more, or none ⇒ picker (T-115).
- CONTRIBUTING.md "Running clide from the shell" section — documents
  the shell verbs, exit-code contract per D-68, and Claude Code
  `/ide` MCP discovery via `~/.claude/ide/<pid>.lock` (T-131).

### Changed

- The empty Claude pane now shows a native startup banner — clide logo,
  session role, workspace, and tmux status — instead of a bare "Waiting
  for Claude…" (T-149).
- User and Claude turns in the conversation now render as distinct
  accent-striped cards over a filled background — your prompts in the
  theme focus colour, Claude's replies in Claude's brand orange
  (T-143, T-144).
- Claude conversation content now flows through the kernel MessageBus —
  a reader tails the transcript and publishes items; the pane subscribes.
  Decouples reading from rendering so the upcoming team panels can show
  one lead plus a tile per teammate (T-137).
- In-process IPC dispatch swapped for socket loopback (T-127). The
  Flutter UI's `DaemonClient` now talks to its own `IpcServer` over
  the same per-workspace Unix socket the C `clide` client uses — one
  transport, one contract.
- D-56 / D-68 amended with implementation notes — both decisions now
  link out to T-99's eight slices (T-124–T-131) and the D-70/71/72/73
  records they spawned (T-131).

### Deprecated

### Removed

- `lib/kernel/src/ipc/in_process.dart` (`InProcessClient`) — replaced
  by the socket-loopback `DaemonClient` (T-127).
- `lib/kernel/src/backend.dart`, `lib/kernel/src/backend_entry.dart`,
  `lib/kernel/src/ipc/isolate_client.dart` — the third unused IPC
  path (a backend-isolate model that was never wired through). Only
  the socket model survives now (T-128).

### Fixed

- Claude pane is no longer dead-on-arrival when resuming a session (T-161).
  The primary pane (and `/resume`) relaunched Claude with `--session-id
  <existing-id>`, which Claude rejects as "already in use" — so the pane had
  no live backend and typed input vanished. clide now uses `--resume` for an
  existing session and `--session-id` only for a brand-new one.
- Claude pane no longer floods the console with "markNeedsBuild called
  during build" (T-159) — a focused pane surfacing its status-bar widget
  now defers the notification out of the build phase instead of rebuilding
  the status item mid-build.
- The git / tickets / decisions / pql / problems tabs no longer log
  `i18n: namespace not registered` on boot (T-155). An extension's
  localized tab title is now loaded automatically on activation, and the
  five missing catalogs were added.
- Slash commands sent from the Claude composer now actually run (T-153).
  Recognised commands are delivered as typed input so Claude's TUI parses
  them; other input (and stray leading slashes like a `/tmp` path) stays
  bracketed-pasted as literal text.
- `/clear` is now handled by clide — it resets the Claude pane to a fresh,
  empty session — instead of being forwarded to Claude Code, whose `/clear`
  forked to a new session clide couldn't follow and left the pane
  unresponsive (T-156).
- `/resume` is now handled by clide too (T-156): it opens a picker of the
  workspace's past sessions — each labelled by its first … last user message
  and when it was last active — and re-binds the pane to the chosen one,
  instead of forwarding Claude Code's session-forking `/resume`.
- Claude secondary panes no longer flash a false "session exited" while
  the session is alive (a transient tmux client exit is now verified
  against the live session), and the tab and banner agree on the label
  ("session N") (T-149).
- Claude pane no longer gets stuck on "Waiting for Claude…" when its
  session can't be bound (T-147) — e.g. a session left over from before
  session-id binding, or a fresh machine. It now retires that stale
  clide session and starts a clean one. Only clide's own `-L clide`
  sessions are touched (never a terminal Claude, never transcript files).
- Secondary Claude tabs showed the primary's conversation instead of
  their own (T-146). Each pane now binds to its own session via
  `claude --session-id`, so concurrent sessions in one workspace stop
  colliding on the newest transcript — the primary keeps a stable id
  (resumes), secondaries get a fresh one (clean session).
- Claude pane no longer freezes the app on open — the transcript reader
  caps its initial read to the recent tail, parses off the UI isolate,
  and coalesces view notifications into one rebuild per burst (T-137).
- Daemon-not-connected on startup — panels and the Claude pane raced
  the socket loopback. Requests now wait briefly for an in-flight
  connection, the server isn't restarted for the same workspace, and
  the client connects once instead of twice.

### Security

## [2.1.0] — 2026-05-18

### Added

- Contrast gate split — baseline `canonicalPairs` every theme passes,
  strict `extendedPairs` (muted/status/syntax/focus-border) gated to
  `-hc` / `-cb` variants. Ships `clide-hc`, `midnight-hc`, `paper-hc`,
  `terminal-hc` siblings of the named themes (D-69, T-114, T-118).
- Pre-push coverage gate — `make push-check` runs `ci/coverage_gate.sh`,
  which fails if total line coverage drops below `coverage_floor:` in
  `pubspec.yaml`. Floor ratchets up only; target 95% (D-66).
- Pre-push changelog gate — `ci/changelog_gate.sh` fails on any
  `## [Unreleased]` bullet over 60 words. Enforces the Keep-a-Changelog
  conciseness rule in the git-commit skill.
- Keymap layer (`KeymapService`) — typed Intents, YAML presets,
  VS-Code-style when-clauses, layered preset → user file → settings
  overlay. Default preset ships; vim/vscode/jetbrains unblocked
  (T-117, supersedes T-110).
- Keyboard operability — `ClideTappable` is now Tab-focusable with a
  focus ring and Enter/Space activation; `ClidePalette` adds arrow
  nav, Escape dismiss, and selection highlight (T-100).
- Panel-to-panel focus traversal — each `SlotHost` wraps in a
  `FocusScope` + `FocusTraversalGroup`; `F6` / `Shift+F6` cycle
  sidebar → workspace → context. `FocusTracker` integrates with
  Flutter focus rather than paralleling it (T-105).
- Event-driven test waits — PTY + watcher tests await stream events
  instead of fixed sleeps; `onTimeout` callbacks now `fail()` loudly
  with diagnostic context. `RecordingEventSink` exposes a broadcast
  stream for the same pattern (T-108).
- Code-quality cleanups — `TreeSitterLib` exposes a last-error
  diagnostic instead of swallowing dlopen failures; `ExtensionManager`
  surfaces a `failedExtensions` map for UI degradation; PTY constants
  consolidated in `libc.dart` + `PosixErrno`; `test_app.dart` gated
  behind `kDebugMode` (T-112).
- Test sweep — `keybindings`, `toolchain_paths`, and several
  `widgets/src/` primitives (tooltip, palette, multitab, markdown).
- `tree_sitter_service` sweep — fake-FFI + real-library smoke,
  17% → 96%. Crosses the 95% global target (T-91).
- Staged `dart doc` CI job — generates and uploads an HTML API
  reference for the public `lib/` surface. The step wraps
  `dart doc --validate-links` and grep-fails the build on any warning.
  Inert with the rest of the workflow until Gitea Actions activates.
- Mouse wheel scrolling in Claude pane — converts scroll events to
  PgUp/PgDown so TUI apps scroll their history naturally.
- Welcome screen Tips card — six common keybindings shown below the
  START / RECENT row when the viewport is tall enough.
- `MultitabPane` widget + `MultitabController` for panes that host
  N runtime tab instances of the same kind. Generic over a payload
  type, supports pinned/non-closeable tabs, drag-reorder, close × on
  hover, and an optional `+` add button.
- `MultitabPane.keepAlive` mode — entry bodies stay mounted via
  IndexedStack so switching tabs preserves their state (PTY
  connections, scroll position, etc.).
- `CONTRIBUTING.md` — human-addressed contributor guide covering
  clone / build / test / DQR / tickets / commit conventions. The
  `[Unreleased]` section is reorganised to one subsection per kind
  per Keep a Changelog 1.1.0 (T-109).
- `make verify` — no-tests sweep (analyze + format + decisions +
  changelog gate). For mid-edit checks; `make push-check` stays the
  full pre-push pipeline.

### Changed

- Terminal mouse wheel forwards as proper xterm wheel-button escapes
  when the inner program declares a mouse mode (?1000h / ?1002h /
  ?1003h, optionally +?1006h SGR). Falls back to PgUp/PgDown only
  when no mouse mode is active. vim mouse=a / htop / less mouse modes
  now react to the wheel (T-74).
- `lib/src/terminal/` cleaned to the project bar — commented-out
  `print()` debugging stubs stripped from `custom_text_edit.dart`,
  stale TODOs in `parser.dart` + `keytab.dart` replaced with clear
  "not implemented" notes (G2/G3 charsets, VT52 records), and the
  one `// ignore: invalid_use_of_protected_member` in
  `terminal_view.dart` gets an inline reason explaining why
  TerminalView owns its own ShortcutManager. Parser split deferred
  to T-123 (T-107).
- Window-control close-button red, white close glyph, and palette
  ambient shadow are now tokens (`windowControl.closeHover*`,
  `shadow.ambient`) instead of hard-coded hex. Light themes get a
  softer ink-tinted shadow (T-114).
- Text-zoom (Ctrl +/-/0) is now a kernel `TextZoom` service and shows
  up in the palette as `View: Zoom In/Out/Reset Zoom` (T-114).
- `make gen-build-info` bakes `lib/src/build_info.g.dart` (name,
  tagline, version, repository, commit, date) and rewrites
  `assets/licenses.yaml` `self.version:` from `pubspec.yaml` on every
  build/run/test target. Welcome banner / status line / window title
  / project switcher labels all read from those constants — one
  source of truth, no manual sync, no `--dart-define` plumbing.
  New `tagline:` field in pubspec for the short user-facing line
  (welcome subtitle, future web meta).
- Panel splitters (sidebar / context / editor-split) are tab-focusable;
  arrow keys nudge by 10 px, Shift+arrow by 50 px (2% / 10% for the
  editor split). Exposed as slider Semantics nodes so screen readers
  announce the current size. CLI verb deferred to T-99 (T-111).
- Changelog gate is binary — dropped the soft 40-word warning, kept
  the 60-word hard cap. Warnings that never blocked just normalised
  drift.
- PTY spawning uses `posix_openpt` + `posix_spawn` instead of
  `forkpty` — closes a ~5% deadlock window in the multithreaded Dart
  VM (T-96, D-5 amended). Missing exe/cwd now throw `PtyException` at
  spawn time. Drops the `libutil.so.1` dependency.
- Coverage floor ratcheted to 95% — D-66 target hit.
- `TreeSitterService` and `TreeSitterLib` accept injectable FFI + asset
  loaders for fake-driven tests; production paths unchanged.
- Tidied test imports flagged by `unnecessary_import`.
- `README.md` rewritten to match current architecture;
  `docs/initial-plan.md` bannered as historical; new
  `docs/architecture.md` describes today's shape (T-101).
- `SchedulerService._stopTicker` now awaits the in-flight isolate spawn
  before killing — closes the same race shape we fixed in PTY (T-106).
- `make push-check-full` added — runs `push-check` plus integration +
  smoke for pre-release checks. Integration tests skip the hanging
  theme_picker case until that's fixed (T-103, T-116).
- Governance bookkeeping: D-66 amended (floor at `coverage_floor:` in
  `pubspec.yaml`); `licenses.yaml` reconciled with `pubspec.yaml`;
  Q-1/Q-2/Q-3/Q-25 triaged; `.claude/skills/README.md` inventory
  added; `--no-fatal-infos` dropped from `ci/test.sh` (T-113).
- Terminal panes render bold attributes with a real bold weight —
  bundled JetBrainsMono Bold + BoldItalic registered with the
  `JetBrainsMono` family at `weight: 700`. The painter's bold
  suppression workaround is gone.
- Claude pane uses `MultitabPane` for primary + secondaries — drops
  ~100 lines of bespoke tab-strip code, gains drag-to-reorder.
- UI spacing constants live in `lib/widgets/src/spacing.dart` —
  `clideInset*` for paddings, `clideGap*` for sibling distances,
  `clideIcon*` / `clideControlHeight` for control sizes.
- Tagline reads "IDE for Claude Code CLI" everywhere (welcome
  subtitle, README, CLAUDE.md, pubspec, web manifest, CLI banner).
- Inline terminal emulator based on xterm.dart v4.0.0 — replaces the
  pub.dev dependency with owned code under `lib/src/terminal/`. Drops
  three transitive dependencies (xterm, quiver, zmodem).
- Bundle clide-specific tmux.conf for Claude pane sessions: no status
  bar, 50k scrollback, mouse on, zero escape delay, isolated socket.
- Claude pane spawns `claude` directly inside tmux with
  `CLAUDE_CODE_NO_FLICKER=1` to enable Claude's fullscreen TUI mode.
- PTY read buffer increased from 4 KB to 64 KB.
- Terminal view 2 px padding on all sides.

### Removed

- **`bin/clide.dart` + `DaemonServer`** — completing the D-56
  dissolution. The separate daemon process was dissolved on 2026-04-23
  but the entry point and socket server class were never deleted.
  Gone now, along with orphaned tests, stale i18n strings, and
  "start `clide --daemon`" error messages.
- **`ptyc/` source tree + `PtySession` + `scm_rights.dart`** — PTY
  spawning migrated to Dart FFI `forkpty()` (`NativePty`) but the old
  C helper and its Dart wiring were never cleaned up. Removed from
  toolchain resolution, `ToolCheck` gate, backend serialization,
  testmode harness, CI scripts, Makefile, and sandbox entitlements.
  D-5 amended to record the retirement.
- CI golden images (`test/goldens/goldens/ci/`) — Skia anti-aliasing
  of geometric shapes differs between macOS and Linux even with the
  Ahem font. Replaced with platform-keyed goldens (`goldens/linux/`,
  `goldens/macos/`).
- Bold JetBrains Mono font registration that prevented glyph-width
  mismatch in terminal rendering — superseded by the Bold/BoldItalic
  re-registration above.

### Fixed

- Welcome status line no longer overflows on narrow viewports —
  whole-row `FittedBox(scaleDown)` instead of fixed sibling widths.
  Inline `fontSize:` literals replaced with the typography
  constants. Version label reads `clideVersion` so the status line
  stays in sync with `pubspec.yaml` (T-116).
- Integration test `theme_picker_test.dart` no longer deadlocks —
  was `await`ing `services.commands.execute('theme.pick')` whose
  Future doesn't complete until the dialog is dismissed. Now
  fire-and-forget around `pumpAndSettle` (T-116).
- `TerminalView.onTapUp` now actually fires on primary tap — was
  wired to a dead code path (T-93). Dead `onTapUp` surface on
  `TerminalGestureHandler` / `TerminalGestureDetector` removed.
- `BufferLine.eraseRange` no longer panics when called with `end == 0`.
  Real trigger: `Terminal.eraseDisplayAbove` with the cursor at
  column 0 — common after `ESC[H\x1b[1J` (home + erase-above).
- Terminal selections no longer vanish when resizing narrower —
  reflow's tail-anchor handler left anchors detached past the
  trimmed range. Common triggers: Ctrl+A then resize, drag past a
  partially-filled line (T-92).
- `BufferLine.removeCells` / `insertCells` / `dispose` no longer skip
  anchors due to concurrent list modification during iteration —
  iteration now snapshots the list first (T-91).
- Closing a secondary Claude pane tab now kills its tmux session on
  the clide socket, honouring D-41's lifecycle. Previously
  `pane.close` only killed the ptyc-spawned tmux client.
- Cold-start reap: every clide launch kills any leftover secondary
  tmux sessions for the current repo before spawning new ones, so
  D-41's "secondary numbering resets between runs" holds.
- `claude.kill-all-sessions` command now actually kills the
  server-side tmux sessions for the repo, not just the panes.
- Terminal cell grid no longer drifts on bold text — bold rendering
  is suppressed at the painter level since synthetic bold (with no
  Bold.ttf registered) shifts glyph advance widths.
- PTY surfaces errno on `forkpty` / `write` / `ioctl` failures
  instead of swallowing. `execve` failures write a diagnostic to the
  slave before `_exit`. `NativePty.write` and `PtySession.write`
  loop on short writes; both throw `PtyException` on hard errors.
- PTY teardown order fixed — kill child first so the master fd
  returns EOF, await reader isolate exit, then close the fd.
- Reader isolate spawn errors in `NativePty` / `PtySession` are now
  surfaced via the output stream instead of silently dropped.
  `_recvFdAsync` no longer leaks the `ReceivePort` on spawn throw.
- IPC server hardening: per-request 60s timeout (configurable),
  broadcast/response write failures logged instead of swallowed,
  client dropped on response-write failure, and the stale-socket
  retry now probes for a live daemon before unlinking the socket.
- `pane.spawn` and `editor.open` map POSIX errno values to actionable
  IPC error kinds (ENOENT → `not_found`, EACCES/EPERM → `user_error`,
  EISDIR/ENOTDIR/EEXIST → distinct kinds, EMFILE/ENFILE →
  `tool_error` with an fd-limit hint).

### Security

- IPC: `git.checkout`, `git.push` reject branch/remote args starting
  with `-` (closes the `--upload-pack=...` argv-injection vector).
  `files.read` rejects files over 10 MB. `git.log` caps `count` at
  1000; `git.diff` / `git.stage` cap paths at 256 (T-104).
- Toolchain no longer resolves the dugite git binary against the open
  workspace — a malicious repo could plant `native/dugite/bin/git`
  and clide would run it on auto-fired `git.status`. Dugite now
  resolves against the install dir + `CLIDE_DUGITE_DIR` env override
  only (T-98).
- `files.read` and `files.ls` reject symlinks whose targets live
  outside the workspace — closes a path-safety bypass via in-repo
  symlinks (T-102).
- `files.read` and `files.ls` reject paths that resolve outside the
  workspace root. Previously a relative path containing `..` could
  read arbitrary files via path traversal.

## [2.0.0] — 2026-05-03

### Fixed

- PTY FFI constants now platform-dispatched: `TIOCSWINSZ` (`0x80087467`
  macOS / `0x5414` Linux), `O_NONBLOCK` (`0x0004` / `0x0800`), and
  `MsghdrDarwin` struct with correct 4-byte field widths for macOS
  `recvmsg()`.

- App settings directory uses `~/Library/Application Support/clide` on
  macOS instead of `~/.config/clide`.

- Removed hardcoded `TERMINFO=/usr/share/terminfo` from pane spawn
  environment — let the system resolve terminfo per platform.

- Panel `tabsFor()` now sorts by contribution priority when no user
  order is set.

### Changed

- Canonical upstream moved from Gitea to GitHub
  (`github.com/postmeridiem/clide`).

- README rewritten to reflect current single-process Flutter
  architecture, built-in extensions, and build commands.

- Renamed desktop binary from `clide_app` to `clide` (Linux + macOS).

- macOS app icon uses the black-circle variant matching the Linux
  desktop icon.

- ClideTestApp expanded to three test categories (toolchain, ipc,
  extensions) with JSON summary, non-zero exit on failure, and
  `make run-testmode TESTMODE_CATEGORY=<cat>` for selective runs.

### Added

- `make install` / `make uninstall` — builds the release bundle and
  installs it to `~/.local/` with XDG desktop entry, icon registration
  at seven sizes, and icon cache refresh. macOS installs to
  `~/Applications/clide.app`.

- Backend isolate — all subprocess and file I/O runs in a dedicated
  isolate, keeping the merged UI/platform thread on macOS free for
  rendering. Communicates via SendPort using the existing IPC protocol.
  Two-phase boot: resolve toolchain on spawn, initialize services on
  project open. Scheduler ticker only runs while a project is active.

- Toolchain — centralized binary resolution replacing five ad-hoc
  mechanisms. Resolves git, pql, tmux, ptyc, shell once at boot via
  background isolate. Status bar reads `toolchain.missing` directly.

- GitClient — typed Dart API wrapping all git operations. Every
  subprocess call goes through `_run()` with toolchain-resolved path
  and environment. Replaces scattered `Process.run('git', ...)` calls.

- Native directory picker — macOS NSOpenPanel via method channel in
  AppDelegate, GTK file chooser on Linux. Falls back to text-input
  dialog on web. Shows "No git repo found" dialog on invalid selection.

- macOS desktop target — OS-detecting Makefile (`make run` works on
  macOS/Linux/Windows), 1280x720 default window, squared app icons,
  sandbox entitlements with SBPL exceptions, `_DARWIN_C_SOURCE` for
  ptyc compilation, native traffic dots skipped (macOS titlebar owns
  them), expanded PATH for Homebrew and `~/.local/bin` on GUI apps.

- Shared ClideFilterBox widget with search icon, clear button, and
  debounced input. Applied consistently across all sidebar panes:
  Files (path filter with flat results), Git (filter staged/unstaged
  by path), Decisions (filter by ID/title/domain), Tickets (filter
  by ID/title/status), Problems (filter by source/message), and
  pql Query (replaces custom input).

- Interaction model from Wireframe Flows v3: eight new D-records
  (D-47 through D-54) and five Q-records (Q-26 through Q-30)
  codifying layout invariants, chrome budget, editor mode, context
  auto-behavior, collapse spine, focus mode, state persistence, and
  the canonical keyboard map.

- Panel collapse spine — collapsed side panels render as a 12px
  vertical spine with rotated label, hover highlight, and badge dot
  for pending context (D-51, T-30).

- Focus mode — `Ctrl+.` takes the active panel full-window;
  `Escape` restores the prior layout with collapse states and
  divider positions intact (D-52, T-31).

- Canonical keyboard shortcuts from the interaction model: collapse
  toggles (`Ctrl+Shift+1/3`), panel focus (`Ctrl+1/2/3`), sidebar
  section switching (`Alt+1–5`), focus mode, and `Escape` dismiss
  (D-54, T-33).

- Right panel (context) icon rail — bottom section switcher matching
  the left sidebar rail pattern (D-47, T-34).

- Editor-above-Claude mode — `Ctrl+E` opens the editor as a split
  above Claude in the middle column with a draggable divider;
  `Ctrl+W` or `Escape` closes it. Prompt bar Y stays fixed
  (D-49, T-35).

- Layout state persists across sessions — collapse state, sidebar
  and context panel sizes, active sections, and editor split ratio
  saved to `.clide/settings.yaml` (D-53, T-32).

- Phosphor Icons font (v2.0.8, MIT) — regular, bold, and fill
  weights. Replaces hand-painted CustomPaint icons in sidebar and
  context panel icon rails.

- Decisions panel in sidebar — lists confirmed D-records from
  `pql decisions list` with ID and title (T-37).

- Tickets panel in sidebar — lists tickets from `pql ticket list`
  with status dot color-coded by state (T-37).

- Markdown viewer in context panel — shows raw content of the
  active .md file, auto-updating on buffer switch (T-38).

- Clickable DQRT record links in markdown — `[D-56]`, `[T-43]` etc.
  rendered as tappable links that navigate to the decision or ticket
  detail pane via the message bus.

- Ctrl+Plus / Ctrl+Minus / Ctrl+0 text zoom (5% steps, 60%–200%
  range) via `MediaQuery.textScaler`. Resets on app restart.

- Sidebar focus indicators — selecting a ticket or decision
  highlights the active card in the sidebar list, auto-expands the
  accordion section if collapsed, and scrolls the card into view.

- Typography scale constants `clideFontSmall` (12) and
  `clideFontBadge` (11) for sidebar metadata and status badges.
  `clideLineHeight` (1.25) applied app-wide via `DefaultTextStyle`.

- `files.read` IPC command for reading file content by path.

- pql sidebar restructured: Search tab is the default left tab with
  ranked text search (debounced, scored results with score bar) and
  a DSL toggle for raw PQL query mode; Markdown tab (filtered to
  `.md` files) on the right. Clicking a result opens it in the
  context panel markdown viewer with bidirectional focus highlighting.

- Kernel scheduler service with tiered timers (1min, 10min, 15min,
  1hr, midnight) running on a background isolate. Emits `SchedulerTick`
  events on the `DaemonBus`. Extensions subscribe by tier (T-61).

- Auto-refresh for sidebar panels: decisions refresh on file changes
  to `decisions/*.md` and on 1-minute scheduler tick; tickets refresh
  on 1-minute tick and on status change events (T-62).

- Manual refresh button (arrowClockwise icon) in decisions, tickets,
  and pql markdown panels (T-63).

- `ClideAccordion` shared widget — extracted from tickets and
  decisions views. Supports optional `leading` widget (color dot).
  Pin/focus accordion logic: manually toggled sections are pinned;
  the focused item's section auto-opens; unpinned sections without
  focus auto-collapse.

- Ticket status buttons wired to `pql ticket status` — clicking a
  status in the detail view transitions the ticket, refreshes the
  sidebar list, and scrolls the ticket into its new section.

- `pql.tickets.status` IPC command accepting a list of IDs for
  batch status transitions.

- Ticket sidebar sections split into individual statuses: IN
  PROGRESS, REVIEW, READY, BACKLOG, DONE, CANCELLED (was four
  coarse groups).

- Phosphor Icons codepoint reference CSV at
  `assets/fonts/phosphor/codepoints.csv` — full mapping of all
  1512 icon glyphs to kebab-case and PascalCase names.

- Graph view in context panel — lists files with inbound/outbound
  link counts from `pql search --connections` (T-39).

- Welcome screen redesigned as full-screen overlay with two-column
  layout: START actions (open folder, clone, Claude session) with
  keyboard shortcuts, and RECENT projects list showing path, branch,
  and relative timestamps. Status line shows version, daemon
  connection, and active theme.

- Recent projects history persisted to user settings (up to 10
  entries with path, branch, and last-opened timestamp). Last
  project auto-restored on boot; falls back to cwd, then welcome.

### Changed

- Workspace renders Claude as the always-visible primary surface
  instead of showing a tab bar (D-47, D-48). The editor is a
  split overlay, not a tab.

- Syntax highlighting via tree-sitter (dart:ffi to vendored
  libtree-sitter.so with embedded wasmtime). 48 grammar WASM files,
  48 highlight queries. Colors map to theme syntax tokens.

- ClideMarkdown renderer — inline grouping for tight list items,
  proper HTML entity unescaping after AST parse, Josefin Sans Light
  with 1.25 line height, 16px body text. Inline code sized to
  `clideFontMono` to match surrounding text weight.

- Default sidebar and context panel widths widened to 400px and
  420px respectively (previous maximums). Context panel max raised
  to 1000px.

- Ticket detail loading uses `pql ticket show --with-context` for
  a single-call fetch of ancestors, decisions, and children.
  Replaces N+1 parent-chain walk. `--with-decision` and
  `--with-children` flags consolidated into `--with-context`.

- Ticket descriptions render through ClideMarkdown instead of plain
  text, with clickable DQRT record links.

- Decision detail view subscribes to the message bus for navigation
  (same pattern as tickets), enabling navigation from any source.

- TreeSitterService is now a shared singleton — eliminates native
  double-free crashes from multiple WASM engine instances.

- Code block syntax highlighting fixes overlapping tree-sitter spans
  that caused duplicated text (e.g. `makemake` instead of `make`).

- Context panel drag resize fixed — dragging left now correctly
  grows the right panel instead of shrinking it.

- POLICY.md — project-wide rules for runtime behavior, dependency
  vetting, vendored binary management, telemetry, and licensing.

### Changed

- Line length set to 160 across .editorconfig and dart formatter.

- Core frame vs shipped extension boundary defined (D-46). Builtins
  are frame infrastructure only; content extensions are bundled but
  architecturally removable.

### Removed

- `builtin.jira` stub — Jira integration belongs as a third-party
  extension, not a frame builtin.
- `wasm_run` and `wasm_run_flutter` dependencies — replaced by
  vendored libtree-sitter.so via dart:ffi. Eliminates runtime network
  download that violated POLICY.md.

### Added

- pql skill installed via `pql init --with-skill=yes`
  (`.claude/skills/pql/SKILL.md`). Covers vault queries and the
  planning surface (decisions + tickets).

- `Bash(pql)` and `Bash(pql *)` permissions in
  `.claude/settings.json`.

- pql daemon subsystem (`lib/src/pql/`). `PqlClient` wraps the pql
  CLI per D-3. IPC verbs `pql.files | meta | backlinks | outlinks
  | tags | schema | query | doctor | decisions.sync | decisions.list
  | decisions.show | decisions.coverage | tickets.list | tickets.show
  | tickets.board | plan.status`. 15 new core tests.

- `builtin.pql` — sidebar panel with four views: Files (pql-indexed
  file listing), Query (PQL DSL input + results), Decisions (synced
  D/Q/R records colour-coded by type), Tickets (kanban board columns).
  Context panel tab showing backlinks + outlinks for the active file,
  auto-refreshing on `editor.active-changed` events.

- `builtin.problems` — sidebar panel aggregating diagnostics from
  `pql.doctor` and `pql.decisions.sync`. Surfaces missing index DB,
  stale skill installs, and broken decision cross-references with
  actionable hints.

- Git subsystem in the daemon (`lib/src/git/`). Status parser
  (`git status --porcelain`), unified-diff parser, and operations
  (stage, unstage, stage-hunk, discard, commit, stash, log, pull,
  push). IPC verbs `git.status | diff | stage | stage-all | unstage
  | stage-hunk | unstage-hunk | discard | commit | stash | stash-pop
  | log | pull | push` with `git.changed` events on mutations.
  42 new core tests cover parsing, operations, and dispatcher
  round-trips.

- `clide git …` CLI shortcuts: `git status`, `git diff [--staged]`,
  `git stage <paths>`, `git stage-all`, `git unstage`, `git discard`,
  `git commit "<msg>"`, `git log [--count N]`, `git stash`,
  `git stash-pop`, `git pull`, `git push`.

- `builtin.git` — sidebar panel showing staged, unstaged, untracked,
  and conflicted file groups. Per-file stage/unstage/discard on hover.
  Inline commit message input with Commit button. Branch + ahead/behind
  display with Pull/Push actions. Auto-refreshes on `git.changed`
  events.

- `builtin.diff` — workspace tab rendering unified diffs with
  old/new line numbers, addition/removal colouring, and binary/rename
  metadata. Staged/Unstaged toggle toolbar. Auto-refreshes on
  `git.changed` events.

- `builtin.editor` — Tier-2 editor tab wired up. Contributes a
  single `Editor` workspace tab that renders the daemon's active
  buffer via a new `EditorController`. Hydrates on mount
  (`editor.active` → `editor.read`), subscribes to
  `editor.opened | active-changed | edited | saved | closed`, and
  propagates user edits back through `editor.set-content`. Small
  echo-suppression guard avoids clobbering the caret when the
  daemon's authoritative edit echo comes back. Text surface is
  Flutter's `EditableText` primitive — no `TextField` / Material —
  so the D-7 "no Material root" stance carries into the editor;
  JetBrainsMono via the shared `clideMonoFamily` constants, cursor
  + selection colours bind to the theme.

- File-tree click in `builtin.files` now opens the clicked file in
  the editor via `ipc.request('editor.open', {path})`. No local
  command hop — the dispatch goes straight to the daemon and the
  UI reconciles through the `editor.active-changed` event.

- CLI shortcuts per CLAUDE.md's Tier-2 list: `clide open <path>`,
  `clide active`, `clide insert <text | ->`, `clide replace-selection
  <text | ->`, `clide save`, `clide tail --events [--filter
  SUBSYSTEM[:ID]]`. A lone `-` on insert / replace-selection reads
  text from stdin (pipe-friendly). `tail` reads the event-broadcast
  stream and prints JSON lines until SIGINT; `--filter` narrows by
  subsystem or subsystem+id. 5 new end-to-end CLI tests spin up real
  daemon subprocesses via a per-test `CLIDE_SOCKET_PATH` override (new
  env knob on `defaultSocketPath`) so tests run in parallel without
  colliding.

- Editor subsystem in the daemon (`lib/src/editor/`). `EditorBuffer`
  holds path + content + cursor/selection + dirty flag;
  `EditorRegistry` owns the open-buffer set, active-buffer tracking,
  and file I/O. IPC verbs land alongside (`editor.open | active |
  activate | list | read | insert | replace-selection | set-selection
  | set-content | save | close`) with matching events (`editor.opened
  | active-changed | selection-changed | edited | saved | closed`).
  Omitting `id` on mutating verbs targets the active buffer so the
  tier-2 CLI shortcuts (`clide insert "…"`, `clide replace-selection
  "…"`) read naturally. 16 new core tests cover the lifecycle +
  dispatcher round-trips.

- `builtin.claude` — Tier-1 stub upgraded to the real Claude pane per
  D-41. Contributes a primary `Claude` tab in the workspace slot that
  spawns `tmux new-session -A -s clide-claude-<hash> -- claude` via
  IPC `pane.spawn`, with `<hash>` derived from the git root path so
  reopening the app re-attaches to the running conversation. Primary
  has no close affordance; closing the tab doesn't kill the session.
  Command `claude.new-secondary` is registered for the palette wiring
  that's coming next. If tmux isn't on PATH, falls back to spawning
  `claude` directly and surfaces "no-tmux · fresh every launch" in
  the header subtitle. Accompanied by D-41 in
  [`decisions/architecture.md`](decisions/architecture.md#d-41-claude-panes-one-primary-per-repo-tmux-backed).

- `builtin.files` — workspace filesystem panel in the sidebar. Lazy
  tree rooted at the git root, expand/collapse, click-to-open plumbed
  to a future `editor.open` command. Backed by a new daemon-side
  `files.*` IPC subsystem (`files.root`, `files.ls`, `files.watch`)
  and a `FileWatcher` that wraps `Directory.watch(recursive: true)`
  with ignore-file filtering. Ignore set composes clide's built-in
  hide list (`.git/`, `.pql/`, `.clide/`, `.dart_tool/`, `build/`,
  `node_modules/`) with `.gitignore` / `.clideignore` at the root per
  D-4. `IgnoreSet` + `IgnorePattern` support line-per-pattern, `#`
  comments, anchored / directory-only / negated forms, and `**` across
  directories. 11 new unit tests on the matcher; 5 new dispatcher
  tests; 171 app tests still green.

- `builtin.terminal` — general-purpose terminal pane, Tier-1 stub
  upgraded to a working implementation. Contributes a `Terminal` tab
  in the workspace slot that spawns `$SHELL -l` via IPC
  `pane.spawn`, streams `pane.output` events into `xterm.dart`, and
  routes user input through `pane.write`. Resize propagates via
  `pane.resize` on viewport change. `initState` → spawn;
  `dispose` → `pane.close`. Error-state surface for "daemon not
  connected" / "shell exited." No Claude-specific behaviour — that
  lives in `builtin.claude` + D-41.

- Shared pane widgets under `app/lib/widgets/`: `ClidePtyView` wraps
  `xterm.dart` with clide-theme token bindings, JetBrains Mono as the
  face, and a Semantics live-region wrapper; `ClidePaneChrome` is the
  reusable title strip + optional close button. Consumers of the new
  widgets (`builtin.terminal`, `builtin.claude`) drive the xterm
  `Terminal` model and route bytes through IPC `pane.write` /
  `pane.output` events themselves — the widgets are rendering only,
  no IPC coupling.

- `xterm: 4.0.0` Dart dependency on the Flutter app — MIT, listed in
  `licenses.yaml` per D-42. Hand-rolling a VT100 / xterm / truecolour
  parser + renderer would be weeks for no fidelity win.

- `Q-23` — open question on SSH-remote development (run clide against
  a workspace on another host). Local-first stays the Tier-1 target;
  this records the constraint so the daemon / IPC / extension seams
  don't unknowingly accrete local-only assumptions.

- IPC `pane` subsystem in the daemon (per D-6). Commands:
  `pane.spawn | list | focus | close | write | resize | tail`. Events:
  `pane.spawned`, `pane.output` (base64-framed), `pane.exit`,
  `pane.resized`, `pane.focused`, `pane.closed`. `PaneRegistry` owns
  per-pane `PtySession` lifecycles + id generation (`p_N`); a
  `DaemonEventSink` seam lets handlers emit events without depending
  on the IPC server package. `DaemonServer.broadcast()` fans events
  out to every connected client (a later pass adds per-client
  `--filter` scoping). Panes carry a `kind:` field — `terminal` today,
  `claude` ready for step 7. Covered by 14 new Dart core tests
  exercising the real registry + dispatcher against the `ptyc` helper.

- `PtySession` in the Dart core (`lib/src/pty/`) — spawns a child
  under a PTY via the `ptyc` supporter tool, receives the master fd
  over `SCM_RIGHTS`, and exposes a byte stream, write, resize, and
  kill. A background isolate loops on blocking `read(fd)` and posts
  chunks to the main isolate. `close()` sends SIGTERM to the child
  so the PTY's EOF wakes the isolate cleanly, then falls through to
  SIGKILL + fd close + isolate kill as a safety net. Child env is
  built via `mergePtyEnv()` which stamps clide's true-colour defaults
  (`TERM=xterm-256color`, `COLORTERM=truecolor`, `CLICOLOR_FORCE=1`).
  Test coverage: echo round-trip, cat write/readback, env stamping
  verification, idempotent close.

- `ffi: 2.1.3` as a runtime dependency on the Dart core — justified
  in `pubspec.yaml` + documented in `licenses.yaml` per D-42. Used
  by `lib/src/pty/ffi/` for `socketpair`, `recvmsg` with `SCM_RIGHTS`,
  `read`/`write` on raw fds, and `ioctl(TIOCSWINSZ)`.

- `ci/test_core.sh` + `make test-core` — runs the Flutter-free core
  Dart tests (`test/`) under a 120s hard timeout with process-group
  cleanup. Wired into `push-check` ahead of the app test suite so a
  hung PTY test can't block the pre-push gate.

- Josefin Sans bundled as `app/assets/fonts/josefin_sans/` as the
  application UI face — variable-font pair (upright + italic, weight
  range 100-700), OFL-licensed. Declared as the `JosefinSans` family
  in `app/pubspec.yaml`. `_AppRoot` installs it as the ambient
  `DefaultTextStyle` at weight `w300` (Light) per the project's
  aesthetic direction; callers can still pass an explicit
  `fontWeight` on `ClideText` to get bolder emphasis.

- JetBrains Mono bundled as `app/assets/fonts/jetbrains_mono/` —
  Regular / Italic / Bold / BoldItalic weights (OFL-licensed,
  license file checked in alongside). Declared as the `JetBrainsMono`
  family in `app/pubspec.yaml`. `app/lib/widgets/src/typography.dart`
  exposes `clideUiFamily` + `clideMonoFamily` plus platform-ordered
  fallback chains for both faces, for web builds and harnesses that
  don't load asset fonts.

- `app/assets/licenses.yaml` — canonical manifest of every bundled
  third-party artefact (fonts today; Dart packages + native tools as
  they land). Schema has name, kind, version, homepage, license,
  `license_file` pointer, and a one-line purpose. Bundled alongside
  the per-dep license texts. The About screen (Tier 6) will render
  this file verbatim. Accompanied by
  [`D-42`](decisions/tooling.md#d-42-bundled-dependencies-documented-in-licensesyaml):
  adding a dep is a two-step commit (artefact + `licenses.yaml`
  entry in the same changeset).

### Changed

- CLAUDE.md "Dependencies & supply chain" section gains the
  "document every bundled dependency" rule, pointing at
  `app/assets/licenses.yaml` and `D-42`.

- `ptyc/` — the C PTY-spawn helper, peer of `pql` per
  [`D-5`](decisions/architecture.md#d-5-dart-core-sidecar-dissolved-ptyc-as-pql-peer).
  One-shot, libc-only, ~400 LOC. Reads a JSON request on stdin
  (`argv`, optional `cwd`/`env`/`cols`/`rows`), does
  `posix_openpt` + `fork` + `execvp`, and hands the master fd back
  to the caller over a unix socket via `SCM_RIGHTS`. Socket fd
  defaults to 3; override via `PTYC_SOCK_FD` for language runtimes
  that shuffle pipe fds through the low numbers (Python's
  `subprocess` with `stdout=PIPE` does this). Exec-failure pipe
  (CLOEXEC) reports child-side errors to the parent without leaking
  zombies. Root Makefile gains `ptyc-test` target in addition to
  `ptyc-build` / `ptyc-clean`.

- Migrated the `docs/ADRs/` content into `decisions/` as D/R records:
  ADR 0001 → `D-1`, ADR 0002 → `R-2` (superseded by `D-5`), ADR
  0003 → `D-3`, ADR 0004 → `D-4`, ADR 0005 → `D-5`, ADR 0006 →
  `D-6`. Titles preserved; ADR 0006's trailing open questions moved
  to `questions-architecture.md` as `Q-1` / `Q-2` / `Q-3`. The
  originals are preserved in git history.

- `decisions/` at the repo root — Q&D record system ported from
  settled-reach and adapted for clide's domains. Confirmed decisions
  (`D-NNN`) live under domain files (`architecture.md`, `extensions.md`,
  `accessibility.md`, `testing.md`, `tooling.md`, `process.md`); open
  questions (`Q-NNN`) live under parallel `questions-<domain>.md`;
  rejected alternatives (`R-NNN`) live in `rejected.md`. Record shape,
  claiming rules, and the eventual pql-side tooling plan are documented
  in `decisions/README.md`. Migration of the existing `docs/ADRs/` into
  these files lands in a follow-up commit.
- `DECISIONS.md` one-line pointer at the repo root (matches
  settled-reach's convention).

- `tools/scripts/plan` — Python stopgap entrypoint for `decisions`
  and `ticket` subcommands, writing to `.pql/pql.db` (gitignored).
  Supports `decisions sync | validate | claim | list | show | coverage`
  and `ticket new | list | show | status | assign | team | block |
  unblock | label | search | board`, plus `sqlite-query`. Verb shape
  and output format mirror the eventual `pql` subcommands so migration
  when pql ships feature parity is a call-site find-replace
  (`tools/scripts/plan ` → `pql `). Ported from settled-reach with
  the Scrum layer stripped; ticket IDs are `T-NNN` (TEXT PKs) and
  there's no `sprints` table. Time-limited per
  [`D-40`](decisions/process.md#d-40-python-stopgap-under-toolsscriptsplan)
  / [`R-11`](decisions/rejected.md#r-11-permanent-stopgap).

- `make decisions-validate` — cheap parser dry-run wired into
  `push-check`. Catches malformed records before push.

- Reserved extension slots — `builtin.decisions`, `builtin.tickets`,
  `builtin.claude-control`. Id-reserving stubs under
  `app/lib/builtin/` with no contributions yet. Implementations land
  once [`Q-21`](decisions/questions-architecture.md#q-21-pql-absorbs-planning-vs-keeps-separate)
  resolves (decisions + tickets) or when the claude-control tier
  arrives (`.claude/` first-class surface — distinct from the
  existing `builtin.claude` PTY-pane stub).

- `CLAUDE.md` — new "Decision discipline" guardrail pointing at
  `decisions/`.

### Changed

- `CLAUDE.md` — inline ADR links rewritten to point at the migrated
  `decisions/` records; bottom "Open questions" section collapsed to
  a pointer at `decisions/questions-*.md`; parent-project note
  updated to reference `decisions/architecture.md` instead of the
  deleted `docs/ADRs/`.

- `make decisions-validate` rewired from `tools/scripts/plan` to
  `pql decisions validate`.

- Decision discipline guardrail in CLAUDE.md now points at
  `pql decisions claim` instead of the Python stopgap.

### Removed

- `tools/scripts/plan` — Python stopgap planning scripts, superseded
  by `pql` 1.0 native `decisions` and `ticket` subcommands. Sunset
  condition from
  [`D-40`](decisions/process.md#d-40-python-stopgap-under-toolsscriptsplan)
  met; deletion per
  [`R-11`](decisions/rejected.md#r-11-permanent-stopgap).

### Removed

- `docs/ADRs/` directory — content lifted into `decisions/` as D/R
  records (see Added above). Originals preserved in git history.

- Go sidecar skeleton under `sidecar/` — `cmd/clide/main.go`, `go.mod`, and the `internal/*` packages (`cli`, `daemon`, `diag`, `git`, `ipc`, `pql`, `proc`, `pty`, `version`). Deleted wholesale per [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md): the "sidecar language: Go" premise no longer holds once the core is Dart. All functionality listed for those packages will be reimplemented under `lib/` as part of Tier 0.
- Go-specific Makefile targets (`lint`, `vuln`, `test-race`, `fmt`, `tidy`, `snapshot`, `tools`, `install` via Go), the `govulncheck`/`goimports`/`golangci-lint` version pins, and the pre-push hook's `GOBIN` PATH injection. Replaced with Dart/Flutter equivalents (`analyze`, `format`, `test`, `test-integration`, `build` via `dart compile exe`).
- `module:` and `go_version:` from `pubspec.yaml` — single-language core means no Go module path to track.

### Changed

- [ADR 0002](docs/ADRs/0002-sidecar-language-go.md) marked **superseded** by [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md). The "sidecar language: Go" guardrail is retired. CLAUDE.md's guardrails, dependency notes, and command reference are updated to reflect the Dart-core direction.
- `.gitignore` retargeted: Flutter/Dart output at the repo root (`.dart_tool/`, `build/`, platform ephemeral dirs, `bin/clide`), plus a `ptyc/` section for the C helper's build artefacts. Go-specific rules removed.
- `ci/lint.sh`, `ci/test.sh`, `ci/security.sh`, and `.githooks/pre-push` rewritten for the Dart toolchain — no Go shell-outs, no `GOBIN` PATH dance.

### Added

- Testing docs under `docs/testing/`: `README.md` (what each layer covers, how to run, local vs CI flow), `a11y-manual.md` (15-minute Orca + VoiceOver checklist run at every tier cut), `claude-ui-workflow.md` (how Claude Code drives the app through the Playwright harness, including the `flt-semantics-placeholder` quirk).
- Makefile targets for every test layer and the UI harness: `test`, `test-a11y`, `test-integration`, `test-e2e`, `test-all`, `coverage`, `smoke-bundle`, `ui-dev`, `ui-stop`, `ui-smoke`. `push-check` now runs `test + test-a11y` (fast pre-push gate, <90s).
- Per-layer CI shell scripts under `ci/`: `test.sh` (analyze + format + unit + widget + golden, ~5s), `test_a11y.sh` (a11y contract), `test_integration.sh` (integration_test one file at a time — desktop can't batch them reliably), `test_e2e.sh` (daemon subprocess + browser WASM Playwright smoke), `smoke_bundle.sh` (xvfb-run the Linux release bundle for 5s; catches dynamic-linker / asset-bundle / plugin-init regressions that widget tests can't see), `coverage.sh` (flutter test --coverage + lcov summary).
- `.gitea/workflows/test.yml` — four-job pipeline (`unit`, `integration`, `startup-bundle`, `e2e`) that shells out to the `ci/*.sh` scripts. **Not activated yet** — Gitea Actions has to be enabled in the instance settings first. GitHub-Actions-syntax-compatible, so copying to `.github/workflows/` is a one-file move when the repo migrates.
- Web WASM harness under `tools/ui/` — Playwright driver so Claude Code (and humans) can drive the Flutter build in a real browser via the Semantics tree. `build.sh` / `serve.sh` / `stop.sh` manage a local `http.server` on `:4280` with port-based reclaim and kill (so orphaned listeners from earlier runs get swept). `driver.ts` exposes `ClideDriver` with `byLabel` / `click` / `type` / `readText` / `screenshot` / `dumpSemanticsTree` / `waitUntilReady` (auto-clicks the `flt-semantics-placeholder` to enable the semantics tree). First Playwright test `smoke.spec.ts` asserts welcome + disconnected labels render in the browser.
- Integration tests under `app/integration_test/`, run with the `integration_test` package against the real built app (not an in-memory widget pump). The load-bearing startup gate lives here: `app_starts_test.dart` boots `ClideApp`, waits for the root shell to settle, and asserts the three-column layout + welcome tab + statusbar connection indicator all render. Also covers theme-picker modal open/select/dismiss (`theme_picker_test.dart`) and extension enable/disable lifecycle with contributions mounting/unmounting (`extension_lifecycle_test.dart`).
- App-level test suite under `app/test/` — 168 tests across four layers:
  - **Unit** (`kernel/`, `extension/`) — events bus, settings (scope + YAML round-trip), log, i18n fallback chain matrix, theme resolver + loader + controller, panel registry + arrangement, command registry + keybinding parser + palette filter, extension-manager dep-order / cycle detection / enable-disable, manifest loader, extension scanner.
  - **Widget** (`widgets/`, `builtin/`) — every primitive's Semantics presence + token consumption + hover/press states; each Tier 0 built-in's contributions, view, and locale-switch re-render.
  - **Golden** (`goldens/`) — widget primitives only, Alchemist + Ahem font; PNG fixtures checked in under `_files/ci/` and `_files/linux/`.
  - **A11y** (`a11y/`) — `semantic_coverage_test.dart` (contract-level check that every built-in carries title + version + label-ready contributions), `contrast_test.dart` (WCAG-AA ratio gate on every bundled theme's canonical token pairs), `i18n_coverage_test.dart` (asserts every Tier-0-referenced key is present in its `en_US` catalog), `keyboard_traversal_test.dart` (focusability smoke).
- Test helpers under `app/test/helpers/` — `KernelFixture` (boots a KernelServices with in-memory defaults + a fake daemon for widget-level tests), `FakeDaemonClient` (subclasses the real client, no socket, drivable connected-state), `golden_harness` (Alchemist config with Ahem font for cross-platform pixel stability), `widget_harness` (wraps a widget in Directionality + ClideKernel + ClideTheme + MediaQuery).
- Flutter desktop app scaffold under `app/` with a bare `WidgetsApp` root (no Material, no Cupertino) and the Tier 0 three-column layout.
  - **Kernel** (`app/lib/kernel/`) — 18 services consumed by every extension: `settings` (scope-resolved get/set across `app.*`/`project.*`/`ext.*`), `project`, `extensions`, `theme`, `panels` (slot registry + arrangement), `events`, `ipc`, `commands` (+ palette + keybinding resolver), `clipboard`, `files`, `notify`, `dialog` (single-at-a-time modal router), `tray`, `secrets`, `os`, `net`, `focus`, and `log`. Unified in a `ClideKernel` `InheritedWidget`.
  - **i18n** (`app/lib/kernel/src/i18n/`) — text-driven lookup ported from [fframe](https://github.com/postmeridiem/fframe)'s `L10n`: namespaced JSON catalogs, `string()` / `interpolated()` calls with caller-supplied placeholders, and a proper locale fallback chain (exact → language → default-country → default-language → placeholder). Improves on fframe's design by adding the chain, which fframe lacks.
  - **A11y from Tier 0** — `Semantics(label:, hint:, button:)` on every interactive primitive; `SemanticsBinding.ensureSemantics()` at boot; a `theme/contrast.dart` helper exposes token pairs that the a11y suite walks for WCAG-AA compliance.
  - **Extension contract** (`app/lib/extension/`) — abstract `ClideExtension`, sealed `ContributionPoint` hierarchy (`TabContribution`, `StatusItemContribution`, `ToolbarButtonContribution`, `CommandContribution`, `TrayItemContribution`, `LayoutPresetContribution`). Each extension ships one manifest contributing N atoms into kernel slots. Priority-based ordering within a slot, dependency-aware activation, YAML manifest loader + scanner for `~/.clide/extensions/`.
  - **Three-tier theme pipeline** — palette (named colors) → semantic roles → ~60 VS-Code-style surface tokens, each layer with defaults so palette-only themes ship. Ported `summer-night` as the first bundled theme; muted value calibrated for WCAG-AA contrast.
  - **Widget primitives** (`app/lib/widgets/`) — `ClideSurface`, `ClideText`, `ClideButton`, `ClideTabBar`, `ClideDivider`, `ClideScrollbar`, `ClideTooltip`, `ClideIcon` + eight `CustomPainter`-rendered icons (folder, gear, x, chevron-left/right, dot, check, plug). All token-consuming, all Semantics-wrapped.
  - **Tier 0 built-in extensions** — `builtin.default-layout` (classic three-column preset + reset command), `builtin.welcome` (workspace placeholder), `builtin.ipc-status` (live-region statusbar indicator), `builtin.theme-picker` (command + modal, bound to `ctrl+k`). Plus 17 id-reserving stubs (`builtin.claude`, `builtin.terminal`, `builtin.files`, `builtin.editor`, `builtin.git`, ...) so later tiers can fill in without rename churn.
  - **Lua runtime boundary** — `app/lib/lua/` ships as typed stubs (`host`, `adapter`, `capability_api`, `render_intent`) so third-party Lua extensions can plug in at Tier 6 without retrofitting.
- `.gitignore` extended to cover `app/` sub-package artefacts (`app/.dart_tool`, `app/build`, per-platform ephemeral dirs, `app/*.iml`) and the Playwright harness under `tools/ui/` (`node_modules`, `out`, test-results).
- Dart core package at the repo root: `bin/clide.dart` (one binary, `--daemon` and one-shot subcommand modes), `lib/clide.dart` barrel exporting the shared IPC types, `lib/src/ipc/` (`envelope.dart`, `server.dart`, `paths.dart`, `schema_v1.dart`), and `lib/src/daemon/dispatcher.dart`. `clide --daemon` listens on a unix socket; `clide ping` / `clide version` round-trip through it with the ADR 0006 exit-code contract (`0/1/2/3/4`). Includes `test/ipc/` and `test/daemon/` suites covering envelope parsing, the in-process server, and a subprocess smoke that verifies signal-driven shutdown + socket unlink.
- `scripts/bazzite-flutter-setup.sh` — one-shot installer for the Flutter SDK + desktop build deps on Bazzite / Fedora Silverblue. Drops the SDK under `~/opt/flutter`, wires PATH in the user's shell rc files, and layers the Linux desktop build deps via `rpm-ostree install`.
- [ADR 0005](docs/ADRs/0005-dart-core-ptyc-peer.md) — Dart core; sidecar directory dissolved; `ptyc` as pql-peer. Establishes one Dart AOT binary for both CLI and daemon, `lib/` as the shared core, and promotes the C PTY helper to a standalone supporter tool on the same footing as pql.
- [ADR 0006](docs/ADRs/0006-cli-and-event-surface.md) — CLI and event surface contract. Defines the subsystem list (`pane`, `tab`, `editor`, `panel`, `tree`, `git`, `pql`, `canvas`, `graph`, `theme`, `settings`, `project`), the command shape, the versioned JSON event schema, the pql-style exit-code contract, and the command↔event duality rule that operationalises user/Claude parity.

- Architectural decision records carried forward from the short-lived
  `claudian` plugin project (discarded in favour of this Flutter
  rebuild):
  [ADR 0001](docs/ADRs/0001-cli-first-not-mcp.md) — CLI-first, not MCP.
  [ADR 0002](docs/ADRs/0002-sidecar-language-go.md) — Sidecar language: Go.
  [ADR 0003](docs/ADRs/0003-pql-as-supporter-tool.md) — pql as supporter tool; wrap, don't duplicate; pql is a Clide subsystem when present.
  [ADR 0004](docs/ADRs/0004-ignore-file-strategy.md) — Ignore file strategy (`ignore_files:` in `.pql/config.yaml`, layered).
- Pre-push quality gate: `.githooks/pre-push` runs `make push-check` (lint + test + test-race + test-integration + vuln + app-analyze + app-test) so bad pushes are caught locally before they hit Gitea. The app-side targets gracefully noop until Flutter is scaffolded. Install with `make hooks` (sets `git config core.hooksPath .githooks`); the hook prepends `$GOBIN`/`$HOME/go/bin` to PATH so govulncheck resolves without the user touching their shell profile.
- Go sidecar/CLI skeleton under `sidecar/` (module `git.schweitz.net/jpmschweitzer/clide/sidecar`): `cmd/clide/main.go`, `internal/cli` with a stdlib-flag dispatch, `internal/diag` mirroring pql's exit-code + stderr-JSON contract, `internal/version` with ldflag-stamped build info, and placeholder packages for `daemon`, `pty`, `proc`, `git`, `ipc`, `pql` awaiting their tier. `clide --version` emits JSON build-info today.
- Root `Makefile` drives both the Go sidecar and the Flutter app under one toolchain. Version is read from `pubspec.yaml` via awk and stamped into the sidecar via `-ldflags -X`. Flutter targets gracefully noop before the app is scaffolded so the Makefile is usable from day one. Pinned Go tooling (govulncheck, goimports, golangci-lint) installs via `make tools`.
- `ci/` entry scripts: `test.sh`, `lint.sh` (includes the supply-chain gate — no green lint without a green CVE scan), `security.sh`, `release.sh` (stub).
- Project identity files for the Flutter rebuild at the repo root: `pubspec.yaml` (single source of truth for version + module path, version 2.0.0-dev), a fresh `README.md`, MIT `LICENSE`, and `.editorconfig`. The Python clide's manifest and README are preserved under `legacy/`.
- [`docs/initial-plan.md`](docs/initial-plan.md) — the north-star design document for the Flutter rebuild. Captures what we kept from Python Clide (pane model, git skills, Claude-always-visible), what we took from Obsidian (canvas and graph — no vault, no bases, no plugin inheritance), what Claudian's short experiment contributed (Go sidecar, CLI-first, pql-as-subsystem, ignore-file strategy), and the tier roadmap (Tier 0 app+sidecar handshake → Tier 5 canvas+graph).
- [`CLAUDE.md`](CLAUDE.md) orientation doc for future Claude Code instances: project identity, guardrails as one-liners, tier ordering, parent-project pointers, commands, dependencies & supply chain, open questions. Points at the design doc and ADRs rather than restating their content.
- Claude Code configuration under `.claude/`: project-level
  allow/deny permissions and two skills — `skill-create` (generic
  skill authoring guidance) and `git-commit` (this repo's commit
  conventions: no Conventional Commits, Keep a Changelog discipline,
  `pubspec.yaml`-and-changelog-bumped-together rule, attribution
  trailer, safety reminders).
