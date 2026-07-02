# Clide Claude-Code skills

Skills are reusable instruction packs Claude Code loads on demand. Each one
lives in its own directory with a `SKILL.md` (frontmatter + body) and any
helper scripts. This index is for humans skimming what's available; Claude
discovers skills automatically from the directory structure.

Only clide-specific skills live in this repo. Repo-agnostic skills
(`d2-diagram`, `frame0-wireframe`, `skill-create`) live at user scope
(`~/.claude/skills/`), as do the pql-distributed ones (`pql`, `clean-house`,
installed via `pql init`).

| Skill | Purpose |
|---|---|
| [`clide`](clide/SKILL.md) | Observe/drive the live clide UI through the `clide` CLI; discover the surface with `clide capabilities`. |
| [`git-commit`](git-commit/SKILL.md) | Commit conventions for this repo — message style, CHANGELOG discipline (60-word cap), attribution trailer, safety rules. |
| [`testmode`](testmode/SKILL.md) | Run and interpret the `ClideTestApp` platform integration harness; smoke-test after toolchain / IPC / PTY / theme / native changes. |
| [`ui-design`](ui-design/SKILL.md) | Visual design guide — surface tokens, control geometry, Phosphor icons (`byName` + generated glyph table). |
| [`whats-next`](whats-next/SKILL.md) | Dependency-driven batch selection against the pql backlog. Walks the initiative/epic tree, filters unblocked work, refines, optionally activates. |

## Adding a skill

Use the `skill-create` skill (user scope; or follow its SKILL.md by hand).
Clide-specific skills go here; repo-agnostic ones go to `~/.claude/skills/`.
Add a row to the table above so the inventory stays accurate; the index is
otherwise just a directory listing.
