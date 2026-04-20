# ADR 0006 — CLI and event surface contract

**Status:** accepted
**Date:** 2026-04-20

## Context

[ADR 0001](0001-cli-first-not-mcp.md) established that Claude drives
Clide via a Bash CLI, not MCP. That decided the *channel*. It did
not define the *surface* — which subsystems exist, how commands
relate to events, what the JSON looks like on the wire, how
subscribers discover state changes.

CLAUDE.md states the rule colloquially: "every CLI subcommand has a
UI affordance in the app, and every UI action has a CLI. If you add
one side without the other, the feature is incomplete." This ADR
restates that as an implementable contract.

The shape needs to satisfy three things at once:

1. **User/Claude parity.** Anything the user can do with a mouse,
   Claude can do with `clide <...>`. Anything the user can observe
   in the UI, Claude can observe via events.
2. **Daemon as authoritative state.** The app and the CLI are both
   clients. State lives in the `clide --daemon` process; commands
   mutate it; events broadcast changes to all subscribers.
3. **pql-style ergonomics.** One tool-use pattern for Claude across
   pql and clide — same exit codes, same JSON-on-stdout habit, same
   stderr-for-diagnostics rule.

## Decision

The CLI is organised into **subsystems**. Each subsystem owns a
noun, a set of verbs, and a set of events. The set is closed at any
point in time (documented); growth is additive (new verbs, new
events — never renaming existing ones without a version bump).

### Subsystem list (initial, by tier)

| Subsystem | Tier | Nouns | Representative verbs | Representative events |
|---|---|---|---|---|
| `pane`     | 1 | terminal pane | spawn, list, focus, close, write, resize, tail | `pane.spawned`, `pane.output`, `pane.exit`, `pane.resized` |
| `tab`      | 2 | workspace tab | new, switch, close, list | `tab.opened`, `tab.switched`, `tab.closed` |
| `open`     | 2 | editor shortcut | *(verb-only: `clide open <path>`)* | — (emits `editor.opened`) |
| `editor`   | 2 | active editor buffer | goto, highlight, insert, replace-selection, save | `editor.opened`, `editor.selection_changed`, `editor.saved` |
| `panel`    | 2 | sidebar/context panels | show, hide, toggle, list | `panel.visibility_changed` |
| `tree`     | 2 | file tree | reveal, refresh | `tree.node_expanded`, `file.changed` |
| `git`      | 3 | working tree | status, stage, unstage, stage-hunk, commit, stash, pull, push | `git.status_changed`, `git.branch_changed` |
| `pql`      | 4 | queries | run, tags, backlinks | `pql.result` |
| `canvas`   | 5 | canvas surface | open, node add/move/connect, save | `canvas.node_added`, `canvas.node_moved`, `canvas.connection_added` |
| `graph`    | 5 | graph view | open, focus, filter | `graph.focused`, `graph.filter_changed` |
| `theme`    | 6 | theme/palette | set, list, get | `theme.changed` |
| `settings` | 6 | settings store | get, set, list | `settings.changed` |
| `project`  | — | whole-workspace | status, reload, events | `project.ready`, `project.reloaded` |

Two umbrella entry points sit outside any subsystem:

- `clide tail --events [--filter <subsystem>[:<id>]]` — subscribe to
  the event stream. Bare `tail --events` gets everything; filtered
  forms narrow by subsystem or by subsystem+id (e.g.
  `--filter pane:p_7`, `--filter git`).
- `clide status` — one-shot daemon snapshot: connected clients,
  live panes, open tabs, workspace root, daemon version, uptime.

### Command shape

```
clide <subsystem> <verb> [<positional>...] [--flag ...] [-- argv...]
```

- Positionals are nouns/ids; flags are modifiers.
- `--` separates Clide's args from an inner argv passed through
  (e.g. `clide pane spawn --cwd X -- tmux new-session -A -s foo`).
- Verbs are imperative (`spawn`, not `create-pane`).
- Where it reads naturally, single-word shortcuts exist for the
  hottest paths (`clide open <path>` → `clide editor open <path>`).
  Shortcuts alias; they do not fork.

### Exit-code contract (parity with pql)

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error (bad args, unknown id, precondition failed) |
| `2` | Tool error (daemon unreachable, IPC failure, internal panic) |
| `3` | Not-found (id or path doesn't resolve) |
| `4` | Conflict (state busy, already-running, concurrent-modify) |
| `64`–`78` | Reserved, per `sysexits.h`, for future specific cases |

Diagnostic JSON on **stderr** (not stdout) on any non-zero exit:
```json
{"code":1,"kind":"user_error","subsystem":"pane","message":"pane id p_99 not found","hint":"clide pane list"}
```

Stdout stays machine-parseable on success. This matches pql.

### Event schema

Events are JSON objects, one per line, on the `--events` stream.
Every event:

```json
{
  "v": 1,
  "ts": "2026-04-20T21:00:00.123Z",
  "type": "pane.output",
  "subsystem": "pane",
  "id": "p_7",
  "payload": { "bytes_b64": "…", "seq": 412 }
}
```

- `v`: schema version. Bumped only for breaking changes. Old
  subscribers pin `v`.
- `ts`: ISO-8601 UTC with millisecond precision.
- `type`: `<subsystem>.<verb_past|noun_changed>`. Past-tense for
  things that happened; `_changed` suffix for state transitions.
- `subsystem` + `id`: redundant with `type`, but makes
  filtering cheap and future-flexible.
- `payload`: subsystem-defined; documented per subsystem.

Binary payloads (PTY output, file contents) are base64. The ergonomic
cost is worth the "entire stream is line-delimited JSON" invariant.

### Command ↔ event duality

Every state-changing command emits at least one event. Subscribers
see the same mutation whether they triggered it or not, and the
issuing client gets the event back (so `clide pane spawn` followed
by a `tail --events` subscription sees `pane.spawned` regardless of
subscribe order, via a short replay buffer per subsystem).

Read-only commands (`list`, `get`, `status`) emit nothing.

### User/Claude parity as a check

Every merge to `main` that adds a UI affordance must either:
- add the matching CLI verb, or
- include a linked follow-up task naming the verb to add next.

Every merge that adds a CLI verb must either:
- surface it in the UI, or
- document why the verb is Claude-only (rare; mostly diagnostics
  like `clide status`).

Events have the symmetric rule: any UI surface that reacts to state
must react to the corresponding event; any new event must be
consumable both by the UI and by `clide tail --events`.

## Consequences

- **Surface is enumerable.** Adding a subsystem means adding a row
  to the table above and specifying its verbs + events in a short
  doc under `docs/cli/`. The daemon registers it; the CLI dispatcher
  picks it up; `clide --help` and `clide <subsystem> --help` stay
  accurate by construction.
- **Wire schema is versioned.** `v: 1` is the starting point.
  Compatibility breaks bump the major and land alongside a
  `project.yaml` `schema_version:` bump.
- **Replay buffer per subsystem.** Cheap (most subsystems emit
  seldom); needed so a subscriber that connects after a command
  still sees that command's effect. Buffer depth per subsystem is a
  tuning parameter; defaults to 16 events.
- **Events are the only UI→app state channel.** The Flutter app
  does not poll; it subscribes. Panels render from the last event
  for their subsystem + current snapshot from `project status`.
- **pql events fit naturally.** Long-running `pql` queries stream
  rows as `pql.result` events keyed by a query id, letting the
  Query panel render incrementally.
- **Testability.** Every subsystem can be integration-tested by:
  start a daemon → open a `tail --events` subscriber → issue
  commands over the CLI → assert events. No UI needed for
  protocol-level coverage.
- **Extension API (Tier 6) inherits this.** A Dart extension
  publishes a subsystem; the same registration pipeline exposes
  it to Claude via the CLI. Extensions don't get a second-class
  channel.

## Open questions

- **Authorisation granularity.** The daemon's token auth is coarse
  (allow all / deny all). Later, per-subsystem grants may matter
  (e.g. restrict `git push`). Out of scope here.
- **Back-pressure on event streams.** A subscriber that falls behind
  on `pane.output` (a firehose) needs a policy: drop oldest, block
  producer, coalesce, or kill subscriber. Defer until Tier 1 is in
  real use.
- **Event persistence.** Events are in-memory only in v1. If a
  future need (audit log, undo) wants persistence, it becomes a
  subsystem that subscribes and writes — not a property of the bus.
