"""TODOs view component."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Button, Collapsible, ListItem, ListView, Static

from clide.models.todos import ProjectTodoItem, TodoItem, TodoType

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


class TodoListItem(ListItem):
    """A single code TODO item."""

    def __init__(self, item: TodoItem) -> None:
        super().__init__()
        self.item = item
        self.is_project_item = False

    def compose(self) -> ComposeResult:
        icon = self.item.type_icon
        type_class = self.item.todo_type.value.lower()

        yield Static(
            f"[{type_class}]{icon} {self.item.todo_type.value}[/] "
            f"[dim]{self.item.file_path}:{self.item.line}[/] "
            f"{self.item.text}",
            markup=True,
        )


class ProjectTodoListItem(ListItem):
    """A single project TODO item from TODO.md."""

    def __init__(self, item: ProjectTodoItem) -> None:
        super().__init__()
        self.item = item
        self.is_project_item = True

    def compose(self) -> ComposeResult:
        icon = self.item.icon
        checked_style = "dim strike" if self.item.checked else ""
        category = f"[dim]{self.item.category}[/] " if self.item.subsection else ""

        yield Static(
            f"[project]{icon}[/] {category}" f"[{checked_style}]{self.item.text}[/]",
            markup=True,
        )


class TodosView(Vertical):
    """View for TODO/FIXME comments and project TODOs."""

    DEFAULT_CSS = """
    TodosView {
        height: 100%;
    }

    TodosView .todos-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    TodosView .section-header {
        height: 1;
        background: $panel;
        padding: 0 1;
        color: $text-muted;
    }

    TodosView ListView {
        height: auto;
        max-height: 50%;
    }

    TodosView #code-todos-list {
        height: 1fr;
        max-height: none;
    }

    TodosView Collapsible {
        padding: 0;
        border: none;
    }

    TodosView CollapsibleTitle {
        background: $panel;
        padding: 0 1;
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
        color: $success;
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
        total = len(self._items) + len(self._project_items)
        yield Static(f"TODOs ({total})", classes="todos-header", id="todos-header")

        # Create TODO.md section (shown when file doesn't exist)
        with Vertical(classes="create-todo-section", id="create-todo-section"):
            yield Static(
                "No TODO.md found in project",
                classes="create-todo-message",
            )
            yield Button("Create TODO.md", id="create-todo-btn", variant="primary")

        # Project TODOs section (collapsible)
        with Collapsible(title="Project TODOs", id="project-todos-section"):
            yield ListView(id="project-todos-list")

        # Code TODOs section
        yield Static("Code TODOs", classes="section-header", id="code-todos-header")
        yield ListView(id="code-todos-list")

        yield Static("No TODOs found", classes="empty-message", id="todos-empty")

    def on_mount(self) -> None:
        """Initialize the lists with items."""
        self._refresh_lists()

    def _refresh_lists(self) -> None:
        """Refresh both list views with current items."""
        try:
            create_section = self.query_one("#create-todo-section", Vertical)
            project_section = self.query_one("#project-todos-section", Collapsible)
            project_list = self.query_one("#project-todos-list", ListView)
            code_header = self.query_one("#code-todos-header", Static)
            code_list = self.query_one("#code-todos-list", ListView)
            empty_msg = self.query_one("#todos-empty", Static)

            # Clear both lists
            project_list.clear()
            code_list.clear()

            # Check if TODO.md exists
            self._has_todo_md = (self._project_path / "TODO.md").exists()

            has_items = False

            # Show create button if no TODO.md and no project items
            if not self._has_todo_md and not self._project_items:
                create_section.display = True
                project_section.display = False
            else:
                create_section.display = False

                # Populate project TODOs
                if self._project_items:
                    has_items = True
                    # Group by section
                    sections: dict[str, list[ProjectTodoItem]] = {}
                    for item in self._project_items:
                        if item.section not in sections:
                            sections[item.section] = []
                        sections[item.section].append(item)

                    # Add items (flat list, grouped display can be added later)
                    for item in self._project_items:
                        if not item.checked:  # Only show unchecked by default
                            project_list.append(ProjectTodoListItem(item))

                    unchecked = sum(1 for i in self._project_items if not i.checked)
                    project_section.title = f"Project TODOs ({unchecked})"
                    project_section.display = True
                else:
                    project_section.display = False

            # Populate code TODOs
            if self._items:
                has_items = True
                for item in self._items:
                    code_list.append(TodoListItem(item))
                code_header.update(f"Code TODOs ({len(self._items)})")
                code_header.display = True
                code_list.display = True
            else:
                code_header.display = False
                code_list.display = False

            # Show empty message only if no items at all and TODO.md exists
            empty_msg.display = not has_items and self._has_todo_md

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

        # Update header with total count
        try:
            unchecked_project = sum(1 for p in self._project_items if not p.checked)
            total = len(items) + unchecked_project
            header = self.query_one("#todos-header", Static)
            header.update(f"TODOs ({total})")
        except Exception:
            pass

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
