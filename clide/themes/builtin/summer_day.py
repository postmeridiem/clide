"""Summer Day theme - Light variant of Summer Night.

Inverted lightness scale with adjusted accent hues for readability.
"""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="summer-day",
    display_name="Summer Day",
    dark=False,
    colors=ThemeColors(
        primary="#0088b0",
        secondary="#008a99",
        accent="#d03060",
        background="#f5f7fa",
        surface="#e8ebf0",
        panel="#dde1e8",
        foreground="#21262f",
        success="#008a7a",
        warning="#b06830",
        error="#c04048",
    ),
)
