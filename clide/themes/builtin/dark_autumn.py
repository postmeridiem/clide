"""Dark Autumn Frost theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="dark-autumn",
    display_name="Dark Autumn Frost",
    dark=True,
    colors=ThemeColors(
        primary="#c49a6c",
        secondary="#8b7355",
        accent="#a0522d",
        background="#1c1410",
        surface="#2a1f18",
        panel="#382a20",
        foreground="#d2b48c",
        success="#6b8e23",
        warning="#b8860b",
        error="#8b0000",
    ),
)
