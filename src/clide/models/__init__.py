"""Pydantic models for Clide."""

from clide.models.config import ClideSettings, PanelConfig
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
from clide.models.problems import Problem, ProblemsSummary, ProblemsState, Severity
from clide.models.theme import ThemeColors, ThemeDefinition, ThemeMetadata
from clide.models.todos import TodoItem, TodosSummary, TodosState, TodoType

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
]
