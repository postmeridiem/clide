"""TODOs view component."""

from pathlib import Path

from textual.app import ComposeResult
from textual.message import Message
from textual.widgets import Label, ListItem, ListView, Static
from textual.containers import Vertical

from clide.models.todos import TodoItem, TodoType


class TodoListItem(ListItem):
    """A single TODO item."""

    def __init__(self, item: TodoItem) -> None:
        super().__init__()
        self.item = item

    def compose(self) -> ComposeResult:
        icon = self.item.type_icon
        type_class = self.item.todo_type.value.lower()

        yield Static(
            f"[{type_class}]{icon} {self.item.todo_type.value}[/] "
            f"[dim]{self.item.file_path}:{self.item.line}[/] "
            f"{self.item.text}",
            markup=True,
        )


class TodosView(Vertical):
    """View for TODO/FIXME comments."""

    DEFAULT_CSS = """
    TodosView {
        height: 100%;
    }

    TodosView .todos-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    TodosView ListView {
        height: 1fr;
    }

    TodosView .todo { color: $primary; }
    TodosView .fixme { color: $warning; }
    TodosView .hack { color: $error; }
    TodosView .xxx { color: $error; }
    TodosView .note { color: $secondary; }
    TodosView .bug { color: $error; }

    TodosView .empty-message {
        padding: 2;
        text-align: center;
        color: $success;
    }
    """

    class TodoClicked(Message):
        """Emitted when a TODO is clicked."""

        def __init__(self, item: TodoItem) -> None:
            self.item = item
            super().__init__()

    def __init__(self, items: list[TodoItem] | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._items = items or []

    def compose(self) -> ComposeResult:
        count = len(self._items)
        yield Static(f"TODOs ({count})", classes="todos-header", id="todos-header")

        if self._items:
            yield ListView(
                *[TodoListItem(item) for item in self._items],
                id="todos-list",
            )
        else:
            yield Static("No TODOs found ✓", classes="empty-message")

    def update_items(self, items: list[TodoItem]) -> None:
        """Update the TODOs list."""
        self._items = items

        # Update header
        header = self.query_one("#todos-header", Static)
        header.update(f"TODOs ({len(items)})")

        # Update list
        try:
            todos_list = self.query_one("#todos-list", ListView)
            todos_list.clear()
            for item in items:
                todos_list.append(TodoListItem(item))
        except Exception:
            pass

    def filter_by_type(self, todo_type: TodoType) -> list[TodoItem]:
        """Filter by TODO type."""
        return [i for i in self._items if i.todo_type == todo_type]

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle item selection."""
        if isinstance(event.item, TodoListItem):
            self.post_message(self.TodoClicked(event.item.item))
