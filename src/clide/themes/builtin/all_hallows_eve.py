"""All Hallows' Eve Plus theme - Halloween."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="all-hallows-eve",
    display_name="All Hallows' Eve",
    dark=True,
    colors=ThemeColors(
        primary="#ff7518",  # Pumpkin orange
        secondary="#9932cc",  # Dark orchid
        accent="#ff6347",
        background="#1a0a1a",
        surface="#2d1a2d",
        panel="#401a40",
        foreground="#dda0dd",
        success="#32cd32",
        warning="#ff7518",
        error="#dc143c",
    ),
)
