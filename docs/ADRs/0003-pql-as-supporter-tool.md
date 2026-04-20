# ADR 0003 — pql as supporter tool; Clide wraps, never duplicates

**Status:** accepted
**Date:** 2026-04-20 (ported from the claudian lineage)

## Context

[`pql`](https://github.com/postmeridiem/pql) is a pre-existing Go
CLI that indexes a markdown-bearing directory tree into SQLite and
exposes its semantics (frontmatter, wikilinks, tags, headings,
bases) through a query surface. Clide needs those capabilities for
its Query panel, canvas drivers, graph view, and any feature that
needs to know structure.

## Decision

Two complementary rules.

### 1. Wrap, don't duplicate.

Clide never re-implements backlinks, ranking, frontmatter parsing,
or wikilink resolution for query purposes. If a capability is
missing in pql, it is added upstream in pql's repo and Clide bumps
the dependency.

The only place Clide contains pql logic is
`sidecar/internal/pql/` — pure shell-outs to the `pql` binary, no
logic beyond invocation and result rendering.

### 2. pql is a Clide subsystem when Clide is present in the repo.

Broader than "wrap, don't duplicate." When Clide is loaded in a
repo, it owns pql's lifecycle and the config keys it cares about.
On load, Clide writes its current state into `.pql/config.yaml` —
no conditional sync, no "did anything change" logic.

Clide only stomps the keys it manages (starting with `ignore_files:`
— see ADR 0004). Other pql config keys are left alone so pql's
config surface can grow independently.

Clide does **not** touch pql's index/cache data under `<repo>/.pql/`
— that stays pql's private store. Only the config file is Clide's
to edit.

In repos without Clide, pql works standalone, unaffected. The rule:
direct-pql users get vanilla pql; Clide users get pql managed by
Clide.

## Consequences

- One source of truth for markdown semantics (pql).
- Clide's `sidecar/internal/pql/` package is deliberately thin.
- Any new query capability the UI wants goes through a pql upstream
  PR, not a local workaround.
- User never has to learn pql's config file to get consistent
  behavior — Clide manages it.
- The arrow Clide → pql is never inverted: pql stays ignorant of
  its wrapper, never hardcodes Clide filenames.
- pql is also the **only** query engine. Obsidian-style inline
  "bases" (YAML query tables embedded in markdown) are explicitly
  not supported; queries live at the repo level where they belong.
