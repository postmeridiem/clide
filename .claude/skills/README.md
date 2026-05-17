# Clide Claude-Code skills

Skills are reusable instruction packs Claude Code loads on demand. Each one
lives in its own directory with a `SKILL.md` (frontmatter + body) and any
helper scripts. This index is for humans skimming what's available; Claude
discovers skills automatically from the directory structure.

| Skill | Purpose |
|---|---|
| [`d2-diagram`](d2-diagram/SKILL.md) | Generate technical diagrams from `.d2` source with the d2 CLI; renders to PNG. |
| [`frame0-wireframe`](frame0-wireframe/SKILL.md) | Author UI wireframes as local JSON and sync to the Frame0 desktop app for rendering + export. |
| [`git-commit`](git-commit/SKILL.md) | Commit conventions for this repo — message style, CHANGELOG discipline (40/60 word cap), attribution trailer, safety rules. |
| [`pql`](pql/SKILL.md) | Query and plan against the markdown vault via the `pql` CLI (decisions, tickets, structural queries). |
| [`skill-create`](skill-create/SKILL.md) | Guidance for creating new skills — SKILL.md structure, bundling scripts, packaging. |
| [`testmode`](testmode/SKILL.md) | Run and interpret the `ClideTestApp` platform integration harness; smoke-test after toolchain / IPC / theme / native changes. |
| [`ui-design`](ui-design/SKILL.md) | Visual design guide — surface tokens, control geometry, Phosphor icons. |
| [`whats-next`](whats-next/SKILL.md) | Dependency-driven batch selection against the pql backlog. Walks the initiative/epic tree, filters unblocked work, refines, optionally activates. |

## Adding a skill

Use the `skill-create` skill (or follow its SKILL.md by hand). Add a row to
the table above so the inventory stays accurate; the index is otherwise just
a directory listing.
