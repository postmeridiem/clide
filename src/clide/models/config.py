"""Configuration models using Pydantic Settings."""

from pathlib import Path

from pydantic import BaseModel, ConfigDict
from pydantic_settings import BaseSettings, SettingsConfigDict


class ClideSettings(BaseSettings):
    """Main application settings loaded from environment and config files."""

    model_config = SettingsConfigDict(
        env_prefix="CLIDE_",
        env_file=".config/.env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Appearance
    theme: str = "summer-night"  # Default to Summer Night

    # Paths
    claude_path: str = "claude"
    default_workdir: Path = Path.cwd()
    jira_cli_path: str = "jira"

    # Behavior
    auto_save: bool = True
    confirm_exit: bool = True

    # Integrations
    jira_enabled: bool = False
    confluence_enabled: bool = False
    imagin_enabled: bool = False

    # Linters
    linters: list[str] = ["ruff"]


class PanelConfig(BaseModel):
    """Panel visibility and layout configuration."""

    model_config = ConfigDict(strict=True, frozen=True)

    sidebar_visible: bool = True
    context_visible: bool = True
    workspace_visible: bool = False  # Hidden by default
    sidebar_width_percent: int = 20
    context_width_percent: int = 25


class KeybindingsConfig(BaseModel):
    """Keybinding configuration."""

    model_config = ConfigDict(strict=True)

    # Global
    command_palette: str = "ctrl+shift+p"
    quick_open: str = "ctrl+p"
    toggle_sidebar: str = "ctrl+b"
    toggle_context: str = "ctrl+shift+b"
    toggle_terminal: str = "ctrl+`"
    toggle_compact: str = "ctrl+shift+c"
    fullscreen: str = "f11"

    # Navigation
    focus_claude: str = "ctrl+1"
    focus_editor: str = "ctrl+2"
    focus_terminal: str = "ctrl+3"
    focus_sidebar: str = "ctrl+0"
    next_tab: str = "ctrl+tab"
    prev_tab: str = "ctrl+shift+tab"
    close_tab: str = "ctrl+w"

    # Git
    git_panel: str = "ctrl+shift+g"
    stage_file: str = "ctrl+enter"
    unstage_file: str = "ctrl+backspace"

    # Search
    find_in_file: str = "ctrl+f"
    find_in_project: str = "ctrl+shift+f"
    problems_panel: str = "ctrl+shift+m"
    next_problem: str = "f8"
    prev_problem: str = "shift+f8"

    # Editor
    save: str = "ctrl+s"
    undo: str = "ctrl+z"
    redo: str = "ctrl+shift+z"
    go_to_line: str = "ctrl+g"

    # Theme
    select_theme: str = "ctrl+k ctrl+t"
