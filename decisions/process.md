# Process Decisions

Q&D record system itself, kanban, commit conventions, changelog.

---

### D-034: Q&D record system
- **Date:** 2026-04-21
- **Decision:** Adopt settled-reach's Q&D record convention. Confirmed decisions are `D-NNN` under `decisions/<domain>.md`; open questions are `Q-NNN` under `decisions/questions-<domain>.md`; rejected alternatives are `R-NNN` under `decisions/rejected.md`. Markdown is the source of truth; `.pql/pql.db` is a query index built from markdown. Record shape and claiming rules live in [`decisions/README.md`](README.md).
- **Rationale:** Two places currently hold clide's architectural knowledge — ADRs and scattered plan files — and neither lets an agent or reviewer locate "the unresolved thing in this subsystem." Q&D fixes that: one index, one shape, one claim rule. Proven in daily use in settled-reach.
- **Cost:** One more directory to maintain. A learning curve for contributors (tiny: read `decisions/README.md`).
- **Raised by:** 2026-04-21 planning.

### D-035: Kanban / waterfall, not Scrum
- **Date:** 2026-04-21
- **Decision:** Ticketing is kanban + waterfall. Tickets flow backlog → ready → in_progress → review → done → cancelled. No sprints, no velocity, no story points. Settled-reach's Scrum layer (sprints, sprint reviews, sprint close as a sync event) is stripped.
- **Rationale:** Clide has a solo-or-small-team cadence. Sprint ceremonies add overhead without adding signal at this scale. Kanban matches how the work actually happens.
- **Cost:** No natural "sprint close" event to sync shared state. See [Q-022](questions-process.md#q-022-ticket-persistence-strategy).
- **Raised by:** 2026-04-21 planning.

### D-036: `.claude/` is committed project surface, managed through the IDE
- **Date:** 2026-04-21
- **Decision:** `.claude/` (hooks, skills, agents, MCP settings) is committed alongside code. Only `.claude/settings.local.json` is gitignored. The reserved `builtin.claude-control` extension surfaces `.claude/` as a first-class sidebar tab (sub-tabs: Settings / Skills / Agents / Hooks / MCP) in a future tier.
- **Rationale:** `.claude/` is project governance — same status as `CLAUDE.md`, `decisions/`, `Makefile`. Treating it as dotfile-cruft loses project-wide conventions (skills, hooks) that should travel with the repo.
- **Cost:** Contributors commit Claude Code config alongside code changes. Discipline required; minor.
- **Raised by:** 2026-04-21 planning. Distinct from the existing `builtin.claude` stub reserved for Tier 1's "run Claude Code in a PTY pane."

### D-037: Commit conventions per git-commit skill
- **Date:** 2026-04-21
- **Decision:** Commits follow `.claude/skills/git-commit/SKILL.md`: imperative subject ≤ 70 chars, no `feat:`/`fix:` type prefixes, no emojis, optional body wrapped at ~72 chars, multi-line messages via HEREDOC, attribution trailer `Co-Authored-By: Claude <noreply@anthropic.com>` (the model-identifier variant the harness produces is also accepted).
- **Rationale:** Python-era clide under `legacy/` used Conventional Commits; the Flutter rebuild does not. Imperative mood reads better for a project-governance log; types are noise when every commit is scoped to a subsystem already.
- **Cost:** Contributors with Conventional Commits muscle memory adjust.
- **Raised by:** 2026-04-21 planning.

### D-038: Changelog discipline — Keep a Changelog 1.1.0
- **Date:** 2026-04-21
- **Decision:** `CHANGELOG.md` follows Keep a Changelog 1.1.0. Every user-visible commit adds an entry under `## [Unreleased]` in the appropriate subsection (Added / Changed / Deprecated / Removed / Fixed / Security). Cutting a release moves entries under a dated heading and bumps `project.yaml` `version:` in the same commit. Pure bookkeeping commits (comment-only, .gitignore tweak, lint config) skip the changelog.
- **Rationale:** Release notes that have to be written after the fact aren't written. Writing them per commit keeps the log honest.
- **Cost:** One extra edit per user-visible commit; zero if the change is invisible.
- **Raised by:** 2026-04-21 planning.

### D-039: Planning tooling lives in pql, not clide
- **Date:** 2026-04-21
- **Decision:** Planning subcommands (`decisions`, `ticket`, `plan`) land in pql's repo long-term. Clide consumes them via shell-out, matching [D-003](architecture.md)'s wrap-don't-duplicate rule for pql. Clide does not grow Dart subcommands for planning.
- **Rationale:** A terminal user or a user in VS Code / JetBrains still needs Q&D access. Binding planning tooling to clide-the-Flutter-app would cut them off from their own work — see [R-009](rejected.md#r-009-port-planning-tooling-into-clide). pql is already the CLI, already universal, already wrapped by clide.
- **Cost:** Planning features don't ship until pql catches up. Mitigated by [D-040](#d-040-python-stopgap-under-toolsscriptsplan). Gated by [Q-021](questions-process.md#q-021-pql-absorbs-planning-vs-keeps-separate).
- **Raised by:** 2026-04-21 planning.

### D-040: [SUPERSEDED] Python stopgap under `tools/scripts/plan`
- **Date:** 2026-04-21
- **Decision:** A time-limited Python port of settled-reach's `decisions_sync.py` + `ticket` + `decision` scripts lives at `tools/scripts/plan` with support modules under `tools/scripts/planning/`. Writes to `.pql/pql.db` (gitignored). Ticket IDs are `T-NNN` (TEXT PK, reshape from settled-reach's integers). Same schema, same markdown, same verb shape as the eventual `pql` subcommands.
- **Sunset:** Delete the stopgap when pql ships `pql decisions sync | validate | list | show | claim | coverage` + `pql ticket new | list | show | status | assign | block | board` with feature parity, and reads the same `.pql/pql.db` file the stopgap wrote. Removal commit shape: [R-011](rejected.md#r-011-permanent-stopgap).
- **Rationale:** Planning tooling must work day one. Pql's Go implementation won't land for at least a cycle or two. Without a stopgap, the convention lives on paper; with one, tickets + decisions are queryable from today. Same schema means migration is call-site find-replace (`tools/scripts/plan ` → `pql `), no data migration.
- **Cost:** Python dep on contributors' machines (already present on most Linux dists). One time-limited tool to maintain. See [R-010](rejected.md#r-010-python-script-stopgap-at-toolingdb) for why `tools/scripts/plan` and not `tooling/db/`.
- **Raised by:** 2026-04-21 planning.
- **Amendment (2026-04-22):** Sunset condition met. pql 1.0.0 ships full feature parity. Stopgap deleted per [R-011](rejected.md#r-011-permanent-stopgap).

---
