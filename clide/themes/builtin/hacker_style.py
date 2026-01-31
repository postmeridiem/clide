"""Hacker Style theme - Matrix inspired."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="hacker-style",
    display_name="Hacker Style",
    dark=True,
    colors=ThemeColors(
        primary="#20c20e",
        secondary="#33ff33",
        accent="#66ff66",
        background="#0c0c0c",
        surface="#121212",
        panel="#1a1a1a",
        foreground="#33ff33",
        success="#20c20e",
        warning="#c0c020",
        error="#c02020",
    ),
)
