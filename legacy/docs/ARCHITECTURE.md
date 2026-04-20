# Clide Architecture

Technical documentation covering Clide's architecture, the frameworks it builds on, and implementation patterns.

## Table of Contents

- [Application Architecture](#application-architecture)
- [Textual TUI Framework](#textual-tui-framework)
- [Pydantic Data Validation](#pydantic-data-validation)
- [Extension System](#extension-system)
- [Testing Strategy](#testing-strategy)
- [Build and Distribution](#build-and-distribution)

---

## Application Architecture

Clide follows a layered architecture with clear separation between UI, business logic, and data.

### Layer Overview

```
┌─────────────────────────────────────────────────────────┐
│                    ClideApp (app.py)                    │
│         Main application, layout, keybindings           │
├─────────────────────────────────────────────────────────┤
│                      Widgets Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Panels    │  │ Components  │  │   Themes    │     │
│  │  (layout)   │  │ (reusable)  │  │  (styling)  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│                    Controllers Layer                     │
│         Business logic, state management                 │
├─────────────────────────────────────────────────────────┤
│                     Services Layer                       │
│      Git, files, scanning, settings, skills              │
├─────────────────────────────────────────────────────────┤
│                      Models Layer                        │
│           Pydantic data structures                       │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action (click, keypress)
         │
         ▼
    Widget Event
         │
         ▼
  Message Bubbles Up
         │
         ▼
   App Event Handler
         │
         ▼
  Controller Method
         │
         ▼
   Service Call
         │
         ▼
  Return Data/Status
         │
         ▼
   Update UI State
         │
         ▼
 Reactive UI Update
```

### Key Patterns

**Message-based communication** — Widgets emit messages that bubble up. Parent widgets or the app handle messages and coordinate responses.

**Reactive properties** — UI state uses Textual's `reactive` type. Changes automatically trigger `watch_*` methods.

**Background workers** — Long operations use `@work(thread=True)` to avoid blocking the UI.

**State preservation** — Hiding panels uses `display: none`, never destroying widgets. All state persists.

For detailed code organization, see [Code Organization](code-organization.md).

---

## Textual TUI Framework

Textual provides the foundation for Clide's terminal UI.

### Core Concepts

**Widgets** — Building blocks of the UI. Everything visible is a widget.

**Containers** — Widgets that hold other widgets (Vertical, Horizontal, Container).

**Reactive Programming** — State changes trigger automatic UI updates.

**CSS Styling** — Layout and appearance defined in CSS, similar to web development.

### Layout System

Clide uses CSS Grid for the main layout:

```css
Screen {
    layout: grid;
    grid-size: 3 1;
    grid-columns: 20% 1fr 25%;
}
```

Panels use percentage widths with minimum sizes:

```css
#panel-sidebar {
    width: 20%;
    min-width: 25;
}
```

### Widget Lifecycle

```python
class MyWidget(Widget):
    def __init__(self):
        super().__init__()
        # Initialize instance variables

    def compose(self) -> ComposeResult:
        # Yield child widgets
        yield Label("Hello")

    def on_mount(self) -> None:
        # Called after widget is added to DOM
        # Safe to query other widgets here

    def on_unmount(self) -> None:
        # Cleanup when removed
```

### Event Handling

Events bubble up through the widget tree:

```python
# Define a message
class FileSelected(Message):
    def __init__(self, path: Path):
        self.path = path
        super().__init__()

# Emit the message
self.post_message(self.FileSelected(path))

# Handle in parent (naming convention: on_<widget>_<message>)
def on_files_view_file_selected(self, event: FilesView.FileSelected):
    self.open_file(event.path)
```

### Background Tasks

Use `@work` for operations that shouldn't block the UI:

```python
from textual import work

@work(thread=True)
def fetch_data(self) -> dict:
    """Runs in thread pool."""
    result = expensive_operation()
    return result

def on_worker_state_changed(self, event: Worker.StateChanged) -> None:
    if event.state == WorkerState.SUCCESS:
        self.update_ui(event.worker.result)
```

### References

- [Textual Documentation](https://textual.textualize.io/)
- [Textual Widgets](https://textual.textualize.io/widgets/)
- [Textual CSS](https://textual.textualize.io/guide/CSS/)

---

## Pydantic Data Validation

All data models use Pydantic v2 with strict mode.

### Model Configuration

```python
from pydantic import BaseModel, ConfigDict

class GitChange(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)

    path: str
    status: Literal["added", "modified", "deleted"]
    staged: bool
```

**strict=True** — No type coercion. `"123"` won't become `123`.

**frozen=True** — Immutable instances. Enables hashing for use as dict keys.

### Settings Management

Application settings use `pydantic-settings`:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class ClideSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="CLIDE_",
        env_file=".env",
    )

    theme: str = "summer-night"
    jira_enabled: bool = False
```

Settings load from (in priority order):
1. Environment variables (`CLIDE_THEME=dracula`)
2. `.env` file
3. Default values

### References

- [Pydantic Documentation](https://docs.pydantic.dev/latest/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)

---

## Extension System

Clide uses Pluggy for hook-based extensibility.

### Hook Specifications

Hooks define extension points:

```python
# clide/extensions/hookspecs.py
import pluggy

hookspec = pluggy.HookspecMarker("clide")
hookimpl = pluggy.HookimplMarker("clide")

class ClideHookSpec:
    @hookspec
    def clide_startup(self, app: App) -> None:
        """Called when the app starts."""

    @hookspec
    def clide_on_file_changed(self, event: FileEvent) -> None:
        """Called when a file changes."""
```

### Implementing Hooks

Extensions implement hooks with the `@hookimpl` decorator:

```python
from clide.extensions import hookimpl

class MyExtension:
    @hookimpl
    def clide_startup(self, app: App) -> None:
        app.notify("Extension loaded!")

    @hookimpl
    def clide_on_file_changed(self, event: FileEvent) -> None:
        if event.path.suffix == ".py":
            # React to Python file changes
            pass
```

### Distribution

Extensions can be packaged and distributed via entry points:

```toml
# pyproject.toml of extension package
[project.entry-points."clide.extensions"]
my_extension = "my_package:MyExtension"
```

### Available Hooks

| Hook | When Called |
|------|-------------|
| `clide_startup` | App initialization |
| `clide_shutdown` | App cleanup |
| `clide_on_file_changed` | File created/modified/deleted |
| `clide_on_file_saved` | File saved in editor |

### References

- [Pluggy Documentation](https://pluggy.readthedocs.io/)

---

## Testing Strategy

### Test Organization

```
tests/
├── unit/           # Isolated component tests
├── integration/    # Component interaction tests
└── snapshots/      # Visual regression tests
```

### Async Testing

Configure pytest-asyncio in auto mode:

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

Tests can be async without decorators:

```python
async def test_async_operation():
    result = await some_async_function()
    assert result == expected
```

### Snapshot Testing

Visual regression testing with pytest-textual-snapshot:

```python
def test_layout(snap_compare):
    assert snap_compare(ClideApp(), terminal_size=(120, 40))

def test_with_interaction(snap_compare):
    async def setup(pilot):
        await pilot.press("tab", "enter")

    assert snap_compare(ClideApp(), run_before=setup)
```

Update snapshots after intentional changes:

```bash
pytest tests/snapshots/ --snapshot-update
```

### Mocking

Use `AsyncMock` for async dependencies:

```python
from unittest.mock import AsyncMock

async def test_with_mock():
    mock_service = AsyncMock(return_value={"status": "ok"})
    result = await mock_service()
    assert result["status"] == "ok"
```

### References

- [pytest-asyncio](https://pytest-asyncio.readthedocs.io/)
- [pytest-textual-snapshot](https://github.com/Textualize/pytest-textual-snapshot)
- [Textual Testing Guide](https://textual.textualize.io/guide/testing/)

---

## Build and Distribution

### Development

```bash
make setup      # Create venv, install deps
make run        # Run application
make test       # Run all tests
make typecheck  # Run mypy
make lint       # Run ruff
make format     # Format code
```

### PyInstaller

Build standalone executables:

```bash
pip install -e ".[build]"
pyinstaller clide.spec --clean
```

**Important**: PyInstaller cannot cross-compile. Build on each target platform.

### CI/CD

Multi-platform builds via Gitea Actions:

```yaml
jobs:
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -e ".[build]"
      - run: pyinstaller clide.spec --clean

  build-macos:
    runs-on: macos-latest
    # ... same steps
```

### Optimization

- Use `--onefile` for single executable
- Apply `--strip` to reduce size
- Use UPX compression for further reduction
- Exclude unused modules with `--exclude-module`

### References

- [PyInstaller Documentation](https://pyinstaller.org/)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)
