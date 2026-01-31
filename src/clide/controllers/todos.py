"""TODOs controller for tracking TODO comments."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.models.todos import TodoItem, TodosSummary, TodosState, TodoType
from clide.services.todo_scanner import TodoScanner


@controller
class TodosController:
    """Controller for TODO/FIXME comment tracking."""

    class TodosUpdated(Message):
        """Emitted when TODOs list is updated."""

        def __init__(self, items: list[TodoItem], summary: TodosSummary) -> None:
            self.items = items
            self.summary = summary
            super().__init__()

    class TodoSelected(Message):
        """Emitted when a TODO is selected."""

        def __init__(self, item: TodoItem) -> None:
            self.item = item
            super().__init__()

    def __init__(self, project_path: Path) -> None:
        self._scanner = TodoScanner(project_path)
        self._state = TodosState()

    @property
    def state(self) -> TodosState:
        """Get TODOs state."""
        return self._state

    @property
    def items(self) -> list[TodoItem]:
        """Get list of TODO items."""
        return self._state.items

    @property
    def summary(self) -> TodosSummary:
        """Get TODOs summary."""
        return self._state.summary

    @property
    def total_count(self) -> int:
        """Get total TODO count."""
        return self._state.summary.total

    async def refresh(self) -> tuple[list[TodoItem], TodosSummary]:
        """Refresh TODOs from project.

        Returns:
            Tuple of (items, summary)
        """
        items, summary = await self._scanner.scan()

        self._state.items = items
        self._state.summary = summary

        return items, summary

    def filter_by_type(self, todo_type: TodoType | None) -> list[TodoItem]:
        """Filter TODOs by type.

        Args:
            todo_type: Type to filter by, or None for all

        Returns:
            Filtered list of TODOs
        """
        self._state.filter_type = todo_type

        if todo_type is None:
            return self._state.items

        return self._state.items_by_type(todo_type)

    def get_items_for_file(self, path: Path) -> list[TodoItem]:
        """Get TODOs for a specific file.

        Args:
            path: File path

        Returns:
            List of TODOs for that file
        """
        return self._state.items_for_file(path)

    def select_item(self, index: int) -> TodoItem | None:
        """Select a TODO by index.

        Args:
            index: Item index

        Returns:
            Selected item or None
        """
        if 0 <= index < len(self._state.items):
            self._state.selected_index = index
            return self._state.items[index]
        return None

    def toggle_group_by_file(self) -> bool:
        """Toggle grouping by file.

        Returns:
            New group_by_file value
        """
        self._state.group_by_file = not self._state.group_by_file
        return self._state.group_by_file

    def get_grouped_items(self) -> dict[Path, list[TodoItem]]:
        """Get TODOs grouped by file.

        Returns:
            Dictionary mapping file paths to TODO lists
        """
        grouped: dict[Path, list[TodoItem]] = {}
        for item in self._state.items:
            if item.file_path not in grouped:
                grouped[item.file_path] = []
            grouped[item.file_path].append(item)
        return grouped

    async def scan(self) -> list[TodoItem]:
        """Scan for TODOs and return items.

        Returns:
            List of TODO items
        """
        items, _ = await self.refresh()
        return items
