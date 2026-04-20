# Code Organization

Clide follows a layered architecture separating UI components from business logic, enabling testability and maintainability.

## Directory Structure

```
clide/
├── app.py                    # Main application, layout, keybindings
├── cli.py                    # Typer entry point
├── models/                   # Pydantic data models
├── services/                 # Background services and utilities
├── controllers/              # Business logic (no UI)
├── widgets/
│   ├── panels/               # Main layout containers
│   └── components/           # Reusable UI pieces
├── themes/                   # Theme definitions and registry
├── extensions/               # Plugin system (hookspecs, manager)
├── templates/                # Bundled templates (skills, etc.)
└── vendor/                   # Vendored dependencies (pyte)
```

## Layers

### Models (`clide/models/`)

Pure data structures using Pydantic with strict mode. Models are immutable and contain no business logic.

```python
from pydantic import BaseModel, ConfigDict

class GitChange(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)

    path: str
    status: Literal["added", "modified", "deleted", "untracked", "renamed"]
    staged: bool
```

**Key models:**
- `git.py` — Git-related types (GitBranch, GitCommit, GitChange, GitStatus)
- `config.py` — Application settings (ClideSettings, PanelConfig)
- `problems.py` — Linter output (Problem, Severity)
- `todos.py` — TODO items (TodoItem, ProjectTodoItem, TodoType)

### Services (`clide/services/`)

Stateless utilities that perform work without UI interaction. Services may be async or use background threads.

```python
class GitService:
    """Git operations via subprocess."""

    def __init__(self, workdir: Path):
        self._workdir = workdir

    async def get_status(self) -> GitStatus:
        """Get current repository status."""
        ...

    async def get_branches(self) -> list[GitBranch]:
        """List all branches."""
        ...
```

**Key services:**
- `git_service.py` — Git CLI operations
- `file_service.py` — File read/write operations
- `todo_scanner.py` — Scans codebase for TODO/FIXME comments
- `settings_service.py` — User settings persistence
- `skill_installer.py` — Claude Code skill management
- `file_watcher.py` — File system change monitoring
- `syntax_service.py` — Tree-sitter syntax highlighting

### Controllers (`clide/controllers/`)

Bridge between services and UI. Controllers contain business logic, manage state, and emit Textual messages. Controllers have no direct UI rendering.

```python
from clide.controllers.base import controller

@controller
class GitController:
    """Manages git state and operations."""

    def __init__(self, workdir: Path):
        self._service = GitService(workdir)
        self._status: GitStatus | None = None

    async def refresh_status(self) -> GitStatus:
        """Refresh and cache git status."""
        self._status = await self._service.get_status()
        return self._status

    def stage_file(self, path: str) -> None:
        """Stage a file for commit."""
        ...
```

**Key controllers:**
- `git.py` — Git operations, skill integration
- `editor.py` — File editing state
- `diff.py` — Diff viewing and management
- `problems.py` — Linter integration
- `todos.py` — TODO tracking
- `jira.py` — Jira CLI integration

### Widgets (`clide/widgets/`)

UI components split into panels (layout containers) and components (reusable pieces).

#### Panels (`clide/widgets/panels/`)

Top-level layout containers that compose the application UI.

```python
class SidebarPanel(Vertical):
    """Left sidebar with Files, Git, and Tree tabs."""

    class FileSelected(Message):
        """Emitted when a file is selected."""
        def __init__(self, path: Path):
            self.path = path
            super().__init__()

    def compose(self) -> ComposeResult:
        with TabbedContent():
            with TabPane("Files"):
                yield FilesView(path=self._workdir)
            with TabPane("Git"):
                yield GitChangesView()
            with TabPane("Tree"):
                yield GitGraphView()
        yield BranchStatus()
```

**Panels:**
- `sidebar.py` — Left sidebar (files, git, graph)
- `context.py` — Right sidebar (problems, todos, jira)
- `workspace.py` — Center workspace (editor, diff, terminal)
- `claude.py` — Claude Code terminal integration

#### Components (`clide/widgets/components/`)

Reusable UI pieces composed into panels.

**File browsing:**
- `files_view.py` — Project file tree
- `file_entry.py` — Single file/directory entry

**Git:**
- `git_changes.py` — Staged/unstaged file lists
- `git_graph.py` — Visual branch graph
- `branch_status.py` — Branch indicator with popout selector

**Context:**
- `problems_view.py` — Linter problems list
- `todos_view.py` — TODO/FIXME list with sub-tabs
- `jira_view.py` — Jira issue display

**Editor:**
- `editor_pane.py` — Code editor with syntax highlighting
- `diff_pane.py` — Side-by-side diff viewer
- `terminal_pane.py` — Command execution terminal

## Communication Patterns

### Message Flow

Components communicate via Textual's message system. Messages bubble up through the widget tree.

```
Component emits message
        │
        ▼
Parent panel receives and may re-emit
        │
        ▼
App handles and coordinates response
        │
        ▼
App calls controller methods
        │
        ▼
Controller updates state, may emit messages
        │
        ▼
UI updates reactively
```

**Example: File selection**

```python
# In FilesView (component)
class FileSelected(Message):
    def __init__(self, path: Path):
        self.path = path
        super().__init__()

def on_tree_node_selected(self, event):
    if event.node.data.is_file:
        self.post_message(self.FileSelected(event.node.data.path))

# In SidebarPanel (panel)
def on_files_view_file_selected(self, event: FilesView.FileSelected):
    # Re-emit for app to handle
    self.post_message(self.FileSelected(event.path))

# In ClideApp (app)
def on_sidebar_panel_file_selected(self, event: SidebarPanel.FileSelected):
    self.editor_controller.open_file(event.path)
    self.show_workspace("editor")
```

### Reactive Properties

State that affects UI uses Textual's reactive system:

```python
class ClideApp(App):
    # Reactive state
    workspace_visible: reactive[bool] = reactive(False)
    problem_count: reactive[int] = reactive(0)
    current_branch: reactive[str] = reactive("main")

    def watch_workspace_visible(self, visible: bool) -> None:
        """React to workspace visibility changes."""
        workspace = self.query_one("#panel-workspace")
        workspace.display = visible

        claude = self.query_one("#panel-claude")
        claude.styles.height = "40%" if visible else "100%"
```

### Background Tasks

Long-running operations use the `@work` decorator to avoid blocking the UI:

```python
from textual import work

class ClideApp(App):
    @work(thread=True)
    def refresh_git_status(self) -> None:
        """Refresh git status in background."""
        status = self.git_controller.get_status_sync()
        self.call_from_thread(self._update_git_ui, status)

    def _update_git_ui(self, status: GitStatus) -> None:
        """Update UI with git status (runs on main thread)."""
        sidebar = self.query_one(SidebarPanel)
        sidebar.update_git_status(status.staged, status.unstaged)
```

## Extension System

Clide uses Pluggy for extensibility. Extensions implement hooks defined in `hookspecs.py`.

```python
# clide/extensions/hookspecs.py
class ClideHookSpec:
    @hookspec
    def clide_startup(self, app: App) -> None:
        """Called when app starts."""

    @hookspec
    def clide_on_file_changed(self, event: FileEvent) -> None:
        """Called when a file changes."""

# User extension
class MyExtension:
    @hookimpl
    def clide_on_file_changed(self, event: FileEvent) -> None:
        if event.path.suffix == ".py":
            # Custom logic for Python files
            ...
```

**Available hooks:**
- `clide_startup` — App initialization
- `clide_shutdown` — App cleanup
- `clide_on_file_changed` — File system changes
- `clide_on_file_saved` — File saved in editor

## Skills System

Clide integrates with Claude Code skills for git operations. Skills are installed to the project's `.claude/skills/` directory.

```python
# clide/services/skill_installer.py
class SkillInstaller:
    def install(self, skill_name: str, scope: Literal["user", "project"] = "project"):
        """Install a skill from bundled templates."""
        template_dir = TEMPLATES_DIR / skill_name
        target_dir = self.project_skills_dir / skill_name
        shutil.copytree(template_dir, target_dir)
```

**Bundled skills** (`clide/templates/skills/`):
- `commit` — Git commit workflow
- `stash` — Git stash operations
- `pull` — Git pull with rebase
- `push` — Git push to remote
- `branch` — Branch management

When a git action button is clicked, Clide ensures the skill is installed before sending the command to Claude.

## Testing

Tests mirror the source structure:

```
tests/
├── unit/
│   ├── test_models.py
│   ├── test_services.py
│   ├── test_controllers.py
│   ├── test_widgets.py
│   └── test_app.py
├── integration/
│   └── test_files_view.py
└── snapshots/
    └── test_app_snapshots.py
```

**Unit tests** verify individual components in isolation.
**Integration tests** verify component interactions.
**Snapshot tests** catch visual regressions using pytest-textual-snapshot.

## Configuration

### Application Settings

`ClideSettings` in `clide/models/config.py` defines app configuration loaded from environment or `.config/settings.toml`.

### User Settings

`UserSettings` persisted to `~/.clide/settings.json` stores user preferences:
- Theme selection
- Panel visibility defaults
- Compact mode preference
- Jira integration settings
