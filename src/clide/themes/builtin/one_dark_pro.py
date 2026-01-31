"""One Dark Pro theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="one-dark-pro",
    display_name="One Dark Pro",
    dark=True,
    colors=ThemeColors(
        primary="#61afef",
        secondary="#56b6c2",
        accent="#c678dd",
        background="#282c34",
        surface="#1e2227",
        panel="#333842",
        foreground="#abb2bf",
        success="#98c379",
        warning="#d19a66",
        error="#e06c75",
    ),
)
