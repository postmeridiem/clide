# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clide is a TUI IDE wrapper for Claude Code CLI, designed to be Claude-centric with VSCode-familiar keybindings. See `docs/tui-ide-spec.md` for full specification.

### Design Principles
- **Claude-centric**: Claude Code is the primary workspace, always visible
- **Contextual panels**: Editor/Diff/Terminal appear only when needed
- **VSCode-familiar**: Keybindings follow VSCode conventions
- **Responsive**: Works on 13" laptop to widescreen monitors
- **State preservation**: Hiding panels preserves all state (never destroy widgets)

## Tech Stack

| Component | Library | Version |
|-----------|---------|---------|
| Runtime | Python | 3.12+ |
| TUI Framework | Textual | latest |
| CLI | Typer | latest |
| Data Validation | Pydantic | v2 (strict mode) |
| Settings | pydantic-settings | latest |
| Testing | pytest + pytest-asyncio + pytest-textual-snapshot | latest |
| Extensions | pluggy | latest |

## Development Commands

```bash
make setup          # Create venv, install deps
make run            # Run application
make test           # Run all tests
make test-single    # Run single test (TEST=path::test_name)
make typecheck      # Run mypy
make lint           # Run ruff check
make format         # Run ruff format
make build          # Build for current platform
```

## Panel Architecture

```
┌─────────────────┬─────────────────────────┬──────────────────┐
│ panel-sidebar   │ panel-workspace (60%)   │ panel-context    │
│                 │ [Editor][Diff][Terminal]│                  │
│ [Files][Git]    │ (hidden when inactive)  │ [Problems][TODOs]│
│ [Tree]          ├─────────────────────────┤ [Jira]           │
│                 │                         │                  │
│ (content area)  │ panel-claude            │ (content area)   │
│                 │ (40% when workspace     │                  │
│                 │  visible, else 100%)    │                  │
├─────────────────┤                         ├──────────────────┤
│ ⎇ main ▾       │                         │ [⚠ 3][✓12][Jira]│
└─────────────────┴─────────────────────────┴──────────────────┘
```

## Project Structure

```
clide/
├── clide/                        # Package source
│   ├── __init__.py
│   ├── __main__.py
│   ├── app.py                    # Main App, layout, keybindings
│   ├── cli.py                    # Typer entry point
│   ├── controllers/              # Domain logic (no UI)
│   ├── widgets/                  # UI components
│   │   ├── panels/               # Main layout containers
│   │   └── components/           # Reusable UI pieces
│   ├── models/                   # Pydantic data models
│   ├── services/                 # Background task logic
│   ├── themes/                   # Theme system
│   ├── extensions/               # Plugin system
│   └── helpers/                  # Utility functions
│
├── tests/
│   ├── conftest.py
│   ├── harnesses/
│   │   ├── app_harness.py
│   │   └── controller_harness.py
│   ├── unit/
│   ├── integration/
│   └── snapshots/
│
├── .config/                      # User config (gitignored)
│   ├── settings.toml             # User settings
│   └── themes/                   # Custom user themes
│       └── my-theme.toml
├── docs/
│   ├── tui-ide-spec.md           # Full UI/UX specification
│   └── ARCHITECTURE.md           # Framework best practices
├── pyproject.toml
└── Makefile
```

## Key Patterns

### Panel Visibility (Hide, Don't Destroy)

```python
def toggle_workspace(self, visible: bool) -> None:
    workspace = self.query_one("#panel-workspace")
    workspace.display = visible  # Preserves all child state

    claude = self.query_one("#panel-claude")
    claude.styles.height = "40%" if visible else "100%"
```

### Background Tasks

Use `@work` decorator for non-blocking operations:

```python
@work(thread=True)
def refresh_git_status(self) -> None:
    result = subprocess.run(["git", "status", "--porcelain"], ...)
    self.call_from_thread(self.update_git_view, result.stdout)
```

### Reactive State

```python
class ClideApp(App):
    current_file: reactive[str | None] = reactive(None)
    workspace_visible: reactive[bool] = reactive(False)
    problem_count: reactive[int] = reactive(0)
    todo_count: reactive[int] = reactive(0)
    compact_mode: reactive[bool] = reactive(False)
```

### Pydantic Models (Strict + Frozen)

```python
from pydantic import BaseModel, ConfigDict

class GitChange(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)
    path: str
    status: Literal["added", "modified", "deleted", "untracked", "renamed"]
    staged: bool
```

### Controller → Widget Communication

Controllers emit Textual messages; widgets subscribe:

```python
# In controller
class GitStatusUpdated(Message):
    def __init__(self, status: GitStatus) -> None:
        self.status = status
        super().__init__()

self.post_message(GitStatusUpdated(status))

# In widget
def on_git_status_updated(self, event: GitStatusUpdated) -> None:
    self.refresh_view(event.status)
```

## Theme System

### Default Theme: Summer Night

Based on [jackw01/summer-night-vscode-theme](https://github.com/jackw01/summer-night-vscode-theme):

```python
SUMMER_NIGHT = ThemeColors(
    primary="#00a3d2",      # cyan
    secondary="#00a9b9",    # teal
    accent="#fa5f8b",       # pink
    background="#21262f",   # mono_8
    surface="#393e48",      # mono_7
    panel="#292e38",
    foreground="#e2e8f5",   # mono_1
    success="#00ab9a",      # green
    warning="#d08447",      # orange
    error="#f06c6f",        # red
)
```

### Built-in Themes (22 total)

| Category | Themes |
|----------|--------|
| Core | summer-night (default), summer-day |
| Popular | one-dark, one-dark-pro, one-light, dracula, nord, gruvbox-dark, gruvbox-light |
| GitKraken | one-dark-teal, gamma |
| Seasonal - Winter | winter-is-coming, monokai-winter |
| Seasonal - Fall | fall, dark-autumn |
| Seasonal - Halloween | all-hallows-eve, halloween |
| Seasonal - Christmas | christmas, santa-baby |
| Hacker | pro-hacker, hacker-style |
| Bonus | houston |

### Theme Definition

```python
class ThemeColors(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)
    primary: str       # Main accent
    secondary: str     # Secondary accent
    accent: str        # Highlight accent
    background: str    # Main background
    surface: str       # Elevated surfaces
    panel: str         # Panel backgrounds
    foreground: str    # Primary text
    success: str       # Success/green
    warning: str       # Warning/yellow
    error: str         # Error/red

class ThemeDefinition(BaseModel):
    name: str          # Identifier (e.g., "summer-night")
    display_name: str  # Human-readable name
    dark: bool         # Dark or light theme
    colors: ThemeColors
```

### Custom Themes

Users can add themes in `.config/themes/`:

```toml
# .config/themes/my-theme.toml
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

### Theme Switching

- Keybinding: `Ctrl+K Ctrl+T`
- Settings: `theme = "summer-night"` in ClideSettings
- Runtime: `app.theme = "dracula"`

## Keybindings (VSCode-style)

| Action | Binding |
|--------|---------|
| Command palette | `Ctrl+Shift+P` |
| Quick open | `Ctrl+P` |
| Toggle left sidebar | `Ctrl+B` |
| Toggle right sidebar | `Ctrl+Shift+B` |
| Toggle terminal | `` Ctrl+` `` |
| Focus Claude | `Ctrl+1` |
| Focus Editor | `Ctrl+2` |
| Focus Terminal | `Ctrl+3` |
| Toggle compact mode | `Ctrl+Shift+C` |
| Git panel | `Ctrl+Shift+G` |
| Problems panel | `Ctrl+Shift+M` |
| Select theme | `Ctrl+K Ctrl+T` |

## Configuration

Settings are loaded from multiple sources (in priority order):
1. Environment variables (`CLIDE_*`)
2. `.config/settings.toml`
3. Defaults in ClideSettings

```python
class ClideSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="CLIDE_",
        env_file=".env",
        extra="ignore",
    )

    theme: str = "summer-night"
    jira_enabled: bool = False
    jira_cli_path: str = "jira"

    panels: PanelConfig = PanelConfig()
    keybindings: KeybindingsConfig = KeybindingsConfig()
```

## Documentation Links

### Core Stack
- [Textual Documentation](https://textual.textualize.io/)
- [Textual Testing Guide](https://textual.textualize.io/guide/testing/)
- [Textual Themes Guide](https://textual.textualize.io/guide/design/)
- [Typer Documentation](https://typer.tiangolo.com/)
- [Pydantic v2 Documentation](https://docs.pydantic.dev/latest/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)

### Testing
- [pytest-asyncio](https://pytest-asyncio.readthedocs.io/en/latest/)
- [pytest-textual-snapshot](https://github.com/Textualize/pytest-textual-snapshot)

### Extensions
- [Pluggy Documentation](https://pluggy.readthedocs.io/)

### Build
- [PyInstaller Documentation](https://pyinstaller.org/)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)

### Theme References
- [Summer Night VSCode Theme](https://github.com/jackw01/summer-night-vscode-theme)
