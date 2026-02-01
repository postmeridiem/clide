"""Editor controller for managing open files."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.models.editor import CursorPosition, EditorState, FileBuffer


@controller
class EditorController:
    """Controller for editor state and file operations."""

    class FileOpened(Message):
        """Emitted when a file is opened."""

        def __init__(self, buffer: FileBuffer) -> None:
            self.buffer = buffer
            super().__init__()

    class FileClosed(Message):
        """Emitted when a file is closed."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    class FileSaved(Message):
        """Emitted when a file is saved."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    class FileModified(Message):
        """Emitted when file content changes."""

        def __init__(self, path: Path, is_modified: bool) -> None:
            self.path = path
            self.is_modified = is_modified
            super().__init__()

    class ActiveBufferChanged(Message):
        """Emitted when active buffer changes."""

        def __init__(self, buffer: FileBuffer | None) -> None:
            self.buffer = buffer
            super().__init__()

    def __init__(self, project_path: Path | None = None) -> None:
        self._project_path = project_path or Path.cwd()
        self._state = EditorState()

    @property
    def state(self) -> EditorState:
        """Get editor state."""
        return self._state

    @property
    def active_buffer(self) -> FileBuffer | None:
        """Get currently active buffer."""
        return self._state.active_buffer

    @property
    def open_files(self) -> list[FileBuffer]:
        """Get list of open file buffers."""
        return self._state.buffers

    @property
    def has_unsaved_changes(self) -> bool:
        """Check if any buffer has unsaved changes."""
        return any(b.is_modified for b in self._state.buffers)

    async def open_file(self, path: Path, line: int | None = None) -> FileBuffer:
        """Open a file in the editor.

        Args:
            path: File path to open
            line: Optional line number to jump to

        Returns:
            FileBuffer for the opened file
        """
        # Check if already open
        existing = self._state.get_buffer_by_path(path)
        if existing:
            self._set_active_buffer(existing)
            if line:
                existing.cursor = CursorPosition(line=line - 1, column=0)
            return existing

        # Read file content
        content = await self._service.read_file(path)
        language = await self._service.get_language(path)

        cursor = CursorPosition(line=line - 1 if line else 0, column=0)

        buffer = FileBuffer(
            path=path,
            content=content,
            language=language,
            cursor=cursor,
        )

        self._state.buffers.append(buffer)
        self._set_active_buffer(buffer)

        # Add to recent files
        if path not in self._state.recent_files:
            self._state.recent_files.insert(0, path)
            self._state.recent_files = self._state.recent_files[:20]

        return buffer

    async def close_file(self, path: Path) -> bool:
        """Close a file buffer.

        Args:
            path: File path to close

        Returns:
            True if closed (may be False if unsaved and user cancels)
        """
        buffer = self._state.get_buffer_by_path(path)
        if not buffer:
            return True

        # Remove from buffers
        self._state.buffers.remove(buffer)

        # Update active buffer
        if self._state.active_buffer_index is not None and self._state.active_buffer_index >= len(
            self._state.buffers
        ):
            self._state.active_buffer_index = (
                len(self._state.buffers) - 1 if self._state.buffers else None
            )

        return True

    async def save_file(self, path: Path | None = None) -> bool:
        """Save a file.

        Args:
            path: File path (defaults to active buffer)

        Returns:
            True if saved successfully
        """
        buffer = self._state.get_buffer_by_path(path) if path else self.active_buffer

        if not buffer:
            return False

        await self._service.write_file(buffer.path, buffer.content)
        buffer.is_modified = False

        return True

    async def save_all(self) -> int:
        """Save all modified buffers.

        Returns:
            Number of files saved
        """
        count = 0
        for buffer in self._state.buffers:
            if buffer.is_modified:
                await self._service.write_file(buffer.path, buffer.content)
                buffer.is_modified = False
                count += 1
        return count

    def update_content(self, path: Path, content: str) -> None:
        """Update buffer content.

        Args:
            path: File path
            content: New content
        """
        buffer = self._state.get_buffer_by_path(path)
        if buffer:
            buffer.content = content
            buffer.is_modified = True

    def update_cursor(self, path: Path, line: int, column: int) -> None:
        """Update cursor position.

        Args:
            path: File path
            line: Line number (0-indexed)
            column: Column number (0-indexed)
        """
        buffer = self._state.get_buffer_by_path(path)
        if buffer:
            buffer.cursor = CursorPosition(line=line, column=column)

    def set_active_by_index(self, index: int) -> None:
        """Set active buffer by index.

        Args:
            index: Buffer index
        """
        if 0 <= index < len(self._state.buffers):
            self._state.active_buffer_index = index

    def _set_active_buffer(self, buffer: FileBuffer) -> None:
        """Set active buffer."""
        try:
            index = self._state.buffers.index(buffer)
            self._state.active_buffer_index = index
        except ValueError:
            pass
