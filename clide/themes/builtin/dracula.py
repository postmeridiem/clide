"""Dracula theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="dracula",
    display_name="Dracula",
    dark=True,
    colors=ThemeColors(
        primary="#bd93f9",
        secondary="#8be9fd",
        accent="#ff79c6",
        background="#282a36",
        surface="#21222c",
        panel="#343746",
        foreground="#f8f8f2",
        success="#50fa7b",
        warning="#ffb86c",
        error="#ff5555",
    ),
)
