# STOPGAP — Planning tooling

This directory is a **time-limited stopgap**. The Python scripts here
port settled-reach's `decisions_sync.py` + `ticket` + `decision`
scripts, Scrum-stripped, and write to `.pql/pql.db` (gitignored).

## Sunset clause

Per [`D-040`](../../decisions/process.md#d-040-python-stopgap-under-toolsscriptsplan)
and [`R-011`](../../decisions/rejected.md#r-011-permanent-stopgap),
this stopgap deletes when pql ships:

- `pql decisions sync | validate | list | show | claim | coverage`
- `pql ticket new | list | show | status | assign | block | board`

with feature parity on the same `.pql/pql.db` file this stopgap wrote.

Migration is a call-site find-replace:

```
tools/scripts/plan decisions sync        →  pql decisions sync
tools/scripts/plan ticket new task "…"   →  pql ticket new task "…"
tools/scripts/plan ticket board          →  pql ticket board
```

See [`Q-021`](../../decisions/questions-architecture.md#q-021-pql-absorbs-planning-vs-keeps-separate)
for the open gate on whether pql absorbs planning long-term.

## Entrypoint

`plan` is a Python executable. Support modules live under `planning/`.

```
plan decisions sync | validate | claim D|Q|R <domain> [title] | list | show <id> | coverage
plan ticket    new <type> "title" | list | show <id> | status <id> <new> | assign <id> <agent>
plan ticket    block <id> --by <other> | unblock <id> --from <other>
plan ticket    team <id> <team> | label <id> add|rm <label> | board | search "query"
plan sqlite-query "SELECT …"
```

Needs Python 3.9+ (f-strings + `pathlib`). No third-party deps.

## Where things live

- DB: `.pql/pql.db` (gitignored, per-dev)
- Records (source of truth): `decisions/*.md`
- Tickets: today SQLite-only; see
  [`Q-022`](../../decisions/questions-architecture.md#q-022-ticket-persistence-strategy)
  for the markdown-mirror question.
