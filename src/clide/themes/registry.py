"""Theme registry for managing available themes."""

from typing import Callable

from clide.models.theme import ThemeDefinition, ThemeMetadata

# Theme registry
_themes: dict[str, ThemeDefinition] = {}
_theme_metadata: dict[str, ThemeMetadata] = {}

DEFAULT_THEME = "summer-night"


def register_theme(
    theme: ThemeDefinition,
    category: str = "custom",
) -> None:
    """Register a theme in the registry.

    Args:
        theme: Theme definition to register
        category: Theme category (core, popular, seasonal, custom)
    """
    _themes[theme.name] = theme
    _theme_metadata[theme.name] = ThemeMetadata(
        name=theme.name,
        display_name=theme.display_name,
        dark=theme.dark,
        category=category,
    )


def get_theme(name: str) -> ThemeDefinition | None:
    """Get a theme by name.

    Args:
        name: Theme name

    Returns:
        Theme definition or None if not found
    """
    return _themes.get(name)


def get_all_themes() -> list[ThemeMetadata]:
    """Get metadata for all registered themes.

    Returns:
        List of theme metadata sorted by category then name
    """
    themes = list(_theme_metadata.values())
    # Sort: core first, then alphabetically by category, then by name
    category_order = {"core": 0, "popular": 1, "gitkraken": 2, "seasonal": 3, "hacker": 4, "custom": 5}
    themes.sort(key=lambda t: (category_order.get(t.category, 99), t.name))
    return themes


def get_themes_by_category(category: str) -> list[ThemeMetadata]:
    """Get themes filtered by category.

    Args:
        category: Category to filter by

    Returns:
        List of theme metadata in that category
    """
    return [t for t in _theme_metadata.values() if t.category == category]


def _load_builtin_themes() -> None:
    """Load all built-in themes."""
    # Import here to avoid circular imports
    from clide.themes.builtin import (
        summer_night,
        summer_day,
        one_dark,
        one_dark_pro,
        one_light,
        dracula,
        nord,
        gruvbox_dark,
        gruvbox_light,
        one_dark_teal,
        gamma,
        winter_is_coming,
        monokai_winter,
        fall,
        dark_autumn,
        all_hallows_eve,
        halloween,
        christmas,
        santa_baby,
        pro_hacker,
        hacker_style,
        houston,
    )

    # Core themes
    register_theme(summer_night.theme, "core")
    register_theme(summer_day.theme, "core")

    # Popular themes
    register_theme(one_dark.theme, "popular")
    register_theme(one_dark_pro.theme, "popular")
    register_theme(one_light.theme, "popular")
    register_theme(dracula.theme, "popular")
    register_theme(nord.theme, "popular")
    register_theme(gruvbox_dark.theme, "popular")
    register_theme(gruvbox_light.theme, "popular")

    # GitKraken style
    register_theme(one_dark_teal.theme, "gitkraken")
    register_theme(gamma.theme, "gitkraken")

    # Seasonal - Winter
    register_theme(winter_is_coming.theme, "seasonal")
    register_theme(monokai_winter.theme, "seasonal")

    # Seasonal - Fall
    register_theme(fall.theme, "seasonal")
    register_theme(dark_autumn.theme, "seasonal")

    # Seasonal - Halloween
    register_theme(all_hallows_eve.theme, "seasonal")
    register_theme(halloween.theme, "seasonal")

    # Seasonal - Christmas
    register_theme(christmas.theme, "seasonal")
    register_theme(santa_baby.theme, "seasonal")

    # Hacker style
    register_theme(pro_hacker.theme, "hacker")
    register_theme(hacker_style.theme, "hacker")

    # Bonus
    register_theme(houston.theme, "popular")


# Load built-in themes on module import
_load_builtin_themes()
