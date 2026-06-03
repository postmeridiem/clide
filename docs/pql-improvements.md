# pql — improvement notes from a live session

Feedback for [`postmeridiem/pql`](https://github.com/postmeridiem/pql), gathered
while using pql as the planning backend for the `clide` repo. Everything below
was observed first-hand, not inferred from docs.

**Environment**

- pql `1.5.0`, commit `ab191fb`, schema_version 1 (binary), DB schema_version 2.
- Consumer: a single-dev repo using pql for decisions + tickets, with pql's
  installed git hooks (`.pql/hooks/post-checkout`, `post-merge`, `post-rewrite`,
  `pre-commit`) and a git-tracked `.pql/changelog/` + `.pql/pql-plan.json`.

The core is genuinely good — structural queries, the decision/ticket model, exit
codes, and the changelog-as-source-of-truth idea all worked. The notes below are
where it bit us or surprised us, roughly in priority order.

---

## 1. CRITICAL — ticket mutations aren't persisted, and rebuild-on-checkout silently destroys them

**Observed.** `pql ticket new` (and `ticket status` / `ticket block`) write only to
`.pql/pql.db`, which is gitignored. Nothing writes through to the git-tracked
`.pql/changelog/` automatically. Separately, pql's installed `post-checkout` and
`post-merge` hooks run `pql plan rebuild`, which replays the **committed**
changelog and overwrites `pql.db`.

The two facts combine into silent data loss:

1. Created an 18-ticket tree (an initiative + 4 epics + tasks, with blockers and
   decision refs) via a series of `pql ticket new` calls. Verified present in
   `pql ticket list`.
2. A routine `git checkout` fired `post-checkout` → `pql plan rebuild` → `pql.db`
   was rebuilt from the changelog, which still ended at the previous max ticket.
3. All 18 tickets were gone. No warning, no prompt.

**Impact.** Total, silent loss of un-exported planning work on an ordinary git
operation. The user did nothing wrong — they switched branches.

**Repro.**
```bash
pql ticket new task "scratch ticket"   # lands in pql.db only
git checkout -b somebranch             # post-checkout runs `pql plan rebuild`
pql ticket list | grep "scratch"       # gone
```

**Suggested fixes** (any one closes the hole; (a) is the principled one):

- **(a) Write-through.** Have ticket/decision mutations append to the changelog
  at mutation time, making the changelog the log of record and `pql.db` a derived
  cache. Then rebuild is always safe.
- **(b) Divergence guard.** `pql plan rebuild` (and the hooks that call it) should
  detect when `pql.db` holds rows not represented in the changelog and refuse or
  loudly warn instead of overwriting — e.g. *"pql.db has 18 un-exported rows; run
  `pql plan export` first, or pass --force."*
- **(c) Non-destructive rebuild.** Merge the changelog into `pql.db` rather than
  replacing it.

At an absolute minimum, the `post-checkout`/`post-merge` hooks should not
discard local state without a word.

---

## 2. `pql plan export` writes the changelog, but docs/help say it writes a JSON snapshot

**Observed.** `pql plan export` wrote:
```
{"files_written":[".pql/changelog/ticket_deps/2026-06.sql",
                  ".pql/changelog/tickets/2026-06.sql"],"rows_written":23}
```
It did **not** touch `.pql/pql-plan.json`, which stayed frozen at an older date
across every mutation and export this session. But the `--help` text and the
bundled skill both describe export as *"Snapshot planning state to JSON (default:
`pql-plan.json`)"* and recommend committing `pql-plan.json`.

**Impact.** Users (and the bundled skill) commit `pql-plan.json` believing it is
the durable artifact. It is stale. The actually-durable artifact is the
changelog. This directly compounds #1 — people think they've versioned their
planning state when they haven't.

**Suggested fix.** Make `--help`, docs, and the embedded skill match real
behavior. Clarify the role of `pql-plan.json` vs `.pql/changelog/`: is the JSON
snapshot deprecated in favor of the changelog? If both exist, document which one
`pql plan import` / `pql plan rebuild` prefer.

---

## 3. Schema upgrade is a hard break requiring multi-step manual recovery

**Observed.** After a pql binary upgrade, every planning command failed:
```
$ pql decisions sync
planning: decision_refs.created_at missing — pql.db is from an earlier schema.
$ pql plan status
planning: decisions.created_at missing — pql.db is from an earlier schema.
```
(exit 69). Recovery was manual and multi-step: delete `pql.db`, `pql plan
rebuild`, then `pql decisions sync`.

**Impact.** All planning surfaces are dead until the user performs a manual
recovery they have to read out of the error text. Easy to get wrong (the error
also offers a `--legacy pql-plan.json` path — see #4).

**Suggested fix.** Auto-migrate the schema on open (additive column adds are
cheap), or ship a single `pql plan repair` / `pql migrate` command that performs
the safe delete-rebuild-sync sequence (with a backup of the old DB).

---

## 4. Schema-error recovery hint can point at the stale snapshot

**Observed.** The schema error (see #3) lists recovery options including
`pql plan import --legacy .pql/pql-plan.json`. Given #2 (that file is stale), a
user following that branch restores an out-of-date snapshot. The correct path
was the changelog rebuild.

**Suggested fix.** In the recovery list, prefer/recommend `pql plan rebuild` when
`.pql/changelog/` is present, and annotate the `pql-plan.json` option as
potentially stale.

---

## 5. Scripting ergonomics — no id-only output from `pql ticket new`

**Observed.** Building a ticket tree means capturing each created ticket's id to
use as the next call's `--parent`/blocker. `pql ticket new` emits the full ticket
JSON, so a creation script must parse `.id` out of every call.

**Suggested fix.** A `--quiet` / `--id-only` (or `-o id`) flag that prints just
the new `T-NNN`, so tree-creation scripts stay simple. (Determinism is already a
strength: re-running the same `new` calls in order against a clean baseline
reproduces the same ids — which is what let us recover from #1.)

---

## 6. Minor — bundled skill assumes binary features the installed version lacks

**Observed.** The bundled `pql` skill documents `pql ticket show --tree`,
`--leaf`, `--unblocked`, `--under`, and `pql ticket append` (annotated "pql ≥
1.6.0"). The installed binary reports 1.5.0 as current (`pql doctor` /
`pql skill status`), and rejects them:
```
$ pql ticket show T-65 --tree
unknown flag: --tree           # exit 64
```

**Impact.** A consumer following the skill hits unknown-flag errors and has to
discover the 1.5.0 fallbacks (`--with-children`, `--with-blockers`) by trial.

**Suggested fix.** Keep the embedded skill's documented surface in lockstep with
the binary it ships alongside, or have `pql skill install` stamp/gate
version-specific sections so the skill never advertises flags the paired binary
doesn't have.

---

## 7. Question-index regeneration drops the "Resolved questions" section

**Observed.** The repo keeps a human-readable index of decisions/questions in
`governance/README.md`, regenerated by `pql decisions sync` (run by the installed
hooks). After a sync, the regenerated index moves every *resolved* question back
into the main (open) list, in numeric order, and deletes the `## Resolved
questions` heading entirely. Concretely, Q-6, Q-19, Q-21, Q-22 are all
`status: resolved` per `pql decisions show`, yet the regenerated README lists
them as if open.

**Impact.** Two problems: (a) the index mislabels resolved questions as open, so
the doc lies about project state; and (b) because a hook regenerates it on every
sync/commit, it produces a persistent false-dirty diff — `git restore` it and the
next pql operation brings it back, so the working tree never stays clean.

**Repro.**
```bash
pql decisions show Q-6   # -> status: resolved
pql decisions sync       # regenerates governance/README.md
git diff governance/README.md
# Q-6/19/21/22 moved into the open list; "## Resolved questions" section gone
```

**Suggested fix.** The index generator should key each question's section off its
`status` (open vs resolved vs withdrawn) and keep resolved/withdrawn entries
under their own heading — i.e. round-trip the same structure it parses, so a
sync is idempotent and doesn't reclassify resolved questions.

---

## Summary

The one that matters most is **#1** — a routine `git checkout` can silently erase
planning work because mutations live only in a gitignored DB and the
pql-installed hooks rebuild that DB destructively. **#2** makes it worse by
pointing users at the wrong file to commit. Fixing write-through (or a divergence
guard) plus aligning the export docs would remove a whole class of "where did my
tickets go" incidents.
