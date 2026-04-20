# Clide User Manual

Clide is a terminal-based IDE that puts Claude Code at the center of your development workflow. This manual covers installation, daily usage, and customization.

## Installation

### Requirements

- Python 3.12 or later
- Git
- Claude Code CLI installed and authenticated

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd clide

# Install dependencies and create virtual environment
make setup

# Run Clide
make run
```

Or install directly:

```bash
pip install -e .
clide
```

### First Run

On first launch, Clide creates a configuration directory at `~/.clide/` for user settings. Project-specific settings are stored in `.clide/` within your project.

## Interface Overview

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

### Panels

**Left Sidebar** — File browser, git changes, and branch graph

**Center** — Claude Code (always visible) and workspace panels (editor, diff, terminal) that appear when needed

**Right Context** — Jira integration, TODO list, and problems from linters

## Keyboard Shortcuts

All shortcuts use `Alt` as the modifier to avoid conflicts with Claude Code input.

### Panel Navigation

| Action | Shortcut |
|--------|----------|
| Toggle left sidebar | `Alt+B` |
| Toggle right sidebar | `Alt+Shift+B` |
| Toggle terminal | `` Alt+` `` |
| Focus Claude | `Alt+1` |
| Focus Editor | `Alt+2` |
| Focus Terminal | `Alt+3` |
| Toggle compact mode | `Alt+C` |

### File Operations

| Action | Shortcut |
|--------|----------|
| Quick open file | `Alt+O` |
| Save file | `Alt+S` |
| Go to line | `Alt+L` |

### Git Operations

| Action | Shortcut |
|--------|----------|
| Open Git panel | `Alt+G` |
| Open Problems panel | `Alt+M` |

### Application

| Action | Shortcut |
|--------|----------|
| Command palette | `Alt+P` |
| Select theme | `Alt+T` |
| Quit | `Alt+Q` |

## Working with Claude

Claude Code runs in the center panel and is always visible. Type your prompts directly and Claude will respond with code suggestions, explanations, and file operations.

### Git Integration

The sidebar includes buttons for common git operations that delegate to Claude:

- **Commit** — Claude reviews staged changes and creates a well-formatted commit
- **Stash** — Claude stashes your working changes
- **Pull** — Claude pulls with rebase and helps resolve conflicts
- **Push** — Claude pushes to remote, setting upstream if needed

On first use, Clide installs the corresponding skill to your project's `.claude/skills/` directory. These skills guide Claude through each operation following best practices.

### Branch Status

The branch status bar at the bottom of the sidebar shows:

- Current branch name
- Staged and unstaged file counts

Click the branch name to open the branch selector:

```
┌─────────────────┐
│ Recent branches │
│ ● main         │
│ ○ feature/xyz  │
│ ○ develop      │
├─────────────────┤
│[Checkout] [New] │
└─────────────────┘
```

## Left Sidebar

### Files Tab

Browse your project structure. Click a file to open it in the editor.

- Directories expand/collapse on click
- Hidden files (starting with `.`) are shown but dimmed
- Noisy directories (`.git`, `__pycache__`, `node_modules`) are filtered

### Git Tab

View staged and unstaged changes:

```
Staged (2)
  + src/new_file.py
  ~ src/modified.py

Unstaged (3)
  ~ README.md
  ? untracked.txt
  - deleted.py
```

**Status indicators:**
- `+` Added
- `~` Modified
- `-` Deleted
- `?` Untracked
- `→` Renamed

Click a file to view its diff. Use the action buttons to commit, stash, pull, or push via Claude.

### Tree Tab

Visual git graph showing branch history:

```
● main: Latest commit message
│
├─● feature: Feature work
│
●─┴ Merge branch 'feature'
```

**Commit types:**
- `●` Regular commit
- `◆` Merge commit

## Right Context Panel

### Jira Tab

Displays Jira issues when configured. Click the refresh button to update.

Configure Jira integration in settings:

```json
{
  "jira_enabled": true,
  "jira_cli_path": "jira"
}
```

### TODOs Tab

Scans your codebase for TODO comments and project tasks.

**Sub-tabs:**

- **Project** — Items from `TODO.md` (checkbox format)
- **Comments** — TODO/FIXME/HACK/XXX comments in code

Click an item to jump to that location in the editor.

**Supported comment markers:**
- `TODO` — Tasks to complete
- `FIXME` — Bugs to fix
- `HACK` — Temporary solutions
- `XXX` — Dangerous or problematic code
- `NOTE` — Important notes
- `BUG` — Known bugs

### Problems Tab

Displays linter errors and warnings. Click a problem to jump to the source location.

## Workspace Panels

The workspace appears when you need to view or edit files. It contains three tabs:

### Editor

Full-featured code editor with:

- Syntax highlighting (Python, JavaScript, TypeScript, HTML, CSS, JSON, YAML, Markdown, and more)
- Line numbers
- Current line highlighting

### Diff

Side-by-side diff viewer for reviewing changes. Used when:

- Viewing git changes
- Reviewing Claude's proposed edits

### Terminal

Command-line terminal for running commands. Output is preserved when the panel is hidden.

## Themes

Clide includes 22 built-in themes. Press `Alt+T` to open the theme selector.

**Theme categories:**

| Category | Themes |
|----------|--------|
| Core | summer-night (default), summer-day |
| Popular | one-dark, one-dark-pro, one-light, dracula, nord, gruvbox-dark, gruvbox-light |
| Seasonal | winter-is-coming, monokai-winter, fall, dark-autumn |
| Halloween | all-hallows-eve, halloween |
| Christmas | christmas, santa-baby |
| Hacker | pro-hacker, hacker-style |
| Other | gamma, one-dark-teal, houston |

Your theme choice is saved and persists across sessions.

### Custom Themes

Create custom themes in `~/.clide/themes/`:

```toml
# ~/.clide/themes/my-theme.toml
name = "my-theme"
display_name = "My Custom Theme"
dark = true

[colors]
primary = "#007acc"
secondary = "#3c3c3c"
accent = "#0e639c"
background = "#1e1e1e"
surface = "#252526"
panel = "#2d2d30"
foreground = "#d4d4d4"
success = "#4ec9b0"
warning = "#dcdcaa"
error = "#f44747"
```

## Configuration

### User Settings

Settings are stored in `~/.clide/settings.json`:

```json
{
  "theme": "summer-night",
  "compact_mode": false,
  "jira_enabled": false,
  "jira_cli_path": "jira"
}
```

### Project Settings

Project-specific settings in `.clide/`:

```
.clide/
├── settings.json     # Project overrides
└── skills/           # Installed Claude skills
    ├── commit/
    ├── stash/
    └── ...
```

### Environment Variables

Override settings with environment variables prefixed with `CLIDE_`:

```bash
CLIDE_THEME=dracula clide
```

## Compact Mode

Press `Alt+C` to toggle compact mode, which hides both sidebars for focused work. All panel state is preserved—nothing is lost when hiding panels.

## Project TODOs

Clide integrates with a `TODO.md` file in your project root. Format:

```markdown
# TODO

## Features

- [ ] Implement user authentication
- [ ] Add search functionality
- [x] Set up database connection

## Bugs

- [ ] Fix login redirect
```

Items appear in the TODOs panel, grouped by section. Click to jump to that line. Check off items directly in the file.

If no `TODO.md` exists, click "Create TODO.md" in the TODOs panel to generate a template.

## Tips

### Efficient Navigation

1. Use `Alt+1/2/3` to quickly switch between Claude, Editor, and Terminal
2. Click items in Problems or TODOs to jump directly to source
3. Use compact mode (`Alt+C`) when you need more space for Claude

### Git Workflow

1. Make changes to your code
2. Review changes in the Git tab
3. Click "Commit" to have Claude create a well-formatted commit
4. Use "Push" when ready to share

### Working with Claude

- Claude sees your project context automatically
- Use the git action buttons for consistent commit messages
- Click files in the sidebar to show Claude what you're working on

## Troubleshooting

### Claude Code not starting

Ensure Claude Code CLI is installed and authenticated:

```bash
claude --version
claude auth status
```

### Theme not applying

Check that the theme name in settings matches exactly. Theme names are case-sensitive.

### Skills not working

Skills are installed to `.claude/skills/` in your project. If a skill fails:

1. Check that the skill folder exists
2. Verify `SKILL.md` is present
3. Try removing and re-triggering the action

### Panels not updating

Try refreshing with the relevant shortcut or clicking the refresh button. File changes should update automatically via file watching.
