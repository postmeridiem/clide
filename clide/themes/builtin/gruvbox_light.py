"""Gruvbox Light theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="gruvbox-light",
    display_name="Gruvbox Light",
    dark=False,
    colors=ThemeColors(
        primary="#076678",
        secondary="#427b58",
        accent="#8f3f71",
        background="#fbf1c7",
        surface="#ebdbb2",
        panel="#d5c4a1",
        foreground="#3c3836",
        success="#79740e",
        warning="#b57614",
        error="#9d0006",
    ),
)
