"""Context panel with Jira, TODOs, and Problems tabs."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import TabbedContent, TabPane

from clide.models.problems import Problem
from clide.models.todos import ProjectTodoItem, TodoItem
from clide.widgets.components.jira_view import JiraView
from clide.widgets.components.problems_view import ProblemsView
from clide.widgets.components.todos_view import TodosView


class ContextPanel(Vertical):
    """Right context panel with Jira, TODOs, and Problems tabs."""

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

    ContextPanel TabPane {
        height: 1fr;
        padding: 0;
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
        """Emitted when a code TODO is clicked."""

        def __init__(self, item: TodoItem) -> None:
            self.item = item
            super().__init__()

    class ProjectTodoClicked(Message):
        """Emitted when a project TODO (from TODO.md) is clicked."""

        def __init__(self, item: ProjectTodoItem) -> None:
            self.item = item
            super().__init__()

    class JiraRefreshRequested(Message):
        """Emitted when Jira refresh is requested."""

        pass

    class TodoMdCreated(Message):
        """Emitted when TODO.md has been created."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    # Reactive state with counts for tab badges
    problem_count: reactive[int] = reactive(0)
    todo_count: reactive[int] = reactive(0)
    project_todo_count: reactive[int] = reactive(0)
    code_todo_count: reactive[int] = reactive(0)
    visible: reactive[bool] = reactive(True)

    def __init__(
        self,
        jira_enabled: bool = True,
        project_path: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._jira_enabled = jira_enabled
        self._project_path = project_path or Path.cwd()
        self.id = "panel-context"

    def compose(self) -> ComposeResult:
        with TabbedContent(id="context-tabs"):
            with TabPane("Jira", id="context-jira"):
                yield JiraView(enabled=self._jira_enabled, id="jira-view")
            with TabPane("TODOs (0)", id="context-todos"):
                yield TodosView(project_path=self._project_path, id="todos-view")
            with TabPane("Problems (0)", id="context-problems"):
                yield ProblemsView(id="problems-view")

    def on_mount(self) -> None:
        """Initialize tab counts."""
        self._update_tab_headers()

    def watch_visible(self, visible: bool) -> None:
        """Handle visibility changes."""
        self.display = visible

    def watch_problem_count(self, count: int) -> None:
        """Update problem count display."""
        self._update_tab_headers()

    def watch_todo_count(self, count: int) -> None:
        """Update todo count display."""
        self._update_tab_headers()

    def _update_tab_headers(self) -> None:
        """Update the tab headers with counts."""
        try:
            tabs = self.query_one("#context-tabs", TabbedContent)

            # Update tab labels via the Tabs widget
            for tab in tabs.query("Tab"):
                tab_id = str(tab.id) if tab.id else ""
                if "context-todos" in tab_id:
                    tab.label = f"TODOs ({self.todo_count})"
                elif "context-problems" in tab_id:
                    tab.label = f"Problems ({self.problem_count})"
        except Exception:
            pass

    def _update_todos_subtabs(self) -> None:
        """Update the TODOs view sub-tab labels."""
        try:
            view = self.query_one("#todos-view", TodosView)
            view.update_tab_counts(self.project_todo_count, self.code_todo_count)
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

    def update_todos(
        self,
        items: list[TodoItem],
        project_items: list[ProjectTodoItem] | None = None,
    ) -> None:
        """Update TODOs view and count."""
        project_items = project_items or []
        # Count includes both code TODOs and unchecked project TODOs
        unchecked_project = sum(1 for p in project_items if not p.checked)
        self.project_todo_count = unchecked_project
        self.code_todo_count = len(items)
        self.todo_count = unchecked_project + len(items)
        try:
            view = self.query_one("#todos-view", TodosView)
            view.update_items(items, project_items)
            # Update sub-tab counts
            self._update_todos_subtabs()
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
        """Forward code todo click."""
        self.post_message(self.TodoClicked(event.item))

    def on_todos_view_project_todo_clicked(
        self,
        event: TodosView.ProjectTodoClicked,
    ) -> None:
        """Forward project todo click."""
        self.post_message(self.ProjectTodoClicked(event.item))

    def on_jira_view_refresh_requested(
        self,
        event: JiraView.RefreshRequested,
    ) -> None:
        """Forward Jira refresh request."""
        self.post_message(self.JiraRefreshRequested())

    def on_todos_view_todo_md_created(
        self,
        event: TodosView.TodoMdCreated,
    ) -> None:
        """Forward TODO.md created event."""
        self.post_message(self.TodoMdCreated(event.path))
