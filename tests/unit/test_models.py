"""Tests for Pydantic models."""

from pathlib import Path

import pytest
from pydantic import ValidationError

from clide.models.config import ClideSettings, KeybindingsConfig, PanelConfig
from clide.models.diff import ChangeType, DiffContent, DiffHunk, DiffLine, DiffViewState
from clide.models.editor import CursorPosition, EditorState, FileBuffer, Selection
from clide.models.git import ChangeStatus, GitBranch, GitChange, GitCommit, GitGraph, GitStatus
from clide.models.problems import Problem, ProblemsSummary, ProblemsState, Severity
from clide.models.theme import ThemeColors, ThemeDefinition, ThemeMetadata
from clide.models.todos import TodoItem, TodosSummary, TodosState, TodoType


class TestCursorPosition:
    """Tests for CursorPosition model."""

    def test_create_cursor(self):
        cursor = CursorPosition(line=10, column=5)
        assert cursor.line == 10
        assert cursor.column == 5

    def test_cursor_is_frozen(self):
        cursor = CursorPosition(line=0, column=0)
        with pytest.raises(ValidationError):
            cursor.line = 1


class TestFileBuffer:
    """Tests for FileBuffer model."""

    def test_create_buffer(self):
        buffer = FileBuffer(
            path=Path("/test/file.py"),
            content="print('hello')",
            language="python",
        )
        assert buffer.path == Path("/test/file.py")
        assert buffer.content == "print('hello')"
        assert buffer.language == "python"
        assert buffer.is_modified is False

    def test_buffer_display_name(self):
        buffer = FileBuffer(path=Path("/test/file.py"), content="")
        assert buffer.display_name == "file.py"

    def test_buffer_modified_display_name(self):
        buffer = FileBuffer(path=Path("/test/file.py"), content="", is_modified=True)
        assert buffer.display_name == "● file.py"

    def test_buffer_filename(self):
        buffer = FileBuffer(path=Path("/some/deep/path/script.js"), content="")
        assert buffer.filename == "script.js"


class TestEditorState:
    """Tests for EditorState model."""

    def test_empty_state(self):
        state = EditorState()
        assert state.buffers == []
        assert state.active_buffer_index is None
        assert state.active_buffer is None

    def test_active_buffer(self):
        buffer1 = FileBuffer(path=Path("/a.py"), content="a")
        buffer2 = FileBuffer(path=Path("/b.py"), content="b")
        state = EditorState(buffers=[buffer1, buffer2], active_buffer_index=1)
        assert state.active_buffer == buffer2

    def test_get_buffer_by_path(self):
        buffer = FileBuffer(path=Path("/test.py"), content="test")
        state = EditorState(buffers=[buffer])
        assert state.get_buffer_by_path(Path("/test.py")) == buffer
        assert state.get_buffer_by_path(Path("/other.py")) is None


class TestGitChange:
    """Tests for GitChange model."""

    def test_create_change(self):
        from clide.models.git import ChangeStatus
        change = GitChange(path="src/main.py", status=ChangeStatus.MODIFIED, staged=True)
        assert change.path == "src/main.py"
        assert change.status == ChangeStatus.MODIFIED
        assert change.staged is True

    def test_change_is_frozen(self):
        from clide.models.git import ChangeStatus
        change = GitChange(path="f", status=ChangeStatus.ADDED, staged=False)
        with pytest.raises(ValidationError):
            change.path = "new.py"


class TestGitStatus:
    """Tests for GitStatus model."""

    def test_create_status(self):
        staged = (GitChange(path="a.py", status=ChangeStatus.ADDED, staged=True),)
        unstaged = (GitChange(path="b.py", status=ChangeStatus.MODIFIED, staged=False),)
        status = GitStatus(branch="main", staged=staged, unstaged=unstaged)
        assert status.branch == "main"
        assert len(status.staged) == 1
        assert len(status.unstaged) == 1

    def test_empty_status(self):
        status = GitStatus(branch="main", staged=(), unstaged=())
        assert status.branch == "main"
        assert len(status.staged) == 0
        assert len(status.unstaged) == 0


class TestGitBranch:
    """Tests for GitBranch model."""

    def test_create_branch(self):
        branch = GitBranch(name="feature/test", is_current=True, is_remote=False)
        assert branch.name == "feature/test"
        assert branch.is_current is True
        assert branch.is_remote is False


class TestGitCommit:
    """Tests for GitCommit model."""

    def test_create_commit(self):
        commit = GitCommit(
            hash="abc123def456789",
            short_hash="abc123",
            message="Test commit",
            author="Test Author",
            date="2024-01-01",
        )
        assert commit.hash == "abc123def456789"
        assert commit.short_hash == "abc123"
        assert commit.message == "Test commit"


class TestDiffLine:
    """Tests for DiffLine model."""

    def test_added_line(self):
        line = DiffLine(change_type=ChangeType.ADDED, content="new line", new_line_num=10)
        assert line.change_type == ChangeType.ADDED
        assert line.content == "new line"

    def test_removed_line(self):
        line = DiffLine(change_type=ChangeType.REMOVED, content="old line", old_line_num=5)
        assert line.change_type == ChangeType.REMOVED

    def test_context_line(self):
        line = DiffLine(
            change_type=ChangeType.CONTEXT,
            content="unchanged",
            old_line_num=5,
            new_line_num=5,
        )
        assert line.change_type == ChangeType.CONTEXT


class TestDiffHunk:
    """Tests for DiffHunk model."""

    def test_create_hunk(self):
        lines = (
            DiffLine(change_type=ChangeType.REMOVED, content="old", old_line_num=1),
            DiffLine(change_type=ChangeType.ADDED, content="new", new_line_num=1),
        )
        hunk = DiffHunk(
            header="@@ -1,1 +1,1 @@",
            old_start=1,
            old_count=1,
            new_start=1,
            new_count=1,
            lines=lines,
        )
        assert len(hunk.lines) == 2


class TestDiffContent:
    """Tests for DiffContent model."""

    def test_create_diff(self):
        hunk = DiffHunk(
            header="@@ -1 +1 @@",
            old_start=1,
            old_count=1,
            new_start=1,
            new_count=1,
            lines=(),
        )
        diff = DiffContent(file_path="test.py", hunks=(hunk,))
        assert diff.file_path == "test.py"
        assert len(diff.hunks) == 1


class TestProblem:
    """Tests for Problem model."""

    def test_create_problem(self):
        problem = Problem(
            file_path=Path("/test.py"),
            line=10,
            column=5,
            severity=Severity.ERROR,
            message="Syntax error",
            source="ruff",
            code="E999",
        )
        assert problem.line == 10
        assert problem.severity == Severity.ERROR

    def test_severity_icon(self):
        error = Problem(
            file_path=Path("/t.py"),
            line=1,
            column=1,
            severity=Severity.ERROR,
            message="err",
            source="test",
        )
        assert error.severity_icon == "✖"

        warning = Problem(
            file_path=Path("/t.py"),
            line=1,
            column=1,
            severity=Severity.WARNING,
            message="warn",
            source="test",
        )
        assert warning.severity_icon == "⚠"


class TestProblemsSummary:
    """Tests for ProblemsSummary model."""

    def test_create_summary(self):
        summary = ProblemsSummary(errors=5, warnings=3, infos=1, hints=0)
        assert summary.total == 9


class TestTodoItem:
    """Tests for TodoItem model."""

    def test_create_todo(self):
        todo = TodoItem(
            file_path=Path("/src/main.py"),
            line=42,
            column=5,
            todo_type=TodoType.TODO,
            text="Implement this feature",
            context_line="# TODO: Implement this feature",
        )
        assert todo.line == 42
        assert todo.todo_type == TodoType.TODO

    def test_type_icon(self):
        todo = TodoItem(
            file_path=Path("/t.py"),
            line=1,
            column=1,
            todo_type=TodoType.TODO,
            text="todo",
            context_line="# TODO: todo",
        )
        assert todo.type_icon == "☐"

        fixme = TodoItem(
            file_path=Path("/t.py"),
            line=1,
            column=1,
            todo_type=TodoType.FIXME,
            text="fixme",
            context_line="# FIXME: fixme",
        )
        assert fixme.type_icon == "🔧"


class TestTodosSummary:
    """Tests for TodosSummary model."""

    def test_create_summary(self):
        summary = TodosSummary(
            todo_count=5,
            fixme_count=3,
            hack_count=2,
            other_count=0,
        )
        assert summary.total == 10
        assert summary.todo_count == 5


class TestThemeColors:
    """Tests for ThemeColors model."""

    def test_valid_colors(self):
        colors = ThemeColors(
            primary="#00a3d2",
            secondary="#00a9b9",
            accent="#fa5f8b",
            background="#21262f",
            surface="#393e48",
            panel="#292e38",
            foreground="#e2e8f5",
            success="#00ab9a",
            warning="#d08447",
            error="#f06c6f",
        )
        assert colors.primary == "#00a3d2"

    def test_invalid_color_rejected(self):
        with pytest.raises(ValidationError):
            ThemeColors(
                primary="invalid",
                secondary="#00a9b9",
                accent="#fa5f8b",
                background="#21262f",
                surface="#393e48",
                panel="#292e38",
                foreground="#e2e8f5",
                success="#00ab9a",
                warning="#d08447",
                error="#f06c6f",
            )

    def test_color_normalized_to_lowercase(self):
        colors = ThemeColors(
            primary="#00A3D2",
            secondary="#00A9B9",
            accent="#FA5F8B",
            background="#21262F",
            surface="#393E48",
            panel="#292E38",
            foreground="#E2E8F5",
            success="#00AB9A",
            warning="#D08447",
            error="#F06C6F",
        )
        assert colors.primary == "#00a3d2"


class TestThemeDefinition:
    """Tests for ThemeDefinition model."""

    def test_create_theme(self):
        colors = ThemeColors(
            primary="#00a3d2",
            secondary="#00a9b9",
            accent="#fa5f8b",
            background="#21262f",
            surface="#393e48",
            panel="#292e38",
            foreground="#e2e8f5",
            success="#00ab9a",
            warning="#d08447",
            error="#f06c6f",
        )
        theme = ThemeDefinition(
            name="test-theme",
            display_name="Test Theme",
            dark=True,
            colors=colors,
        )
        assert theme.name == "test-theme"
        assert theme.dark is True

    def test_to_textual_theme(self):
        colors = ThemeColors(
            primary="#00a3d2",
            secondary="#00a9b9",
            accent="#fa5f8b",
            background="#21262f",
            surface="#393e48",
            panel="#292e38",
            foreground="#e2e8f5",
            success="#00ab9a",
            warning="#d08447",
            error="#f06c6f",
        )
        theme_def = ThemeDefinition(
            name="test",
            display_name="Test",
            dark=True,
            colors=colors,
        )
        textual_theme = theme_def.to_textual_theme()
        assert textual_theme.name == "test"


class TestThemeMetadata:
    """Tests for ThemeMetadata model."""

    def test_create_metadata(self):
        meta = ThemeMetadata(
            name="summer-night",
            display_name="Summer Night",
            dark=True,
            category="core",
        )
        assert meta.name == "summer-night"
        assert meta.category == "core"


class TestClideSettings:
    """Tests for ClideSettings model."""

    def test_default_settings(self):
        settings = ClideSettings()
        assert settings.theme == "summer-night"
        assert settings.jira_enabled is False

    def test_custom_settings(self):
        settings = ClideSettings(theme="dracula", jira_enabled=True)
        assert settings.theme == "dracula"
        assert settings.jira_enabled is True


class TestPanelConfig:
    """Tests for PanelConfig model."""

    def test_default_panel_config(self):
        config = PanelConfig()
        assert config.sidebar_visible is True
        assert config.context_visible is True
        assert config.workspace_visible is False


class TestKeybindingsConfig:
    """Tests for KeybindingsConfig model."""

    def test_default_keybindings(self):
        config = KeybindingsConfig()
        assert config.toggle_sidebar == "ctrl+b"
        assert config.toggle_terminal == "ctrl+`"
