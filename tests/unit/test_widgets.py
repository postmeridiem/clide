"""Tests for widget components."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from clide.models.diff import ChangeType, DiffContent, DiffHunk, DiffLine
from clide.models.editor import CursorPosition, FileBuffer
from clide.models.git import ChangeStatus, GitBranch, GitChange, GitCommit
from clide.models.problems import Problem, Severity
from clide.models.todos import TodoItem, TodoType


class TestFilesView:
    """Tests for FilesView component."""

    def test_filter_paths_excludes_hidden(self, tmp_path: Path):
        """Test that hidden files are filtered out."""
        from clide.widgets.components.files_view import FilesView

        view = FilesView(path=tmp_path)
        paths = [
            tmp_path / "visible.py",
            tmp_path / ".hidden",
            tmp_path / ".git",
            tmp_path / "__pycache__",
            tmp_path / "node_modules",
            tmp_path / ".venv",
            tmp_path / "src",
        ]
        filtered = view.filter_paths(paths)

        assert tmp_path / "visible.py" in filtered
        assert tmp_path / "src" in filtered
        assert tmp_path / ".hidden" not in filtered
        assert tmp_path / ".git" not in filtered
        assert tmp_path / "__pycache__" not in filtered
        assert tmp_path / "node_modules" not in filtered
        assert tmp_path / ".venv" not in filtered

    def test_file_selected_message(self):
        """Test FileSelected message."""
        from clide.widgets.components.files_view import FilesView

        mock_node = MagicMock()
        msg = FilesView.FileSelected(mock_node, Path("/test/file.py"))
        assert msg.path == Path("/test/file.py")
        assert msg.node == mock_node

    def test_directory_selected_message(self):
        """Test DirectorySelected message."""
        from clide.widgets.components.files_view import FilesView

        mock_node = MagicMock()
        msg = FilesView.DirectorySelected(mock_node, Path("/test/dir"))
        assert msg.path == Path("/test/dir")
        assert msg.node == mock_node


class TestGitChangesView:
    """Tests for GitChangesView component."""

    def test_initial_state(self):
        """Test initial state with no changes."""
        from clide.widgets.components.git_changes import GitChangesView

        view = GitChangesView()
        assert view._staged == []
        assert view._unstaged == []

    def test_initial_state_with_changes(self):
        """Test initial state with provided changes."""
        from clide.widgets.components.git_changes import GitChangesView

        staged = [GitChange(path="a.py", status=ChangeStatus.ADDED, staged=True)]
        unstaged = [GitChange(path="b.py", status=ChangeStatus.MODIFIED, staged=False)]

        view = GitChangesView(staged=staged, unstaged=unstaged)
        assert len(view._staged) == 1
        assert len(view._unstaged) == 1

    def test_file_clicked_message(self):
        """Test FileClicked message."""
        from clide.widgets.components.git_changes import GitChangesView

        change = GitChange(path="test.py", status=ChangeStatus.MODIFIED, staged=False)
        msg = GitChangesView.FileClicked(change)
        assert msg.change == change

    def test_stage_requested_message(self):
        """Test StageRequested message."""
        from clide.widgets.components.git_changes import GitChangesView

        msg = GitChangesView.StageRequested("test.py")
        assert msg.path == "test.py"

    def test_unstage_requested_message(self):
        """Test UnstageRequested message."""
        from clide.widgets.components.git_changes import GitChangesView

        msg = GitChangesView.UnstageRequested("test.py")
        assert msg.path == "test.py"


class TestGitChangeItem:
    """Tests for GitChangeItem component."""

    def test_status_icons(self):
        """Test status icon mapping."""
        from clide.widgets.components.git_changes import GitChangeItem

        assert GitChangeItem.STATUS_ICONS[ChangeStatus.ADDED] == "+"
        assert GitChangeItem.STATUS_ICONS[ChangeStatus.MODIFIED] == "~"
        assert GitChangeItem.STATUS_ICONS[ChangeStatus.DELETED] == "-"
        assert GitChangeItem.STATUS_ICONS[ChangeStatus.RENAMED] == "→"
        assert GitChangeItem.STATUS_ICONS[ChangeStatus.UNTRACKED] == "?"

    def test_create_item(self):
        """Test creating a GitChangeItem."""
        from clide.widgets.components.git_changes import GitChangeItem

        change = GitChange(path="test.py", status=ChangeStatus.ADDED, staged=True)
        item = GitChangeItem(change)
        assert item.change == change


class TestGitGraphView:
    """Tests for GitGraphView component."""

    def test_initial_state(self):
        """Test initial state with no commits."""
        from clide.widgets.components.git_graph import GitGraphView

        view = GitGraphView()
        assert view._commits == []

    def test_initial_state_with_commits(self):
        """Test initial state with provided commits."""
        from clide.widgets.components.git_graph import GitGraphView

        commits = [
            GitCommit(
                hash="abc123def456789",
                short_hash="abc123",
                message="Test commit",
                author="Author",
                date="2024-01-01",
            )
        ]
        view = GitGraphView(commits=commits)
        assert len(view._commits) == 1

    def test_graph_symbols(self):
        """Test graph drawing symbols."""
        from clide.widgets.components.git_graph import GitGraphView

        assert GitGraphView.COMMIT == "●"
        assert GitGraphView.MERGE == "◆"
        assert GitGraphView.LINE == "│"
        assert GitGraphView.BRANCH == "├"
        assert GitGraphView.JOIN == "┴"

    def test_commit_selected_message(self):
        """Test CommitSelected message."""
        from clide.widgets.components.git_graph import GitGraphView

        commit = GitCommit(
            hash="abc123def456",
            short_hash="abc",
            message="Test",
            author="A",
            date="2024-01-01",
        )
        msg = GitGraphView.CommitSelected(commit)
        assert msg.commit == commit

    def test_format_commit_line(self):
        """Test commit line formatting."""
        from clide.widgets.components.git_graph import GitGraphView

        view = GitGraphView()
        commit = GitCommit(
            hash="abc123def456789",
            short_hash="abc123",
            message="Test commit message",
            author="Author",
            date="2024-01-01",
            is_merge=False,
            refs=(),
        )
        line = view._format_commit_line(commit)
        assert "abc123" in line
        assert "Test commit message" in line
        assert "Author" in line

    def test_format_merge_commit_line(self):
        """Test merge commit line formatting."""
        from clide.widgets.components.git_graph import GitGraphView

        view = GitGraphView()
        commit = GitCommit(
            hash="abc123def456789",
            short_hash="abc123",
            message="Merge branch",
            author="Author",
            date="2024-01-01",
            is_merge=True,
            refs=("main", "HEAD"),
        )
        line = view._format_commit_line(commit)
        assert "◆" in line  # Merge symbol
        assert "main" in line
        assert "HEAD" in line


class TestBranchStatus:
    """Tests for BranchStatus component."""

    def test_initial_state(self):
        """Test initial state."""
        from clide.widgets.components.branch_status import BranchStatus

        status = BranchStatus()
        assert status._current == "main"
        assert status._branches == []
        assert status._popout_visible is False

    def test_initial_state_with_branch(self):
        """Test initial state with custom branch."""
        from clide.widgets.components.branch_status import BranchStatus

        status = BranchStatus(current_branch="develop")
        assert status._current == "develop"

    def test_branch_property(self):
        """Test branch property getter."""
        from clide.widgets.components.branch_status import BranchStatus

        status = BranchStatus(current_branch="feature")
        assert status.branch == "feature"

    def test_branch_changed_message(self):
        """Test BranchChanged message."""
        from clide.widgets.components.branch_status import BranchStatus

        msg = BranchStatus.BranchChanged("develop")
        assert msg.branch == "develop"

    def test_branch_change_requested_alias(self):
        """Test BranchChangeRequested is alias for BranchChanged."""
        from clide.widgets.components.branch_status import BranchStatus

        assert BranchStatus.BranchChangeRequested is BranchStatus.BranchChanged


class TestEditorPane:
    """Tests for EditorPane component."""

    def test_initial_state_no_buffer(self):
        """Test initial state without buffer."""
        from clide.widgets.components.editor_pane import EditorPane

        pane = EditorPane()
        assert pane._buffer is None
        assert pane.current_file is None
        assert pane.modified is False

    def test_initial_state_with_buffer(self):
        """Test initial state with buffer."""
        from clide.widgets.components.editor_pane import EditorPane

        buffer = FileBuffer(path=Path("/test.py"), content="print('hello')")
        pane = EditorPane(buffer=buffer)
        assert pane._buffer == buffer
        assert pane.current_file == Path("/test.py")

    def test_status_text_no_buffer(self):
        """Test status text with no buffer."""
        from clide.widgets.components.editor_pane import EditorPane

        pane = EditorPane()
        assert pane._get_status_text() == ""

    def test_status_text_with_buffer(self):
        """Test status text with buffer."""
        from clide.widgets.components.editor_pane import EditorPane

        buffer = FileBuffer(
            path=Path("/test.py"),
            content="print('hello')",
            language="python",
        )
        pane = EditorPane(buffer=buffer)
        status = pane._get_status_text()
        assert "Ln" in status
        assert "Col" in status
        assert "python" in status

    def test_content_changed_message(self):
        """Test ContentChanged message."""
        from clide.widgets.components.editor_pane import EditorPane

        msg = EditorPane.ContentChanged(Path("/test.py"), "new content")
        assert msg.path == Path("/test.py")
        assert msg.content == "new content"

    def test_cursor_moved_message(self):
        """Test CursorMoved message."""
        from clide.widgets.components.editor_pane import EditorPane

        msg = EditorPane.CursorMoved(Path("/test.py"), 10, 5)
        assert msg.path == Path("/test.py")
        assert msg.line == 10
        assert msg.column == 5

    def test_save_requested_message(self):
        """Test SaveRequested message."""
        from clide.widgets.components.editor_pane import EditorPane

        msg = EditorPane.SaveRequested(Path("/test.py"))
        assert msg.path == Path("/test.py")

    def test_file_saved_message(self):
        """Test FileSaved message."""
        from clide.widgets.components.editor_pane import EditorPane

        msg = EditorPane.FileSaved(Path("/test.py"))
        assert msg.path == Path("/test.py")

    def test_modified_property(self):
        """Test modified property."""
        from clide.widgets.components.editor_pane import EditorPane

        buffer = FileBuffer(path=Path("/test.py"), content="", is_modified=True)
        pane = EditorPane(buffer=buffer)
        assert pane.modified is True

        buffer2 = FileBuffer(path=Path("/test2.py"), content="", is_modified=False)
        pane2 = EditorPane(buffer=buffer2)
        assert pane2.modified is False


class TestDiffPane:
    """Tests for DiffPane component."""

    def test_initial_state_no_diff(self):
        """Test initial state without diff."""
        from clide.widgets.components.diff_pane import DiffPane

        pane = DiffPane()
        assert pane._diff is None
        assert pane._is_proposal is False

    def test_initial_state_with_diff(self):
        """Test initial state with diff."""
        from clide.widgets.components.diff_pane import DiffPane

        diff = DiffContent(file_path="test.py", hunks=())
        pane = DiffPane(diff=diff, is_proposal=True)
        assert pane._diff == diff
        assert pane._is_proposal is True

    def test_accept_clicked_message(self):
        """Test AcceptClicked message."""
        from clide.widgets.components.diff_pane import DiffPane

        msg = DiffPane.AcceptClicked("test.py")
        assert msg.file_path == "test.py"

    def test_reject_clicked_message(self):
        """Test RejectClicked message."""
        from clide.widgets.components.diff_pane import DiffPane

        msg = DiffPane.RejectClicked("test.py")
        assert msg.file_path == "test.py"


class TestTerminalPane:
    """Tests for TerminalPane component."""

    def test_initial_state(self, tmp_path: Path):
        """Test initial state."""
        from clide.widgets.components.terminal_pane import TerminalPane

        pane = TerminalPane(cwd=tmp_path)
        assert pane.cwd == tmp_path
        assert pane._history == []
        assert pane._history_index == 0

    def test_default_cwd(self):
        """Test default cwd is current directory."""
        from clide.widgets.components.terminal_pane import TerminalPane

        pane = TerminalPane()
        assert pane.cwd == Path.cwd()

    def test_cwd_property(self, tmp_path: Path):
        """Test cwd property."""
        from clide.widgets.components.terminal_pane import TerminalPane

        pane = TerminalPane()
        pane._cwd = tmp_path
        assert pane.cwd == tmp_path

    def test_command_submitted_message(self):
        """Test CommandSubmitted message."""
        from clide.widgets.components.terminal_pane import TerminalPane

        msg = TerminalPane.CommandSubmitted("ls -la")
        assert msg.command == "ls -la"


class TestProblemsView:
    """Tests for ProblemsView component."""

    def test_initial_state_no_problems(self):
        """Test initial state without problems."""
        from clide.widgets.components.problems_view import ProblemsView

        view = ProblemsView()
        assert view._problems == []

    def test_initial_state_with_problems(self):
        """Test initial state with problems."""
        from clide.widgets.components.problems_view import ProblemsView

        problems = [
            Problem(
                file_path=Path("/test.py"),
                line=10,
                column=5,
                severity=Severity.ERROR,
                message="Error",
                source="ruff",
            )
        ]
        view = ProblemsView(problems=problems)
        assert len(view._problems) == 1

    def test_filter_by_file(self):
        """Test filtering problems by file."""
        from clide.widgets.components.problems_view import ProblemsView

        problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="Error 1",
                source="ruff",
            ),
            Problem(
                file_path=Path("/b.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="Error 2",
                source="ruff",
            ),
            Problem(
                file_path=Path("/a.py"),
                line=5,
                column=1,
                severity=Severity.WARNING,
                message="Warning 1",
                source="ruff",
            ),
        ]
        view = ProblemsView(problems=problems)
        filtered = view.filter_by_file(Path("/a.py"))
        assert len(filtered) == 2

    def test_problem_clicked_message(self):
        """Test ProblemClicked message."""
        from clide.widgets.components.problems_view import ProblemsView

        problem = Problem(
            file_path=Path("/test.py"),
            line=10,
            column=5,
            severity=Severity.ERROR,
            message="Test error",
            source="ruff",
        )
        msg = ProblemsView.ProblemClicked(problem)
        assert msg.problem == problem


class TestProblemItem:
    """Tests for ProblemItem component."""

    def test_create_item(self):
        """Test creating a ProblemItem."""
        from clide.widgets.components.problems_view import ProblemItem

        problem = Problem(
            file_path=Path("/test.py"),
            line=10,
            column=5,
            severity=Severity.ERROR,
            message="Test error",
            source="ruff",
        )
        item = ProblemItem(problem)
        assert item.problem == problem


class TestTodosView:
    """Tests for TodosView component."""

    def test_initial_state_no_items(self):
        """Test initial state without items."""
        from clide.widgets.components.todos_view import TodosView

        view = TodosView()
        assert view._items == []

    def test_initial_state_with_items(self):
        """Test initial state with items."""
        from clide.widgets.components.todos_view import TodosView

        items = [
            TodoItem(
                file_path=Path("/test.py"),
                line=10,
                column=1,
                todo_type=TodoType.TODO,
                text="Fix this",
                context_line="# TODO: Fix this",
            )
        ]
        view = TodosView(items=items)
        assert len(view._items) == 1

    def test_filter_by_type(self):
        """Test filtering items by type."""
        from clide.widgets.components.todos_view import TodosView

        items = [
            TodoItem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                todo_type=TodoType.TODO,
                text="TODO 1",
                context_line="# TODO: TODO 1",
            ),
            TodoItem(
                file_path=Path("/b.py"),
                line=1,
                column=1,
                todo_type=TodoType.FIXME,
                text="FIXME 1",
                context_line="# FIXME: FIXME 1",
            ),
            TodoItem(
                file_path=Path("/a.py"),
                line=5,
                column=1,
                todo_type=TodoType.TODO,
                text="TODO 2",
                context_line="# TODO: TODO 2",
            ),
        ]
        view = TodosView(items=items)
        todos = view.filter_by_type(TodoType.TODO)
        assert len(todos) == 2
        fixmes = view.filter_by_type(TodoType.FIXME)
        assert len(fixmes) == 1

    def test_todo_clicked_message(self):
        """Test TodoClicked message."""
        from clide.widgets.components.todos_view import TodosView

        item = TodoItem(
            file_path=Path("/test.py"),
            line=10,
            column=1,
            todo_type=TodoType.TODO,
            text="Test todo",
            context_line="# TODO: Test todo",
        )
        msg = TodosView.TodoClicked(item)
        assert msg.item == item


class TestTodoListItem:
    """Tests for TodoListItem component."""

    def test_create_item(self):
        """Test creating a TodoListItem."""
        from clide.widgets.components.todos_view import TodoListItem

        item = TodoItem(
            file_path=Path("/test.py"),
            line=10,
            column=1,
            todo_type=TodoType.FIXME,
            text="Fix this bug",
            context_line="# FIXME: Fix this bug",
        )
        list_item = TodoListItem(item)
        assert list_item.item == item


class TestJiraView:
    """Tests for JiraView component."""

    def test_initial_state_enabled(self):
        """Test initial state when enabled."""
        from clide.widgets.components.jira_view import JiraView

        view = JiraView(enabled=True)
        assert view._enabled is True
        assert view._content == ""

    def test_initial_state_disabled(self):
        """Test initial state when disabled."""
        from clide.widgets.components.jira_view import JiraView

        view = JiraView(enabled=False)
        assert view._enabled is False

    def test_initial_state_with_content(self):
        """Test initial state with content."""
        from clide.widgets.components.jira_view import JiraView

        view = JiraView(content="# Issues\n- PROJ-123")
        assert view._content == "# Issues\n- PROJ-123"

    def test_refresh_requested_message(self):
        """Test RefreshRequested message."""
        from clide.widgets.components.jira_view import JiraView

        msg = JiraView.RefreshRequested()
        assert msg is not None

    def test_issue_clicked_message(self):
        """Test IssueClicked message."""
        from clide.widgets.components.jira_view import JiraView

        msg = JiraView.IssueClicked("PROJ-123")
        assert msg.issue_key == "PROJ-123"
