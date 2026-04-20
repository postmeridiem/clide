# ADR 0002 — Sidecar language: Go

**Status:** accepted
**Date:** 2026-04-20 (ported from the claudian lineage)

## Context

The Clide sidecar owns PTYs, subprocesses, file watchers, git
shelling-out, and the IPC server. It ships as a single static binary
that also serves as the `clide` CLI in one-shot mode. The Flutter
desktop app talks to it over IPC; Claude talks to it via the CLI.
Language candidates were Go and Rust.

Related hard constraint: **no heavy lifting in the UI layer.** The
Flutter app stays focused on rendering and interaction. Everything
heavy (PTYs, subprocesses, file watching, git, pql invocations)
lives in the sidecar. Reason: keep the UI layer thin and the
security-sensitive surface auditable in one language.

## Decision

The sidecar/CLI is written in Go.

Rationale:

- **Matches pql.** pql is Go; Clide wraps pql and reaches into its
  idioms constantly. Shared toolchain and shared patterns cut
  cognitive overhead.
- **Static binary.** Single artifact, trivial cross-compile, no
  runtime dependencies on the user's machine.
- **PTY story is fine.** `creack/pty` covers what we need; Rust's
  crates are marginally nicer but not decisive.
- **Muscle memory.** Build pipeline, `project.yaml` conventions,
  goreleaser setup, exit-code contract, diagnostic format — all
  already established in pql and portable one-to-one.

## Consequences

- Module path: `git.schweitz.net/jpmschweitzer/clide/sidecar`.
- Layout mirrors pql: `cmd/clide/main.go`, `internal/cli`,
  `internal/version` (ldflag-stamped `Version`, `Commit`, `Date`),
  `internal/diag` (exit codes + stderr-JSON diagnostics).
- Same Makefile shape: version read from `project.yaml` via awk,
  stamped via `-ldflags -X`.
