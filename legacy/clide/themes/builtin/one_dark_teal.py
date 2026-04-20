"""One Dark Teal theme - GitKraken signature teal accent."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="one-dark-teal",
    display_name="One Dark Teal",
    dark=True,
    colors=ThemeColors(
        primary="#2acf9f",  # GitKraken teal
        secondary="#61afef",
        accent="#c678dd",
        background="#282c34",
        surface="#21252b",
        panel="#2c313a",
        foreground="#abb2bf",
        success="#2acf9f",
        warning="#e5c07b",
        error="#e06c75",
    ),
)
