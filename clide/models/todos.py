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


class ProjectTodoItem(BaseModel):
    """A TODO item from TODO.md file."""

    model_config = ConfigDict(strict=True, frozen=True)

    text: str
    section: str  # Top-level section (## heading)
    subsection: str | None = None  # Optional subsection (### heading)
    line: int  # Line number in TODO.md
    checked: bool = False  # Whether the checkbox is checked

    @property
    def category(self) -> str:
        """Get full category path."""
        if self.subsection:
            return f"{self.section} › {self.subsection}"
        return self.section

    @property
    def icon(self) -> str:
        """Icon for display."""
        return "☑" if self.checked else "☐"


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
    project_todo_count: int = 0  # Count from TODO.md
    project_done_count: int = 0  # Checked items in TODO.md

    @property
    def total(self) -> int:
        """Total number of code TODOs."""
        return self.todo_count + self.fixme_count + self.hack_count + self.other_count

    @property
    def project_total(self) -> int:
        """Total number of project TODOs."""
        return self.project_todo_count + self.project_done_count

    @property
    def display_text(self) -> str:
        """Text for tab badge."""
        return f"✓{self.total}"


class TodosState(BaseModel):
    """State of the TODOs panel."""

    model_config = ConfigDict(strict=True)

    items: list[TodoItem] = []
    project_items: list[ProjectTodoItem] = []  # Items from TODO.md
    summary: TodosSummary = TodosSummary()
    filter_type: TodoType | None = None
    selected_index: int | None = None
    group_by_file: bool = True
    show_completed_project_todos: bool = False  # Toggle for checked items

    def items_for_file(self, path: Path) -> list[TodoItem]:
        """Get TODO items for a specific file."""
        return [item for item in self.items if item.file_path == path]

    def items_by_type(self, todo_type: TodoType) -> list[TodoItem]:
        """Get TODO items of a specific type."""
        return [item for item in self.items if item.todo_type == todo_type]

    def project_items_by_section(self, section: str) -> list[ProjectTodoItem]:
        """Get project TODO items for a specific section."""
        return [item for item in self.project_items if item.section == section]

    def get_project_sections(self) -> list[str]:
        """Get unique sections from project TODOs."""
        sections: list[str] = []
        for item in self.project_items:
            if item.section not in sections:
                sections.append(item.section)
        return sections
