"""TODOs view component with sub-tabs for Project and Comment TODOs."""

from pathlib import Path

from rich.markup import escape
from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Button, ListView, Static, TabbedContent, TabPane

from clide.models.todos import ProjectTodoItem, TodoItem, TodoType
from clide.widgets.components.tile_list import TileItem, TileListView

# Template for new TODO.md files
TODO_MD_TEMPLATE = """# TODO

<!--
  Clide Integration: This file is parsed by Clide's TODO panel.

  Format:
  - Use ## for sections and ### for subsections
  - Use markdown checkboxes: - [ ] for open items, - [x] for completed
  - Items appear in the TODOs panel grouped by section
  - Click an item in Clide to jump to this file at that line

  For AI agents: Add new items under the appropriate section using the
  checkbox format. Mark items as done with [x] when completed.
-->

Project TODO items.

## Features

- [ ] Add your first feature here
- [ ] Another feature to implement

## Bugs

- [ ] Bug to fix

## Documentation

- [ ] Documentation to write
"""


class TodoListItem(TileItem):
    """A single code TODO item displayed as a tile."""

    def __init__(self, item: TodoItem) -> None:
        super().__init__()
        self.item = item
        self.is_project_item = False

    def compose(self) -> ComposeResult:
        icon = self.item.type_icon
        type_class = self.item.todo_type.value.lower()
        # Show just filename, not full path
        filename = (
            self.item.file_path.name
            if hasattr(self.item.file_path, "name")
            else str(self.item.file_path).split("/")[-1]
        )
        # Escape user content to prevent markup errors
        safe_text = escape(self.item.text)

        yield Static(
            f"[{type_class}]{icon}[/] {safe_text}\n" f"  [dim]{filename}:{self.item.line}[/]",
            markup=True,
        )


class ProjectTodoListItem(TileItem):
    """A single project TODO item from TODO.md displayed as a tile."""

    def __init__(self, item: ProjectTodoItem) -> None:
        super().__init__()
        self.item = item
        self.is_project_item = True

    def compose(self) -> ComposeResult:
        icon = self.item.icon
        category = f"[dim]{escape(self.item.category)}[/] " if self.item.subsection else ""
        safe_text = escape(self.item.text)

        text_part = f"[dim strike]{safe_text}[/]" if self.item.checked else safe_text

        yield Static(
            f"[project]{icon}[/] {category}{text_part}",
            markup=True,
        )


class TodosView(TileListView):
    """View for TODO/FIXME comments and project TODOs with sub-tabs."""

    DEFAULT_CSS = """
    TodosView {
        height: 1fr;
        background: $background;
    }

    TodosView TabbedContent {
        height: 1fr;
    }

    TodosView Tabs {
        width: 100%;
    }

    TodosView Tab {
        width: 1fr;
    }

    TodosView TabPane {
        height: 1fr;
        padding: 0;
    }

    TodosView ContentSwitcher {
        height: 1fr;
    }

    TodosView #project-todos-list,
    TodosView #code-todos-list {
        height: 1fr;
    }

    TodosView ListItem {
        padding: 1 1;
    }

    TodosView .todo { color: $primary; }
    TodosView .fixme { color: $warning; }
    TodosView .hack { color: $error; }
    TodosView .xxx { color: $error; }
    TodosView .note { color: $secondary; }
    TodosView .bug { color: $error; }
    TodosView .project { color: $accent; }

    TodosView .empty-message {
        padding: 2;
        text-align: center;
        color: $text-muted;
    }

    TodosView .create-todo-section {
        height: auto;
        padding: 1 2;
        align: center middle;
    }

    TodosView .create-todo-message {
        text-align: center;
        color: $text-muted;
        margin-bottom: 1;
    }

    TodosView #create-todo-btn {
        width: auto;
    }
    """

    class TodoClicked(Message):
        """Emitted when a code TODO is clicked."""

        def __init__(self, item: TodoItem) -> None:
            self.item = item
            super().__init__()

    class ProjectTodoClicked(Message):
        """Emitted when a project TODO is clicked."""

        def __init__(self, item: ProjectTodoItem) -> None:
            self.item = item
            super().__init__()

    class CreateTodoMdRequested(Message):
        """Emitted when user wants to create a TODO.md file."""

        pass

    class TodoMdCreated(Message):
        """Emitted when TODO.md has been created."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    def __init__(
        self,
        items: list[TodoItem] | None = None,
        project_items: list[ProjectTodoItem] | None = None,
        project_path: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._items = items or []
        self._project_items = project_items or []
        self._project_path = project_path or Path.cwd()
        self._has_todo_md = (self._project_path / "TODO.md").exists()

    def compose(self) -> ComposeResult:
        # Calculate initial counts
        unchecked_project = sum(1 for i in self._project_items if not i.checked)
        code_count = len(self._items)

        with TabbedContent(id="todos-tabs"):
            # Project TODOs tab (default, for Claude collaboration)
            with TabPane(f"Project ({unchecked_project})", id="tab-project"):
                # Create TODO.md section (shown when file doesn't exist)
                with Vertical(classes="create-todo-section", id="create-todo-section"):
                    yield Static(
                        "No TODO.md found in project",
                        classes="create-todo-message",
                    )
                    yield Button("Create TODO.md", id="create-todo-btn", variant="primary")

                yield ListView(id="project-todos-list")
                yield Static("No project TODOs", classes="empty-message", id="project-empty")

            # Code Comment TODOs tab
            with TabPane(f"Comments ({code_count})", id="tab-comments"):
                yield ListView(id="code-todos-list")
                yield Static("No code TODOs found ✓", classes="empty-message", id="code-empty")

    def on_mount(self) -> None:
        """Initialize the lists with items."""
        self._refresh_lists()

    def _refresh_lists(self) -> None:
        """Refresh both list views with current items."""
        try:
            create_section = self.query_one("#create-todo-section", Vertical)
            project_list = self.query_one("#project-todos-list", ListView)
            project_empty = self.query_one("#project-empty", Static)
            code_list = self.query_one("#code-todos-list", ListView)
            code_empty = self.query_one("#code-empty", Static)

            # Clear both lists
            project_list.clear()
            code_list.clear()

            # Check if TODO.md exists
            self._has_todo_md = (self._project_path / "TODO.md").exists()

            # Project TODOs tab
            if not self._has_todo_md and not self._project_items:
                # Show create button
                create_section.display = True
                project_list.display = False
                project_empty.display = False
            else:
                create_section.display = False

                if self._project_items:
                    # Add unchecked items
                    for item in self._project_items:
                        if not item.checked:
                            project_list.append(ProjectTodoListItem(item))

                    unchecked = sum(1 for i in self._project_items if not i.checked)
                    project_list.display = unchecked > 0
                    project_empty.display = unchecked == 0
                else:
                    project_list.display = False
                    project_empty.display = True

            # Code TODOs tab
            if self._items:
                for item in self._items:
                    code_list.append(TodoListItem(item))
                code_list.display = True
                code_empty.display = False
            else:
                code_list.display = False
                code_empty.display = True

            # Update tab labels with counts
            self._update_tab_labels()

        except Exception:
            pass

    def _update_tab_labels(self) -> None:
        """Update tab labels with current counts."""
        try:
            tabs = self.query_one("#todos-tabs", TabbedContent)

            unchecked_project = sum(1 for i in self._project_items if not i.checked)
            code_count = len(self._items)

            # Update tab labels via the Tabs widget
            # Tab IDs include the pane ID, e.g., "--content-tab-tab-project"
            for tab in tabs.query("Tab"):
                tab_id = str(tab.id) if tab.id else ""
                if "tab-project" in tab_id:
                    tab.label = f"Project ({unchecked_project})"
                elif "tab-comments" in tab_id:
                    tab.label = f"Comments ({code_count})"
        except Exception:
            pass

    def update_tab_counts(self, project_count: int, code_count: int) -> None:
        """Update tab labels with provided counts (called from ContextPanel)."""
        try:
            tabs = self.query_one("#todos-tabs", TabbedContent)

            for tab in tabs.query("Tab"):
                tab_id = str(tab.id) if tab.id else ""
                if "tab-project" in tab_id:
                    tab.label = f"Project ({project_count})"
                elif "tab-comments" in tab_id:
                    tab.label = f"Comments ({code_count})"
        except Exception:
            pass

    def update_items(
        self,
        items: list[TodoItem],
        project_items: list[ProjectTodoItem] | None = None,
    ) -> None:
        """Update both TODO lists."""
        self._items = items
        self._project_items = project_items or []

        # Refresh the lists
        self._refresh_lists()

    def filter_by_type(self, todo_type: TodoType) -> list[TodoItem]:
        """Filter code TODOs by type."""
        return [i for i in self._items if i.todo_type == todo_type]

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle item selection."""
        if isinstance(event.item, TodoListItem):
            self.post_message(self.TodoClicked(event.item.item))
        elif isinstance(event.item, ProjectTodoListItem):
            self.post_message(self.ProjectTodoClicked(event.item.item))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "create-todo-btn":
            self._create_todo_md()

    def _create_todo_md(self) -> None:
        """Create a new TODO.md file with template."""
        todo_path = self._project_path / "TODO.md"
        if todo_path.exists():
            return

        try:
            todo_path.write_text(TODO_MD_TEMPLATE)
            self._has_todo_md = True
            self.post_message(self.TodoMdCreated(todo_path))
            # Notify app to refresh TODOs
            self.post_message(self.CreateTodoMdRequested())
        except OSError as e:
            self.app.notify(f"Failed to create TODO.md: {e}", severity="error")

    def set_project_path(self, path: Path) -> None:
        """Update the project path."""
        self._project_path = path
        self._has_todo_md = (path / "TODO.md").exists()
        self._refresh_lists()
