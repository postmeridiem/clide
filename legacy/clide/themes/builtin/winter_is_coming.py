"""Winter Is Coming theme - Bluish, icy vibe."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="winter-is-coming",
    display_name="Winter Is Coming",
    dark=True,
    colors=ThemeColors(
        primary="#89ddff",
        secondary="#82aaff",
        accent="#c792ea",
        background="#011627",
        surface="#0d293e",
        panel="#1d3b53",
        foreground="#d6deeb",
        success="#22da6e",
        warning="#ecc48d",
        error="#ef5350",
    ),
)
