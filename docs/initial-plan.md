# Clide — Initial Plan (Flutter rebuild)

**Working name:** clide (unchanged from the Python era). Repo root:
`/var/mnt/data/projects/clide`. Flutter desktop app + Go sidecar/CLI.

## Context

Clide v1.2.0 is a Python Textual TUI — terminal-only, polished, with
a pane model, panel set, git skills, plugin system, and a ttyd-backed
web variant. That implementation is archived under `legacy/` in this
repo; `git log -- legacy/` preserves its history.

In parallel, a two-day experiment called **claudian** explored a
"thin Obsidian plugin + Go sidecar" approach to the same problem:
run Claude Code inside a markdown-aware IDE. That project was tossed
when the implementation hit two walls:

1. Obsidian is Electron. Terminal rendering in Electron has a
   documented failure mode on macOS (repaint thrash, WebGL context
   loss, display-drag ghosting) that the user has lived through.
   xterm.js mitigations soften the pain; they don't remove it.
2. Most of "Obsidian's value" turned out, on examination, to be two
   features: canvas and graph. The rest — the vault concept, inline
   YAML "bases," the wikilink implementation, the plugin ecosystem —
   was either parallel ceremony to what the git repo already
   provides, or better solved elsewhere (pql).

The lesson: we were fighting the host instead of using it. Clide
becomes a Flutter desktop app, with the Python Clide IDE skeleton
rebuilt natively and a sharpened subset of Obsidian's ideas folded
in. Claudian's architectural patterns (Go sidecar, CLI-first,
pql-as-subsystem, ignore-file strategy, supply-chain gate,
changelog discipline) port over as ADRs 0001–0004 and the
`.claude/skills/git-commit` rules; the plugin code itself does not.

**Intended outcome:** Clide is the IDE you open on a code repo.
Claude runs inside it (the terminal is first-class, always visible).
Markdown files are first-class content. Canvas and graph surfaces
support concept development. pql is the query engine. The Go
sidecar handles PTYs, subprocesses, file watching, git, and pql
invocations; the Flutter app renders. Claude drives the UI through
a `clide` CLI with the same contract as pql.

## Guardrails / non-negotiables

- **Flutter desktop is the UI host.** No Electron, ever. Web target
  may work as a happy accident; don't compromise desktop fidelity for
  it. `xterm.dart` is the terminal renderer.
- **No heavy lifting in the UI layer.** Flutter app stays focused on
  rendering and interaction. PTYs, subprocesses, file watching, git,
  pql invocations all live in the Go sidecar.
- **CLI-first, not MCP.** Claude talks Bash (`clide ...`), same
  contract style as pql. See [ADR 0001](ADRs/0001-cli-first-not-mcp.md).
- **Sidecar language: Go.** Static binary, same idioms as pql. See
  [ADR 0002](ADRs/0002-sidecar-language-go.md).
- **User/Claude parity.** Every `clide` subcommand has a UI
  affordance in the Flutter app, and every UI action has a
  corresponding subcommand. Incomplete otherwise.
- **pql is a supporter tool and a clide-managed subsystem.** The
  only place clide contains pql logic is `sidecar/internal/pql/` —
  pure shell-outs. See [ADR 0003](ADRs/0003-pql-as-supporter-tool.md).
- **Repo-is-the-workspace.** The git repo root is the workspace.
  No parallel "vault" concept. Ignore behaviour drives through
  `.pql/config.yaml` — see [ADR 0004](ADRs/0004-ignore-file-strategy.md).
- **Dependencies: version-locked and CVE-checked.** Go deps exact-
  pinned and govulncheck-gated; Dart deps prefer-zero-then-exact-
  pinned. See the memory files under
  `~/.claude/projects/-var-mnt-data-projects-clide/memory/`.

## What carries forward from each parent project

| From Python clide (`legacy/`) | Carried forward as |
|---|---|
| Pane/visibility model (Sidebar / Workspace / Context) | Same model, rendered in Flutter widget trees |
| Workspace tabs (Editor / Diff / Terminal — appear when needed) | Same pattern; `xterm.dart` hosts the Terminal tab |
| Claude-always-visible in the workspace center | Unchanged; the centrepiece |
| Git panel (staged/unstaged, click actions) | Port widget-for-widget; sidecar shells out to git |
| Git skills (`/commit`, `/stash`, `/pull`, `/push`) | Rewire to call `clide git ...` under the new CLI |
| Context panel (Jira / TODOs / Problems) | Port; data providers become sidecar subsystems |
| TODO.md parsing for the TODOs panel | Preserve the format; sidecar parses and serves |
| Theme system (22 themes, TOML) | Port the palette over time; Flutter theming is first-class so no bespoke system needed |
| Plugin system (pluggy hookspecs) | Translates into a Dart extension API we design fresh; not imported |

| From Obsidian (as an idea, not a dep) | Carried forward as |
|---|---|
| Canvas | Flutter `CustomPaint` + `InteractiveViewer`; `.canvas` JSON-schema-compatible where easy |
| Graph view | Flutter-native; data from pql, not a re-parser |
| Wikilink syntax (`[[page]]`) | Parser + renderer, nothing more |
| Frontmatter | Standard YAML; pql already parses it |

| From Obsidian, **rejected** |
|---|
| "Vault" concept — the git repo is the workspace |
| Inline bases (YAML query tables) — pql at the repo level |
| Obsidian's wikilink implementation — syntax only |
| Plugin ecosystem — clide's extension API is its own |

| From claudian (2-day experiment) | Carried forward as |
|---|---|
| Go sidecar + CLI-first architecture | Unchanged; ADRs 0001–0002 |
| pql-as-supporter-tool + pql-as-clide-subsystem rules | Unchanged; ADR 0003 |
| Ignore-file strategy (`ignore_files:` in `.pql/config.yaml`) | Unchanged; ADR 0004 |
| Supply-chain gate (`make security`, `make vuln`, lockfile discipline) | Port for Go sidecar; Dart equivalent TBD |
| Changelog discipline (Keep a Changelog, `project.yaml` version sync) | Port verbatim |
| Commit conventions (imperative, no types, HEREDOC, attribution trailer, logical splits) | Port verbatim to `.claude/skills/git-commit` |

**Python clide's future:** feature-frozen at v1.2.0. Stays under
`legacy/` for reference. No back-porting.

## Architecture

```
┌────────────────── clide (Flutter Desktop) ───────────────────┐
│                                                              │
│  ┌─────────────┬────────────────────────────┬─────────────┐  │
│  │ Sidebar     │ Workspace                  │ Context     │  │
│  │             │ ┌──── Editor / Diff ─────┐ │             │  │
│  │ Files       │ │  (appears when needed) │ │ Jira        │  │
│  │ Git         │ └────────────────────────┘ │ TODOs       │  │
│  │ Tree        │                            │ Problems    │  │
│  │             │ ┌──── Claude (xterm.dart) │ │             │  │
│  │             │ │  (always visible)       │ │             │  │
│  │             │ └────────────────────────┘ │             │  │
│  │             │ ┌──── Terminal (optional)│ │             │  │
│  │             │ └────────────────────────┘ │             │  │
│  ├─────────────┤                            ├─────────────┤  │
│  │ ⎇ main      │   Canvas + Graph live as   │             │  │
│  │ staged: 2   │   full-screen views        │             │  │
│  └─────────────┴────────────────────────────┴─────────────┘  │
│                          │                                    │
│                          │ Dart IPC client                    │
│                          ▼                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  clide sidecar daemon (Go, same binary as CLI)         │  │
│  │  - real PTYs (for xterm.dart panes)                    │  │
│  │  - subprocess management                               │  │
│  │  - filesystem watchers                                 │  │
│  │  - git shelling-out                                    │  │
│  │  - pql wrapper                                         │  │
│  │  - IPC server (unix socket, token auth, JSON-lines)    │  │
│  └─────────────┬──────────────────────────────────────────┘  │
│                │                                              │
│                ▼                                              │
│   ┌────────────────────────┐   ┌─────────────────────────┐   │
│   │ Claude Code (inside    │   │ pql (Go CLI, external)  │   │
│   │ a workspace PTY pane)  │   │ called by sidecar and   │   │
│   │                        │   │ by Claude directly      │   │
│   │ $ clide open wiki/...  │   └─────────────────────────┘   │
│   └────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────┘
```

**Three surfaces, one coherent tool:**

- **`clide` Flutter app** (UI): renders panels via widget trees,
  hosts `xterm.dart` panes for terminals, connects to the sidecar
  over IPC.
- **`clide` CLI** (one-shot): Claude's entry point. Parses args,
  opens the sidecar socket, sends a request, prints JSON on stdout
  with the pql-style exit-code contract, exits.
- **`clide --daemon`** (long-running sidecar): Same binary, different
  mode. Owns PTYs, subprocesses, file watchers, git, pql shell-outs.
  IPC server for app + CLI. Started by the app on load; survives app
  restarts so Claude sessions persist.

## Repo layout (target)

```
projects/clide/
├── README.md                           # pitch + link to this plan
├── LICENSE
├── CHANGELOG.md
├── CLAUDE.md                           # lean orientation for Claude Code
├── project.yaml                        # single source of truth: version, module path, schema version
├── Makefile                            # drives both app (flutter) and sidecar (go)
├── .gitignore / .editorconfig
├── .clideignore                        # optional; see ADR 0004
├── .claude/                            # project-level Claude Code config + skills (committed)
├── .githooks/pre-push                  # push-gate runs lint/test/vuln on both app and sidecar
├── ci/                                 # lint.sh, test.sh, security.sh, release.sh
├── docs/
│   ├── initial-plan.md                 # this document
│   └── ADRs/0001..0005                 # decisions
├── app/                                # Flutter desktop (generated by `flutter create`)
│   ├── pubspec.yaml
│   ├── lib/                            # main.dart + panels/, widgets/, ipc/, theme/
│   ├── linux/ macos/ windows/          # platform scaffolding
│   └── test/
├── sidecar/                            # Go sidecar + CLI, single binary, two modes
│   ├── go.mod
│   ├── cmd/clide/main.go
│   └── internal/
│       ├── cli/                        # one-shot subcommand dispatch
│       ├── daemon/                     # --daemon mode
│       ├── ipc/                        # unix-socket server (for app + CLI)
│       ├── pty/                        # real PTYs for xterm.dart panes
│       ├── proc/                       # subprocess management
│       ├── git/                        # git shell-outs
│       ├── pql/                        # thin wrappers around the pql binary
│       ├── diag/                       # exit-code contract + stderr-JSON
│       └── version/                    # ldflag-stamped build info
├── legacy/                             # archived Python clide v1.2.0
└── tests/                              # integration tests that span app + sidecar
```

## Tier roadmap (prioritized)

### Tier 0 — Foundation: Flutter app + sidecar daemon connected, empty IDE

- Flutter app scaffold (`app/`) with a three-column layout, placeholders.
- Go sidecar daemon (`sidecar/`) — socket, token auth, JSON-lines
  protocol, single-instance lock, graceful shutdown.
- `clide` CLI one-shot mode — version + a `ping` subcommand.
- Dart IPC client — auto-reconnect, JSON-lines envelope.

**Acceptance:** `clide --daemon` runs; Flutter app connects; the app
shows a connected-status indicator and the panels as placeholders.

### Tier 1 — Claude runs inside clide

- `xterm.dart` Terminal pane in the Workspace center, connected to
  a sidecar-owned PTY.
- Session persistence: sidecar keeps PTYs alive across app restarts.
- "Open Claude" button that spawns a PTY running `claude` (or
  `tmux attach -t claude` for team mode when that ships later).

**Acceptance:** open clide → Claude is running in the workspace →
quit and reopen clide → Claude session is still there.

### Tier 2 — Pane model and active-file awareness

- File tree panel (Sidebar/Files), drag-to-reveal, click-to-open.
- Editor tab — markdown and code via `flutter_highlight` or our own
  light renderer; saves through the sidecar's file watcher.
- `clide open <path>`, `clide active`, `clide insert`,
  `clide replace-selection`, `clide tail --events …` — the CLI
  surface Claude uses to drive the UI. Equal UI affordance for each.

**Acceptance:** Claude says *"opening `notes/today.md`"* → runs
`clide open notes/today.md` → the file appears in the Editor tab.

### Tier 3 — Git

- Git panel (Sidebar/Git) — staged/unstaged groups, hunk-level
  stage/unstage, conflict UI. Sidecar shells out to git; Flutter
  renders.
- Diff tab in the Workspace (side-by-side + unified toggle).
- `clide git …` subcommands back the panel actions. Python clide's
  `/commit`, `/stash`, `/pull`, `/push` skills rewire to call
  `clide git …`.

**Acceptance:** the common day-to-day git flow works entirely in
clide, with Claude driving the same operations.

### Tier 4 — pql integration (Query panel + everywhere else)

- Query panel renders `pql <args>` output as table / list.
- Results click-through opens the referenced file in the Editor
  tab.
- File tree, canvas node sources, graph view, backlinks indicator,
  problems panel — all pull from pql where applicable.

**Acceptance:** `pql tags` output renders in a Query panel; clicking
a tag narrows the file tree; backlinks show in the Context panel.

### Tier 5 — Canvas and graph

- Canvas surface: `CustomPaint` + `InteractiveViewer`, pan/zoom,
  node creation, connection drawing. Format aims for `.canvas`
  JSON-schema compatibility with Obsidian.
- Graph view: force-directed layout, link data from pql.
- `clide canvas node …`, `clide canvas connect …`,
  `clide graph open` — CLI parity.

**Acceptance:** open a canvas file from the Sidebar; drag a new
node; Claude can add a node by `clide canvas node …`.

### Tier 6 — Extension API (later)

- Dart extension API (design fresh, not ported from pluggy).
- Settings page, theme picker, keybinding editor.
- Distributable builds (macOS/Linux) via Flutter's native tooling.

## Critical integration points

- **`sidecar/cmd/clide/main.go`** — Cobra root: `clide <subcommand>`
  (one-shot) vs `clide --daemon` (long-running).
- **`sidecar/internal/ipc/server.go`** — single socket; token-auth;
  dispatches to subsystems (pty, proc, git, pql, canvas, panes).
- **`sidecar/internal/pql/`** — *only* place Clide contains pql
  logic; pure wrappers, no re-implementation.
- **`app/lib/ipc/client.dart`** — Dart IPC client; reconnect-on-
  reload; JSON-lines envelope.
- **Claude settings** — `.claude/settings.json` allow rule
  `Bash(clide *)`; no MCP config.
- **pql** — first-class supporter tool, called by Claude directly
  AND wrapped by Clide where ergonomics justify it.

## Decisions locked

1. **Name:** clide (unchanged). Binary: `clide`. Flutter app bundle
   id: `clide`.
2. **First milestone:** Tier 0 + Tier 1.
3. **Packaging:** single app + single sidecar/CLI binary. Platform
   builds via Flutter's native tooling.
4. **Distribution:** personal-only now, MIT-licensed (carried from
   legacy/).
5. **CLI-first, not MCP** (ADR 0001).
6. **No Electron, no Node in the UI layer** — Flutter and Dart only.
7. **pql is a supporter tool; wrap, don't duplicate; pql is a Clide
   subsystem when present** (ADR 0003).
8. **User-and-Claude parity** — every CLI has a UI affordance and
   vice versa.
9. **Dataview / bases out of scope** — pql is the query engine (ADR
   0003).
10. **Workspace = git repo root** — no vault concept.

## Open questions (investigate in-repo, not now)

- **`.canvas` schema compatibility** — how strictly do we match
  Obsidian's format? Decide during Tier 5 spike.
- **Extension API shape** — widgets? subcommands? both? Decide
  during Tier 6 planning.
- **IPC wire-format stability** — when to lock the schema,
  versioning strategy. Mirror in `project.yaml`
  `schema_version:` when it lands.
- **Code editor quality bar** — does the Editor tab need full LSP
  integration via the sidecar, or a lighter tree-sitter-based
  highlight-only view first? Decide during Tier 2.

## Remaining assumptions (flag if wrong)

- **Flutter Desktop on Linux + macOS** is the primary target;
  Windows is a stretch goal. Mobile is not a goal.
- **Gitea remote** (`git.schweitz.net/jpmschweitzer/clide`) remains
  the canonical host.
- **`pql` stays untouched** for Tiers 0–2; upstream pql work
  happens in pql's repo during Tiers 3–5.
- **tmux** is optional plumbing the sidecar can compose for team
  mode; not a hard dependency for Tier 1's session persistence
  (the sidecar holds the PTY fd directly).
