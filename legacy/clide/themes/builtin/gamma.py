"""Gamma theme - GitKraken Gamma style."""

from clide.models.theme import ThemeColors, ThemeDefinition

theme = ThemeDefinition(
    name="gamma",
    display_name="Gamma",
    dark=True,
    colors=ThemeColors(
        primary="#00d4aa",
        secondary="#7c3aed",
        accent="#f472b6",
        background="#0f172a",
        surface="#1e293b",
        panel="#334155",
        foreground="#e2e8f0",
        success="#22c55e",
        warning="#f59e0b",
        error="#ef4444",
    ),
)
