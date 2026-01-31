"""Diff-related Pydantic models."""

from enum import Enum

from pydantic import BaseModel, ConfigDict


class ChangeType(str, Enum):
    """Type of change in a diff line."""

    ADDED = "added"
    REMOVED = "removed"
    CONTEXT = "context"
    HEADER = "header"


class DiffLine(BaseModel):
    """A single line in a diff."""

    model_config = ConfigDict(strict=True, frozen=True)

    change_type: ChangeType
    content: str
    old_line_num: int | None = None
    new_line_num: int | None = None


class DiffHunk(BaseModel):
    """A hunk (section) of a diff."""

    model_config = ConfigDict(strict=True, frozen=True)

    header: str
    old_start: int
    old_count: int
    new_start: int
    new_count: int
    lines: tuple[DiffLine, ...]


class DiffContent(BaseModel):
    """Complete diff for a file."""

    model_config = ConfigDict(strict=True, frozen=True)

    file_path: str
    old_path: str | None = None  # For renames
    hunks: tuple[DiffHunk, ...]
    is_binary: bool = False
    is_new_file: bool = False
    is_deleted: bool = False


class DiffViewState(BaseModel):
    """State of the diff viewer."""

    model_config = ConfigDict(strict=True)

    diff: DiffContent | None = None
    scroll_offset: int = 0
    selected_hunk_index: int | None = None
    side_by_side: bool = True
    # For Claude-proposed changes
    is_proposal: bool = False
    accepted_hunks: set[int] = set()
    rejected_hunks: set[int] = set()
