"""Custom theme loader for user-defined themes."""

from pathlib import Path

import tomllib

from clide.models.theme import ThemeColors, ThemeDefinition
from clide.themes.registry import register_theme


def load_custom_themes(themes_dir: Path) -> list[str]:
    """Load custom themes from a directory.

    Args:
        themes_dir: Directory containing .toml theme files

    Returns:
        List of loaded theme names
    """
    loaded = []

    if not themes_dir.exists():
        return loaded

    for theme_file in themes_dir.glob("*.toml"):
        try:
            theme = load_theme_file(theme_file)
            if theme:
                register_theme(theme, "custom")
                loaded.append(theme.name)
        except Exception as e:
            # Log but don't crash on bad theme files
            print(f"Failed to load theme {theme_file}: {e}")

    return loaded


def load_theme_file(path: Path) -> ThemeDefinition | None:
    """Load a single theme from a TOML file.

    Args:
        path: Path to the theme TOML file

    Returns:
        Theme definition or None if invalid

    Example TOML format:
        name = "my-theme"
        display_name = "My Custom Theme"
        dark = true

        [colors]
        primary = "#007acc"
        secondary = "#3c3c3c"
        accent = "#0e639c"
        background = "#1e1e1e"
        surface = "#252526"
        panel = "#2d2d2d"
        foreground = "#d4d4d4"
        success = "#4ec9b0"
        warning = "#dcdcaa"
        error = "#f14c4c"
    """
    with open(path, "rb") as f:
        data = tomllib.load(f)

    # Validate required fields
    required = ["name", "display_name", "dark", "colors"]
    for field in required:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")

    colors_data = data["colors"]
    color_fields = [
        "primary", "secondary", "accent", "background", "surface",
        "panel", "foreground", "success", "warning", "error"
    ]
    for field in color_fields:
        if field not in colors_data:
            raise ValueError(f"Missing color field: {field}")

    colors = ThemeColors(**colors_data)
    return ThemeDefinition(
        name=data["name"],
        display_name=data["display_name"],
        dark=data["dark"],
        colors=colors,
    )
