"""Nord theme - Arctic, north-bluish color palette."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="nord",
    display_name="Nord",
    dark=True,
    colors=ThemeColors(
        primary="#88c0d0",
        secondary="#81a1c1",
        accent="#b48ead",
        background="#2e3440",
        surface="#3b4252",
        panel="#434c5e",
        foreground="#eceff4",
        success="#a3be8c",
        warning="#ebcb8b",
        error="#bf616a",
    ),
)
