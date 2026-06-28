# AGENTS.md for clide — Mistral Vibe operating as Claude Code peer

This file configures Mistral Vibe to operate in this repo with the same
effectiveness as Claude Code. It distills the CLAUDE.md guardrails and all
`.claude/skills/` into Vibe's instruction hierarchy, preserving "Claude punch"
in a hybrid workflow.

---

## Identity

You are operating in **clide** — a Flutter/Dart IDE for Claude Code CLI.
Your role: **peer to Claude Code**, not replacement. Maintain Claude's
behavioral standards, tool discipline, and architectural rigor.

**Primary directive:** Never lose "Claude punch" — the combination of
strict guardrails, CLI-first interaction, and parity between UI and CLI
that defines effective operation in this repo.

---

## Non-Negotiable Guardrails (from CLAUDE.md)

These are load-bearing. Violating any means the design is wrong, not the rule.

- **Flutter desktop is the host. No Electron, ever.**
- **Single process.** The Flutter app hosts everything in-process: IPC server,
  subsystem handlers (pane, files, editor, git, pql), extensions.
- **CLI-first, not MCP.** Drive via `clide <subsystem> <verb>` Bash commands.
- **Dart is the core; pql fills the query gap.** PTY spawning is native Dart FFI
  (`posix_openpt` + `posix_spawn`). `pql` (Go) handles vault queries.
- **Own the rendering stack.** PTY, markdown, graph, canvas — all clide-owned.
- **User/Claude parity (D-6).** Every CLI subcommand has a UI affordance,
  and every UI action has a CLI equivalent.
- **pql: wrap, don't duplicate.** Clide wraps pql; never re-implements it.
- **Repo-is-the-workspace.** Git repo root is the workspace.
- **Decision discipline.** All architectural choices live in
  `governance/decisions/<domain>.md` as `D-NNN` records. Open questions as
  `Q-NNN` under `governance/questions/<domain>.md`. Rejected as `R-NNN`.
- **No pre-existing excuse.** Solo-dev repo — if `make test` is red, fix it
  first, then your work. Surface blockers; don't push on top of broken state.

---

## Tool Discipline (from CLAUDE.md)

### Make targets are the entry points

| Purpose | Command | Never call directly |
|---------|---------|---------------------|
| Launch app | `make run` | `flutter run` |
| Static analysis | `make analyze` | `flutter analyze` |
| Format | `make format` | `dart format` |
| Fast test suite | `make test` | `flutter test` |
| Core subsystem tests | `make test-core` | underlying scripts |
| Accessibility tests | `make test-a11y` | underlying scripts |
| Integration tests | `make test-integration` | underlying scripts |
| Pre-push gate | `make push-check` | `ci/*` scripts |
| Setup hooks | `make hooks` | `cp .githooks/* .git/hooks/` |
| Clean | `make clean` | `rm -rf build/` |

### Shell hygiene

- **Working directory is repo root** — never `cd /path/to/clide` or `git -C`
- **One command per invocation** — no `&&`/`;` chaining
- Exception: `git commit -F` HEREDOC for multi-line messages
- Prefer Read/Edit/Grep tools over `cat`/`sed`/`grep` for file inspection

---

## Git Workflow (from git-commit skill)

### Commit message format: Conventional Commits 1.0

```
<type>(<scope>): <imperative subject> (<T-NNN>)

Optional body: explain WHY, not WHAT. Wrap at ~72 chars.

Co-Authored-By: Mistral Vibe <vibe@mistral.ai>
```

**Type:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `chore`
- Use `feat`/`fix` for user-visible behavior
- Use `chore` for bookkeeping (`chore(plan)` for pql ticket housekeeping)
- Append `!` after scope for breaking changes: `feat(ipc)!: ...`

**Scope:** Optional but preferred — subsystem: `settings`, `vim`, `pty`, `git`, `plan`
- Lower-case, no spaces

**Subject:** ≤ 72 characters INCLUDING prefix. No emojis. No "and".

**Ticket ref:** Trailing `(T-NNN)` when work has a ticket.

**Body:** Explain the *why*. The diff shows the *what*. Don't restate it.
- Hard cap: **60 words per bullet** for CHANGELOG entries
- No multi-paragraph bullets
- No sub-headers inside bullets
- No probe numbers, latency stats, or %-coverage deltas

### Logically-separated commits

1. **Read `git status` + `git diff` first** — never stage blind
2. **Group by concern, not location:**
   - Bookkeeping: `.gitignore`, lockfiles, config
   - Documentation: `README.md`, ADRs, design notes
   - Tooling/skills: reusable, non-project-specific
   - Project conventions: repo's own rules
   - Feature/subsystem: one cohesive change
   - Layer changes: app, sidecar CLI, daemon, IPC, pql wrapper, canvas, git panel
3. **Prefer many small focused commits over one large mixed one**
4. **Use `git add <specific paths>`** — NEVER `git add -A`, `git add .`, `git add -u`
5. **Verify between commits** with `git status`, `git diff --staged`, `git log -1`

### Changelog discipline

- **Every user-visible commit must touch CHANGELOG.md** under `## [Unreleased]`
- Use Keep a Changelog 1.1.0 format with sections: Added, Changed, Deprecated, Removed, Fixed, Security
- Entries: short imperative phrases describing user-facing impact
- **60 words hard cap per bullet** — verify with `make changelog-gate`
- What skips changelog: pure bookkeeping with no user-visible effect

### Safety rules (reinforced)

- **Never** `--no-verify`
- **Never** `--amend` unless user explicitly asks
- **Never** force-push to `main` or `master`
- **Always** check `git status` before staging, `git diff --staged` before committing
- Commit message via HEREDOC:
  ```bash
  git commit -m "$(cat <<'EOF'
  <message>
  EOF
  )"
  ```

### What NOT to commit

- `.env`, `*.env.local`
- `.claude/settings.local.json`
- Build artefacts: `sidecar/bin/`, `sidecar/dist/`, `build/`, `app/.dart_tool/`
- SQLite index files: `*.sqlite`, `*.sqlite-wal`, `*.sqlite-shm`, `*.db`
- Coverage/test output: `*.out`, `coverage.*`, `*.test`
- `.pql/changelog/` — auto-staged by pre-commit hook from pql DB

---

## pql — Vault Queries + Project Planning

`pql` indexes a vault into SQLite and exposes structural queries plus a
planning layer for decision records and tickets. One binary, two surfaces.

### Precondition

```bash
command -v pql
```

If absent, tell the user to install from
https://github.com/postmeridiem/pql/releases/latest. Don't install it
yourself. Don't fall back to grep unless the user explicitly asks.

### First touch: learn the vault

```bash
pql schema
```

Returns one row per frontmatter key with observed types and file counts.
Run once per session before writing queries.

---

### Surface 1: Vault queries

#### Subcommands

| Command | Purpose |
|---|---|
| `pql files [glob]` | List indexed files; optional glob filter |
| `pql tags [--sort count]` | Distinct tags with counts |
| `pql backlinks <path>` | Files linking TO a path |
| `pql outlinks <path>` | Links FROM a file |
| `pql meta <path>` | Frontmatter + tags + outlinks + headings for one file |
| `pql schema` | Typed frontmatter schema |
| `pql base <name>` | Execute an Obsidian .base file |
| `pql shell` | Interactive REPL (indexes once, then query per line) |
| `pql query "<DSL>"` | SQL-derived DSL for complex queries |
| `pql doctor` | Resolved vault/config/DB/index state |

#### DSL examples

```sql
SELECT name, fm.date WHERE fm.type = 'meeting' ORDER BY fm.date DESC LIMIT 10
SELECT path WHERE 'project' IN tags ORDER BY path
SELECT name, fm.prior_job WHERE fm.type = 'council-member' ORDER BY name
```

Use `--file q.pql` or `--stdin` for long queries. Don't interpolate vault
content into the command line.

#### Query cookbook

- **Files in folder** → `pql files 'sessions/*'`
- **Top tags** → `pql tags --sort count --limit 20`
- **What links to X?** → `pql backlinks members/vaasa/persona.md`
- **Date range** → `pql query "SELECT name, fm.date WHERE fm.date BETWEEN '2024-01-01' AND '2024-12-31'"`
- **Run a Base** → `pql base council-sessions`
- **Inspect one file** → `pql meta members/vaasa/persona.md --pretty`

---

### Surface 2: Planning (decisions + tickets)

Planning state lives in `<vault>/.pql/pql.db` (user-authored state, not a
cache). Decision records come from the DQR tree — `governance/{decisions,
questions,rejected}/<domain>.md` by default (D-21), configurable via
`dqr_dir` in `.pql/config.yaml` or the `PQL_DQR_DIR` env var (env > file >
default); a legacy flat `decisions/` is auto-detected as a fallback.
Tickets are SQLite-native.

#### Decision subcommands

| Command | Purpose |
|---|---|
| `pql decisions sync [--no-style]` | Parse the DQR tree → upsert into pql.db; surfaces style warnings (filename, subdir-type, domain pairing/conflicts) unless `--no-style` |
| `pql decisions validate [--no-style]` | Dry-run parse; structural errors exit non-zero, style issues warn (suppress with `--no-style`) |
| `pql decisions claim <D\|Q\|R> <domain> "title"` | Print next available ID |
| `pql decisions list [--type X] [--domain X] [--status X]` | List decisions |
| `pql decisions show <id> [--with-refs] [--with-tickets]` | Show with joins |
| `pql decisions coverage` | Confirmed decisions without tickets |
| `pql decisions refs <id>` | Cross-references involving a decision |

Always `pql decisions sync` before querying if decisions/*.md may have changed.

#### Ticket subcommands

| Command | Purpose |
|---|---|
| `pql ticket new <type> "title" [--parent T-NNN] [--decision D-NNN] [--priority P] [--id-only]` | Create (emits T-NNN; `--parent` files it under an epic/story in one step; `--id-only` prints the bare id for tree-creation scripts) |
| `pql ticket list [--status S] [--team T] [--assigned A] [--label L] [--under T-NNN] [--leaf] [--unblocked]` | List with filters. `--under` = recursive descendants of a ticket; `--leaf` = no children; `--unblocked` = blockers all reached a terminal status |
| `pql ticket show <id[,id,...]> [--with-context] [--with-blockers] [--with-children] [--tree] [--depth N]` | Show one or more (comma-batch → array of show-trees). `--with-children` = direct children; `--tree` = nested descendant subtree + direct parent (cap with `--depth N`) |
| `pql ticket status <id> <new-status> [--force]` | Change status. Closing (terminal status) is blocked while the ticket has open children; `--force` cascades that status to all not-yet-closed descendants and lists them |
| `pql ticket statuslist` | List the configured status vocabulary (name, label, class, order, is_default, is_terminal) — what a UI reads to render columns |
| `pql ticket relabel <id\|record_id> [--new-label T-NNN] [--fix-prose]` | Reassign a ticket's friendly T-NNN label (reconcile a duplicate-label collision). Identity (record_id) and the structural graph are untouched; only the label moves. `--fix-prose` rewrites stale T-NNN mentions in DQR markdown |
| `pql ticket assign <id> <agent>` | Set assignee |
| `pql ticket setparent <id[,id,...]> <parent-id \| none>` | Set (or clear with `none`) a ticket's **parent** — the hierarchy link (epic→story→task). Positional, not a flag. This is the parent/child relationship, distinct from blockers |
| `pql ticket append <id> <text\|--file\|--stdin>` | Append to the description (blank-line separated); never round-trips existing text |
| `pql ticket block <id> --by <other>` | Add a **blocker** (a dependency: <id> can't start until <other> is done) — NOT a parent/child link; use `setparent` or `new --parent` for hierarchy |
| `pql ticket unblock <id> --from <other>` | Remove blocker |
| `pql ticket team <id> <team>` | Set team |
| `pql ticket label <id> add\|rm <label>` | Manage labels |
| `pql ticket board [--team T]` | Kanban board view |
| `pql ticket refine list` | Tickets with empty descriptions, status-priority-sorted |
| `pql ticket refine next [--skip N]` | Head of the unrefined queue with full show-tree + remaining count |
| `pql ticket refine write <id> <json\|--file\|--stdin>` | Patch writable fields (title, description, priority, type) |

Ticket types: initiative, epic, story, task, bug.
The `id` you type and see (T-NNN) is a friendly label backed by a stable
underwater `record_id` (also in output); two clones never collide on identity,
and a duplicate label is fixed with `pql ticket relabel` (D-26).
Statuses are a per-vault vocabulary (`ticket_statuses` in `.pql/config.yaml`),
defaulting to: backlog, ready, in_progress, review, done, cancelled. Each status
has a class — initial, active, review, terminal — that the engine reasons about.
Run `pql ticket statuslist` to discover the live set. Any status can transition
to any other — pql does not enforce a state machine — except that a ticket
cannot reach a terminal status while it has open children (use `--force` to
cascade the close down the subtree).

#### Plan subcommands

| Command | Purpose |
|---|---|
| `pql plan status` | Dashboard: decision counts, open Qs, ticket summary, coverage gaps |
| `pql plan whatsnext` | Next ticket to work on (active work, then the "ready" lane) with full context bundle |
| `pql plan review` | Next ticket awaiting review with full context bundle |
| `pql plan export [--stage]` | Append changed planning rows to `.pql/changelog/<table>/<YYYY-MM>.sql` (the git-tracked log of record); `--stage` also `git add`s them. Normally a no-op — mutations already write through |
| `pql plan import [--legacy FILE]` | Replay `.pql/changelog/` into `pql.db` (or one-time `--legacy pql-plan.json` migration from the pre-D-15 snapshot) |
| `pql plan rebuild` | Drop replicated tables and replay `.pql/changelog/` from scratch. Warns on stderr (`changelog.ticket_id_collision`) + lists `collisions` in the result if one ticket id was filed twice across clones |

#### Versioning planning state

`pql.db` is gitignored — the durable, git-tracked artifact is
`.pql/changelog/` (D-15/D-16). Ticket mutations **write through** to the
changelog synchronously, so it is always current; you never have to
remember to "export". The hooks installed by `pql init` do the rest:

- `pre-commit` stages `.pql/changelog/` so it lands in the same commit as
  the change that produced it.
- `post-merge` replays incoming changelog edits (`pql plan import`) and
  re-syncs decisions from their markdown.
- `post-checkout` / `post-rewrite` rebuild `pql.db` from the changelog.

On a fresh clone, `pql plan import` (run automatically on first open)
replays the changelog into a new `pql.db`. There is **no** `pql-plan.json`
snapshot — that artifact is retired; `pql plan export` is now only a
manual catch-up/reconcile.

A ticket mutation (create / status transition / any write) leaves
`.pql/changelog/` dirty by design — the `pre-commit` hook stages it onto
the next `git commit`. This is expected, not a problem to flag. Don't
narrate "the ticket won't persist until committed" on every edit; either
fold the bookkeeping into a commit or trust the normal commit flow.

#### Planning cookbook

- **Sync and list confirmed** → `pql decisions sync && pql decisions list --type confirmed`
- **Show with refs** → `pql decisions show D-5 --with-refs --pretty`
- **Read full body** → `pql decisions read D-5`
- **Create ticket** → `pql ticket new task "implement X" --decision D-5`
- **Create ticket, capture id for a script** → `id=$(pql ticket new task "implement X" --id-only)` — prints just `T-NNN`
- **File a ticket under an epic** → `pql ticket new bug "fix X" --parent T-276` (one step), or reparent an existing one → `pql ticket setparent T-9 T-276` (clear with `none`). Parent = hierarchy; use `block` only for blocking dependencies
- **Batch close** → `pql ticket status T-1,T-2,T-3 done`
- **Full context** → `pql ticket show T-5 --with-context --pretty`
- **Batch show** → `pql ticket show T-1,T-2,T-3 --pretty`
- **Refine next ticket** → `pql ticket refine next --pretty`, then `pql ticket refine write T-N '{"description":"..."}'`
- **Append a note** → `pql ticket append T-5 "benchmarked; TTL now 5m"` — blank-line separated, never overwrites; use `--file note.md` or `--stdin` for longer content
- **Subtree of an epic** → `pql ticket show T-2 --tree --pretty` — nested `subtree` + direct parent in `ancestors`; add `--depth N` to cap levels
- **Ready leaf work under an epic** → `pql ticket list --under T-2 --leaf --unblocked` — leaf tickets beneath T-2 whose blockers have all reached a terminal status; the batch complement to `plan whatsnext`
- **What's next?** → `pql plan whatsnext --pretty`
- **Review queue** → `pql plan review --pretty`
- **Coverage gaps** → `pql decisions coverage`
- **Dashboard** → `pql plan status --pretty`
- **Force a changelog catch-up** → `pql plan export` (normally a no-op; mutations already write through to `.pql/changelog/`)

---

### Output contract (both surfaces)

- **stdout:** JSON array (default); `--jsonl` for one object/line; `--pretty`; `--limit N`.
- **stderr:** JSON diagnostics `{"level":"...","code":"pql.<phase>.<kind>","msg":"..."}`.
- **Exit codes:**
  - `0` — success, including zero matches (empty `[]` — say "no matches", not "failed")
  - `64` — bad flag
  - `65` — parse/compile error (pass stderr back)
  - `66` — vault/config not found
  - `69` — unavailable
  - `70` — internal error

### Anti-patterns

- Don't pipe to `jq` for simple projections — use `--limit`, `--pretty`, `--jsonl`.
- Don't chain `pql files` + `pql meta` — one `pql query` with WHERE.
- Don't parse errors — pass stderr diagnostics back directly.
- Don't forget `pql decisions sync` before querying decisions.
- Don't try to install or upgrade pql — instruct the user if missing.

### When NOT to use

- **Body text search** → `grep`/`rg`.
- **Reading file contents** → `Read` tool.
- **Code structure** → tree-sitter / LSP.
- **Modifying vault files** → `Write`/`Edit`. pql doesn't write to vault content.

---

## Driving clide UI via CLI (from clide skill)

**Core principle: Every UI action has a CLI equivalent (D-6).**
Discover the live surface; don't hard-code it.

### Discover capabilities

```bash
clide capabilities
```

Returns JSON: every registered command, split into `subsystem` + `verb`,
with argument schema. **This is authoritative** — re-run it, don't trust
remembered lists.

### Slots (layout areas)

- `sidebar` — left
- `workspace` — center (where Claude lives)
- `context` — right
- `statusbar` — bottom

### Observe state

```bash
# One-shot orientation
clide status

# Narrower snapshots
clide pane list
clide editor active
clide git status
```

### Drive UI

```bash
# Open a doc in a GUI reader
clide ui open <reader> <ref>
# readers: tickets, decisions, markdown, diff
# examples:
clide ui open tickets T-123
clide ui open decisions D-456
clide ui open diff lib/src/foo.dart
clide ui open markdown docs/bar.md

# Show diff and scroll to file
clide ui diff lib/src/foo.dart

# Raise a toast
clide ui toast "message" --severity success|warning|error|info

# General: clide <subsystem> <verb> [args]
clide files list
clide editor open <path>
clide pane focus <pane-id>
```

**Convention:** If a drive verb has no live GUI, return toolError
("no live UI to drive"), not hang. Exit code conveys ok/usage/tool error.
JSON on stdout.

### You only see what flows through clide

Your own non-`clide` shell work (plain file reads, `make test`, `git`) is
outside clide's view by design (D-83). Run it **through** `clide ...` if
you want clide to observe it.

---

## Testmode (from testmode skill)

`ClideTestApp` is a lightweight Flutter app for integration testing.
Catches regressions unit tests cannot: missing binaries, broken subprocess
wiring, IPC dispatch failures, extension activation order, theme parse errors.

### Running

```bash
make run-testmode              # all categories, 60s timeout
make run-testmode TESTMODE_CATEGORY=toolchain
make run-testmode TESTMODE_CATEGORY=ipc
make run-testmode TESTMODE_CATEGORY=extensions
make run-testmode TESTMODE_TIMEOUT=120
```

Results: stdout + `/tmp/clide-testmode.log`
Last line is machine-readable JSON: `{"passed":N,"failed":M,"total":N+M,"failures":[...]}`

### When to run

| Changed area | Category | Why |
|-------------|----------|-----|
| Toolchain, PATH, ptyc | `toolchain` | Binary resolution + exec |
| IPC envelope, dispatcher | `ipc` | Round-trip + error contract |
| Extension manifest, activate | `extensions` | Register + activate lifecycle |
| Theme YAML, loader | `extensions` | Theme parse is in this category |
| Platform config | `all` | Full rebuild validates everything |
| Any doubt | `all` | ~30s, cheap insurance |

### Interpreting output

- `[testmode] exec | ... | OK` — subprocess ran, exit 0 or 1
- `[testmode] PASS | ...` — assertion passed
- `[testmode] FAIL | ...` — assertion failed
- `[testmode] exec | ... | EXCEPTION` — binary not found or not executable
- `[testmode] exec | ... | TIMEOUT` — subprocess hung

If no `[testmode]` lines appear, the testmode gate didn't fire — verify
`CLIDE_TESTMODE` is set to a non-empty string.

### Adding tests

All test logic in `lib/test_app.dart`. Pattern:
```dart
await _testExec('label', binary, ['args'], workDir);
// or
_addResult('label', boolCondition, 'detail string');
```

---

## Repo Layout

```
lib/
  main.dart           # Flutter entry point
  app.dart            # Root layout, workspace, panels
  clide.dart          # Barrel: shared types
  src/                # Core subsystems (IPC, PTY, git, files, pql, panes)
  kernel/             # Kernel services (theme, i18n, settings, panels)
  builtin/            # Built-in extensions
  widgets/            # Custom widget primitives
  extension/          # Extension contract and registration
  lua/                # Lua runtime support

test/                 # All tests (core + widgets + goldens + a11y)
assets/               # Fonts, themes, grammars, licenses, logo
linux/, macos/, web/  # Flutter platform directories
native/               # Vendored native libs (tree-sitter, dugite)
governance/          # D/Q/R records
docs/                 # Design docs, wireframes
legacy/               # Python Textual clide v1.2 (frozen)
```

---

## Dependency & Supply Chain Discipline

- **Prefer-zero-deps.** Flutter-SDK widgets first; third-party needs justification
- **Exact-pinned in pubspec.yaml** — no caret ranges
- **Advisories reviewed** before every bump
- **pubspec.lock committed**
- **Document every bundled dependency** in `assets/licenses.yaml`:
  - name, kind, version, homepage, license, purpose
- Adding a dep: two-step commit — artefact AND `licenses.yaml` entry
- Native deps (dugite, libtree-sitter): vendored in `native/`, pinned by SHA

---

## Pre-push Gate

```bash
make push-check
```

Runs: decisions validation + core tests + fast suite + a11y + coverage + changelog

**Never bypass.** If it fails, fix the underlying issue.

---

## Session Setup

One-time setup on fresh clone:
```bash
make hooks && flutter pub get
pql init  # wires up pql skill + perms
```

---

## Mistral-Specific Notes

### What to preserve from Claude

- CLI-first interaction model
- Strict guardrails enforcement
- Logically-separated commits
- Changelog discipline (60-word cap)
- pql as single source of truth for decisions/tickets
- UI/CLI parity
- Testmode for integration validation

### What to adapt

- **Tool names:** Claude's `Bash(...)` → my `bash` tool
- **Agent spawning:** Claude's `Agent{}` → my `task` tool for subagents
- **Permissions:** `.claude/settings.json` allow/deny → my system prompt + your instructions

### When in doubt

Ask: "What would Claude do?" Then do that. The AGENTS.md is the bridge,
not a replacement.

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Discover clide commands | `clide capabilities` |
| See current UI state | `clide status` |
| Open ticket in UI | `clide ui open tickets T-NNN` |
| Toast notification | `clide ui toast "msg" --severity info` |
| List actionable tickets | `pql ticket list --under <id> --leaf --unblocked --status backlog --pretty` |
| Sync decisions | `pql decisions sync` |
| Run integration tests | `make run-testmode` |
| Fast test suite | `make test` |
| Full pre-push | `make push-check` |
| Commit with message | `git commit -m "$(cat <<'EOF'\n<message>\nEOF\n)"` |
| Verify changelog | `make changelog-gate` |

---

*Generated for Mistral Vibe. Preserves Claude Code punch for clide repo.*
