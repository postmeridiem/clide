---
name: clean-house
description: >
  Run a documentation-discipline pass over a DQR (Decisions / Questions /
  Rejected) markdown system. Audits decisions/, surfaces drift (broken
  anchor links, missing Q→D backlinks, sunset-shaped phrases without
  linked tickets, files over the split threshold, dead cross-references),
  batches findings by category, and uses AskUserQuestion to apply fixes
  interactively. Trigger this skill whenever the user asks to clean,
  tidy, audit, sweep, garden, or review the state of decisions/, the
  DQR system, the questions index, or the records under decisions/.
  Also trigger before a release, after a session that touched many
  records, or whenever the user mentions documentation drift, stale
  plans, or "house" / "clean-house" / "house cleaning". Imperative —
  apply fixes, not just report.
---

# clean-house

A periodic gardening pass over `decisions/`. The DQR system is
markdown-as-source-of-truth; `.pql/pql.db` is a derived index. This skill
operates on the markdown files, batches drift by category, and uses
`AskUserQuestion` to decide what to apply.

The skill is **imperative**. It really cleans. The verb-noun match is
load-bearing — a `clean-house` that only produced a report would be
misnamed. Mechanical fixes get a single batched approval, judgment-call
findings get individual prompts, and a "stop asking" escape hatch is
always present.

You — Claude — are the runtime. Read this file, read
`references/rules.md`, follow the procedure below, call `pql` and `Edit`
to do the work, call `AskUserQuestion` for the prompts.

## When to run

- Before a release.
- After a session that touched many D / Q / R records.
- When something feels stale and a sweep is wanted.
- When `pql decisions validate` is green but `decisions/` still feels off.

This skill is **not** a replacement for `pql decisions validate`.
Validate is fast, hot, and gates pre-push. clean-house is slow, cold,
on-demand. Escalation path: rules that fire often here are candidates
for promotion to `pql decisions validate`; rules that almost never fire
stay here where false positives don't slow anyone down.

## Procedure

1. **Gate on validate.** Run `pql decisions validate`. If it exits
   non-zero, stop and tell the user to fix validator findings first.
   Do not proceed.

2. **Load the rule catalog.** Read `references/rules.md`. Each rule
   names its detection, fix, and finding-id format.

3. **Probe conventions.** Read `decisions/.clean-house.yaml` if it
   exists; otherwise infer from the project. Conventions to resolve:
   - `heading_level`: 2 or 3 — the depth records use (`## D-N` vs
     `### D-N`). Probe by sampling the first 3 records' file
     locations and looking for the first matching ATX heading.
   - `backlink_phrasing`: the project's Q→D backlink phrase (default
     `Resolved → D-N`; some projects use `Resolved as D-N` or
     `→ D-N`).
   - `file_threshold`: default 350 (RULE-FILE-OVER-THRESHOLD).
   - `stale_open_q_days`: default 60 (RULE-STALE-OPEN-Q).

   Pass the resolved conventions into each rule's detection. Cache
   the probe result for the run.

   `decisions/.clean-house.yaml` shape (all keys optional):
   ```yaml
   heading_level: 3
   backlink_phrasing: "Resolved → "
   file_threshold: 500
   stale_open_q_days: 90
   exclude_paths: ["legacy/", "drafts/"]
   ```

4. **Sync the index.** Run `pql decisions sync` so the DB reflects
   the markdown.

5. **Walk decisions/.** Use `pql decisions list` to enumerate
   records, plus `pql decisions read <id>` per record when a rule
   needs the body. For file-level rules (size, sort), read the
   markdown files directly. **Filter out** any record whose
   `file_path` begins with `legacy/` (or any prefix in
   `exclude_paths` from the probe).

6. **Run each rule's detection.** Collect findings. Tag each with
   its rule ID, finding ID (per the rule's format), category
   (`mechanical` | `judgment`), and the record(s)/file(s) involved.

7. **Group findings by rule** and prompt. Honor any "skipped 3+
   times" findings from the skip ledger by escalating their prompt
   ("skipped 3x — promote to manual decision, downgrade to
   summary-only, or keep asking?"):

   - **Mechanical rules** — one prompt per rule, batched. Show the
     count and offer: apply all / show diff first / skip this rule /
     **stop asking** (global — see below).
   - **Judgment rules** — one prompt per finding. Options match the
     rule's `Fix` section, plus the same global **stop asking**.

   **"Stop asking" semantics (global).** When the user picks "stop
   asking" on any prompt, immediately halt all further prompts in
   the run — mechanical batches not yet asked AND remaining
   judgment findings. Move all unprompted findings to the skip
   ledger marked `deferred-stop-asking`. Skip to step 9.

   **"Show diff first" loop.** When the user picks "show diff
   first" on a mechanical batch, emit a unified diff of the staged
   edits (one block per file), then re-prompt the same question
   with the same options minus "show diff first" — preventing
   infinite loops while still letting the user inspect before
   committing.

8. **Apply approvals.** For mechanical rules use `Edit` to mutate
   the markdown directly. For judgment rules, follow the option the
   user picked (file a ticket via `pql ticket new`, mark superseded
   by editing the record, etc.).

9. **Update the skip ledger and history.** Both files live at
   `decisions/.clean-house-state.md`, gitignored. The file uses
   per-run section headers so it doubles as run history:

   ```markdown
   # clean-house run history

   ## 2026-05-06T13:42Z
   fired: RULE-ANCHOR-DRIFT(1) RULE-SUNSET-WITHOUT-TICKET(1)
   applied: RULE-ANCHOR-DRIFT(1) RULE-SUNSET-WITHOUT-TICKET(1)
   skipped:
     - RULE-ANCHOR-DRIFT D-8:#q-1-markdown-mirror-for-tickets

   ## 2026-05-04T11:10Z
   fired: ...
   ```

   Each section starts with a UTC ISO-8601 timestamp. `fired`
   counts findings detected; `applied` counts findings the user
   acted on; `skipped` lists `<rule-id> <finding-id>` pairs.

   **Promotion-candidate computation.** Scan the most recent N=7
   sections (or all sections if fewer). A rule is a promotion
   candidate if it `fired` in ≥ 5 of those sections. Surface the
   candidates in the summary; do not auto-promote.

10. **Emit the summary** (see Output below).

## Question phrasing

Always include the rule ID in the prompt so the user learns what's
being checked.

**Mechanical (batched):**
> RULE-ANCHOR-DRIFT: 12 cross-reference anchors point to headings that
> no longer exist (renamed or deleted). Apply all 12 fixes? Options:
> apply all / show diff first / skip this rule / stop asking, summarize
> the rest.

**Judgment (individual):**
> RULE-SUNSET-WITHOUT-TICKET: D-59 mentions "must track dugite-native
> releases for security updates" but has no linked T. Options: file T
> now / draft a T description first / mark as already covered (add note
> to D) / skip / stop asking.

Phrasing rules:

- **Always include "stop asking, summarize the rest."** Sessions
  without bandwidth for full review need an escape. Forcing answers
  to every question kills the tool.
- **Always include "skip."** Skipped findings go to the ledger; three
  consecutive skips of the same finding promote the next prompt.
- **Mechanical batches; judgment doesn't.** "Apply all 12 fixes?" is
  one decision against a clear delta. Twelve individual prompts defeat
  the point. Conversely, judgment findings are each separate work —
  presenting them as a batch hides cost.

## What this skill does NOT do

- Does not file tickets without asking.
- Does not rewrite D-record body prose, only metadata fields and
  cross-reference links.
- Does not touch records under `legacy/`.
- Does not run `pql decisions validate` *as a fix* — only as a
  precondition gate.
- Does not promote rules to `pql decisions validate` automatically.
  Promotion is a human decision; this skill only flags candidates
  ("RULE-X has fired in 5 of the last 7 runs — consider promoting").

## Non-interactive context

If invoked without an interactive `AskUserQuestion` surface (a CI run,
a batch script), refuse to apply judgment fixes. Apply mechanical
fixes only if the user explicitly says so via the trigger phrase
("auto-apply mechanical, skip judgment"); otherwise emit the summary
and exit without mutating files.

## Output

At the end, emit a summary block:

```
clean-house — sweep complete
────────────────────────────
Files scanned:        11
Records parsed:       62 D, 23 Q, 11 R
Conventions:          heading_level=3 backlink="Resolved → "
Mechanical fixes:     14 applied, 0 deferred
Judgment findings:    3 acted on, 2 deferred (in state file)
Promotion candidates: RULE-ANCHOR-DRIFT (5/7 runs)
Touched files:        decisions/architecture.md, decisions/questions.md
```

If this is the first run (no prior history) or there are fewer
than 5 prior runs, `Promotion candidates:` reports
`(none — N/7 runs of history)` instead of decorative empty content.

The summary names the touched files so the next commit message can be
honest about what changed. The skill does not commit on its own.

## Versioning

clean-house ships embedded in the pql binary; its version is the
pql version (`pql --version`). To see what changed and when, read
`CHANGELOG.md` or `git log internal/skill/clean-house/` in the pql
repo. Keep this file and `references/rules.md` consistent with
each other when iterating — they're the contract.
