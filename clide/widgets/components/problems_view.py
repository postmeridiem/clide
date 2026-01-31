"""Problems view component for linter errors."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import ListItem, ListView, Static

from clide.models.problems import Problem


class ProblemItem(ListItem):
    """A single problem item."""

    def __init__(self, problem: Problem) -> None:
        super().__init__()
        self.problem = problem

    def compose(self) -> ComposeResult:
        icon = self.problem.severity_icon
        severity_class = self.problem.severity.value

        yield Static(
            f"[{severity_class}]{icon}[/] "
            f"[dim]{self.problem.file_path}:{self.problem.line}[/] "
            f"{self.problem.message}",
            markup=True,
        )


class ProblemsView(Vertical):
    """View for linter problems/diagnostics."""

    DEFAULT_CSS = """
    ProblemsView {
        height: 100%;
    }

    ProblemsView .problems-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    ProblemsView ListView {
        height: 1fr;
    }

    ProblemsView .error { color: $error; }
    ProblemsView .warning { color: $warning; }
    ProblemsView .info { color: $primary; }
    ProblemsView .hint { color: $secondary; }

    ProblemsView .empty-message {
        padding: 2;
        text-align: center;
        color: $success;
    }
    """

    class ProblemClicked(Message):
        """Emitted when a problem is clicked."""

        def __init__(self, problem: Problem) -> None:
            self.problem = problem
            super().__init__()

    def __init__(self, problems: list[Problem] | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._problems = problems or []

    def compose(self) -> ComposeResult:
        count = len(self._problems)
        yield Static(f"Problems ({count})", classes="problems-header", id="problems-header")

        if self._problems:
            yield ListView(
                *[ProblemItem(p) for p in self._problems],
                id="problems-list",
            )
        else:
            yield Static("No problems found ✓", classes="empty-message")

    def update_problems(self, problems: list[Problem]) -> None:
        """Update the problems list."""
        self._problems = problems

        # Update header
        header = self.query_one("#problems-header", Static)
        header.update(f"Problems ({len(problems)})")

        # Update list
        try:
            problems_list = self.query_one("#problems-list", ListView)
            problems_list.clear()
            for problem in problems:
                problems_list.append(ProblemItem(problem))
        except Exception:
            # List might not exist yet, will be created on next compose
            pass

    def filter_by_file(self, path: Path) -> list[Problem]:
        """Get problems for a specific file."""
        return [p for p in self._problems if p.file_path == path]

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle item selection."""
        if isinstance(event.item, ProblemItem):
            self.post_message(self.ProblemClicked(event.item.problem))
