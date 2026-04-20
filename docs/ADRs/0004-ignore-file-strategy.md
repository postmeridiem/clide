# ADR 0004 — Ignore file strategy

**Status:** accepted
**Date:** 2026-04-20 (ported from the claudian lineage)

## Context

Clide's working assumption is that the git repo *is* the workspace
— no separate "vault" concept layered on top. Every file-enumerating
surface in Clide (pql query panels, canvas drivers, graph view,
sidecar file watchers, pane lists, file tree) needs to skip the
obvious junk — `vendor/`, `node_modules/`, `dist/`, build artifacts
— or results drown in noise.

## Decision

One mechanism everywhere: the `ignore_files:` list in
`.pql/config.yaml`. An ordered list of gitignore-shaped files, later
entries win on per-pattern conflicts.

### Default

pql defaults to `ignore_files: [.gitignore]`. Most repos already
keep exclusions there, so zero config in a code repo; in a
notes-only directory `.gitignore` doesn't exist and the default is
a safe no-op.

### Clide sync

Per ADR 0003's "pql is a Clide subsystem when present" rule, Clide
writes the list on load:

- If `.clideignore` exists in the repo:
  `ignore_files: [.gitignore, .clideignore]`. Clide-specific deltas
  (including `!pattern` negations) layer on top of gitignore.
- Otherwise: `ignore_files: [.gitignore]` (matches the pql default).

No conditional sync. Clide only stomps `ignore_files:`; other pql
config keys are left alone.

### `.clideignore` semantics

- Carries **only** the Clide-specific deviations from `.gitignore`.
  Never duplicate gitignore's contents.
- Supports `!pattern` negations to un-ignore specific entries (e.g.
  `!.github/` to expose workflow docs in query results).

### Walker magic: none except `.git/`

Git self-hides `.git/` — that's the only invisible exclusion in the
stack. Every other tool is explicit: pql adds `.pql/` to
`.gitignore` at install time, and Clide adds any private dirs it
introduces (e.g. `.clide/`) to `.gitignore` on install. Exclusion
flows through the normal `ignore_files:` chain; no hardcoded walker
exceptions for tool-owned dirs.

### Same list, same rules, everywhere

Sidecar consumers (watchers, canvas, pane list, file tree, graph
view) read the same key from `.pql/config.yaml` and apply identical
precedence, so Claude and the user always see the same filtered
surface.

## Consequences

- Users get one config knob, in a file they might already know (pql
  users) or never need to touch (Clide-only users).
- `.clideignore` is short by design — it's deltas, not a full list.
- Removing Clide from a repo leaves pql working with vanilla
  defaults (Clide's last-written `ignore_files:` stays until pql or
  the user rewrites it; worth reconsidering during uninstall design).
- Upstream pql work: the `ignore_files:` list is already the shape
  pql has landed on (plural, ordered, defaults to `[.gitignore]`).
