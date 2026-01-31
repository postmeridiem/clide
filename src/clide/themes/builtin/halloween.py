"""Halloween theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="halloween",
    display_name="Halloween",
    dark=True,
    colors=ThemeColors(
        primary="#ff6600",
        secondary="#8a2be2",
        accent="#ff4500",
        background="#0d0d0d",
        surface="#1a1a1a",
        panel="#262626",
        foreground="#e6e6e6",
        success="#00ff00",
        warning="#ff6600",
        error="#ff0000",
    ),
)
