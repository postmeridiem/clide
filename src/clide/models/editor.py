"""Editor-related Pydantic models."""

from pathlib import Path

from pydantic import BaseModel, ConfigDict


class CursorPosition(BaseModel):
    """Cursor position in editor."""

    model_config = ConfigDict(strict=True, frozen=True)

    line: int
    column: int


class Selection(BaseModel):
    """Text selection range."""

    model_config = ConfigDict(strict=True, frozen=True)

    start: CursorPosition
    end: CursorPosition


class FileBuffer(BaseModel):
    """A file buffer in the editor."""

    model_config = ConfigDict(strict=True)

    path: Path
    content: str
    language: str | None = None
    is_modified: bool = False
    cursor: CursorPosition = CursorPosition(line=0, column=0)
    selection: Selection | None = None
    scroll_offset: int = 0

    @property
    def filename(self) -> str:
        """Get the filename from path."""
        return self.path.name

    @property
    def display_name(self) -> str:
        """Get display name with modification indicator."""
        prefix = "● " if self.is_modified else ""
        return f"{prefix}{self.filename}"


class EditorState(BaseModel):
    """State of the editor panel."""

    model_config = ConfigDict(strict=True)

    buffers: list[FileBuffer] = []
    active_buffer_index: int | None = None
    recent_files: list[Path] = []

    @property
    def active_buffer(self) -> FileBuffer | None:
        """Get currently active buffer."""
        if self.active_buffer_index is not None and self.buffers:
            return self.buffers[self.active_buffer_index]
        return None

    def get_buffer_by_path(self, path: Path) -> FileBuffer | None:
        """Find a buffer by its file path."""
        for buffer in self.buffers:
            if buffer.path == path:
                return buffer
        return None
