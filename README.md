# Clide

A terminal-based IDE that wraps Claude Code CLI, putting AI-assisted development at the center of your workflow.

## Why Clide?

Claude Code is powerful, but switching between your terminal, editor, and project tools breaks your flow. Clide brings everything into one interface:

- **Claude stays visible** — No more switching windows. Claude Code is always front and center.
- **Context at a glance** — File tree, git status, problems, and TODOs in dedicated panels.
- **Panels appear when needed** — Editor, diff viewer, and terminal stay hidden until you need them.
- **Familiar keybindings** — VSCode-inspired shortcuts that don't interfere with your input.

## Layout

```
┌─────────────────┬─────────────────────────┬──────────────────┐
│ Sidebar         │ Workspace               │ Context          │
│                 │ [Editor][Diff][Terminal]│                  │
│ [Files][Git]    │ (appears when needed)   │ [Problems][TODOs]│
│ [Graph]         ├─────────────────────────┤ [Jira]           │
│                 │                         │                  │
│                 │ Claude                  │                  │
│                 │ (always visible)        │                  │
│                 │                         │                  │
├─────────────────┤                         ├──────────────────┤
│ ⎇ main ▾       │                         │ [⚠ 3][✓12][Jira]│
└─────────────────┴─────────────────────────┴──────────────────┘
```

## Features

**Left Sidebar**
- File explorer with project tree
- Git panel showing staged/unstaged changes
- Visual branch graph
- Quick branch switching

**Center Workspace**
- Claude Code integration (primary focus)
- Tabbed editor with syntax highlighting
- Side-by-side diff viewer for proposed changes
- Integrated terminal

**Right Context Panel**
- Problems view (linter errors/warnings)
- TODOs extracted from codebase
- Jira/Confluence integration

**Responsive Design**
- Works on 13" laptops to widescreen monitors
- Compact mode hides sidebars for focused work
- Panels preserve state when hidden

## Tech Stack

| Component | Library |
|-----------|---------|
| Runtime | Python 3.12+ |
| TUI Framework | Textual |
| CLI | Typer |
| Data Validation | Pydantic v2 |
| Extensions | Pluggy |

## Getting Started

```bash
# Clone and setup
git clone <repo-url>
cd clide
make setup

# Run
make run
```

## Keybindings

| Action | Binding |
|--------|---------|
| Toggle left sidebar | `Alt+B` |
| Toggle right sidebar | `Alt+Shift+B` |
| Toggle terminal | `` Alt+` `` |
| Focus Claude | `Alt+1` |
| Focus Editor | `Alt+2` |
| Focus Terminal | `Alt+3` |
| Command palette | `Alt+P` |
| Quick open file | `Alt+O` |
| Toggle compact mode | `Alt+C` |

## Documentation

- [Full UI/UX Specification](docs/tui-ide-spec.md)
- [Architecture Guide](docs/ARCHITECTURE.md)

## License

MIT
