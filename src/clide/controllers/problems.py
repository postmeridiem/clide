"""Problems controller for linter integration."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.models.problems import Problem, ProblemsSummary, ProblemsState, Severity
from clide.services.linter_service import LinterService


@controller
class ProblemsController:
    """Controller for problems/diagnostics from linters."""

    class ProblemsUpdated(Message):
        """Emitted when problems list is updated."""

        def __init__(self, problems: list[Problem], summary: ProblemsSummary) -> None:
            self.problems = problems
            self.summary = summary
            super().__init__()

    class ProblemSelected(Message):
        """Emitted when a problem is selected."""

        def __init__(self, problem: Problem) -> None:
            self.problem = problem
            super().__init__()

    def __init__(self, project_path: Path, linters: list[str] | None = None) -> None:
        self._service = LinterService(project_path)
        self._linters = linters or ["ruff"]
        self._state = ProblemsState()

    @property
    def state(self) -> ProblemsState:
        """Get problems state."""
        return self._state

    @property
    def problems(self) -> list[Problem]:
        """Get list of problems."""
        return self._state.problems

    @property
    def summary(self) -> ProblemsSummary:
        """Get problems summary."""
        return self._state.summary

    @property
    def error_count(self) -> int:
        """Get error count."""
        return self._state.summary.errors

    @property
    def warning_count(self) -> int:
        """Get warning count."""
        return self._state.summary.warnings

    async def refresh(self) -> tuple[list[Problem], ProblemsSummary]:
        """Refresh problems from all linters.

        Returns:
            Tuple of (problems, summary)
        """
        problems, summary = await self._service.run_all(self._linters)

        self._state.problems = problems
        self._state.summary = summary

        return problems, summary

    def filter_by_severity(self, severity: Severity | None) -> list[Problem]:
        """Filter problems by severity.

        Args:
            severity: Severity to filter by, or None for all

        Returns:
            Filtered list of problems
        """
        self._state.filter_severity = severity

        if severity is None:
            return self._state.problems

        return [p for p in self._state.problems if p.severity == severity]

    def filter_by_source(self, source: str | None) -> list[Problem]:
        """Filter problems by source linter.

        Args:
            source: Source to filter by, or None for all

        Returns:
            Filtered list of problems
        """
        self._state.filter_source = source

        if source is None:
            return self._state.problems

        return [p for p in self._state.problems if p.source == source]

    def get_problems_for_file(self, path: Path) -> list[Problem]:
        """Get problems for a specific file.

        Args:
            path: File path

        Returns:
            List of problems for that file
        """
        return self._state.problems_for_file(path)

    def select_problem(self, index: int) -> Problem | None:
        """Select a problem by index.

        Args:
            index: Problem index

        Returns:
            Selected problem or None
        """
        if 0 <= index < len(self._state.problems):
            self._state.selected_index = index
            return self._state.problems[index]
        return None

    def next_problem(self) -> Problem | None:
        """Select next problem.

        Returns:
            Next problem or None
        """
        if not self._state.problems:
            return None

        if self._state.selected_index is None:
            self._state.selected_index = 0
        else:
            self._state.selected_index = (
                self._state.selected_index + 1
            ) % len(self._state.problems)

        return self._state.problems[self._state.selected_index]

    def prev_problem(self) -> Problem | None:
        """Select previous problem.

        Returns:
            Previous problem or None
        """
        if not self._state.problems:
            return None

        if self._state.selected_index is None:
            self._state.selected_index = len(self._state.problems) - 1
        else:
            self._state.selected_index = (
                self._state.selected_index - 1
            ) % len(self._state.problems)

        return self._state.problems[self._state.selected_index]

    def clear(self) -> None:
        """Clear all problems."""
        self._state.problems = []
        self._state.summary = ProblemsSummary()
        self._state.selected_index = None

    async def run_all(self) -> list[Problem]:
        """Run all linters and return problems.

        Returns:
            List of problems
        """
        problems, _ = await self.refresh()
        return problems
