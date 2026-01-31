"""Fall theme - Autumn colors."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="fall",
    display_name="Fall",
    dark=True,
    colors=ThemeColors(
        primary="#e9967a",
        secondary="#daa520",
        accent="#cd853f",
        background="#2d1f1f",
        surface="#3d2929",
        panel="#4d3333",
        foreground="#f5deb3",
        success="#8fbc8f",
        warning="#daa520",
        error="#cd5c5c",
    ),
)
