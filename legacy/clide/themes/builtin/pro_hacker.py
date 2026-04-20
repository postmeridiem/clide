"""Pro Hacker theme - Green on black."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="pro-hacker",
    display_name="Pro Hacker",
    dark=True,
    colors=ThemeColors(
        primary="#00ff00",
        secondary="#00cc00",
        accent="#00ff88",
        background="#000000",
        surface="#0a0a0a",
        panel="#141414",
        foreground="#00ff00",
        success="#00ff00",
        warning="#ffff00",
        error="#ff0000",
    ),
)
