# fable-ous.md

*A fable about clide, as told by Fable.*

*Produced by 13 parallel subsystem reviewers reading ~58k LOC of Dart, ~100 raw
findings put through 70 adversarial verification passes (exactly one finding was
refuted — it had missed D-14), 5 feature-ideation lenses, and a full read of the
pql planning vault: 94 confirmed decisions, 24 open questions, 11 rejected
alternatives, 358 tickets. Everything below cites real file:line evidence that a
skeptical second agent re-read and failed to knock down.*

---

## TL;DR scoreboard

| Dimension | Verdict |
|---|---|
| Build health | **Green.** `make analyze` 0 issues, 1383 tests pass, format clean, coverage 95.30% over the 95 floor |
| Documentation discipline | **Best-in-class.** Near-every file cites its D-NNN/T-NNN; zero TODO/FIXME debt in 58k LOC |
| Honesty | **High.** CHANGELOG claims verified against code; stubs self-describe as stubs |
| Real bugs found | ~14 distinct high-severity, ~35 medium — mostly in process lifecycle, a11y, and terminal conformance |
| Systemic risks | Broadcast-streams-without-replay, silent `catch (_)`, kernel lookup in `dispose()`, copy-paste drift |
| Release process | **Stalled.** No git tag since v2.1.0 despite five CHANGELOG releases; `ci/release.sh` is a stub |
| Killer-feature headroom | Enormous — the moats (owned agent loop, owned renderer, pql vault) are real and barely exploited |

The fable in one sentence: **a castle with exceptional masonry, a few unlocked
side doors, and a dragon hoard of features in the basement nobody has spent yet.**

---

## Part I — The state of the realm (what's genuinely excellent)

Credit where due, because this codebase does several things better than most
production repos:

- **Governance traceability is real, not ceremonial.** Nearly every non-trivial
  declaration carries its ticket/decision id. Multiple reviewers independently
  called it "the best I've seen at this scale." Code-to-decision drift is
  *auditable from the code itself* — and indeed most drift findings below were
  found exactly that way.
- **Schema-validated IPC dispatch (D-74)** is beautifully executed: schemas
  co-registered with handlers, the MCP tool surface and `clide capabilities`
  both generated from the same registry (`lib/src/daemon/dispatcher.dart:90-137`)
  so three surfaces cannot drift apart.
- **The keymap subsystem (D-82)** — layered precedence, headless
  `SequenceMatcher`, clock-injected `ModifierTapTracker` — is exemplary,
  near-fully test-mirrored design.
- **`ClideTappable`, the anchored-overlay/menu family (D-88), reduced-motion
  honoring in every animated primitive** — the owned widget layer is coherent
  and disciplined.
- **Battle scars are encoded where they happened.** `pumpAsync` documents why
  `pumpAndSettle` wedges; `KernelFixture` encodes the T-280 teardown-hang fix;
  flake postmortems live as comments in the test that almost shipped them.
- **Security instincts**: 0600 socket + live-listener probe before unlink, git
  argv hardening with `--` terminators, `path_safety.dart` documenting its
  threat models inline, workspace-relative binary resolution forbidden (T-98).
- **Zero TODO/FIXME/HACK** across the tree. The clean-board policy is lived.

Patterns worth *extending* (the reviewers kept wishing other code did this):
the coalesced-notify `Timer(Duration.zero)` trick in `ConversationController`,
the pure-Dart-core/thin-Flutter-shell split, and `RecordingEventSink`-style
event-driven test waits.

---

## Part II — The bestiary (bugs I would fix, in order)

### 🐉 Dragons (high severity, verified, fix this week)

1. **Every naturally-exited PTY leaks its master fd — forever.**
   `lib/src/pty/native_pty.dart:444-450` — on child EOF, `_reap()` sets
   `_dead = true` but never closes `_fd`; a later `close()` short-circuits at
   `if (_dead) return;` (line 460) so `_nativeClose(_fd)` (line 477) never runs.
   Two reviewers found this independently. Every terminal/Claude pane whose
   child exits on its own leaks an fd and a pty device for the life of the app.

2. **The Claude child process is observed only via stdout.** Three reviewers
   converged here. `lib/builtin/claude/src/stream_json_session.dart:43-78` —
   stderr is *never drained* (≥64KB of `--verbose` spew = pipe fills = child
   blocks mid-turn = the flagship pane wedges with zero diagnostics), and
   nothing watches `exitCode` or `onDone` (line 303), so a crashed/dead
   session just looks… thoughtful. Drain stderr into a ring buffer, surface a
   terminal `SessionEnded` state. This also intersects T-283 (no resume
   timeout/fallback).

3. **The MCP HTTP server exposes the entire dispatcher with zero auth.**
   `lib/src/ipc/mcp_server.dart:138-195`, started unconditionally at boot
   (`lib/main.dart:174-180`). D-71's threat model ("another user on the same
   host should not drive my IDE") is enforced with 0600 on the unix socket —
   and then bypassed wholesale by an unauthenticated localhost HTTP port that,
   since D-86, serves *every* clide verb as a tool. Generate a token in the
   lock file (Claude Code's own `/ide` lock format has a slot for it), require
   the header.

4. **`editor.open`/`editor.save` skip path confinement entirely.**
   `lib/src/editor/registry.dart:215-219` returns absolute paths verbatim, no
   `..` normalization, no `path_safety` call — an unconfined read *and write*
   primitive over IPC while `files.read` is carefully guarded. Same family:
   **`search.replace` silently ignores its include/exclude globs**
   (`lib/src/search/replace_engine.dart:124-143`) and will happily rewrite
   files outside the filter the user typed; and **`listDir`'s symlink
   detection is dead code** (`lib/src/files/listing.dart:46-54` — `stat()`
   follows links, so `isSymlink` is always false) which means `walkFiles`
   descends symlinked dirs the docs claim it skips.

5. **Closing a terminal pane never closes the shell.**
   `lib/builtin/terminal/src/terminal_pane.dart:131-137` calls
   `ClideKernel.of(context)` from `dispose()` — illegal ancestor lookup,
   swallowed by `catch (_)` — so `pane.close` is never sent and the backend
   PTY + daemon pane leak. The same idiom leaks the settings listener in every
   disposed `ClaudePane` (`claude_pane.dart:460-466`). Combined with dragon #1
   this is a two-stage leak pipeline. Cache the kernel ref in
   `didChangeDependencies`, delete the catch-all.

6. **Project switch leaks the entire previous workspace.**
   `lib/main.dart:335-344` — a new dispatcher gets fresh `PaneRegistry`,
   `FilesService`, `EditorRegistry`, etc., but nothing calls the old set's
   `shutdown()` methods (which exist and have zero callers). Old watchers keep
   emitting into the new workspace's bus.

7. **T-274's root cause, found and verified:** the status bar is empty because
   `statusStream` is a plain broadcast controller — the `system/init` event
   fires while `spawn()` is still awaiting a 256KB transcript-tail read, before
   the pane ever subscribes (`claude_pane.dart:322`,
   `session_orchestrator.dart:222-225`). Seed from `session.status` on bind, or
   make it replay-latest. (The broadcast-without-replay shape is a recurring
   bug factory — see Part III.)

8. **Auto-scroll yanks a scrolled-up reader to the bottom on every streamed
   token.** `conversation_view.dart:268-277` — the `_atBottom` pin exists but
   is only consulted on viewport *resize*, not on new items. Anyone reading
   earlier output during a long streaming reply is dragged to the bottom
   continuously. One-line gate + the missing twin test.

9. **The terminal can crash on garbled output.** SGR 38/48 extended-color
   parsing does unguarded `params[i + 1]` lookahead
   (`lib/src/terminal/src/core/escape/parser.dart:501-516`) — `printf '\e[38m'`
   throws RangeError inside `Terminal.write`. An emulator must never throw on
   hostile bytes. While in there: colon-form SGR sub-parameters are mangled
   into bogus params.

10. **A11y has drifted despite being a Tier-0 contract.** Two independent
    verified findings: `ClideCollapserCard`'s `excludeSemantics: true` wipes
    *every expanded child* from the a11y tree
    (`lib/widgets/src/clide_collapser_card.dart:92-101`) — a screen-reader user
    can expand a run and hear nothing; and the three a11y gate tests
    hand-enumerate their subjects and have measurably fallen behind `lib/`
    (contrast checks fewer themes than `main.dart:443-454` loads; i18n checks 4
    of 8 namespaces). The gates stay green while covering less. Make `lib/`
    export the canonical lists and iterate them in the gates.

### 🦂 Scorpions (medium — real, will sting eventually)

- **D-72's "serial dispatch" isn't.** `lib/src/ipc/server.dart:151-180` uses an
  `async` onData without pausing the subscription — pipelined requests
  interleave, and the shared `StringBuffer` framing can drop/double lines.
  `client.cast<List<int>>().transform(utf8.decoder).transform(LineSplitter())`
  + `await for` fixes framing, UTF-8 split chunks, and serialization at once.
- **Split-chunk UTF-8 corruption is endemic at byte→String seams**: the
  terminal's only ingestion API is `write(String)` (`terminal.dart:218`) so
  both consumers decode per-chunk; `FileTailFollower` starts mid-character by
  construction. Add `writeBytes()` with a persistent chunked decoder.
- **`Orchestrator.spawn()` races itself** — check-then-act across two awaits;
  concurrent spawns for one id leak a live `claude` process
  (`session_orchestrator.dart:191-249`). Hold a `Map<String, Future<ManagedSession>>`.
- **Fork panes misbehave on `/clear`, `/resume`, `/fork`** —
  `widget.forkSourceId` wins forever, so `/clear` *re-forks the original
  conversation* instead of clearing (`claude_pane.dart:266-281`).
- **Settings persistence corrupts maps-inside-lists on write**
  (`settings.dart:199-219` emits `toString()`), breaking the documented keymap
  overlay across restarts; writes are non-atomic and a parse failure silently
  resets all settings.
- **Extension activation isn't transactional** — a throw mid-contribution
  leaves contributions mounted while the extension records as failed; retry
  double-applies (`extensions_manager.dart:133-192`). Plus: disabling an
  extension ignores dependents, and registries clobber silently on id
  collision — fine among curated builtins, hazardous the day Tier-6 Lua lands.
- **Terminal conformance debt** (the fork fixes what it trips over but has no
  vttest-style suite): HTS is a no-op (`isSetAt` instead of `setAt`,
  `terminal.dart:423`), DECCKM is tracked but never consumed, legacy mouse rows
  are off-by-one *and the test enshrines the bug*, CPR replies 0-based where
  every real terminal is 1-based, scrollback is maintained but structurally
  unreachable (`ViewportOffset.zero()` pinned every build,
  `terminal_view.dart:224`).
- **Markdown renderer**: hard breaks and images render as empty text (words
  glue together; `clide_markdown.dart:408-410`), and the whole document
  re-parses with sync `existsSync()` calls *inside build* on every streaming
  delta — multiplied by the conversation view re-deriving everything O(n) per
  notification and token streaming re-encoding the full reply per delta
  (O(n²) churn, `stream_json_session.dart:410-431`).
- **Terminal panes spawn in `Directory.current`**, not the open project root
  (`terminal_pane.dart:69`) — desktop launches get `$HOME` shells.
- **The Notifications service renders nowhere** — `notify.dart` has zero widget
  consumers; cli_install's dogfood warnings vanish into an unrendered list
  while `ToastService` sits right there.
- **Welcome screen no-ops**: "Clone from git…" and "Start a Claude session"
  advertise shortcuts that don't exist and do nothing on tap
  (`welcome_view.dart:173-174`).
- **`make test-e2e`/`ui-dev`/`ui-smoke` are dead** — `tools/ui/*.sh` still `cd`
  into the removed `app/` directory; the staged Gitea CI workflow would fail in
  three independent ways on activation, while D-32 calls it "ready."

### 🐀 Rats (low, but they breed)

Dead code worth a one-day extermination sweep: the entire legacy free-function
git API (~250 LOC duplicating `GitClient`, kept alive only by tests, *with its
own latent pipe-deadlock bug*), `ToolCheck`, ~60% of `ffi/libc.dart` (fd-passing
era), `GraphView` (unreachable placeholder), `ColumnHat` (duplicated
line-for-line in app.dart, kept alive by a zero-coverage test), the tmux-era
team pipeline (`TranscriptPublisher`, `TeamMemberJoined` — *nothing emits these
events*, yet the team roster UI still listens to them exclusively, meaning team
tiles are populated by ghosts), the dead `ptyc` binary still committed in
`native/linux-x64/` against D-62/D-63, and `mocktail` — pinned, documented in
D-25 as the IO-mocking strategy, and imported by exactly zero files.

---

## Part III — Patterns I would change (the systemic stuff)

1. **Broadcast streams that carry state need replay-latest.** This one shape
   caused T-274, the meta sidebar's manual compensation, and the
   prompt-stream's `initialData` workaround. Write a tiny `ValueStream` wrapper
   once; retrofit `statusStream`, `busyStream`, `pendingPromptStream`.

2. **Ban `catch (_) {}` on I/O and lifecycle paths.** The silent-swallow idiom
   turned an illegal-lookup-in-dispose into two resource leaks and turned
   process-spawn failures into blank panes. Cleanup paths may swallow; spawn,
   read, and dispose paths must log through the kernel Logger they already have.

3. **Sync I/O in async handlers on the single isolate.** `files.read` does a
   sync 10MB read; the replace engine reads and rewrites the workspace
   synchronously *while grep right next to it fans out to isolates per D-79*.
   Decide the rule (offload above N KB), write it into a D-record, apply it.

4. **Path confinement belongs at the dispatch layer, not per-verb.** files.read
   remembered, search.replace half-remembered, editor.* forgot. A confinement
   check keyed off the co-registered schema (the registry already knows which
   params are paths) ends the per-verb lottery.

5. **Copy-paste is the repo's main duplication tax.** The welcome screen clones
   FileActions' entire open-folder flow verbatim; palette and quick-open are
   ~230-line near-twins; three private "tail a growing file" implementations in
   the claude builtin alone; five hand-rolled `_userErr` helpers; five
   copy-pasted git test sandboxes (none isolating host git config); two
   parallel ANSI flag enums that already drifted (strikethrough is stored but
   never painted). Each is small; together they're how a solo-dev repo rots.

6. **Hand-enumerated lists drift; export the truth.** Bundled themes (already
   drifted between `main.dart` and the testmode harness — catppuccin is
   silently unvalidated), a11y gate subjects, i18n namespaces. One exported
   const each, consumed by both sides.

7. **The claude builtin returns `ok` with an `error` payload in 16 handlers**,
   drifting from the D-6 exit-code contract every other subsystem honors. A
   scripted `clide claude.agent.set-permission-mode bogus` exits 0 today.

8. **God-files**: `app.dart` (1187 LOC, five concerns — split plan is in the
   findings), `claude_meta_sidebar.dart` (1192), `parser.dart` (1139, T-123
   already exists — and the split should also fix `_consumeCsi` discarding
   intermediate bytes, which permanently blocks DECSCUSR/DECSTR).

9. **Docs drift at the front door**: CLAUDE.md and README still say "tmux owns
   Claude session persistence (D-41)" — superseded by D-75/D-77 per
   `docs/architecture.md`; README says "Pre-v2.0 (2.0.0-dev)" at v2.3.3 and
   headlines "canvas and graph surfaces" that are a 17-line stub and a flat
   ListView respectively. clide's honesty is its brand; the README is the one
   place currently off-brand.

10. **Close the release loop.** Five CHANGELOG releases since the last git tag;
    `ci/release.sh` exits 64 and references the dissolved sidecar; the pre-push
    fast path's safety argument cites "release CI on tagged versions" that
    doesn't exist; and the fast path skips ALL tests for pushes touching
    `test/`, `ci/`, or the hook itself. Back-tag 2.2.0–2.3.3, add tagging to
    the git-commit skill ritual, widen the fast-path regex. (This is also the
    blocking prerequisite your own T-47 refinement identified for self-update.)

---

## Part IV — Killer features (the dragon hoard)

Five ideation lenses, 27 proposals, deduplicated and ranked. The convergence
test mattered: **two lenses independently invented the flight recorder, and two
independently invented the visual canvas round-trip** — when separate agents
with different briefs land on the same feature, that's the market talking.

Clide's structural moats, verified against code: it *spawns and owns* the agent
process (D-77/D-78) where competitors are sandboxed extension guests; it owns
every pixel (terminal, markdown, canvas); everything is local-and-committed
(transcripts, costs, decisions, tickets) where competitors' business models
require cloud custody; and the pql vault is structured planning data no
mainstream IDE has an analogue for.

### Tier 1 — do these (high leverage, mostly M-effort, plumbing exists)

1. **Agent Blame + Session Flight Recorder** `[L]` — gutter action on any line:
   *which session, which turn, which prompt, which permission grant, what it
   cost* — opening the native conversation at the exact `tool_use`. Timeline
   scrubber to replay a session. The transcript pipeline
   (`transcript_reader.dart`, `session_index.dart`) already parses everything
   needed. Cursor/Copilot cannot ship this: their logs live server-side by
   business design. *Two lenses converged here.*

2. **Context X-ray** `[M]` — per-card token attribution ("this 40KB Bash tail
   is 12% of your window") + a real compaction indicator. `stream_json_session.dart`
   already parses usage and contextWindow per event; the renderer owns the
   cards. Fixes T-244 (invisible compaction) as a side effect. Context is the
   scarcest resource in agent pairing and every tool renders it as one opaque
   percentage.

3. **Trust Ledger + decision-aware permission prompts** `[M]` — every
   permission rule with provenance (which prompt, which session, which ticket),
   ticket-scoped expiry; and when a `can_use_tool` request arrives, chip the
   relevant D-record onto the card (edit touching pubspec.yaml → D-31
   prefer-zero-deps, one keystroke to deny *with the decision cited*).
   Governance stops being documentation and becomes live agent policy. No
   competitor has a queryable in-repo decision system to even attempt this.

4. **Agent Activity HUD** `[M]` — four backlog tickets and one open question
   are secretly one feature: build T-59's `OperationsRegistry` once and feed it
   git/pql progress (T-59), sidebar badges (T-58), compaction state (T-244),
   the status strip (T-274), with Q-34's budget slot reserved. Fix the T-274
   plumbing bug first or the HUD inherits blank-slot syndrome.

5. **Active Ticket Context** `[S]` ← *cheapest win in the whole list* — picking
   up a ticket binds it to the session: a "working on T-244" chip, auto
   `in_progress` flip, `(T-NNN)` pre-suggested in commit messages, changelog
   reminder on done. Makes kanban ambient instead of homework, and makes every
   trail/ledger feature below reliable.

### Tier 2 — the differentiators (L/XL, each could headline a release)

6. **Twin-timeline rewind** `[L]` — snapshot the worktree as hidden git refs
   (`git write-tree` → `refs/clide/checkpoints`) at every turn boundary, keyed
   to turn uuid; every user-message card gains "restore files to before this."
   Claude's `/rewind` only restores what Claude itself edited; clide owns both
   timelines.

7. **Visual Dialog** `[L]` — one bidirectional scene schema: Claude draws
   (D-91 canvas cards), the user annotates in the interaction zone (T-260), and
   the annotations return as *structured geometry + flattened PNG*, not prose.
   Merge the T-317/T-318 and T-260 specs into one protocol before they become
   two dialects. *Two lenses converged here.*

8. **Immortal terminals** `[M]` — T-258 (terminal as editor-mode peer) fused
   with T-325 live-tails: any long process — user shell *or* agent-spawned
   build — promotes to a full tmux-backed surface that survives restart.
   "The build that never dies" is structural for clide, a plugin fantasy for
   Electron. Resolve Q-27 (swap vs split) as part of it, as T-258 already notes.

9. **Local cost ledger** `[M]` — per-turn cost/tokens persisted against the
   active pql ticket; the board shows what each feature actually cost.
   Flat-subscription opacity is the competitors' business model; turn-level
   local cost data is clide's birthright. (Tokens primary, dollars advisory —
   subscription auth reports notional costs.)

10. **Label-routed work queues / ticket dispatch** `[M→XL]` — T-277 labels +
    the shipped pick-up path turn the board into an agent control surface;
    the XL extension dispatches a ticket to a teammate session in an isolated
    git worktree (SpawnSpec.cwd already exists). Local, no-telemetry
    background agents with the work item, isolation, review surface, and audit
    trail all in-repo.

### Tier 3 — moonshots (XL, pick one per quarter, they compound)

11. **Semantic terminal** — OSC 133 markers (clide spawns the shell, injection
    is trivial) lift scrollback into foldable command regions with recognizers
    for test runners and stack traces; real widgets between rows is something
    xterm.js structurally cannot do. *Note: fix the scrollback-unreachable bug
    first — a semantic scrollback you can't scroll is a koan.*
12. **Living codebase map** — tree-sitter imports + pql links + git churn on
    the owned canvas, with live agent heat from `tool_use` events: watch Claude
    *move through your codebase* in real time.
13. **Live mixed documents** — fenced blocks in the owned markdown renderer
    become live embeds (canvas scenes, pql query results, decision cards,
    confirm-gated command buttons). Notebook-grade, zero webview. The
    `ClideMarkdownHooks` seam already exists.
14. **Remote Claude over SSH** — T-329 is fully ticketed and undersold: agent
    on the buildbox, permission prompts rendering natively local. VS Code
    Remote moves the editor; nobody remotes the *agent control channel*.
15. **Sealed-workspace mode** — an egress-audit proxy around the whole agent
    stack, operationalizing D-60/D-64 into a provable property. The one
    feature in this list competitors *cannot* copy without breaking their own
    products.

### Honorable mentions

Plan-to-Board bridge (ExitPlanMode approval files the plan as a ticket tree),
Release Cockpit (renders `[Unreleased]` with word-count badges + one-action
release cut — would also unstall Part III #10), Daily Helm ("since you were
last here" pulse on the welcome screen, computed from data the repo already
commits), Total-recall conversation search (D-79 grep over the transcript
corpus + fork-from-here), Shared Gaze (attach editor selection/scroll context
to each outgoing turn), Speakable Layouts (`clide layout apply review.yaml` —
the agent stages your workspace), Agent fleet tray (enumerate per-workspace
sockets, show every repo's agent state — *requires fixing T-247's stale-socket
litter first*), Governance Graph (the D/Q/R/T web as a navigable map — gives
the placeholder graph view a flagship dataset).

---

## Part V — If I were you, Monday morning

1. **One leak-fix commit**: PTY fd on natural exit + kernel-lookup-in-dispose
   (terminal & claude panes) + project-switch service disposal. Three findings,
   one theme, one afternoon.
2. **One Claude-resilience commit**: drain stderr, watch exitCode, seed status
   on bind, gate auto-scroll on `_atBottom`. The flagship pane stops having
   silent failure modes.
3. **One security commit**: MCP auth token + editor.* path confinement +
   search.replace glob filter + symlink-walk fix.
4. **One rat-extermination day**: dead git API, ToolCheck, libc bindings,
   ColumnHat, GraphView, tmux-era team pipeline, ptyc binary, mocktail. The
   diff is gloriously red and the coverage denominator thanks you.
5. **Tag your releases.** Five releases of honest changelog work are currently
   unaddressable commits.
6. Then go build the **Active Ticket chip** (S!) and the **Context X-ray**, and
   let clide start showing people things no other IDE can.

---

*Findings methodology: every medium/high claim above survived an independent
adversarial re-read of the cited lines (one claim did not — the proposed
"can't-disable core extensions" guard, which D-14 deliberately rejects, so it
stays out of this report). The full per-finding evidence, severities, and
suggested fixes live in the review transcripts; ~34 additional low-severity
findings were verified by citation only.*

*— Fable, 2026-06-11*
