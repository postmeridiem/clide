"""Pydantic models for Clide."""

from clide.models.config import ClideSettings, PanelConfig
from clide.models.db import ConnectionLog, Project, Session, UserPreference
from clide.models.diff import ChangeType, DiffContent, DiffHunk, DiffLine, DiffViewState
from clide.models.editor import CursorPosition, EditorState, FileBuffer, Selection
from clide.models.git import (
    ChangeStatus,
    GitBranch,
    GitChange,
    GitCommit,
    GitGraph,
    GitStatus,
)
from clide.models.problems import Problem, ProblemsState, ProblemsSummary, Severity
from clide.models.theme import ThemeColors, ThemeDefinition, ThemeMetadata
from clide.models.todos import TodoItem, TodosState, TodosSummary, TodoType
from clide.models.workspace import TAB_ICONS, TabInfo, TabType

__all__ = [
    # Config
    "ClideSettings",
    "PanelConfig",
    # Git
    "ChangeStatus",
    "GitBranch",
    "GitChange",
    "GitCommit",
    "GitGraph",
    "GitStatus",
    # Editor
    "CursorPosition",
    "EditorState",
    "FileBuffer",
    "Selection",
    # Diff
    "ChangeType",
    "DiffContent",
    "DiffHunk",
    "DiffLine",
    "DiffViewState",
    # Problems
    "Problem",
    "ProblemsSummary",
    "ProblemsState",
    "Severity",
    # Todos
    "TodoItem",
    "TodosSummary",
    "TodosState",
    "TodoType",
    # Theme
    "ThemeColors",
    "ThemeDefinition",
    "ThemeMetadata",
    # Workspace
    "TabInfo",
    "TabType",
    "TAB_ICONS",
    # Database (SQLModel)
    "Project",
    "Session",
    "UserPreference",
    "ConnectionLog",
]
