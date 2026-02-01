# Clide

A terminal-based IDE that wraps Claude Code CLI, putting AI-assisted development at the center of your workflow.

## Why Clide?

Claude Code is powerful, but switching between terminal, editor, and project tools breaks your flow. Clide brings everything into one interface:

- **Claude stays visible** — Claude Code runs in the center panel, always accessible
- **Context at a glance** — File tree, git status, problems, and TODOs in dedicated panels
- **Panels appear when needed** — Editor, diff viewer, and terminal stay hidden until you need them
- **Git integration** — Commit, stash, pull, and push via Claude with built-in skills
- **22 themes** — From summer-night to dracula, with custom theme support

## Screenshot

```
┌─────────────────┬─────────────────────────┬──────────────────┐
│ Sidebar         │ Workspace               │ Context          │
│                 │ [Editor][Diff][Terminal]│                  │
│ [Files][Git]    │ (appears when needed)   │ [Jira][TODOs]    │
│ [Tree]          ├─────────────────────────┤ [Problems]       │
│                 │                         │                  │
│                 │ Claude                  │                  │
│                 │ (always visible)        │                  │
│                 │                         │                  │
├─────────────────┤                         ├──────────────────┤
│ ⎇ main ▾       │                         │                  │
│ staged: 2      │                         │                  │
└─────────────────┴─────────────────────────┴──────────────────┘
```

## Features

### Left Sidebar
- **Files** — Project file tree with syntax-aware icons
- **Git** — Staged/unstaged changes with action buttons
- **Tree** — Visual branch graph
- **Branch status** — Current branch with quick switcher

### Center
- **Claude Code** — Full PTY terminal integration, always visible
- **Editor** — Syntax highlighting via tree-sitter
- **Diff** — Side-by-side diff viewer
- **Terminal** — Command execution

### Right Context
- **Jira** — Issue display via CLI integration
- **TODOs** — Code comments and TODO.md items
- **Problems** — Linter errors and warnings

### Git Operations

Click buttons in the Git panel to delegate operations to Claude:

| Button | Skill | What Claude Does |
|--------|-------|------------------|
| Commit | `/commit` | Reviews changes, writes commit message |
| Stash | `/stash` | Stashes working changes |
| Pull | `/pull` | Pulls with rebase, helps resolve conflicts |
| Push | `/push` | Pushes to remote, sets upstream if needed |

Skills are installed automatically to your project's `.claude/skills/` directory.

## Installation

### Requirements

- Python 3.12+
- Git
- Claude Code CLI (installed and authenticated)

### Setup

```bash
git clone <repo-url>
cd clide
make setup
make run
```

Or install directly:

```bash
pip install -e .
clide
```

## Keybindings

All shortcuts use `Alt` to avoid conflicts with Claude Code input.

| Action | Binding |
|--------|---------|
| Toggle left sidebar | `Alt+B` |
| Toggle right sidebar | `Alt+Shift+B` |
| Toggle terminal | `` Alt+` `` |
| Focus Claude | `Alt+1` |
| Focus Editor | `Alt+2` |
| Focus Terminal | `Alt+3` |
| Toggle compact mode | `Alt+C` |
| Select theme | `Alt+T` |
| Quit | `Alt+Q` |

## Themes

22 built-in themes. Press `Alt+T` to switch.

| Category | Themes |
|----------|--------|
| Core | summer-night (default), summer-day |
| Popular | one-dark, one-dark-pro, one-light, dracula, nord, gruvbox-dark, gruvbox-light |
| Seasonal | winter-is-coming, monokai-winter, fall, dark-autumn |
| Special | all-hallows-eve, halloween, christmas, santa-baby |
| Hacker | pro-hacker, hacker-style |

Create custom themes in `~/.clide/themes/` as TOML files.

## Configuration

Settings stored in `~/.clide/settings.json`:

```json
{
  "theme": "summer-night",
  "compact_mode": false,
  "jira_enabled": false
}
```

Override with environment variables:

```bash
CLIDE_THEME=dracula clide
```

## Tech Stack

| Component | Library |
|-----------|---------|
| Runtime | Python 3.12+ |
| TUI Framework | Textual |
| CLI | Typer |
| Data Validation | Pydantic v2 |
| Extensions | Pluggy |
| Syntax Highlighting | tree-sitter |

## Development

```bash
make setup      # Create venv, install deps
make run        # Run application
make test       # Run all tests
make typecheck  # Run mypy
make lint       # Run ruff
make format     # Format code
```

## Documentation

- [User Manual](docs/user-manual.md) — How to use Clide
- [UI/UX Specification](docs/tui-ide-spec.md) — Design decisions
- [Architecture](docs/ARCHITECTURE.md) — Technical overview
- [Code Organization](docs/code-organization.md) — Project structure

## License

MIT
