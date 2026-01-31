"""Tests for panel widgets."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from clide.models.diff import DiffContent
from clide.models.git import GitBranch, GitChange
from clide.models.problems import Problem, Severity
from clide.models.todos import TodoItem, TodoType


class TestSidebarPanel:
    """Tests for SidebarPanel."""

    def test_initial_state(self, tmp_path: Path):
        """Test initial state."""
        from clide.widgets.panels.sidebar import SidebarPanel

        panel = SidebarPanel(workdir=tmp_path)
        assert panel._workdir == tmp_path
        assert panel.current_branch == "main"
        assert panel.visible is True
        assert panel.id == "panel-sidebar"

    def test_default_workdir(self):
        """Test default workdir is cwd."""
        from clide.widgets.panels.sidebar import SidebarPanel

        panel = SidebarPanel()
        assert panel._workdir == Path.cwd()

    def test_file_selected_message(self):
        """Test FileSelected message."""
        from clide.widgets.panels.sidebar import SidebarPanel

        msg = SidebarPanel.FileSelected(Path("/test/file.py"))
        assert msg.path == Path("/test/file.py")

    def test_git_file_selected_message(self):
        """Test GitFileSelected message."""
        from clide.widgets.panels.sidebar import SidebarPanel

        msg = SidebarPanel.GitFileSelected(Path("/test/file.py"), staged=True)
        assert msg.path == Path("/test/file.py")
        assert msg.staged is True

    def test_branch_changed_message(self):
        """Test BranchChanged message."""
        from clide.widgets.panels.sidebar import SidebarPanel

        msg = SidebarPanel.BranchChanged("develop")
        assert msg.branch == "develop"


class TestWorkspacePanel:
    """Tests for WorkspacePanel."""

    def test_initial_state(self, tmp_path: Path):
        """Test initial state."""
        from clide.widgets.panels.workspace import WorkspacePanel

        panel = WorkspacePanel(workdir=tmp_path)
        assert panel._workdir == tmp_path
        assert panel.visible is False
        assert panel.active_tab == "editor"
        assert panel.id == "panel-workspace"

    def test_default_workdir(self):
        """Test default workdir is cwd."""
        from clide.widgets.panels.workspace import WorkspacePanel

        panel = WorkspacePanel()
        assert panel._workdir == Path.cwd()

    def test_show_hide_toggle(self):
        """Test show/hide/toggle methods."""
        from clide.widgets.panels.workspace import WorkspacePanel

        panel = WorkspacePanel()
        assert panel.visible is False

        panel.show()
        assert panel.visible is True

        panel.hide()
        assert panel.visible is False

        panel.toggle()
        assert panel.visible is True

        panel.toggle()
        assert panel.visible is False

    def test_file_saved_message(self):
        """Test FileSaved message."""
        from clide.widgets.panels.workspace import WorkspacePanel

        msg = WorkspacePanel.FileSaved(Path("/test/file.py"))
        assert msg.path == Path("/test/file.py")

    def test_diff_accepted_message(self):
        """Test DiffAccepted message."""
        from clide.widgets.panels.workspace import WorkspacePanel

        msg = WorkspacePanel.DiffAccepted("test.py")
        assert msg.file_path == "test.py"

    def test_diff_rejected_message(self):
        """Test DiffRejected message."""
        from clide.widgets.panels.workspace import WorkspacePanel

        msg = WorkspacePanel.DiffRejected("test.py")
        assert msg.file_path == "test.py"

    def test_command_submitted_message(self):
        """Test CommandSubmitted message."""
        from clide.widgets.panels.workspace import WorkspacePanel

        msg = WorkspacePanel.CommandSubmitted("ls -la")
        assert msg.command == "ls -la"

    def test_close_requested_message(self):
        """Test CloseRequested message."""
        from clide.widgets.panels.workspace import WorkspacePanel

        msg = WorkspacePanel.CloseRequested()
        assert msg is not None


class TestClaudePanel:
    """Tests for ClaudePanel."""

    def test_initial_state(self, tmp_path: Path):
        """Test initial state."""
        from clide.widgets.panels.claude import ClaudePanel

        panel = ClaudePanel(workdir=tmp_path, auto_start=False)
        assert panel.id == "panel-claude"
        assert panel.workspace_visible is False
        assert panel._workdir == tmp_path
        assert panel._auto_start is False
        assert panel._restart_on_exit is True

    def test_default_workdir(self):
        """Test default workdir is cwd."""
        from clide.widgets.panels.claude import ClaudePanel

        panel = ClaudePanel(auto_start=False)
        assert panel._workdir == Path.cwd()

    def test_claude_exited_message(self):
        """Test ClaudeExited message."""
        from clide.widgets.panels.claude import ClaudePanel

        msg = ClaudePanel.ClaudeExited(0)
        assert msg.return_code == 0

    def test_claude_started_message(self):
        """Test ClaudeStarted message."""
        from clide.widgets.panels.claude import ClaudePanel

        msg = ClaudePanel.ClaudeStarted()
        assert msg is not None

    def test_workdir_property(self, tmp_path: Path):
        """Test workdir property."""
        from clide.widgets.panels.claude import ClaudePanel

        panel = ClaudePanel(auto_start=False)
        panel.workdir = tmp_path
        assert panel.workdir == tmp_path

    def test_set_restart_on_exit(self):
        """Test set_restart_on_exit method."""
        from clide.widgets.panels.claude import ClaudePanel

        panel = ClaudePanel(auto_start=False)
        assert panel._restart_on_exit is True

        panel.set_restart_on_exit(False)
        assert panel._restart_on_exit is False


class TestContextPanel:
    """Tests for ContextPanel."""

    def test_initial_state_enabled(self):
        """Test initial state with Jira enabled."""
        from clide.widgets.panels.context import ContextPanel

        panel = ContextPanel(jira_enabled=True)
        assert panel._jira_enabled is True
        assert panel.problem_count == 0
        assert panel.todo_count == 0
        assert panel.visible is True
        assert panel.id == "panel-context"

    def test_initial_state_disabled(self):
        """Test initial state with Jira disabled."""
        from clide.widgets.panels.context import ContextPanel

        panel = ContextPanel(jira_enabled=False)
        assert panel._jira_enabled is False

    def test_problem_clicked_message(self):
        """Test ProblemClicked message."""
        from clide.widgets.panels.context import ContextPanel

        problem = Problem(
            file_path=Path("/test.py"),
            line=10,
            column=5,
            severity=Severity.ERROR,
            message="Test error",
            source="ruff",
        )
        msg = ContextPanel.ProblemClicked(problem)
        assert msg.problem == problem

    def test_todo_clicked_message(self):
        """Test TodoClicked message."""
        from clide.widgets.panels.context import ContextPanel

        item = TodoItem(
            file_path=Path("/test.py"),
            line=10,
            column=1,
            todo_type=TodoType.TODO,
            text="Test todo",
            context_line="# TODO: Test todo",
        )
        msg = ContextPanel.TodoClicked(item)
        assert msg.item == item

    def test_jira_refresh_requested_message(self):
        """Test JiraRefreshRequested message."""
        from clide.widgets.panels.context import ContextPanel

        msg = ContextPanel.JiraRefreshRequested()
        assert msg is not None
