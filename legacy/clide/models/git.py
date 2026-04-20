"""Git-related Pydantic models."""

from enum import Enum

from pydantic import BaseModel, ConfigDict


class ChangeStatus(str, Enum):
    """Git file change status."""

    ADDED = "added"
    MODIFIED = "modified"
    DELETED = "deleted"
    RENAMED = "renamed"
    COPIED = "copied"
    UNTRACKED = "untracked"
    IGNORED = "ignored"
    UNMERGED = "unmerged"


class GitChange(BaseModel):
    """A single file change in git."""

    model_config = ConfigDict(strict=True, frozen=True)

    path: str
    status: ChangeStatus
    staged: bool
    old_path: str | None = None  # For renames


class GitStatus(BaseModel):
    """Current git repository status."""

    model_config = ConfigDict(strict=True, frozen=True)

    branch: str
    ahead: int = 0
    behind: int = 0
    staged: tuple[GitChange, ...]
    unstaged: tuple[GitChange, ...]
    untracked: tuple[str, ...] = ()
    has_conflicts: bool = False


class GitBranch(BaseModel):
    """Git branch information."""

    model_config = ConfigDict(strict=True, frozen=True)

    name: str
    is_current: bool = False
    is_remote: bool = False
    tracking: str | None = None
    commit_hash: str | None = None
    commit_message: str | None = None


class GitCommit(BaseModel):
    """Git commit information for graph view."""

    model_config = ConfigDict(strict=True, frozen=True)

    hash: str
    short_hash: str
    message: str
    author: str
    date: str
    is_merge: bool = False
    refs: tuple[str, ...] = ()  # branch names, tags
    parents: tuple[str, ...] = ()


class GitGraph(BaseModel):
    """Git log graph data."""

    model_config = ConfigDict(strict=True, frozen=True)

    commits: tuple[GitCommit, ...]
    branches: tuple[GitBranch, ...]
