# Spike: Claude Code team / transcript internals (T-134)

**Pinned to:** claude **2.1.148**, tmux **3.6a**. These are undocumented, version-drifting
internal contracts (per D-75) — re-validate on a CC bump.

**Method:** validated from real on-disk artifacts (42 past team `config.json`s, real
team + Task-tool subagent transcripts, `.meta.json` written by the current version) plus
a synthetic `tmux -L clide` control-mode test and the tmux manual. No live team run was
needed to answer the questions — the existing artifacts are conclusive and cost no quota.

---

## Findings

### 1. Teammates get tmux panes; transcripts live under `subagents/`
- **Confirmed:** across real teams, **42 teammate members carry a populated `tmuxPaneId`**
  (e.g. `%5`, `%120`); the lead's `tmuxPaneId` is `""`. So teammates spawn as panes and the
  config records the pane id.
- **Teammate transcript location:** `~/.claude/projects/<munged-cwd>/<session-id>/subagents/agent-<hex>.jsonl`,
  with a sibling `agent-<hex>.meta.json`. `<munged-cwd> = absolutePath.replaceAll('/','-')`
  (leading `-` kept). Note: a team's `<session-id>` dir held **0 top-level `*.jsonl`** and
  **44 `subagents/agent-*.jsonl`** — teammate content is the subagent files, not top-level sessions.
- Each subagent record carries `agentId` (the **hex**, e.g. `a2a3530` — matches the filename),
  `sessionId` (the dir), `isSidechain: true`, `slug` (a random codename), `type`
  (`user`/`assistant`/…). This is the same JSONL schema `TranscriptReader` (T-136) already parses.

### 2. Lifecycle signal — control mode vs. polling
- **tmux 3.6a control-mode notifications** (from `man tmux`): `%window-add`, `%window-close`,
  `%window-pane-changed`, `%layout-change`, `%unlinked-window-add`, `%unlinked-window-close`,
  `%session-changed`, `%sessions-changed`, `%pane-mode-changed`, `%exit`, `%output`/`%extended-output`, …
  **There is NO `%pane-died`** (an-idea.md assumed one). Pane/teammate exit surfaces via
  `%window-close` / `%layout-change` / `%window-pane-changed`.
- **Driving control mode from code is finicky:** a `tmux -L clide -C attach` captured
  `%session-changed`/`%exit` but the attach exited early under non-interactive Bash; reliably
  consuming the stream needs a long-lived managed client.
- **Polling `tmux -L clide list-panes -a -F '...'` works and is reliable** (validated: it
  enumerated panes with pane-id/pid/title). **Recommendation for T-139: use polling as the
  baseline lifecycle source**; treat control mode as a later optimization.

### 3. Team config schema (`~/.claude/teams/<team>/config.json`)
- Top keys: `name`, `description`, `createdAt`, `leadAgentId`, `leadSessionId`, `members[]`.
- Member keys: `name`, `agentId` (=`<name>@<team>`), `agentType`, `model`, `cwd`,
  `joinedAt`, `subscriptions`, `tmuxPaneId`. (Some runs also carry `backendType`/`isActive`/`mode` —
  optional, version-varying.) The lead member has empty `tmuxPaneId`.

### 4. ⚠️ Identity linkage — the real risk for T-139
The pane/teammate identity in **config** does NOT share a key with the **transcript file**:
- Config: `{name: gestalt, agentId: gestalt@control-interaction, agentType: gestalt, tmuxPaneId: %120}`.
- Transcript: `agent-<hex>.jsonl` (records `agentId = <hex>`, `slug = <random>`) +
  `agent-<hex>.meta.json = {agentType, description}`.
- **The only join key is `agentType`** (config.member.agentType ↔ `.meta.json.agentType`).
  This is **unambiguous only when teammates have distinct agentTypes** (e.g. `control-interaction`:
  gestalt/ozzie/tyre/…). For **same-type teammates** (e.g. `art-requirements`: 3× `general-purpose`)
  agentType is ambiguous → need a disambiguator: spawn order / `joinedAt` timestamp vs. file mtime,
  or parse the **lead transcript's** teammate-spawn records (likely carry both ids). **T-139 must
  handle this**; recommend: join on agentType, fall back to ordering by `joinedAt`/mtime, and
  investigate the lead transcript's spawn events for an explicit hex↔name link.

### 5. Resolved elsewhere
- **Session-id discovery (check 5):** Claude doesn't expose its session id; pick newest `*.jsonl`
  by mtime — already implemented in `TranscriptReader` (T-136).
- **Paste (check 4):** scope to `@path` file references over `send-keys` (text channel). Clipboard
  image paste needs an interactive display ($DISPLAY) and is out of scope for headless validation;
  decide the composer's image handling in T-138/T-006.

## Recommendations for the team tickets
- **T-139 (observer):** poll `list-panes -a` for lifecycle; read team `config.json` for the roster
  + pane ids; tail teammate transcripts at `<munged>/<sid>/subagents/agent-<hex>.jsonl`; resolve
  pane→transcript via `agentType` join with a `joinedAt`/mtime tiebreaker (and confirm whether the
  lead transcript gives an explicit link). Isolate all of this behind the one module (D-75).
- **Re-validate on any CC version bump** — key off the transcript `version` field.

## Not done
- A **live, real-time** team run (watching a pane + transcript appear live) was not executed —
  the static artifacts answer every question and a live run costs quota without adding certainty.
  The one item a fresh run would pin precisely: whether the **lead transcript** records an explicit
  teammate hex↔name mapping (would remove the same-type ambiguity). Worth a short observed run when
  T-139 is implemented.
