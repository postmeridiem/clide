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

## FR-2 — Lead the `clide` skill `description` with `clide capabilities` *(accepted → T-512, 2026-07-13)*

Applied: the canonical `.claude/skills/clide/SKILL.md` `description` now
leads with the hosting context (`clide` on PATH, `CLIDE_SOCK`) and
`clide capabilities` as the entry action, keeping the trigger list.
Pure frontmatter wording; no behavior change.
