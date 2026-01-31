"""Context panel with Problems, TODOs, and Jira tabs."""


from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import Static, TabbedContent, TabPane

from clide.models.problems import Problem
from clide.models.todos import TodoItem
from clide.widgets.components.jira_view import JiraView
from clide.widgets.components.problems_view import ProblemsView
from clide.widgets.components.todos_view import TodosView


class ContextPanel(Vertical):
    """Right context panel with Problems, TODOs, and Jira integration."""

    DEFAULT_CSS = """
    ContextPanel {
        width: 25%;
        min-width: 30;
        height: 100%;
        background: $surface;
    }

    ContextPanel TabbedContent {
        height: 1fr;
    }

    ContextPanel .context-tab-bar {
        dock: bottom;
        height: 1;
        background: $panel;
        padding: 0 1;
    }

    ContextPanel .tab-count {
        margin: 0 1;
    }

    ContextPanel .error-count {
        color: $error;
    }

    ContextPanel .warning-count {
        color: $warning;
    }

    ContextPanel .success-count {
        color: $success;
    }
    """

    class ProblemClicked(Message):
        """Emitted when a problem is clicked."""

        def __init__(self, problem: Problem) -> None:
            self.problem = problem
            super().__init__()

    class TodoClicked(Message):
        """Emitted when a TODO is clicked."""

        def __init__(self, item: TodoItem) -> None:
            self.item = item
            super().__init__()

    class JiraRefreshRequested(Message):
        """Emitted when Jira refresh is requested."""
        pass

    # Reactive state with counts for tab badges
    problem_count: reactive[int] = reactive(0)
    todo_count: reactive[int] = reactive(0)
    visible: reactive[bool] = reactive(True)

    def __init__(
        self,
        jira_enabled: bool = True,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._jira_enabled = jira_enabled
        self.id = "panel-context"

    def compose(self) -> ComposeResult:
        with TabbedContent(id="context-tabs"):
            with TabPane("Problems", id="context-problems"):
                yield ProblemsView(id="problems-view")
            with TabPane("TODOs", id="context-todos"):
                yield TodosView(id="todos-view")
            with TabPane("Jira", id="context-jira"):
                yield JiraView(enabled=self._jira_enabled, id="jira-view")
        # Tab bar with counts at bottom
        with Horizontal(classes="context-tab-bar"):
            yield Static("", id="tab-counts")

    def on_mount(self) -> None:
        """Initialize tab counts."""
        self._update_tab_counts()

    def watch_visible(self, visible: bool) -> None:
        """Handle visibility changes."""
        self.display = visible

    def watch_problem_count(self, count: int) -> None:
        """Update problem count display."""
        self._update_tab_counts()

    def watch_todo_count(self, count: int) -> None:
        """Update todo count display."""
        self._update_tab_counts()

    def _update_tab_counts(self) -> None:
        """Update the tab counts display."""
        try:
            counts = self.query_one("#tab-counts", Static)
            problem_style = "error-count" if self.problem_count > 0 else "success-count"
            todo_style = "warning-count" if self.todo_count > 0 else "success-count"

            # Build count display
            parts = []
            if self.problem_count > 0:
                parts.append(f"[{problem_style}]⚠ {self.problem_count}[/]")
            else:
                parts.append(f"[{problem_style}]✓ 0[/]")

            parts.append(f"[{todo_style}]☐ {self.todo_count}[/]")

            counts.update(" │ ".join(parts))
        except Exception:
            pass

    def update_problems(self, problems: list[Problem]) -> None:
        """Update problems view and count."""
        self.problem_count = len(problems)
        try:
            view = self.query_one("#problems-view", ProblemsView)
            view.update_problems(problems)
        except Exception:
            pass

    def update_todos(self, items: list[TodoItem]) -> None:
        """Update TODOs view and count."""
        self.todo_count = len(items)
        try:
            view = self.query_one("#todos-view", TodosView)
            view.update_items(items)
        except Exception:
            pass

    def update_jira(self, content: str) -> None:
        """Update Jira view content."""
        try:
            view = self.query_one("#jira-view", JiraView)
            view.update_content(content)
        except Exception:
            pass

    def set_jira_loading(self) -> None:
        """Set Jira view to loading state."""
        try:
            view = self.query_one("#jira-view", JiraView)
            view.set_loading()
        except Exception:
            pass

    def set_jira_error(self, error: str) -> None:
        """Set Jira view to error state."""
        try:
            view = self.query_one("#jira-view", JiraView)
            view.set_error(error)
        except Exception:
            pass

    def focus_tab(self, tab_id: str) -> None:
        """Focus a specific tab."""
        tabs = self.query_one("#context-tabs", TabbedContent)
        tabs.active = f"context-{tab_id}"

    def focus_problems(self) -> None:
        """Focus problems tab."""
        self.focus_tab("problems")

    def focus_todos(self) -> None:
        """Focus TODOs tab."""
        self.focus_tab("todos")

    def focus_jira(self) -> None:
        """Focus Jira tab."""
        self.focus_tab("jira")

    # Event forwarding
    def on_problems_view_problem_clicked(
        self,
        event: ProblemsView.ProblemClicked,
    ) -> None:
        """Forward problem click."""
        self.post_message(self.ProblemClicked(event.problem))

    def on_todos_view_todo_clicked(self, event: TodosView.TodoClicked) -> None:
        """Forward todo click."""
        self.post_message(self.TodoClicked(event.item))

    def on_jira_view_refresh_requested(
        self,
        event: JiraView.RefreshRequested,
    ) -> None:
        """Forward Jira refresh request."""
        self.post_message(self.JiraRefreshRequested())
