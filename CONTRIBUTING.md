# Contributing to clide

clide is an IDE for the Claude Code CLI, built as a single Flutter
package at the repo root. This guide is for people working on clide
itself.

For day-to-day model-driven work in the codebase, see
[`CLAUDE.md`](CLAUDE.md) — it documents the same guardrails from the
agent's point of view and is the place to look for "why is the code
shaped like this?"

## One-time setup

```
git clone git@github.com:postmeridiem/clide.git
cd clide
make hooks && flutter pub get
```

`make hooks` installs the repo's git hooks (pre-commit + post-merge).
Flutter must be on the stable channel and on `$PATH`.

If you haven't used [pql](https://github.com/postmeridiem/pql) before,
install it and run `pql init` once in the repo root. pql is a hard
dependency for the governance + ticket workflow described below.

## The five commands you'll actually use

```
make run           # launch the desktop app
make verify        # no-tests sweep — analyze + format + decisions + changelog gate
make test          # fast suite — analyze + format + unit + widget + golden
make test-a11y     # WCAG-AA contrast + keyboard traversal contracts
make push-check    # the pre-push gate; what CI runs
make build-linux   # release artefact for the host platform
```

`make verify` is the lightweight "are the gates green?" check for
mid-edit iteration. `make push-check` is the full pre-push pipeline
(verify + every test suite + coverage gate).

`make` with no target prints the full list. `make test-integration`
boots a real app process and is slow; reserve it for the rare change
that touches startup wiring.

The pre-push hook runs `make push-check` automatically. Don't bypass
it with `--no-verify` — fix the underlying issue and create a new
commit. Pre-push includes:

- `flutter analyze` (zero warnings)
- `dart format --set-exit-if-changed`
- the fast unit/widget/golden suites
- accessibility contract tests
- a coverage floor read from `coverage_floor:` in `pubspec.yaml`
  (currently 95 %; ratchets up only — see
  [D-66](governance/decisions/testing.md#d-66))
- `CHANGELOG.md` `[Unreleased]` bullets ≤ 60 words each

## Decisions, questions, rejected (DQR)

clide tracks architectural commitments as durable records under
[`governance/`](governance/):

- `decisions/<domain>.md` — confirmed decisions (`D-NNN`)
- `questions/<domain>.md` — open questions (`Q-NNN`)
- `rejected/<domain>.md` — rejected proposals (`R-NNN`)

When you make a non-trivial architectural choice, write it down:

```
pql decisions claim D <domain> "short title"
```

This reserves a fresh ID and tells you where to add the record. The
[governance/README.md](governance/README.md) explains the format and
the recommended domain list.

Pre-push validates that every `D-NNN` / `Q-NNN` / `R-NNN` link in
the docs and code resolves to an actual record (`pql decisions
validate`). Broken references fail the build.

## Tickets

All non-trivial work is tracked in `pql ticket`:

```
pql ticket list --status in_progress
pql ticket show T-NNN[,T-NNN…]      # batch form on pql 1.4.33+
pql ticket new task "title" --parent T-NNN --priority medium
pql ticket status T-NNN in_progress
pql ticket status T-NNN done
```

A ticket exists for any change a reviewer might want to ask "why?"
about. Bug fixes, refactors, and consultant findings all become
tickets before the diff lands. Trivial typo fixes don't need one.

## Commit conventions

See [D-37](governance/decisions/process.md#d-37) and the bundled
[`git-commit` skill](.claude/skills/git-commit/SKILL.md). In short:

- Imperative subject ≤ 70 chars, no Conventional Commits prefix
  (this isn't a Conventional Commits repo — the archived Python
  predecessor under [`legacy/`](legacy/) is, but the rebuild isn't).
- One logical change per commit. If the subject needs "and", split it.
- Every user-visible commit adds an entry to `CHANGELOG.md` under
  `[Unreleased]` in the right subsection (Added, Changed, Deprecated,
  Removed, Fixed, Security). Keep entries to one or two short
  sentences — the 60-word cap is enforced by `ci/changelog_gate.sh`.
- Co-author trailer:
  `Co-Authored-By: Claude <noreply@anthropic.com>` when Claude wrote
  any of the diff.

Never `--amend` a commit unless explicitly asked. Never force-push
to `main`. Never `git add -A` / `git add .` when staging — name
files explicitly so stray secrets or build artefacts don't sneak in.

## Cutting a release

A release is a single commit:

1. Move all `## [Unreleased]` entries under a new `## [X.Y.Z] —
   YYYY-MM-DD` heading.
2. Leave an empty `## [Unreleased]` skeleton at the top.
3. Bump `pubspec.yaml` `version:` to `X.Y.Z` (no `-dev` suffix on
   the release tag; add it back on the next development commit if
   you like).
4. Commit subject: `release vX.Y.Z`.

`pubspec.yaml` is the single source of truth for the version — the
Makefile reads it for ldflag stamping and the app reads it for build
info.

## What goes where

- **Bug, feature, sweep:** file/claim a ticket, branch, code, test,
  commit, push. Push triggers `make push-check`.
- **Architectural decision:** `pql decisions claim`, write the
  record, then file the implementation ticket linked via
  `decision_ref`.
- **Open question:** drop a `Q-NNN` under
  `governance/questions/<domain>.md`. Triage later.
- **Rejected proposal:** drop an `R-NNN` under
  `governance/rejected/<domain>.md`. Future-you (or a reviewer)
  will be glad it's written down.

## Reporting issues

The public issue tracker lives at
<https://github.com/postmeridiem/clide/issues>. The Gitea mirror is
read-only.
