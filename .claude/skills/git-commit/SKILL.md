---
name: git-commit
description: >
  Git commit conventions for this repo — message style, changelog and
  version-bump rules, attribution trailer, and the safety rules that
  always apply. Use whenever the user says "commit", "commit this",
  "create a commit", "make a commit", "amend", or asks Claude to check
  work into git in any form.
---

# Git commit rule — this repo

Follow these conventions whenever you create a commit in this repository. These are in addition to the standard Claude Code git-safety protocol (no `--no-verify`, no force-push to main, prefer new commits over `--amend`, etc.).

## Message style

This repo uses [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/) (per [D-37](../../../governance/decisions/process.md#d-37)).

- **First line:** `type(scope): imperative subject`, ≤ 72 characters **including** the prefix. Examples: `feat(settings): add Appearance font picker (T-460)`, `fix(ipc): reconnect after app reload`, `docs(readme): drop brittle version line`.
- **Type:** one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `chore`. Use `feat`/`fix` for user-visible behavior; `chore` for bookkeeping (`chore(plan)` is the convention for pql ticket housekeeping). Append `!` after the scope for a breaking change (`feat(ipc)!: …`).
- **Scope (optional but preferred):** the subsystem the change lives in — `settings`, `vim`, `pty`, `git`, `plan`, etc. Lower-case, no spaces.
- **Ticket ref:** keep a trailing `(T-NNN)` on the subject when the work has a ticket — `feat(settings): category rail + navigation (T-447)`.
- **Body (optional):** wrap at ~72 chars. Explain the *why* — the reason this change exists. The diff already shows the *what*; don't restate it in prose.
- **No emojis.** Anywhere.
- **Don't reference the current task or flow** (`for the v2.0 milestone`, `used by the canvas panel`) — that context belongs in the PR description and rots as the repo evolves.
- **Naming:** the project is `clide`. The Flutter desktop app lives at the repo root; the `clide` CLI is a thin C client (`native/clide-cli/`). The supporter project is `pql` (referenced, not part of this repo). The archived Python implementation lives under `legacy/`.

## Logically-separated commits

Default to **one logical change per commit**, even when a lot of work lands in the tree at once. When there's a pile of uncommitted or untracked files:

1. **Read `git status` + `git diff` first** — never stage the whole tree blind.
2. **Group by concern**, not by file location. Typical concerns to separate:
   - **Bookkeeping** — `.gitignore`, editor/IDE config, lockfiles, `go.sum` / `pubspec.lock` updates.
   - **Documentation** — `README.md`, `CLAUDE.md`, ADRs under `docs/ADRs/`, design notes under `docs/`.
   - **General-purpose tooling / skills** — things that aren't project-specific (reusable skills, shared scripts).
   - **Project-specific conventions** — this repo's own rules.
   - **Feature or subsystem** — one cohesive change per commit; a sidecar change and an app change for the same feature can land together, but two unrelated features should split.
   - **Layer changes** — Flutter app, sidecar CLI, sidecar daemon, IPC server, pql wrapper, canvas driver, git panel — separate concerns; prefer separate commits when the changes are independent.
3. **Sequence the commits** so each one is cleanly scoped, but don't obsess about whether each intermediate commit "works" — for scaffolding PRs it's fine if the full picture only snaps together at the end.
4. **Prefer many small focused commits over one large mixed one** — a reviewer can read, revert, or cherry-pick a focused commit; they can't do any of those to a blob.
5. **Use `git add <specific paths>`** — never `git add -A` or `git add .` when splitting, or you'll sweep in the next commit's work by accident.
6. **Verify between commits** with `git status` and `git log -1` to confirm the split landed as intended.

Corollary: if a commit's subject line needs the word "and" to be accurate, it probably should have been two commits.

## Changelog discipline

This repo follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). **Every user-visible commit must touch `CHANGELOG.md`** under the `## [Unreleased]` section, in the appropriate subsection:

- **Added** — new features or capabilities.
- **Changed** — changes to existing functionality.
- **Deprecated** — soon-to-be-removed features.
- **Removed** — now-removed features.
- **Fixed** — bug fixes.
- **Security** — vulnerability fixes.

Entries should be short imperative phrases that describe user-facing impact — not implementation detail. "Added sidecar PTY support for terminal pane" beats "Added `internal/pty/session.go`."

### Be concise — this is the rule, not a suggestion

CHANGELOG entries must be **one or two short sentences**. Hard cap: **60 words per bullet**, enforced by the pre-push gate — verify before committing with `make changelog-gate` (run the `make` target, not the script it wraps). Aim for 30 or under; if you can't say it in one line wrapped at ~75 columns, you're writing the wrong document.

The CHANGELOG is read by humans scanning for what changed between two versions. It is **not** the place for the rationale, the probe results, the implementation detail, the behavior-change deep dive, or the "see also" cross-references. Those belong in:

- the **commit message body** — explain *why*, list evidence, name the trade-offs;
- a **D-record / decision document** — durable architectural rationale;
- the **ticket / PR description** — work-context and review notes.

Hard rules:

- **No multi-paragraph bullets.** One paragraph max. If you reach for a blank line inside a bullet, stop and split or trim.
- **No "Behavior change:" / "Side benefit:" / "Note:" sub-headers inside a bullet.** Those are essay structure; put them in the commit message.
- **No probe numbers, latency stats, or %-coverage deltas in entries.** ("hit 95% target" is fine; "0 hangs in 300 spawns vs ~5% before" is commit-body material.)
- **No nested function/file lists inside parentheses.** If you find yourself writing `(foo, bar, baz, …)` for more than 3 items, just say "several X" and trust the diff.
- **Don't restate the title in the body.** A bullet is its own title.

Calibration — match the **existing entries** in `CHANGELOG.md`. Open it, look at five recent bullets, write to that length. If your draft is visibly bigger than its neighbors, trim until it isn't.

Good:
> - Mouse wheel scrolling in Claude pane — converts scroll events to PgUp/PgDown so TUI apps scroll naturally.

Bad (verbose; commit-body material leaked in):
> - **PTY spawning switched from `forkpty()` to `posix_openpt()` + `posix_spawn()`** (T-96). `forkpty` calls `fork()` underneath, which is unsafe in the multithreaded Dart VM: about 5% of spawns deadlocked in the child before `execve` because libc locks held by ghost-threads remained "locked forever" in the forked child. `posix_spawn` uses `vfork` (glibc/musl/macOS), keeping the parent suspended until `execve` completes — no Dart code runs in the child. Probed: zero hangs in 300 sequential spawns vs ~5% before. **Behavior change:** missing executable / missing workingDirectory now surface as a `PtyException`…

Better:
> - PTY spawning uses `posix_openpt` + `posix_spawn` instead of `forkpty` — closes a ~5% deadlock window in the multithreaded Dart VM (T-96). Missing exe/cwd now throw `PtyException` at spawn time.

**What skips the changelog:** pure bookkeeping commits that have no user-visible effect (typo fix in internal comment, `.gitignore` tweak, lint config change, reformatting). When in doubt, add an entry — the harm of an extra line is zero.

When a commit spans multiple entries (e.g. a feature that adds one thing and fixes another), add a line under each applicable subsection rather than cramming both into one.

## Cutting a release

Cutting a release is its own commit. In a single commit:

1. Move all entries from `## [Unreleased]` under a new heading `## [X.Y.Z] — YYYY-MM-DD`.
2. Leave an empty `## [Unreleased]` section at the top with its subsection skeleton ready.
3. Bump `pubspec.yaml` `version:` to `X.Y.Z` (drop the `-dev` suffix for the tag; re-add it on the next development commit if desired).
4. Run `make gen-build-info` so `assets/licenses.yaml` `self.version:` re-syncs from pubspec (it's auto-rewritten by every build but commit the fresh state). Stage the resulting diff alongside step 3.
5. Commit subject: `release vX.Y.Z`.

`pubspec.yaml` is the single source of truth for the version. Every `make` build/run/test target regenerates `lib/src/build_info.g.dart` (gitignored) and rewrites `assets/licenses.yaml` `self.version:` from it — so the Flutter app sees the current version everywhere without manual sync. Bumping `pubspec.yaml` and the changelog out of sync is the mistake this rule prevents.

## Attribution trailer

Every commit ends with the Claude co-author line:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

The model-identifier variant produced by the Claude Code harness (e.g. `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`) is also accepted — don't rewrite it if the harness emits that form.

## HEREDOC discipline

Pass commit messages via HEREDOC so multi-line formatting survives:

```bash
git commit -m "$(cat <<'EOF'
short imperative summary

Optional longer body explaining why this change was needed,
wrapped at about 72 characters.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Never pass multi-line messages via `-m "line1\nline2"` or multiple `-m` flags — Git's behavior differs between shells and quoting regimes and the trailer can end up in the wrong place.

## What not to commit

- `.env` and any `*.env.local` — see `.gitignore`.
- `.claude/settings.local.json` — user-specific Claude Code settings, ignored.
- Build artefacts: `sidecar/bin/`, `sidecar/dist/`, `build/` (Flutter output), `app/.dart_tool/` — gitignored.
- SQLite index files (`*.sqlite`, `*.sqlite-wal`, `*.sqlite-shm`, `*.db`) — caches generated against local repos; must never land here. Gitignored defensively.
- Coverage / test output (`*.out`, `coverage.*`, `*.test`) — gitignored.

## Don't hand-manage `.pql/changelog`

The pre-commit hook exports the pql ticket DB and **auto-stages `.pql/changelog/` on every commit**. Don't `git add .pql/changelog` yourself and don't write a dedicated "flush the export" commit — just make your normal commit and the hook sweeps the ticket state in. The only thing to remember: a turn that files/changes a ticket but makes **zero commits** never fires the hook, so the change won't persist (and a later branch switch can drop it). The fix is simply to make a commit — you don't need to touch `.pql/changelog`.

## Safety reminders (reinforced from the global Claude Code protocol)

- **Never** `--no-verify`. If a pre-commit hook fails, fix the underlying issue and create a new commit.
- **Never** `--amend` a commit unless the user explicitly asks. A failed-hook commit didn't land, so amending would overwrite the *previous* commit and lose work.
- **Never** force-push to `main` or `master`. Warn the user if they ask.
- When staging, prefer naming specific files over `git add -A` / `git add .` — those can sweep in secrets or unintended files.
- `git status` before staging, `git diff --staged` before committing, `git log -1` after committing to confirm.
