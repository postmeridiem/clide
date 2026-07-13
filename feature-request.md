# clide feature requests

Pre-triage inbox for feature ideas surfaced from consumer use. Accepted
items move into the planning dataset (`pql ticket new …`); this file is
the scratchpad before that, not a parallel backlog. (Same convention as
pql's `feature-request.md`, pointed the other way.)

---

## FR-1 — Settings-panel option: per-repo preset PATH *(accepted → D-106 / T-511, 2026-07-13)*

Moved into the planning dataset: decision
[D-106](governance/decisions/tooling.md#d-106-per-workspace-path-preset-prepended-at-spawn)
and ticket T-511 (shipped). Kept here as a tombstone per this file's
convention; the problem, proposal, and design constraints are captured
in the D-record.

---

## FR-2 — Lead the `clide` skill `description` with `clide capabilities`

- **Status:** proposed
- **Source:** settled-reach estate-cleanup session, 2026-07-13 — de-forking
  the hand-copied `clide` skill back to canonical surfaced a description
  improvement in the consumer's fork worth keeping.
- **Severity:** low; discoverability wording, not a functional gap.

### Problem

The canonical `.claude/skills/clide/SKILL.md` `description` names the
triggers but not the *first move*. settled-reach's drifted copy had a
sharper opening that named `clide capabilities` as the entry action and the
`clide`-on-PATH + `CLIDE_SOCK` mechanics inline. Syncing that copy back to
canonical (de-forking) drops the improvement unless it's adopted here. The
skill *body* already says "discover the surface first → `clide capabilities`",
but the `description` — what an agent reads when *deciding* whether to invoke
the skill — buries that lead.

### Proposal

Fold the fork's opening into the canonical `description` frontmatter:

> clide is the IDE hosting this session; it puts `clide` on your PATH and a
> per-workspace socket in `CLIDE_SOCK`. Start with `clide capabilities` to
> enumerate the live tool surface.

Pure frontmatter wording; no behavior change.

---

*Logged from a settled-reach session (consuming the clide skill), not
authored in a clide session — review and triage/commit from clide.*
