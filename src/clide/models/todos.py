"""TODO comments Pydantic models."""

from enum import Enum
from pathlib import Path

from pydantic import BaseModel, ConfigDict


class TodoType(str, Enum):
    """Type of TODO comment."""

    TODO = "TODO"
    FIXME = "FIXME"
    HACK = "HACK"
    XXX = "XXX"
    NOTE = "NOTE"
    BUG = "BUG"
    OPTIMIZE = "OPTIMIZE"
    REVIEW = "REVIEW"


class TodoItem(BaseModel):
    """A single TODO comment found in code."""

    model_config = ConfigDict(strict=True, frozen=True)

    file_path: Path
    line: int
    column: int
    todo_type: TodoType
    text: str
    context_line: str  # The full line containing the TODO

    @property
    def location(self) -> str:
        """Human-readable location string."""
        return f"{self.file_path}:{self.line}"

    @property
    def type_icon(self) -> str:
        """Icon for TODO type."""
        icons = {
            TodoType.TODO: "☐",
            TodoType.FIXME: "🔧",
            TodoType.HACK: "⚡",
            TodoType.XXX: "❗",
            TodoType.NOTE: "📝",
            TodoType.BUG: "🐛",
            TodoType.OPTIMIZE: "⚡",
            TodoType.REVIEW: "👀",
        }
        return icons[self.todo_type]


class TodosSummary(BaseModel):
    """Summary of TODOs in the workspace."""

    model_config = ConfigDict(strict=True, frozen=True)

    todo_count: int = 0
    fixme_count: int = 0
    hack_count: int = 0
    other_count: int = 0

    @property
    def total(self) -> int:
        """Total number of TODOs."""
        return self.todo_count + self.fixme_count + self.hack_count + self.other_count

    @property
    def display_text(self) -> str:
        """Text for tab badge."""
        return f"✓{self.total}"


class TodosState(BaseModel):
    """State of the TODOs panel."""

    model_config = ConfigDict(strict=True)

    items: list[TodoItem] = []
    summary: TodosSummary = TodosSummary()
    filter_type: TodoType | None = None
    selected_index: int | None = None
    group_by_file: bool = True

    def items_for_file(self, path: Path) -> list[TodoItem]:
        """Get TODO items for a specific file."""
        return [item for item in self.items if item.file_path == path]

    def items_by_type(self, todo_type: TodoType) -> list[TodoItem]:
        """Get TODO items of a specific type."""
        return [item for item in self.items if item.todo_type == todo_type]
