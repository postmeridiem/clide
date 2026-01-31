"""Santa Baby theme - Light Christmas theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="santa-baby",
    display_name="Santa Baby",
    dark=False,
    colors=ThemeColors(
        primary="#c41e3a",  # Cardinal red
        secondary="#228b22",  # Forest green
        accent="#b8860b",  # Dark goldenrod
        background="#fff8f0",
        surface="#f0e8e0",
        panel="#e0d8d0",
        foreground="#2f1f1f",
        success="#228b22",
        warning="#daa520",
        error="#c41e3a",
    ),
)
