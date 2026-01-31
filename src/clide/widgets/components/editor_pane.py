"""Editor pane component with syntax highlighting."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Label, Static, TextArea

from clide.models.editor import CursorPosition, FileBuffer


class EditorPane(Vertical):
    """Editor pane with TextArea and status bar."""

    DEFAULT_CSS = """
    EditorPane {
        height: 100%;
    }

    EditorPane TextArea {
        height: 1fr;
    }

    EditorPane .editor-status {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    EditorPane .file-tab {
        height: 1;
        background: $panel;
    }

    EditorPane .modified {
        color: $warning;
    }
    """

    class ContentChanged(Message):
        """Emitted when content changes."""

        def __init__(self, path: Path, content: str) -> None:
            self.path = path
            self.content = content
            super().__init__()

    class CursorMoved(Message):
        """Emitted when cursor moves."""

        def __init__(self, path: Path, line: int, column: int) -> None:
            self.path = path
            self.line = line
            self.column = column
            super().__init__()

    class SaveRequested(Message):
        """Emitted when save is requested."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    class FileSaved(Message):
        """Emitted when file is saved."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    def __init__(self, buffer: FileBuffer | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._buffer = buffer

    def compose(self) -> ComposeResult:
        if self._buffer:
            yield Static(self._buffer.display_name, classes="file-tab")
            yield TextArea(
                self._buffer.content,
                language=self._buffer.language,
                id="editor-textarea",
                show_line_numbers=True,
            )
            yield Static(
                self._get_status_text(),
                classes="editor-status",
                id="editor-status",
            )
        else:
            yield Static("No file open", classes="file-tab")
            yield TextArea(id="editor-textarea", show_line_numbers=True)
            yield Static("", classes="editor-status", id="editor-status")

    def load_buffer(self, buffer: FileBuffer) -> None:
        """Load a file buffer into the editor."""
        self._buffer = buffer

        textarea = self.query_one("#editor-textarea", TextArea)
        textarea.load_text(buffer.content)
        textarea.language = buffer.language

        # Update tab
        tab = self.query_one(".file-tab", Static)
        tab.update(buffer.display_name)

        # Update status
        self._update_status()

        # Set cursor position
        if buffer.cursor:
            textarea.cursor_location = (buffer.cursor.line, buffer.cursor.column)

    def get_content(self) -> str:
        """Get current editor content."""
        textarea = self.query_one("#editor-textarea", TextArea)
        return textarea.text

    def _get_status_text(self) -> str:
        """Generate status bar text."""
        if not self._buffer:
            return ""

        line = self._buffer.cursor.line + 1 if self._buffer.cursor else 1
        col = self._buffer.cursor.column + 1 if self._buffer.cursor else 1
        lang = self._buffer.language or "plain text"

        return f"Ln {line}, Col {col} | {lang}"

    def _update_status(self) -> None:
        """Update status bar."""
        status = self.query_one("#editor-status", Static)
        status.update(self._get_status_text())

    def on_text_area_changed(self, event: TextArea.Changed) -> None:
        """Handle text changes."""
        if self._buffer:
            self._buffer.content = event.text_area.text
            self._buffer.is_modified = True

            # Update tab to show modified indicator
            tab = self.query_one(".file-tab", Static)
            tab.update(self._buffer.display_name)

            self.post_message(self.ContentChanged(self._buffer.path, event.text_area.text))

    def on_text_area_selection_changed(self, event: TextArea.SelectionChanged) -> None:
        """Handle cursor movement."""
        if self._buffer:
            line, col = event.selection.end
            # CursorPosition is frozen, so create new one
            self._buffer.cursor = CursorPosition(line=line, column=col)
            self._update_status()
            self.post_message(self.CursorMoved(self._buffer.path, line, col))

    @property
    def current_file(self) -> Path | None:
        """Get currently open file path."""
        return self._buffer.path if self._buffer else None

    @property
    def modified(self) -> bool:
        """Check if buffer has unsaved changes."""
        return self._buffer.is_modified if self._buffer else False

    def load_file(self, path: Path, goto_line: int | None = None) -> None:
        """Load a file from disk into the editor."""
        from clide.services.file_service import FileService

        content = FileService.read_file(path)
        language = FileService.detect_language(path)

        buffer = FileBuffer(
            path=path,
            content=content,
            language=language,
            is_modified=False,
        )
        self.load_buffer(buffer)

        if goto_line is not None:
            textarea = self.query_one("#editor-textarea", TextArea)
            textarea.cursor_location = (goto_line - 1, 0)

    def save(self) -> bool:
        """Save current buffer to disk."""
        if not self._buffer:
            return False

        from clide.services.file_service import FileService

        success = FileService.write_file(self._buffer.path, self._buffer.content)
        if success:
            self._buffer.is_modified = False
            # Update tab
            tab = self.query_one(".file-tab", Static)
            tab.update(self._buffer.display_name)
            self.post_message(self.FileSaved(self._buffer.path))
        return success
