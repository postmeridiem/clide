"""Gruvbox Dark theme - Retro groove color scheme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="gruvbox-dark",
    display_name="Gruvbox Dark",
    dark=True,
    colors=ThemeColors(
        primary="#83a598",
        secondary="#8ec07c",
        accent="#d3869b",
        background="#282828",
        surface="#3c3836",
        panel="#504945",
        foreground="#ebdbb2",
        success="#b8bb26",
        warning="#fabd2f",
        error="#fb4934",
    ),
)
