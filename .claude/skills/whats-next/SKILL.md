---
name: whats-next
description: >
  Surface the best batch of tickets to pick up next from pql. Walks the
  initiative/epic tree, filters to unblocked work, refines context via
  parallel agents (or `pql ticket refine` for empty descriptions), and
  optionally activates the batch on a fresh branch. Use when the user
  says "what's next", "next batch", "pick up work", or invokes
  /whats-next. NOT triggered by "what should we work on" in a design
  context — that's a discussion, not a batch selection.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent, AskUserQuestion
---

# What's Next

Dependency-driven batch selection against pql. Three steps:
batch selection → refinement review → batch activation.

Pql is the single source of truth for tickets and decisions in this repo
(see [pql skill](../pql/SKILL.md) and [`decisions/README.md`](../../../decisions/README.md)). Always run from the repo root.

## Step 0: Sync state

Decisions on disk may be ahead of pql.db. Always sync before reading:

```bash
pql decisions sync
```

If `pql` is missing, stop and tell the user — don't fall back to grep.

---

## Step 1: Batch Selection

### 1a. Find active top-level work

Pql has no `milestone` concept; **initiatives** (and large **epics**) play
that role. List in-flight top-level work:

```bash
pql ticket list --status in_progress --pretty
pql ticket list --status ready --pretty
```

If nothing is `in_progress` or `ready` at the initiative/epic level,
fall back to `pql plan status --pretty` for a dashboard read and ask the
user which area to advance.

### 1b. Build the work landscape

For each candidate epic or initiative, expand its children:

```bash
pql ticket show <id> --with-children --pretty
```

Collect every leaf ticket (story/task/bug) underneath. Deduplicate.

### 1c. Filter to unblocked tickets

For each leaf with status `ready` or `backlog`, check blockers:

```bash
pql ticket show <id> --with-blockers --pretty
```

A ticket is **unblocked** if every blocker is `done` or `cancelled`.
Drop the rest.

### 1d. Rank and group

Rank unblocked tickets by:

1. **Priority** (critical > high > medium > low) — read from ticket fields.
2. **Epic proximity to done** — for each epic parent, compute
   `done_children / total_children`. Higher ratio ranks higher: finishing
   an epic unlocks downstream work and tightens the board.
3. **Fan-out** — tickets that unblock the most other tickets rank higher.
   Approximate by scanning `pql ticket list --status backlog --pretty`
   and counting how many list this ticket in their blockers (use
   `--with-blockers` per candidate, or read `--jsonl` once and reduce in
   memory).

Group into **epic-sized batches**: tickets sharing a `parent_id`, or a
logical cluster if no shared parent. If nothing groups naturally, batch
by area (the directory the work touches, e.g. `lib/src/pty/`).

### 1e. Show the board

```bash
pql ticket board --pretty
```

This is the "what's currently in flight" view — the user wants to see
WIP before committing to more.

### 1f. Present the recommended batch

Show the user:

- The recommended batch — IDs, titles, priorities, parent epic.
- **Why this batch** — which epic it advances, what it unblocks downstream.
- Current board state (WIP count vs. ready/backlog).
- One or two alternative batches worth considering.

Wait for user confirmation before Step 2.

---

## Step 2: Ticket Refinement Review

Two cases — handle the cheap one first.

### 2a. Tickets with empty descriptions → use pql

If any ticket in the batch has no description, hand off to pql's
built-in refinement flow:

```bash
pql ticket refine list --pretty
pql ticket refine next --pretty           # full context for the next one
pql ticket refine write T-NN '{"description":"..."}'
```

Walk these with the user (AskUserQuestion per ticket if appropriate)
before moving on.

### 2b. Tickets with descriptions → spawn refinement agents

For each ticket that already has a description but may still be
under-specified, spawn one agent in parallel. Use `general-purpose`
subagent_type (custom subagent_types lose SendMessage):

```
Agent({
  subagent_type: "general-purpose",
  model: "sonnet",
  description: "Refine T-NN context",
  prompt: "You are the Refinement Manager for ticket T-NN.

  Ticket: <title>
  Description: <body>
  Decision ref: <D-NN or Q-NN, if set>

  Your job:
  1. Run `pql decisions show <decision_ref> --with-refs --pretty` and
     read the linked D/Q-record in decisions/<domain>.md.
  2. Grep decisions/questions-*.md for related Q-records.
  3. Verify referenced files, classes, and APIs actually exist in the
     current tree (Read/Grep). Flag dangling references.
  4. Cross-check against CLAUDE.md guardrails (single process, CLI-first,
     own the rendering stack, etc.) — flag tickets that conflict.

  Assess: does an implementer have enough context to proceed without
  guessing? Report exactly one of:
  - READY: <one-paragraph summary of what the implementer needs to know>
  - GAPS: <list of specific ambiguities, each with 2–3 options>"
})
```

Run all agents in parallel (single message, multiple Agent tool calls).

### 2c. Resolve gaps

For each ticket that came back GAPS, surface ambiguities to the user
via AskUserQuestion. After the user resolves, append the resolution to
the ticket via pql:

```bash
pql ticket refine write T-NN '{"description":"<existing body>\n\n---\nRefinement: <resolution>"}'
```

If a gap really requires a new D-record (architectural choice, not just
detail), flag it. Ask whether to write the D-record now (`pql decisions
claim D <domain> "title"` then author the markdown) or defer with a note
on the ticket.

### 2d. Present refined batch summary

Per ticket:

- READY summary, or the resolution the user just gave.
- Linked D/Q-records.
- Remaining blockers (should be none — re-check if Step 1 was a while ago).

Ask: "Batch ready. Activate?"

---

## Step 3: Batch Activation

### 3a. Mark tickets in_progress

Batch transition (comma-separated IDs):

```bash
pql ticket status T-1,T-2,T-3 in_progress
```

### 3b. Branch? Default no.

Solo-dev flow on this repo — work lands directly on `main` (see recent
`git log`). Don't create a topic branch unless the user explicitly asks.
If they do, plain `git checkout -b` is fine; there is no `gh` CLI.

### 3c. Spawn implementation agents (optional)

If the user wants agents driving the work, spawn `general-purpose`
subagents (`model: sonnet`) per ticket. Each prompt should include:

- Ticket details + the refinement summary from Step 2.
- The full content of any linked D-record (Read it and inline it — don't
  just cite the ID; the agent has no project memory of it).
- Repo guardrails the work touches (from CLAUDE.md — quote the relevant
  bullets, don't link).
- A RULES block: write files only, no git commits, no destructive ops,
  message back when blocked or done.

### 3d. Report

End with a tight summary:

- Branch.
- Tickets now `in_progress`.
- Agents spawned (if any).
- Next step: implement, then commit per the [git-commit skill](../git-commit/SKILL.md).

---

## Anti-patterns

- Don't skip Step 0 — stale `pql.db` makes the rest of the skill lie.
- Don't activate a batch the user hasn't confirmed.
- Don't spawn refinement agents for tickets that have no description — use
  `pql ticket refine` instead; it's cheaper and writes back through the
  proper channel.
- Don't reach for `gh` — this system doesn't have it. Plain `git` only.
- Don't `cd` into subdirectories — run everything from the repo root.
