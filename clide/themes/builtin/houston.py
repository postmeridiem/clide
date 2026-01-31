"""Houston theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="houston",
    display_name="Houston",
    dark=True,
    colors=ThemeColors(
        primary="#ff6f00",
        secondary="#00bcd4",
        accent="#ff4081",
        background="#17212b",
        surface="#232e3c",
        panel="#2e3a48",
        foreground="#eeffff",
        success="#4caf50",
        warning="#ff9800",
        error="#f44336",
    ),
)
