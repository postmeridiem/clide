"""Theme system for Clide."""

from clide.themes.registry import (
    DEFAULT_THEME,
    get_all_themes,
    get_theme,
    get_themes_by_category,
    register_theme,
)

__all__ = [
    "get_theme",
    "get_all_themes",
    "get_themes_by_category",
    "register_theme",
    "DEFAULT_THEME",
]
