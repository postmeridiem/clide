# self-analysis.md — can Claude actually work inside clide?

**Date:** 2026-06-02
**Author:** Claude (Opus 4.8), run as the dogfood agent against a live clide instance
**Method:** This is not a documentation review. clide was running while I wrote this
(socket `~/Library/Caches/clide/05cd448c962214d7.sock`, MCP SSE on `127.0.0.1:50354`,
daemon reports `version 2.1.0`). I probed my own environment, drove the live daemon, and
report what actually happened — with the command transcripts as evidence.

The question on the table: *we're close to working together inside clide — what's missing
from my end?* Here's the honest answer.

---

## TL;DR

**The daemon is ready. My hands are missing.**

Everything the CLI-first contract (D-1, D-6) promises works end-to-end at the socket
level — `git status`, `files`, `editor`, `pane`, exit codes, the lot. I verified it live.
But a fresh Claude session dropped into this repo **cannot reach any of it**, because:

1. There is **no `clide` binary on `PATH`** — and no install path that would put one there.
2. Nothing tells a fresh agent that clide is even running, where its socket is, or that
   the CLI exists.
3. The live UI surfaces the user sees (the Claude pane, file tree, open files) are **not
   reflected** in the registries the CLI reads — `pane list` and `editor list` came back
   empty while clide was open and in use.

The first one is the blocker. The fix is roughly ten lines of Makefile. The other two are
the difference between "the agent can issue commands" and "the agent and the user are
actually looking at the same workspace."

---

## What works today (verified live)

I built the C client (`make clide-cli` — it had never been built; `native/macos-arm64/`
did not exist) and pointed it at the running daemon:

```
$ native/macos-arm64/clide ping
{"pong":true,"ts":"2026-06-02T10:45:31Z","version":"2.1.0"}            # exit 0

$ native/macos-arm64/clide git status
{"branch":"main","upstream":"origin/main","ahead":0,"behind":0,
 "clean":false,"unstaged":[{"path":"governance/README.md",...}, ...]}  # exit 0

$ native/macos-arm64/clide files root
{"path":"/Users/jeroenschweitzer/Projects/clide","ignorePatterns":79} # exit 0
```

- **IPC transport is solid.** Unix socket, JSON envelopes, the `_argv` bridge — all live.
- **The command surface is real and broad.** `pane`, `files`, `editor`, `git`, `search`,
  `pql`, `panel` subsystems all dispatch. `git status` returned my actual working tree.
- **Exit-code discipline is correct** (this matters for an agent — it's how I know if a
  command worked):

  | command | exit |
  |---|---|
  | `clide ping` | `0` |
  | `clide git status` | `0` |
  | `clide editor open /nonexistent/path` | `1` |
  | `clide status` (not a real command) | `3` |

  0/1/3 map cleanly onto the pql contract. Good. An agent can trust these.

So the foundation is genuinely there. The gaps below are about **delivery and
observability**, not the core design.

---

## Gap 1 — `clide` is not on PATH, and nothing installs it there *(blocker)*

This is the one that stops us cold.

```
$ which clide          → clide not found
$ clide ping           → command not found (exit 127)
```

The CLI-first contract assumes I run `clide …` from Bash. I can't. Digging in:

- The C client (`native/clide-cli/clide.c`) is the real CLI. It builds only via the
  **separate, non-default** target `make clide-cli`, and the output had never been built.
- `make install` on **macOS** copies *only* the `.app` bundle to `~/Applications`. It
  **never places a `clide` CLI on PATH.**
- `make install` on **Linux** symlinks `clide` → `$(INSTALL_PREFIX)/clide/clide`, which is
  the **GUI app binary** (the Flutter runner), *not* the C client. So even the Linux path
  doesn't deliver the shell client.

Net: there is **no supported way** for the `clide` command to exist on an agent's PATH.
The contract that the entire agent-IDE relationship rests on has no delivery mechanism.

**Impact:** Total. Without this, "Claude works inside clide via the CLI" is aspirational.
I only got there by reverse-engineering the socket path and compiling a C file myself.

**Fix (small):**
- Make `clide-cli` a dependency of `build`/`install`.
- On macOS `install`, also drop the built C client somewhere on PATH
  (`~/.local/bin/clide`, or `/usr/local/bin`), and have the GUI launch offer to install it
  (à la VS Code's "Install 'code' command in PATH").
- Confirm the Linux symlink targets the **C client**, not the GUI binary.

---

## Gap 2 — No bootstrap: a fresh agent doesn't know clide is there

Even with the binary installed, a new session has no signal that it's hosted by clide.
There's a discovery file for the *MCP* path (`~/.claude/ide/<pid>.lock`, which correctly
pointed at workspace + SSE URL), but **nothing for the Bash/CLI path**:

- No `CLIDE_SOCK` / `CLIDE_WORKSPACE` env var in my shell.
- No injected note (CLAUDE.md fragment, system reminder) saying "you're inside clide; use
  `clide …` to drive the editor, git panel, and file tree."
- No pre-seeded `Bash(clide *)` allow rule mentioned anywhere the agent would see it.

I had to be *told* "you're running inside clide" and then go find the socket. That's not
discoverable.

**Impact:** High. Discovery is the difference between a capability existing and a
capability getting used. I won't reach for `clide editor open` if I don't know it's wired
up.

**Fix:** When clide spawns/hosts an agent, export `CLIDE_SOCK`/`CLIDE_WORKSPACE`, ensure
`clide` is on the child's PATH, and inject a short context note describing the CLI surface
and the parity contract.

---

## Gap 3 — The live UI isn't visible to the CLI *(parity premise breaks here)*

D-6's promise is two-way: every UI affordance has a CLI verb, **and the agent can observe
what the user is doing**. Right now I can't see the user's surfaces. While clide was open
and you were talking to me through it:

```
$ clide pane list     → {"panes":[]}
$ clide editor active → {"active":null}
$ clide editor list   → {"buffers":[]}
```

Empty. Either the built-in UI panes (the Claude conversation pane, the file tree, any open
viewer) **don't register into the daemon registries** the CLI reads, or those registries
only track CLI-spawned entities. Either way, the consequence is the same: **I cannot tell
what file you're looking at, what's selected, or what panes are open.** The "agent sees
what the user sees" half of parity isn't there yet.

**Impact:** High for real collaboration. Half of working *together* is me reacting to
what's on your screen ("you've got `dispatcher.dart` open — want me to jump to the handler
that's failing?"). Today I'm blind to it.

**Fix:** Make the built-in extensions register their panes/buffers/active-file state
through the same registries the `pane`/`editor` CLI reads. Add a `clide status` umbrella
(see Gap 6) that returns a one-shot snapshot: active pane, focused file + selection, git
summary, layout.

---

## Gap 4 — Event observation doesn't fit how an agent runs

`clide tail --events` is the design's answer to "how does Claude see state change." But a
streaming, never-returning command is awkward from a request/response tool loop — I can't
sit on an open stream the way a long-lived UI client can. I either background it and poll a
file, or I miss events.

This is more ergonomic than broken, and it overlaps the still-open Q-2 (back-pressure) and
Q-3 (event persistence/audit). But for *me specifically* it matters.

**Impact:** Medium. Without a pull-based form I'll just re-run `git status` / `editor
active` on demand and never use the event bus — which means I miss things that happen
between my polls.

**Fix:** Offer a cursor-based pull alongside the stream: `clide events --since <cursor>`
returning everything since the cursor plus a new cursor. That fits an agent loop natively
and dovetails with Q-3's persistence question.

---

## Gap 5 — Which Claude is the dogfood agent? *(needs a decision)*

There's an unresolved ambiguity I bumped straight into. My shell reports
`TERM_PROGRAM=zed` — i.e. *this* Claude (me) is an external Claude Code harness, not a
session clide spawned via the stream-json protocol (D-77/D-78). So there are two distinct
"Claude inside clide" stories, and they have different gaps:

- **(A) clide-hosted session** — clide spawns `claude --output-format stream-json`, renders
  the conversation natively, handles permission prompts as native cards (D-77/D-78). This
  is the *user's* primary Claude pane.
- **(B) external agent driving via CLI** — a Claude Code process (like me) that issues
  `clide …` commands to manipulate the IDE.

These aren't the same agent. In (A), the hosted Claude *is* the conversation but would
itself need `clide` on PATH to drive the surrounding IDE (Gaps 1–3 apply to it too). In
(B), clide can observe my `clide …` IPC calls but is blind to the rest of my tool use
(file reads, `make test`, plain `git`) because my shell isn't clide-owned.

**Impact:** Medium, but foundational — it decides what "working together inside clide"
even means. Worth a short governance note (Q- or D-record) pinning down the intended model:
is the dogfood agent the hosted stream-json session, an external CLI driver, or both?

---

## Gap 6 — Minor / cleanup

- **No `clide status` command.** There's no single one-shot "what's the whole state right
  now" call — the natural first thing an agent reaches for. (`status` currently returns
  exit 3, unknown command.) Cheap to add and high-value for orienting.
- **MCP transport is up but not reachable by me.** The SSE server is live
  (`:50354`), but `mcp__ide__*` tools aren't in my tool list this session, and
  `getDiagnostics`/`executeCode` were noted as stubs. So neither transport (CLI nor MCP) is
  actually wired to an external agent out of the box. The CLI path is the one to fix first
  (Gap 1); MCP can follow.
- **Version drift cosmetic check:** daemon reports `2.1.0`; worth confirming that matches
  `pubspec.yaml` so an agent keying off `clide version` isn't misled.

---

## Minimum to actually dogfool (priority order)

1. **Ship `clide` on PATH.** Build the C client by default; install it to a PATH dir on
   macOS *and* Linux (targeting the C client, not the GUI binary). *(Gap 1 — blocker)*
2. **Bootstrap the agent.** Export `CLIDE_SOCK`/`CLIDE_WORKSPACE`, ensure PATH, inject a
   context note + `Bash(clide *)` allow rule when clide hosts/launches an agent. *(Gap 2)*
3. **Make the live UI observable.** Register built-in panes/buffers into the CLI-visible
   registries; add `clide status` for a one-shot snapshot. *(Gaps 3, 6)*
4. **Add pull-based events** (`clide events --since`). *(Gap 4)*
5. **Decide the agent model** in governance — hosted session vs external CLI driver vs
   both. *(Gap 5)*

Items 1–2 are small and unblock everything. With just those, I can drive the IDE from
Bash today — I proved the daemon answers. Item 3 is what turns "I can issue commands" into
"we're actually working in the same workspace."

---

*Everything above was checked against a running clide, not inferred from docs. The pleasant
surprise is how little is actually broken: the hard part (a live, correct, single-process
IPC contract with proper exit codes) is done and working. What's missing is the last mile
that puts the tool in the agent's hands and lets the agent see the room.*
