"""Integration tests for FilesView widget."""

from pathlib import Path

import pytest
from textual.app import App, ComposeResult
from textual.widgets import Static

from clide.widgets.components.files_view import FilesView


class FilesViewTestApp(App):
    """Test app for FilesView."""

    def __init__(self, path: Path) -> None:
        super().__init__()
        self.test_path = path
        self.selected_files: list[Path] = []
        self.selected_dirs: list[Path] = []

    def compose(self) -> ComposeResult:
        yield FilesView(self.test_path, id="files")

    def on_files_view_file_selected(self, event: FilesView.FileSelected) -> None:
        self.selected_files.append(event.path)

    def on_files_view_directory_selected(self, event: FilesView.DirectorySelected) -> None:
        self.selected_dirs.append(event.path)


@pytest.fixture
def test_directory(tmp_path: Path) -> Path:
    """Create a test directory structure."""
    # Create directories
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "components").mkdir()
    (tmp_path / "tests").mkdir()

    # Create files
    (tmp_path / "README.md").write_text("# Test")
    (tmp_path / "src" / "main.py").write_text("print('hello')")
    (tmp_path / "src" / "components" / "button.py").write_text("class Button: pass")
    (tmp_path / "tests" / "test_main.py").write_text("def test_main(): pass")

    return tmp_path


async def test_files_view_renders(test_directory: Path):
    """Test that FilesView renders without errors."""
    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)
        assert files_view is not None
        assert files_view.path == test_directory


async def test_files_view_shows_files(test_directory: Path):
    """Test that FilesView shows files in the directory."""
    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)
        # The root should be loaded
        assert files_view.root is not None


async def test_directory_click_expands(test_directory: Path):
    """Test that clicking a directory expands it and emits event."""
    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)

        # Wait for initial load
        await pilot.pause()

        # Find the src directory node and click it
        for node in files_view.root.children:
            if node.data and node.data.path.name == "src":
                files_view.select_node(node)
                await pilot.pause()
                break

        # Check that directory was selected
        assert len(app.selected_dirs) >= 1
        assert any(p.name == "src" for p in app.selected_dirs)


async def test_file_click_emits_event(test_directory: Path):
    """Test that clicking a file emits FileSelected event."""
    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)

        # Wait for initial load
        await pilot.pause()

        # Find and click README.md
        for node in files_view.root.children:
            if node.data and node.data.path.name == "README.md":
                files_view.select_node(node)
                await pilot.pause()
                break

        # Check that file was selected
        assert len(app.selected_files) >= 1
        assert any(p.name == "README.md" for p in app.selected_files)


async def test_filter_paths_hides_hidden_files(test_directory: Path):
    """Test that hidden files are filtered out."""
    # Create hidden files/dirs
    (test_directory / ".git").mkdir()
    (test_directory / ".hidden_file").write_text("hidden")
    (test_directory / "__pycache__").mkdir()

    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)

        # Wait for initial load
        await pilot.pause()

        # Check that hidden items are not in the tree
        visible_names = {
            node.data.path.name
            for node in files_view.root.children
            if node.data
        }

        assert ".git" not in visible_names
        assert ".hidden_file" not in visible_names
        assert "__pycache__" not in visible_names
        assert "src" in visible_names
        assert "README.md" in visible_names


async def test_render_label_shows_icons(test_directory: Path):
    """Test that render_label produces proper icons."""
    app = FilesViewTestApp(test_directory)
    async with app.run_test() as pilot:
        files_view = app.query_one("#files", FilesView)

        # Wait for initial load
        await pilot.pause()

        # Check that nodes have labels rendered (icons are part of label)
        for node in files_view.root.children:
            if node.data:
                # The label should contain the filename
                label_text = str(node.label)
                assert node.data.path.name in label_text
