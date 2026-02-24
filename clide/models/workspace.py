"""Workspace tab models."""

from enum import Enum
from pathlib import Path

from pydantic import BaseModel, ConfigDict


class TabType(str, Enum):
    """Types of workspace tabs."""

    EDITOR = "editor"
    TERMINAL = "terminal"
    DIFF = "diff"


# Nerd Font icons for each tab type
TAB_ICONS: dict[TabType, str] = {
    TabType.EDITOR: "\uf15c",  # nf-fa-file_text_o
    TabType.TERMINAL: "\uf120",  # nf-fa-terminal
    TabType.DIFF: "\uf440",  # nf-oct-diff
}


class TabInfo(BaseModel):
    """Metadata for a workspace tab."""

    model_config = ConfigDict(strict=True)

    tab_id: str
    tab_type: TabType
    label: str
    file_path: Path | None = None
    is_proposal: bool = False
    diff_file_path: str | None = None
