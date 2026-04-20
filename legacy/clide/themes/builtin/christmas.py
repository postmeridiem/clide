"""Christmas theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="christmas",
    display_name="Christmas",
    dark=True,
    colors=ThemeColors(
        primary="#ff0000",  # Christmas red
        secondary="#228b22",  # Forest green
        accent="#ffd700",  # Gold
        background="#0a1a0a",
        surface="#1a2a1a",
        panel="#2a3a2a",
        foreground="#f0f0f0",
        success="#228b22",
        warning="#ffd700",
        error="#ff0000",
    ),
)
