# ADR 0001 — CLI-first, not MCP

**Status:** accepted
**Date:** 2026-04-20 (ported from the claudian lineage)

## Context

Clide exposes capabilities to Claude Code (panes, terminals, git,
pql queries, canvas, graph). The two mainstream options for that
interface are:

1. A Model Context Protocol (MCP) server the agent connects to.
2. A plain Bash CLI the agent calls from its shell, matching the
   contract `pql` already follows.

## Decision

Claude talks to Clide exclusively via Bash (`clide ...`). No MCP
server. No protocol layer in Claude's face. The CLI uses the same
exit-code + stderr-JSON contract as pql.

## Consequences

- Same mental model as pql for the agent — one tool-use pattern
  covers both.
- No MCP runtime to host, authenticate, or keep in sync with client
  versions.
- User/Claude parity is easier to enforce: every CLI subcommand must
  have a UI affordance in the Flutter app and vice versa.
- Claude Code's `Bash(clide *)` allow rule is the only configuration
  Clide needs on the agent side.
- If an MCP-only integration becomes compelling later (e.g. a
  multi-agent scenario), nothing here precludes adding one that
  shells out to the same CLI.
