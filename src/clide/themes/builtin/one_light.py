"""Atom One Light theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="one-light",
    display_name="One Light",
    dark=False,
    colors=ThemeColors(
        primary="#4078f2",
        secondary="#0184bc",
        accent="#a626a4",
        background="#fafafa",
        surface="#f0f0f0",
        panel="#e5e5e6",
        foreground="#383a42",
        success="#50a14f",
        warning="#c18401",
        error="#e45649",
    ),
)
