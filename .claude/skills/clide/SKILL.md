---
name: clide
description: >
  Use when you are running inside the clide IDE and want to observe or drive
  its live UI — panes, editor, files, git, readers, toasts, layout — through
  the `clide` CLI, or to find out what commands clide exposes. clide is the
  IDE hosting this session; it puts `clide` on your PATH and a per-workspace
  socket in `CLIDE_SOCK`. Start with `clide capabilities` to enumerate the
  live tool surface. Triggers: "what can clide do", "drive the clide UI",
  "open this in clide", "show the user", "toast", or invoking /clide.
user-invocable: true
allowed-tools: Bash
---

# Driving clide from the CLI

You are (often) running **inside clide** — a Flutter IDE that hosts this
Claude session. It exposes its whole UI surface as a `clide <subsystem> <verb>`
CLI on your PATH, talking to the running app over a per-workspace socket
(`CLIDE_SOCK`). Every UI action the user can take has a CLI verb, and every
verb's effect is observable — that is the parity contract (D-6). So you can
*see what the user sees* and *show the user what you mean*.

## Discover the surface first — don't hard-code it

The authoritative, always-current list of commands is the app itself:

```
clide capabilities
```

It returns JSON: every registered command, split into `subsystem` + `verb`,
with its argument schema (`positional` order + per-arg `type`/`required`/
constraints) where one is declared. **Sourced from the live dispatcher
registry, so it never drifts.** New panels/verbs appear here the moment they
register — re-run it instead of trusting a remembered list (including this
one). `clide <subsystem>` with no verb, or an unknown command, prints usage.

## The two halves of parity

- **Observe** — read the live UI state:
  - `clide status` — one-shot orientation: workspace, git, active editor
    buffer + selection, open reader docs, the panes the user sees, layout.
  - `clide pane list`, `clide editor active` — narrower snapshots.
- **Drive** — make the UI do something:
  - `clide ui open <reader> <ref>` — open a doc in a GUI reader
    (`tickets`/`decisions` by id, `markdown`/`diff` by path): "look at this
    with me." `diff <path>` reveals the diff tab and scrolls to that file.
  - `clide ui toast "message" [--severity success|warning|error|info]` — raise
    a toast on the user's screen: "tests green", "push failed".
  - pane/editor/files/git verbs — see `clide capabilities` for the current set
    and their args.

## Conventions

- **Slots:** the layout has three content slots — `sidebar` (left), `workspace`
  (center, where Claude lives), `context` (right) — plus the bottom `statusbar`.
  Many verbs take a slot.
- **Honest failures:** a drive verb with no live GUI returns a `toolError`
  ("no live UI to drive"), not a hang. JSON on stdout; exit code conveys
  ok/usage/tool error.
- **You only see what flows through clide.** Your own non-`clide` shell work
  (plain file reads, `make test`, `git`) is outside clide's view by design
  (D-83) — run it *through* `clide …` if you want clide to observe it.
