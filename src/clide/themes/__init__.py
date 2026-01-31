"""Theme system for Clide."""

from clide.themes.registry import (
    get_theme,
    get_all_themes,
    get_themes_by_category,
    register_theme,
    DEFAULT_THEME,
)

__all__ = [
    "get_theme",
    "get_all_themes",
    "get_themes_by_category",
    "register_theme",
    "DEFAULT_THEME",
]
