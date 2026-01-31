"""Atom One Dark theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="one-dark",
    display_name="One Dark",
    dark=True,
    colors=ThemeColors(
        primary="#61afef",
        secondary="#56b6c2",
        accent="#c678dd",
        background="#282c34",
        surface="#21252b",
        panel="#2c313a",
        foreground="#abb2bf",
        success="#98c379",
        warning="#e5c07b",
        error="#e06c75",
    ),
)
