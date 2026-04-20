"""Tests for service classes."""

from pathlib import Path
from unittest.mock import patch

import pytest

from clide.models.todos import TodoType
from clide.services.file_service import FileService
from clide.services.git_service import GitService
from clide.services.linter_service import LinterService
from clide.services.process_service import CommandResult, ProcessService
from clide.services.todo_scanner import TodoScanner


class TestProcessService:
    """Tests for ProcessService."""

    @pytest.fixture
    def service(self, tmp_path: Path) -> ProcessService:
        return ProcessService(cwd=tmp_path)

    def test_run_sync_success(self, service: ProcessService):
        result = service.run_sync("echo", "hello")
        assert result.success is True
        assert "hello" in result.stdout

    def test_run_sync_failure(self, service: ProcessService):
        result = service.run_sync("false")  # Unix command that always fails
        assert result.success is False

    @pytest.mark.asyncio
    async def test_run_async_success(self, service: ProcessService):
        result = await service.run("echo", "world")
        assert result.success is True
        assert "world" in result.stdout

    @pytest.mark.asyncio
    async def test_run_async_with_timeout(self, service: ProcessService):
        # This should complete quickly
        result = await service.run("echo", "fast", timeout=5.0)
        assert result.success is True

    def test_command_result(self):
        result = CommandResult(
            returncode=0,
            stdout="output",
            stderr="",
        )
        assert result.success is True
        assert result.stdout == "output"

    def test_command_result_failure(self):
        result = CommandResult(
            returncode=1,
            stdout="",
            stderr="error",
        )
        assert result.success is False


class TestFileService:
    """Tests for FileService."""

    @pytest.mark.asyncio
    async def test_read_file(self, tmp_path: Path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("Hello, World!")

        service = FileService(tmp_path)
        content = await service.read_file_async(test_file)
        assert content == "Hello, World!"

    @pytest.mark.asyncio
    async def test_read_file_not_found(self, tmp_path: Path):
        service = FileService(tmp_path)
        with pytest.raises(FileNotFoundError):
            await service.read_file_async(tmp_path / "nonexistent.txt")

    @pytest.mark.asyncio
    async def test_write_file(self, tmp_path: Path):
        test_file = tmp_path / "output.txt"
        service = FileService(tmp_path)
        await service.write_file_async(test_file, "Test content")
        assert test_file.read_text() == "Test content"

    @pytest.mark.asyncio
    async def test_get_language_python(self, tmp_path: Path):
        service = FileService(tmp_path)
        assert await service.get_language(Path("test.py")) == "python"

    @pytest.mark.asyncio
    async def test_get_language_javascript(self, tmp_path: Path):
        service = FileService(tmp_path)
        assert await service.get_language(Path("app.js")) == "javascript"

    @pytest.mark.asyncio
    async def test_get_language_typescript(self, tmp_path: Path):
        service = FileService(tmp_path)
        assert await service.get_language(Path("component.tsx")) == "typescript"

    @pytest.mark.asyncio
    async def test_get_language_unknown(self, tmp_path: Path):
        service = FileService(tmp_path)
        assert await service.get_language(Path("file.xyz")) is None

    @pytest.mark.asyncio
    async def test_get_language_markdown(self, tmp_path: Path):
        service = FileService(tmp_path)
        assert await service.get_language(Path("README.md")) == "markdown"


class TestGitService:
    """Tests for GitService."""

    @pytest.fixture
    def git_repo(self, tmp_path: Path) -> Path:
        """Create a minimal git repo for testing."""
        git_dir = tmp_path / ".git"
        git_dir.mkdir()
        (git_dir / "HEAD").write_text("ref: refs/heads/main")
        (git_dir / "config").write_text("")
        return tmp_path

    @pytest.fixture
    def service(self, git_repo: Path) -> GitService:
        return GitService(git_repo)

    @pytest.mark.asyncio
    async def test_get_status(self, service: GitService):
        with patch.object(service._process, "run") as mock_run:

            async def mock_status(*args, **_kwargs):
                if "status" in args:
                    return CommandResult(returncode=0, stdout="", stderr="")
                elif "branch" in args:
                    return CommandResult(returncode=0, stdout="main\n", stderr="")
                return CommandResult(returncode=0, stdout="0\t0", stderr="")

            mock_run.side_effect = mock_status
            status = await service.get_status()
            assert status is not None
            assert status.branch == "main"

    @pytest.mark.asyncio
    async def test_get_branches(self, service: GitService):
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=0,
                stdout="*main|origin/main|abc1234|Test\n feature|origin/feature|def5678|Test2\n",
                stderr="",
            )
            branches = await service.get_branches()
            assert len(branches) == 2
            assert branches[0].name == "main"
            assert branches[0].is_current is True

    @pytest.mark.asyncio
    async def test_get_log(self, service: GitService):
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=0,
                stdout="abc1234567890|abc1234|Test commit|Author|2024-01-01||HEAD -> main\n",
                stderr="",
            )
            commits = await service.get_log(max_count=10)
            assert len(commits) == 1
            assert commits[0].message == "Test commit"

    @pytest.mark.asyncio
    async def test_stage_file(self, service: GitService):
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=0,
                stdout="",
                stderr="",
            )
            result = await service.stage_file("test.py")
            assert result is True

    @pytest.mark.asyncio
    async def test_unstage_file(self, service: GitService):
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=0,
                stdout="",
                stderr="",
            )
            result = await service.unstage_file("test.py")
            assert result is True


class TestLinterService:
    """Tests for LinterService."""

    @pytest.fixture
    def service(self, tmp_path: Path) -> LinterService:
        return LinterService(tmp_path)

    @pytest.mark.asyncio
    async def test_run_ruff_no_issues(self, service: LinterService):
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=0,
                stdout="[]",
                stderr="",
            )
            problems = await service.run_ruff()
            assert problems == []

    @pytest.mark.asyncio
    async def test_run_ruff_with_issues(self, service: LinterService):
        ruff_output = """[
            {
                "filename": "/test/file.py",
                "location": {"row": 10, "column": 5},
                "code": "E501",
                "message": "Line too long"
            }
        ]"""
        with patch.object(service._process, "run") as mock_run:
            mock_run.return_value = CommandResult(
                returncode=1,
                stdout=ruff_output,
                stderr="",
            )
            problems = await service.run_ruff()
            assert len(problems) == 1
            assert problems[0].code == "E501"


class TestTodoScanner:
    """Tests for TodoScanner."""

    @pytest.fixture
    def scanner(self, tmp_path: Path) -> TodoScanner:
        return TodoScanner(tmp_path)

    @pytest.fixture
    def project_with_todos(self, tmp_path: Path) -> Path:
        """Create a project with TODO comments."""
        src = tmp_path / "src"
        src.mkdir()

        (src / "main.py").write_text("""
# TODO: Implement feature
def main():
    pass  # FIXME: Handle errors

# HACK: Temporary workaround
""")
        return tmp_path

    @pytest.mark.asyncio
    async def test_scan_finds_todos(self, project_with_todos: Path):
        scanner = TodoScanner(project_with_todos)
        items, project_items, summary = await scanner.scan()
        # Should find TODO, FIXME, and HACK
        assert len(items) >= 1
        assert summary.total >= 1

    @pytest.mark.asyncio
    async def test_scan_empty_project(self, tmp_path: Path):
        scanner = TodoScanner(tmp_path)
        items, project_items, summary = await scanner.scan()
        assert items == []
        assert summary.total == 0

    def test_parse_ripgrep_output_todo(self, scanner: TodoScanner):
        output = "test.py:10:# TODO: Fix this"
        items = scanner._parse_ripgrep_output(output)
        assert len(items) == 1
        assert items[0].todo_type == TodoType.TODO
        assert "Fix this" in items[0].text

    def test_parse_ripgrep_output_fixme(self, scanner: TodoScanner):
        output = "test.py:20:// FIXME: Broken code"
        items = scanner._parse_ripgrep_output(output)
        assert len(items) == 1
        assert items[0].todo_type == TodoType.FIXME

    def test_parse_ripgrep_output_hack(self, scanner: TodoScanner):
        output = "test.py:30:/* HACK: Workaround */"
        items = scanner._parse_ripgrep_output(output)
        assert len(items) == 1
        assert items[0].todo_type == TodoType.HACK
