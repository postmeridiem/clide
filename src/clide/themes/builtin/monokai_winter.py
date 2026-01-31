"""Monokai Winter Night theme."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="monokai-winter",
    display_name="Monokai Winter Night",
    dark=True,
    colors=ThemeColors(
        primary="#66d9ef",
        secondary="#a6e22e",
        accent="#f92672",
        background="#1a1a2e",
        surface="#16213e",
        panel="#0f3460",
        foreground="#f8f8f2",
        success="#a6e22e",
        warning="#e6db74",
        error="#f92672",
    ),
)
