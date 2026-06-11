# Open Questions — Design

Feature proposals from the 2026-06-11 Fable review (fable-ous.md Part IV,
epic [T-359]). Each asks the same question — are we going to implement this
feature? — so the answer can resolve into a D-record (and an initiative
ticket) or an R-record. Effort tags `[S/M/L/XL]` come from the review.

---

### Q-35: Agent Blame + Session Flight Recorder — implement?
- **Status:** Open
- **Question:** Are we going to implement agent blame — a gutter action on any line answering *which session, which turn, which prompt, which permission grant, what it cost*, opening the native conversation at the exact `tool_use` — plus a timeline scrubber to replay a session? `[L]`
- **Context:** Two ideation lenses independently invented this. The transcript pipeline (`transcript_reader.dart`, `session_index.dart`) already parses everything needed. Cursor/Copilot cannot ship it: their logs live server-side by business design — local-and-committed transcripts are a structural moat.
- **Source:** fable-ous.md Part IV, Tier 1 #1 (2026-06-11 Fable review).

### Q-36: Context X-ray — implement?
- **Status:** Open
- **Question:** Are we going to implement per-card token attribution ("this 40KB Bash tail is 12% of your window") plus a real compaction indicator? `[M]`
- **Context:** `stream_json_session.dart` already parses usage and contextWindow per event; the renderer owns the cards. Would fix T-244 (invisible compaction) as a side effect. Context is the scarcest resource in agent pairing and every tool renders it as one opaque percentage.
- **Source:** fable-ous.md Part IV, Tier 1 #2 (2026-06-11 Fable review).

### Q-37: Trust Ledger + decision-aware permission prompts — implement?
- **Status:** Open
- **Question:** Are we going to implement a permission-rule ledger with provenance (which prompt, which session, which ticket; ticket-scoped expiry), and decision-aware prompts that chip the relevant D-record onto a `can_use_tool` card (edit touching pubspec.yaml → [D-31](../decisions/tooling.md#d-31-prefer-zero-deps-exact-pin), one keystroke to deny *with the decision cited*)? `[M]`
- **Context:** Governance stops being documentation and becomes live agent policy. No competitor has a queryable in-repo decision system to attempt this. Builds on the D-78 interaction-zone prompt surface.
- **Source:** fable-ous.md Part IV, Tier 1 #3 (2026-06-11 Fable review).

### Q-38: Agent Activity HUD — implement?
- **Status:** Open
- **Question:** Are we going to build the `OperationsRegistry` (T-59) once and feed it git/pql progress (T-59), sidebar badges (T-58), compaction state (T-244), and the status strip (T-274), with [Q-34](architecture.md#q-34-how--when-to-surface-the-accountteam-token-budget-given-upstream-doesnt-expose-it)'s budget slot reserved? `[M]`
- **Context:** Four backlog tickets and one open question are secretly one feature. Prerequisite: fix the T-274 plumbing bug first or the HUD inherits blank-slot syndrome (root cause is on T-274; the ValueStream retrofit is T-386).
- **Source:** fable-ous.md Part IV, Tier 1 #4 (2026-06-11 Fable review).

### Q-39: Active Ticket Context — implement?
- **Status:** Open
- **Question:** Are we going to bind picking up a ticket to the session — a "working on T-NNN" chip, auto `in_progress` flip, `(T-NNN)` pre-suggested in commit messages, changelog reminder on done? `[S]`
- **Context:** Cheapest win in the review's whole feature list. Makes kanban ambient instead of homework, and makes trail/ledger features (Q-35, Q-43) reliable by giving every turn a ticket anchor.
- **Source:** fable-ous.md Part IV, Tier 1 #5 (2026-06-11 Fable review).

### Q-40: Twin-timeline rewind — implement?
- **Status:** Open
- **Question:** Are we going to snapshot the worktree as hidden git refs (`git write-tree` → `refs/clide/checkpoints`) at every turn boundary, keyed to turn uuid, so every user-message card gains "restore files to before this"? `[L]`
- **Context:** Claude's `/rewind` only restores what Claude itself edited; clide owns both timelines. Needs a retention/GC policy for the checkpoint refs.
- **Source:** fable-ous.md Part IV, Tier 2 #6 (2026-06-11 Fable review).

### Q-41: Visual Dialog — one bidirectional scene schema — implement?
- **Status:** Open
- **Question:** Are we going to define one bidirectional scene schema where Claude draws ([D-91](../decisions/architecture.md#d-91-unified-conversation-drawing-card-backed-by-a-canvas-renderer) canvas cards), the user annotates in the interaction zone (T-260), and annotations return as *structured geometry + flattened PNG*, not prose?
- **Context:** Two lenses converged here. The T-317/T-318 and T-260 specs should merge into one protocol *before* they become two dialects — this question is urgent in ordering even if the build is later. `[L]`
- **Source:** fable-ous.md Part IV, Tier 2 #7 (2026-06-11 Fable review).

### Q-42: Immortal terminals — implement?
- **Status:** Open
- **Question:** Are we going to fuse T-258 (terminal as editor-mode peer) with T-325 live-tails so any long process — user shell *or* agent-spawned build — promotes to a full tmux-backed surface that survives restart? `[M]`
- **Context:** "The build that never dies" is structural for clide, a plugin fantasy for Electron competitors. Resolving [Q-27](architecture.md#q-27-two-editor-split) (swap vs split) is part of it, as T-258 already notes.
- **Source:** fable-ous.md Part IV, Tier 2 #8 (2026-06-11 Fable review).

### Q-43: Local cost ledger — implement?
- **Status:** Open
- **Question:** Are we going to persist per-turn cost/tokens against the active pql ticket so the board shows what each feature actually cost? (Tokens primary, dollars advisory — subscription auth reports notional costs.) `[M]`
- **Context:** Flat-subscription opacity is the competitors' business model; turn-level local cost data is clide's birthright. Depends on Q-39 (active ticket binding) for reliable attribution.
- **Source:** fable-ous.md Part IV, Tier 2 #9 (2026-06-11 Fable review).

### Q-44: Label-routed work queues / ticket dispatch — implement?
- **Status:** Open
- **Question:** Are we going to turn the board into an agent control surface — T-277 labels + the shipped pick-up path routing work queues, with an XL extension dispatching a ticket to a teammate session in an isolated git worktree (`SpawnSpec.cwd` already exists)? `[M→XL]`
- **Context:** Local, no-telemetry background agents with the work item, isolation, review surface, and audit trail all in-repo.
- **Source:** fable-ous.md Part IV, Tier 2 #10 (2026-06-11 Fable review).

### Q-45: Semantic terminal — implement?
- **Status:** Open
- **Question:** Are we going to inject OSC 133 markers (clide spawns the shell, injection is trivial) to lift scrollback into foldable command regions, with recognizers for test runners and stack traces, and real widgets between rows? `[XL]`
- **Context:** xterm.js structurally cannot do widgets between rows. Hard prerequisite: the scrollback-unreachable bug (in T-378) — a semantic scrollback you can't scroll is a koan.
- **Source:** fable-ous.md Part IV, Tier 3 #11 (2026-06-11 Fable review).

### Q-46: Living codebase map — implement?
- **Status:** Open
- **Question:** Are we going to render tree-sitter imports + pql links + git churn on the owned canvas, with live agent heat from `tool_use` events — watching Claude move through the codebase in real time? `[XL]`
- **Context:** Needs the canvas surface (T-317 family) and the tree-sitter FFI work to be solid first.
- **Source:** fable-ous.md Part IV, Tier 3 #12 (2026-06-11 Fable review).

### Q-47: Live mixed documents — implement?
- **Status:** Open
- **Question:** Are we going to make fenced blocks in the owned markdown renderer live embeds — canvas scenes, pql query results, decision cards, confirm-gated command buttons? Notebook-grade, zero webview. `[XL]`
- **Context:** The `ClideMarkdownHooks` seam already exists.
- **Source:** fable-ous.md Part IV, Tier 3 #13 (2026-06-11 Fable review).

### Q-48: Sealed-workspace mode — implement?
- **Status:** Open
- **Question:** Are we going to build an egress-audit proxy around the whole agent stack, operationalizing [D-60](../decisions/tooling.md#d-60-no-network-on-default-launch-path)/[D-64](../decisions/architecture.md#d-64-no-telemetry--architectural-commitment) into a provable property? `[XL]`
- **Context:** The one feature in the review's list competitors cannot copy without breaking their own products.
- **Source:** fable-ous.md Part IV, Tier 3 #15 (2026-06-11 Fable review).

### Q-49: Review honorable mentions — which, if any, get promoted?
- **Status:** Open
- **Question:** Which of the review's honorable mentions, if any, do we promote to tickets: Plan-to-Board bridge (ExitPlanMode approval files the plan as a ticket tree), Release Cockpit (renders `[Unreleased]` + one-action release cut — would also unstall the release-loop story T-393), Daily Helm (since-you-were-last-here pulse on the welcome screen), Total-recall conversation search (D-79 grep over the transcript corpus + fork-from-here), Shared Gaze (attach editor selection/scroll context to outgoing turns), Speakable Layouts (`clide layout apply review.yaml`), Agent fleet tray (per-workspace sockets — requires T-247's stale-socket fix first), Governance Graph (the D/Q/R/T web as a navigable map)?
- **Context:** Kept as one record to avoid fifteen low-signal questions; promote individually as appetite appears.
- **Source:** fable-ous.md Part IV, honorable mentions (2026-06-11 Fable review).

---
