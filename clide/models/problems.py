"""Problems (linter errors) Pydantic models."""

from enum import Enum
from pathlib import Path

from pydantic import BaseModel, ConfigDict


class Severity(str, Enum):
    """Problem severity level."""

    ERROR = "error"
    WARNING = "warning"
    INFO = "info"
    HINT = "hint"


class Problem(BaseModel):
    """A single linter problem/diagnostic."""

    model_config = ConfigDict(strict=True, frozen=True)

    file_path: Path
    line: int
    column: int
    end_line: int | None = None
    end_column: int | None = None
    severity: Severity
    message: str
    source: str  # e.g., "ruff", "mypy", "eslint"
    code: str | None = None  # e.g., "E501", "W0612"

    @property
    def location(self) -> str:
        """Human-readable location string."""
        return f"{self.file_path}:{self.line}:{self.column}"

    @property
    def severity_icon(self) -> str:
        """Icon for severity level."""
        icons = {
            Severity.ERROR: "✖",
            Severity.WARNING: "⚠",
            Severity.INFO: "ℹ",
            Severity.HINT: "💡",
        }
        return icons[self.severity]


class ProblemsSummary(BaseModel):
    """Summary of problems in the workspace."""

    model_config = ConfigDict(strict=True, frozen=True)

    errors: int = 0
    warnings: int = 0
    infos: int = 0
    hints: int = 0

    @property
    def total(self) -> int:
        """Total number of problems."""
        return self.errors + self.warnings + self.infos + self.hints

    @property
    def display_text(self) -> str:
        """Text for tab badge."""
        if self.errors:
            return f"⚠ {self.errors}"
        if self.warnings:
            return f"⚠ {self.warnings}"
        return f"✓ {self.total}"


class ProblemsState(BaseModel):
    """State of the problems panel."""

    model_config = ConfigDict(strict=True)

    problems: list[Problem] = []
    summary: ProblemsSummary = ProblemsSummary()
    filter_severity: Severity | None = None
    filter_source: str | None = None
    selected_index: int | None = None

    def problems_for_file(self, path: Path) -> list[Problem]:
        """Get problems for a specific file."""
        return [p for p in self.problems if p.file_path == path]
