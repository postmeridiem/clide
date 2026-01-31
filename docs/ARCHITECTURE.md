# Clide Architecture Documentation

Comprehensive documentation of architecture patterns, best practices, and implementation guidelines.

## Table of Contents

- [Textual TUI Framework](#textual-tui-framework)
- [Typer CLI Framework](#typer-cli-framework)
- [Pydantic Data Validation](#pydantic-data-validation)
- [Extension System](#extension-system)
- [Testing Strategy](#testing-strategy)
- [Build and Distribution](#build-and-distribution)

---

## Textual TUI Framework

Textual models TUIs as a reactive tree of widgets, similar to React's component tree but grid-based on character cells.

### Key Concepts

**Widgets and Containers**
- Widgets are the building blocks of the UI
- Containers are widgets that hold other widgets
- Default layout stacks widgets vertically from top of screen

**Reactive Programming**
- State changes trigger automatic UI updates
- No manual refresh loops needed
- Use reactive attributes for state management

**Event-Driven Model**
- Define callbacks for key presses, mouse clicks, timer ticks
- Actions are functions callable via keystroke or text link

### Best Practices

1. **Use Immutable Objects**
   - Prefer tuples, NamedTuples, or frozen dataclasses
   - Easier to reason about, cache, and test
   - Enables side-effect-free code

2. **Separate Styles**
   - Keep CSS in `.tcss` files, not inline
   - Python code stays clean and focused on logic

3. **Async-First**
   - Textual is async under the hood
   - Use `async`/`await` for I/O operations
   - Can integrate with async libraries if needed

### Layout Management

```python
# Grid layout example
CSS = """
Screen {
    layout: grid;
    grid-size: 3 1;
    grid-columns: 1fr 2fr 1fr;
}
"""
```

### References

- [Textual Documentation](https://textual.textualize.io/)
- [Textual Tutorial](https://textual.textualize.io/tutorial/)
- [Real Python Textual Guide](https://realpython.com/python-textual/)
- [Textual GitHub](https://github.com/Textualize/textual)

---

## Typer CLI Framework

Typer is built on Click with Python type hints for automatic argument parsing.

### Project Structure Pattern

```
app/
├── __init__.py
├── main.py          # Root Typer app
├── commands/        # Subcommand modules
│   ├── users.py
│   └── tasks.py
└── helpers/         # Shared utilities
    └── validate.py
```

### Best Practices

1. **Organize Commands**
   - Use `add_typer()` to group commands
   - Avoid giant files with dozens of commands
   - Each command function should orchestrate, not contain all logic

2. **Entry Point Support**
   - Add `__main__.py` for `python -m` support
   - Define entry points in pyproject.toml for CLI scripts

3. **Standard Exit Codes**
   - `0` for success
   - Non-zero for errors
   - Crucial for CI/CD integration

4. **Type Hints for Validation**
   - Use Enum for dropdown-style restrictions
   - Type hints provide editor autocompletion

### Subcommand Example

```python
# commands/users.py
import typer

app = typer.Typer()

@app.command()
def create(name: str):
    """Create a new user."""
    ...

# main.py
from commands import users

main_app = typer.Typer()
main_app.add_typer(users.app, name="users")
```

### References

- [Typer Documentation](https://typer.tiangolo.com/)
- [Typer Subcommands](https://typer.tiangolo.com/tutorial/subcommands/)
- [Building a Package](https://typer.tiangolo.com/tutorial/package/)

---

## Pydantic Data Validation

Pydantic v2 with strict mode ensures type safety and validation.

### Strict Mode Configuration

```python
from pydantic import BaseModel, ConfigDict

class MyModel(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)
    name: str
    count: int  # Will reject "123" string
```

### Settings Management

Settings have moved to `pydantic-settings` package:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="APP_",
        env_file=".env",
        env_nested_delimiter="__",
    )

    database_url: str
    debug: bool = False
```

### Best Practices

1. **Use `frozen=True` for Immutability**
   - Prevents accidental mutation
   - Enables hashing for use as dict keys

2. **Explicit Strict Types**
   - `StrictInt`, `StrictStr` for field-level strictness
   - Or use `model_config` for model-wide strictness

3. **Validation vs Parsing**
   - Strict mode rejects type coercion
   - JSON parsing allows some conversion (ISO8601 → datetime)

### References

- [Pydantic v2 Documentation](https://docs.pydantic.dev/latest/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [Pydantic Configuration](https://docs.pydantic.dev/latest/api/config/)
- [Migration Guide](https://docs.pydantic.dev/latest/migration/)

---

## Extension System

The plugin system uses Pluggy for hook-based extensibility.

### Pluggy Concepts

1. **Hook Specifications** - Define the interface extensions implement
2. **Hook Implementations** - Extension code implementing hooks
3. **Plugin Manager** - Discovers and calls implementations

### Architecture

```python
# hookspecs.py - Define hooks
import pluggy

hookspec = pluggy.HookspecMarker("clide")
hookimpl = pluggy.HookimplMarker("clide")

class ClideHookSpec:
    @hookspec
    def register_panel(self) -> dict: ...

# extension.py - Implement hooks
class MyExtension:
    @hookimpl
    def register_panel(self) -> dict:
        return {"name": "custom", "widget": CustomWidget}
```

### Distribution

Extensions can be distributed as packages using entry points:

```toml
# pyproject.toml of extension package
[project.entry-points."clide.extensions"]
my_extension = "my_package:MyExtension"
```

### Hook Execution Order

- Multiple implementations called in LIFO (Last In, First Out) order
- Use `hookimpl(tryfirst=True)` or `hookimpl(trylast=True)` for ordering

### Alternatives

- **Stevedore** - Better for driver/extension patterns, uses entry points
- Choose Pluggy for hook-based systems (like pytest uses)

### References

- [Pluggy Documentation](https://pluggy.readthedocs.io/)
- [Stevedore Documentation](https://docs.openstack.org/stevedore/latest/)
- [Creating Plugins with Stevedore](https://docs.openstack.org/stevedore/latest/user/tutorial/creating_plugins.html)

---

## Testing Strategy

### pytest-asyncio

Configure auto mode for automatic async test discovery:

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

### Async Test Patterns

```python
import pytest

# Auto mode - no decorator needed
async def test_async_operation():
    result = await some_async_function()
    assert result == expected

# Async fixtures
@pytest.fixture
async def database_connection():
    conn = await create_connection()
    yield conn
    await conn.close()
```

### Async Mocking

```python
from unittest.mock import AsyncMock

async def test_with_mock():
    mock_service = AsyncMock(return_value={"status": "ok"})
    result = await mock_service()
    assert result["status"] == "ok"
```

### Snapshot Testing

Visual regression with pytest-textual-snapshot:

```python
def test_layout(snap_compare):
    assert snap_compare("app.py", terminal_size=(120, 40))

def test_with_interaction(snap_compare):
    async def setup(pilot):
        await pilot.press("tab", "enter")

    assert snap_compare("app.py", run_before=setup)
```

Update snapshots after intentional changes:
```bash
pytest tests/snapshots/ --snapshot-update
```

### Test Harness Pattern

Harnesses provide isolated test environments:

```python
class AppHarness:
    async def start(self) -> tuple[App, Pilot]:
        """Start app with mocked dependencies."""

    async def stop(self) -> None:
        """Clean shutdown."""
```

### Best Practices

1. **Always use `@pytest.mark.asyncio`** (or auto mode)
2. **Use async fixtures** for async setup/teardown
3. **Mock external services** - don't hit real APIs
4. **Choose appropriate fixture scopes** for performance
5. **Avoid blocking the event loop** in async tests

### References

- [pytest-asyncio Documentation](https://pytest-asyncio.readthedocs.io/en/latest/)
- [pytest-textual-snapshot](https://github.com/Textualize/pytest-textual-snapshot)
- [Textual Testing Guide](https://textual.textualize.io/guide/testing/)
- [pytest Fixtures](https://docs.pytest.org/en/stable/how-to/fixtures.html)

---

## Build and Distribution

### PyInstaller Limitations

**Critical: PyInstaller cannot cross-compile.**
- Build on the target OS
- Use CI/CD for multi-platform builds

### CI/CD Multi-Platform Build

Use Gitea Actions (or compatible CI) for multi-platform builds:

```yaml
# .gitea/workflows/build.yml
name: Build
on: [push, tag]

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
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -e ".[build]"
      - run: pyinstaller clide.spec --clean

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -e ".[build]"
      - run: pyinstaller clide.spec --clean
```

### Optimization Tips

1. **Use `--onefile`** for single executable
2. **Apply `--strip`** to reduce binary size
3. **Use UPX compression** (460 MB → ~130 MB possible)
4. **Exclude unused modules** with `--exclude-module`
5. **Lazy imports** for large libraries

### Platform-Specific Output

- **Windows**: `.exe` or MSIX installer
- **macOS**: `.app` bundle in `.dmg`
- **Linux**: AppImage or native package

### Linux Compatibility

Build on the oldest target distro version. Newer systems may produce incompatible binaries.

### References

- [PyInstaller Documentation](https://pyinstaller.org/)
- [Building the Bootloader](https://pyinstaller.org/en/latest/bootloader-building.html)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)
