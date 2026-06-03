# clean-house rule catalog

The rules clean-house runs and the reasoning behind each. New rules
land here as their own entry. Catalog churn — additions, refinements,
retirements — is tracked in pql's `CHANGELOG.md` and `git log
internal/skill/clean-house/`. When a rule is retired, leave a
**Retired** stub (ID + one-line reason + retirement commit) so the
trail of "we used to check X" is recoverable from this file alone.

## Reading a rule

Each entry below has:

- **ID** — Stable identifier (e.g. `RULE-ANCHOR-DRIFT`). Used in
  AskUserQuestion prompts and skip-ledger entries so the user learns
  what's being checked.
- **Category** — `mechanical` or `judgment`. Drives whether findings
  batch into one prompt or each get their own.
- **Finding ID** — Format string for the per-finding stable
  identifier. Skip-ledger entries are written as `<rule-id>
  <finding-id> <ISO-date>`; subsequent runs use the same format to
  recognize "same finding skipped 3 runs in a row" and escalate.
  Use only stable inputs (record IDs, file paths, slug strings, body
  hashes) — never line numbers or timestamps.
- **Detection** — Concrete steps to find violations. Names the
  pql command or file primitive used.
- **Fix** — Mechanical: deterministic action. Judgment: the prompt
  option list and what each option does.
- **Why** — One paragraph on the failure mode this rule guards
  against. Future-you reading the rule benefits from the reasoning,
  not just the check.

---

## RULE-ANCHOR-DRIFT

**Category:** mechanical

**Finding ID:** `<source-record>:<link-target>` (e.g.
`D-8:#q-1-markdown-mirror-for-tickets` or
`D-8:questions.md#q-1`).

**Detection:**

Anchor-only markdown links (`[text](#slug)`) resolve against the
**source file's full heading set**, not the body of a single record
— record-level headings (`### D-N: …`) live as siblings in the
file and are valid link targets. The previous detection (which used
`pql decisions read`'s body-only `headings` array) missed these
and produced false positives.

Per source body:

1. Open the source body's file (`<vault>/<file_path>` from
   `pql decisions list`) and extract every ATX heading. Build a
   slug index for the file using the GFM convention (lowercase,
   hyphenate spaces, drop punctuation, disambiguate duplicates with
   `-1`/`-2`). Cache per file — every record in that file uses the
   same index.
2. For each `[text](target)` link in the body:
   - Anchor-only (`#slug`): check `slug` against the **source file's**
     index. Missing → flag.
   - Cross-file (`path.md#slug`): resolve `path.md` relative to the
     source file's directory; check `slug` against that file's
     index. Missing file or missing slug → flag.

**Fix:**

If the slug exists in a sibling file's index (same directory) and
the link is anchor-only, rewrite to `path.md#slug` (the canonical
cross-file form). If the slug exists in the source file's index
with edit-distance ≤ 2 from the link target, rewrite to the
matched slug. Otherwise downgrade to judgment ("no auto-fix; the
heading was removed, not renamed") with options: drop the link /
point elsewhere / mark as intentionally dangling.

**Fix:**

If exactly one heading with a closely-matching slug exists (slug
edit-distance ≤ 2 or substring match), rewrite the link to point at
that heading. If no plausible match exists, downgrade the finding to
judgment ("no auto-fix; the heading was removed, not renamed") and
prompt the user with options: drop the link / point elsewhere / mark
as intentionally dangling.

**Why:**

When a heading is renamed for clarity, every cross-reference pointing
at the old slug silently breaks. The rendered docs still look fine —
the link just goes nowhere. Without periodic sweeps these decay
indefinitely; the cost of the sweep is small compared to the cost of
a reader following a dead link and losing trust in the index.

---

## RULE-MISSING-Q-BACKLINK

**Category:** mechanical

**Finding ID:** `<d-id>:<q-id>` (e.g. `D-7:Q-2`). Order is always
D-first regardless of which side is missing the backlink.

**Detection:**

For each D record body, find lines of the shape `Resolves: Q-N`
(plain text, typically in the metadata block at the top of the
record). For each Q-N referenced, fetch that Q record's body via
`pql decisions read Q-N` and check whether it contains a line of the
shape `Resolved → D-N` (or equivalent backlink phrasing — match the
project's own convention; default pattern is `Resolved → D-N`).

Also check the reverse direction: any Q record claiming
`Resolved → D-N` whose D-N body lacks `Resolves: Q-N`.

**Fix:**

Insert the missing backlink in-place using `Edit`:

- Missing on the D side: add `Resolves: Q-N` to the D's metadata
  block (typically right after `Domain:` / `Status:` lines).
- Missing on the Q side: append `Resolved → D-N` to the Q's status
  line (or in the conventional position for that project).

**Why:**

Bidirectional Q↔D links are the navigation backbone of the DQR
system. When one side drifts, search-by-decision finds nothing for
that question and search-by-question doesn't surface its resolution.
The asymmetric state usually arises from a hand-edit on one record
that forgot to update the other; the fix is purely mechanical because
the correct content is already determined by the existing pointer
in the other direction.

---

## RULE-RECORD-SORT

**Category:** mechanical

**Finding ID:** `<file-path>` (e.g. `decisions/architecture.md`).
The whole file is one finding — sort applies to the file as a
unit.

**Detection:**

For each `decisions/*.md` file, read it directly (no pql) and find
all top-level `## D-N` / `## Q-N` / `## R-N` headings in order. Strip
the prefix, parse the numeric suffix, and check whether the sequence
is monotonically ascending within each ID family (D, Q, R kept
separate — files commonly mix families).

Only flag a file if it is **otherwise tidy** — currently no out-of-
order amendments interleaved with new records. The heuristic: if the
sort would touch fewer than three records out of position, apply it;
if more, downgrade to judgment ("this file looks deliberately
arranged — confirm before reordering"). Three is a soft threshold; if
the file's last commit message contains `WIP` or `do-not-sort`, skip.

**Fix:**

Reorder the records within the file so each ID family is ascending.
Preserve everything else (headings between record blocks, any prose
prelude/postlude). Use `Edit` with full block replacement, not in-
place line shuffling — easier to verify the diff.

**Why:**

Records added at the bottom of a file are easy to write but hard to
find. Sorted IDs let a reader find D-37 by jumping to the
two-thirds mark of the file rather than scanning. The cost of the
sort is one reordering pass; the benefit is paid back on every
subsequent read.

---

## RULE-EOF-NORMALIZATION

**Category:** mechanical

**Finding ID:** `<file-path>` (one finding per file).

**Detection:**

For each `decisions/*.md` file (and any other markdown the skill
touched during this run), read directly. Flag if:

- File does not end with exactly one `\n`.
- Any line contains trailing whitespace before its `\n`.

**Fix:**

Trim trailing whitespace from each line. Ensure exactly one trailing
newline at end of file. Use `Edit` only if a violation was found —
this rule must not produce a no-op diff.

**Why:**

Editor and git config drift causes whitespace creep that's invisible
in rendering but pollutes diffs (every record edit ends up touching
unrelated lines). A periodic normalization keeps future diffs clean
without forcing per-editor enforcement on every contributor.

---

## RULE-SUNSET-WITHOUT-TICKET

**Category:** judgment

**Finding ID:** `<record-id>:<phrase-hash-8>` where phrase-hash-8 is
the first 8 hex chars of `sha256(<matched-phrase>)`. Lets the
ledger distinguish two sunset phrases in the same record.

**Detection:**

For each D record body (via `pql decisions read <id>`), grep for
sunset-shaped phrases. Default regex set:

```
(?i)\b(delete|remove|sunset|kill[ -]?switch|tear[ -]?down) when\b
(?i)\bmust (track|monitor|watch|follow)\b
(?i)\brevisit (when|after|once)\b
(?i)\b(deprecate|retire) (when|after|once)\b
```

For each match, run `pql ticket list --decision <id>`. If no tickets
exist, the D has work-shaped intent without a tracked T — flag.

**Fix (prompt options):**

- **File T now** — Run `pql ticket new task "<phrase>" --decision <id>`,
  then prompt the user for a description (or call `pql ticket refine
  write <T> --description ...` after creation).
- **Draft a T description first** — Open an `AskUserQuestion` for the
  description, then file as above.
- **Mark as already covered** — Add a note to the D body
  ("Tracked under T-N") via `Edit`. Skill does not assert which T;
  user provides the ID.
- **Skip** — Adds to the ledger.
- **Stop asking** — Skip remaining sunset findings, summarize.

**Why:**

Sunset-shaped intent ("we'll handle X when Y happens") is the most
common source of accumulated debt in a DQR system: the trigger
condition arrives, nobody remembers the D, the work doesn't happen.
Linking each sunset to a T is the simplest defense — a T is a
backlog item that surfaces in `plan whatsnext` / `plan board`. The
fix is judgment because the right action depends on whether the D's
condition is still relevant, whether it's already covered, and what
the right scope is for the resulting T.

---

## RULE-FILE-OVER-THRESHOLD

**Category:** judgment

**Finding ID:** `<file-path>` (one finding per file; threshold
choice is judgment, not a per-line problem).

**Detection:**

For each `decisions/*.md` file, count lines (via `wc -l` or
equivalent). Default threshold: **350 lines**. Configurable per
project — read `decisions/.clean-house.yaml` if present, key
`file_threshold`. Fall back to 350.

**Fix (prompt options):**

- **Split now (which axis?)** — Prompt for the split axis: by ID
  family (D/Q/R), by domain, by date range, custom. Then perform the
  split: create new file(s), move records, update any anchor links
  pointing into the moved records (run RULE-ANCHOR-DRIFT in apply
  mode against the affected files after the split).
- **Accept and raise the threshold** — Update
  `decisions/.clean-house.yaml`'s `file_threshold` to the next
  reasonable round number above the current line count.
- **Defer** — Skip until next run.

**Why:**

A single decisions file growing past ~350 lines is the point at which
linear scanning starts to lose to grep, and where the cost of
splitting (renaming anchors) is still small. Beyond ~600 lines the
split cost compounds. The threshold is judgment because some projects
deliberately keep one file per domain and accept the size; others
split aggressively. The skill surfaces the question; it doesn't
decide.

---

## RULE-DEAD-FILE-REFERENCE

**Category:** judgment

**Finding ID:** `<record-id>:<path-token>` (path token as written
in the body, not resolved).

**Detection:**

For each D record body (via `pql decisions read <id>`), grep for
path-shaped tokens. Default regex:

```
\b([\w./-]+\.(md|go|py|sql|yaml|yml|toml))\b
```

The first detection pass produced 6/6 false positives in
real-world use; the regex is necessary but not sufficient. For
each match, apply the filters below in order — if any matches,
**skip without flagging**:

1. **Placeholder filter.** Token contains `T-NNN`, `D-NNN`,
   `Q-NNN`, `R-NNN`, `...`, `<`, `>`, or `*` — it's a pattern,
   not a real path.
2. **Source-relative resolution.** Resolve the token against the
   source file's directory (`<vault>/<file_path>`'s dir). If
   `[ -e <resolved> ]`, the reference is live.
3. **Repo-relative resolution.** If `[ -e <token> ]` from the
   repo root, the reference is live.
4. **Basename-fallback.** Run `find <repo-root> -name <basename>`
   (where basename is the last path component). If exactly one
   match exists, treat the reference as live and emit a low-
   priority "consider rewriting to the absolute path" note (not a
   judgment finding). If multiple matches exist, do not flag —
   the token is too ambiguous.

Only after all four filters miss does the reference qualify as
truly dead and warrant a judgment prompt.

**Fix (prompt options):**

- **Update reference** — Prompt for the new path; rewrite the
  reference via `Edit`. If the user types a path, validate it exists
  before applying.
- **Mark superseded** — Add a note to the D ("This decision
  references files no longer present; the underlying constraint
  was retired by D-N") and prompt for the superseding D ID.
- **Defer** — Skip until next run.

**Why:**

Decisions reference code paths to ground their reasoning in the
codebase that motivated them. When the code moves or gets deleted,
the D's reasoning becomes harder to verify. Dead refs are a signal
that either the decision should be updated or the decision itself is
no longer load-bearing — both are judgment calls the user needs to
make.

---

## RULE-STALE-OPEN-Q

**Category:** judgment

**Finding ID:** `<q-id>` (one finding per Q-record; staleness
threshold is global per run, so a Q is either stale or not).

**Detection:**

Run `pql decisions list --type question --status open`. For each
returned record, check the `date` field. Default staleness threshold:
**60 days** (configurable via `decisions/.clean-house.yaml` key
`stale_open_q_days`). Flag any Q with `date` older than the
threshold.

**Fix (prompt options):**

- **Still relevant** — Touch the Q's `date` field to today, optionally
  add a one-line "still open as of YYYY-MM-DD: <reason>" to the body.
- **Nudge to load-bearing index** — If the project keeps a
  load-bearing Qs list (a curated index of unresolved questions
  affecting current work), prompt for inclusion and add the Q there.
- **Mark withdrawn** — Change the Q's status to `withdrawn` (the DQR
  system's terminal state for "no longer worth answering"); the
  user supplies a one-line reason.
- **Defer** — Skip until next run.

**Why:**

Open questions are useful when they're current; stale ones become
ambient noise that drowns the signal of new questions. Most
projects don't enforce explicit Q-lifecycle, so without a periodic
prompt the open list grows forever. The right action depends on
whether the question is still open in fact — not just in metadata —
which only the user can confirm.
