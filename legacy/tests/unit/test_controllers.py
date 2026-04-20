"""Tests for controller classes."""

from pathlib import Path
from unittest.mock import patch

import pytest

from clide.controllers.diff import DiffController
from clide.controllers.editor import EditorController
from clide.controllers.git import GitController
from clide.controllers.jira import JiraController
from clide.controllers.problems import ProblemsController
from clide.controllers.todos import TodosController
from clide.models.diff import DiffContent, DiffHunk
from clide.models.editor import FileBuffer
from clide.models.git import ChangeStatus, GitBranch, GitChange, GitCommit, GitStatus
from clide.models.problems import Problem, Severity
from clide.models.todos import TodoItem, TodoType


class TestGitController:
    """Tests for GitController."""

    @pytest.fixture
    def controller(self, tmp_path: Path) -> GitController:
        return GitController(tmp_path)

    @pytest.mark.asyncio
    async def test_get_status(self, controller: GitController):
        mock_status = GitStatus(
            branch="main",
            staged=(GitChange(path="a.py", status=ChangeStatus.ADDED, staged=True),),
            unstaged=(),
        )
        with patch.object(controller._service, "get_status", return_value=mock_status):
            status = await controller.get_status()
            assert status.branch == "main"
            assert len(status.staged) == 1

    @pytest.mark.asyncio
    async def test_get_branches(self, controller: GitController):
        mock_branches = [
            GitBranch(name="main", is_current=True, is_remote=False),
            GitBranch(name="develop", is_current=False, is_remote=False),
        ]
        with patch.object(controller._service, "get_branches", return_value=mock_branches):
            branches = await controller.get_branches()
            assert len(branches) == 2
            assert branches[0].is_current is True

    @pytest.mark.asyncio
    async def test_get_log(self, controller: GitController):
        mock_commits = [
            GitCommit(
                hash="abc123def456",
                short_hash="abc123",
                message="Initial commit",
                author="Test",
                date="2024-01-01",
            )
        ]
        with patch.object(controller._service, "get_log", return_value=mock_commits):
            commits = await controller.get_log(limit=10)
            assert len(commits) == 1
            assert commits[0].message == "Initial commit"

    @pytest.mark.asyncio
    async def test_stage_file(self, controller: GitController):
        mock_status = GitStatus(branch="main", staged=(), unstaged=())
        with patch.object(controller._service, "stage_file", return_value=True):
            with patch.object(controller._service, "get_status", return_value=mock_status):
                result = await controller.stage_file("test.py")
                assert result is True

    @pytest.mark.asyncio
    async def test_unstage_file(self, controller: GitController):
        mock_status = GitStatus(branch="main", staged=(), unstaged=())
        with patch.object(controller._service, "unstage_file", return_value=True):
            with patch.object(controller._service, "get_status", return_value=mock_status):
                result = await controller.unstage_file("test.py")
                assert result is True

    @pytest.mark.asyncio
    async def test_checkout_branch(self, controller: GitController):
        mock_status = GitStatus(branch="develop", staged=(), unstaged=())
        with patch.object(controller._service, "checkout_branch", return_value=True):
            with patch.object(controller._service, "get_status", return_value=mock_status):
                with patch.object(controller._service, "get_branches", return_value=[]):
                    result = await controller.checkout_branch("develop")
                    assert result is True

    @pytest.mark.asyncio
    async def test_current_branch_property(self, controller: GitController):
        mock_status = GitStatus(branch="feature", staged=(), unstaged=())
        with patch.object(controller._service, "get_status", return_value=mock_status):
            await controller.get_status()  # Populate _status
            assert controller.current_branch == "feature"

    def test_current_branch_unknown(self, controller: GitController):
        assert controller.current_branch == "unknown"


class TestEditorController:
    """Tests for EditorController."""

    @pytest.fixture
    def controller(self) -> EditorController:
        return EditorController()

    def test_initial_state(self, controller: EditorController):
        assert controller.active_buffer is None
        assert controller.open_files == []
        assert controller.has_unsaved_changes is False

    def test_update_content(self, controller: EditorController):
        buffer = FileBuffer(path=Path("/test.py"), content="original")
        controller._state.buffers.append(buffer)

        controller.update_content(Path("/test.py"), "modified")
        assert buffer.content == "modified"
        assert buffer.is_modified is True

    def test_update_cursor(self, controller: EditorController):
        buffer = FileBuffer(path=Path("/test.py"), content="test")
        controller._state.buffers.append(buffer)

        controller.update_cursor(Path("/test.py"), 5, 10)
        assert buffer.cursor.line == 5
        assert buffer.cursor.column == 10

    def test_set_active_by_index(self, controller: EditorController):
        buffer1 = FileBuffer(path=Path("/a.py"), content="a")
        buffer2 = FileBuffer(path=Path("/b.py"), content="b")
        controller._state.buffers = [buffer1, buffer2]

        controller.set_active_by_index(1)
        assert controller._state.active_buffer_index == 1

    def test_set_active_invalid_index(self, controller: EditorController):
        controller.set_active_by_index(10)  # Should not crash
        assert controller._state.active_buffer_index is None


class TestDiffController:
    """Tests for DiffController."""

    @pytest.fixture
    def controller(self, tmp_path: Path) -> DiffController:
        return DiffController(tmp_path)

    def test_initial_state(self, controller: DiffController):
        assert controller.diff is None
        assert controller.is_proposal is False

    def test_load_proposal(self, controller: DiffController):
        old_content = "line1\nline2\n"
        new_content = "line1\nmodified\n"

        diff = controller.load_proposal("test.py", old_content, new_content)
        assert diff.file_path == "test.py"
        assert controller.is_proposal is True

    def test_accept_hunk(self, controller: DiffController):
        controller._state.diff = DiffContent(file_path="t.py", hunks=())
        controller.accept_hunk(0)
        assert 0 in controller._state.accepted_hunks
        assert 0 not in controller._state.rejected_hunks

    def test_reject_hunk(self, controller: DiffController):
        controller._state.diff = DiffContent(file_path="t.py", hunks=())
        controller.reject_hunk(0)
        assert 0 in controller._state.rejected_hunks
        assert 0 not in controller._state.accepted_hunks

    def test_accept_all(self, controller: DiffController):
        hunk = DiffHunk(
            header="@@",
            old_start=1,
            old_count=1,
            new_start=1,
            new_count=1,
            lines=(),
        )
        controller._state.diff = DiffContent(file_path="t.py", hunks=(hunk, hunk))
        controller.accept_all()
        assert len(controller._state.accepted_hunks) == 2

    def test_reject_all(self, controller: DiffController):
        hunk = DiffHunk(
            header="@@",
            old_start=1,
            old_count=1,
            new_start=1,
            new_count=1,
            lines=(),
        )
        controller._state.diff = DiffContent(file_path="t.py", hunks=(hunk,))
        controller.reject_all()
        assert len(controller._state.rejected_hunks) == 1

    def test_clear(self, controller: DiffController):
        controller._state.diff = DiffContent(file_path="t.py", hunks=())
        controller._state.is_proposal = True
        controller.clear()
        assert controller.diff is None
        assert controller.is_proposal is False

    def test_toggle_side_by_side(self, controller: DiffController):
        assert controller._state.side_by_side is True  # Default is True
        result = controller.toggle_side_by_side()
        assert result is False  # Toggled to False
        assert controller._state.side_by_side is False


class TestProblemsController:
    """Tests for ProblemsController."""

    @pytest.fixture
    def controller(self, tmp_path: Path) -> ProblemsController:
        return ProblemsController(tmp_path)

    def test_initial_state(self, controller: ProblemsController):
        assert controller.problems == []
        assert controller.error_count == 0
        assert controller.warning_count == 0

    def test_filter_by_severity(self, controller: ProblemsController):
        problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="err",
                source="test",
            ),
            Problem(
                file_path=Path("/b.py"),
                line=1,
                column=1,
                severity=Severity.WARNING,
                message="warn",
                source="test",
            ),
        ]
        controller._state.problems = problems

        errors = controller.filter_by_severity(Severity.ERROR)
        assert len(errors) == 1
        assert errors[0].severity == Severity.ERROR

    def test_filter_by_source(self, controller: ProblemsController):
        problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="err",
                source="ruff",
            ),
            Problem(
                file_path=Path("/b.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="err",
                source="mypy",
            ),
        ]
        controller._state.problems = problems

        ruff_problems = controller.filter_by_source("ruff")
        assert len(ruff_problems) == 1

    def test_next_problem(self, controller: ProblemsController):
        problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="1",
                source="test",
            ),
            Problem(
                file_path=Path("/b.py"),
                line=2,
                column=1,
                severity=Severity.ERROR,
                message="2",
                source="test",
            ),
        ]
        controller._state.problems = problems

        p1 = controller.next_problem()
        assert p1.message == "1"
        p2 = controller.next_problem()
        assert p2.message == "2"
        # Should wrap around
        p3 = controller.next_problem()
        assert p3.message == "1"

    def test_prev_problem(self, controller: ProblemsController):
        problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="1",
                source="test",
            ),
            Problem(
                file_path=Path("/b.py"),
                line=2,
                column=1,
                severity=Severity.ERROR,
                message="2",
                source="test",
            ),
        ]
        controller._state.problems = problems

        p = controller.prev_problem()
        assert p.message == "2"

    def test_clear(self, controller: ProblemsController):
        controller._state.problems = [
            Problem(
                file_path=Path("/a.py"),
                line=1,
                column=1,
                severity=Severity.ERROR,
                message="err",
                source="test",
            )
        ]
        controller.clear()
        assert controller.problems == []


class TestTodosController:
    """Tests for TodosController."""

    @pytest.fixture
    def controller(self, tmp_path: Path) -> TodosController:
        return TodosController(tmp_path)

    def test_initial_state(self, controller: TodosController):
        assert controller.items == []
        assert controller.total_count == 0

    def test_filter_by_type(self, controller: TodosController):
        items = [
            TodoItem(file_path=Path("/a.py"), line=1, column=1, todo_type=TodoType.TODO, text="1", context_line="# TODO: 1"),
            TodoItem(file_path=Path("/b.py"), line=2, column=1, todo_type=TodoType.FIXME, text="2", context_line="# FIXME: 2"),
        ]
        controller._state.items = items

        todos = controller.filter_by_type(TodoType.TODO)
        assert len(todos) == 1
        assert todos[0].todo_type == TodoType.TODO

    def test_get_grouped_items(self, controller: TodosController):
        items = [
            TodoItem(file_path=Path("/a.py"), line=1, column=1, todo_type=TodoType.TODO, text="1", context_line="# TODO: 1"),
            TodoItem(file_path=Path("/a.py"), line=5, column=1, todo_type=TodoType.FIXME, text="2", context_line="# FIXME: 2"),
            TodoItem(file_path=Path("/b.py"), line=1, column=1, todo_type=TodoType.TODO, text="3", context_line="# TODO: 3"),
        ]
        controller._state.items = items

        grouped = controller.get_grouped_items()
        assert len(grouped) == 2
        assert len(grouped[Path("/a.py")]) == 2
        assert len(grouped[Path("/b.py")]) == 1

    def test_toggle_group_by_file(self, controller: TodosController):
        assert controller._state.group_by_file is True  # Default is True per TodosState model
        result = controller.toggle_group_by_file()
        assert result is False
        assert controller._state.group_by_file is False


class TestJiraController:
    """Tests for JiraController."""

    @pytest.fixture
    def controller(self) -> JiraController:
        return JiraController(enabled=True)

    @pytest.fixture
    def disabled_controller(self) -> JiraController:
        return JiraController(enabled=False)

    def test_initial_enabled_state(self, controller: JiraController):
        assert controller.enabled is True

    def test_initial_disabled_state(self, disabled_controller: JiraController):
        assert disabled_controller.enabled is False

    def test_enable_disable(self, disabled_controller: JiraController):
        disabled_controller.enable()
        assert disabled_controller.enabled is True
        disabled_controller.disable()
        assert disabled_controller.enabled is False

    @pytest.mark.asyncio
    async def test_run_command_when_disabled(self, disabled_controller: JiraController):
        result = await disabled_controller.run_command("issue", "list")
        assert "disabled" in result.lower()

    @pytest.mark.asyncio
    async def test_get_content_when_disabled(self, disabled_controller: JiraController):
        result = await disabled_controller.get_content()
        assert result is None
