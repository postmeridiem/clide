"""Summer Night theme - Default dark theme.

Based on jackw01/summer-night-vscode-theme.
Vibrant colors with HCL-based monochrome scale.
"""

from clide.models.theme import ThemeColors, ThemeDefinition

# Monochrome scale (HCL equidistant lightness)
# mono_1: #e2e8f5  - Lightest text
# mono_2: #c4c9d6  - Secondary text
# mono_3: #a6abb8  - Muted text
# mono_4: #898e9a  - Comments
# mono_5: #6d727e  - Subtle
# mono_6: #525762  - Borders
# mono_7: #393e48  - Surface
# mono_8: #21262f  - Background

# Accent colors (HCL analogous scales)
# cyan:    #00a3d2  - Primary accent
# teal:    #00a9b9  - Links
# pink:    #fa5f8b  - Keywords
# yellow:  #d3ab58  - Strings
# red:     #f06c6f  - Errors
# orange:  #d08447  - Warnings
# coral:   #e17954  - Functions
# green:   #00ab9a  - Success

theme = ThemeDefinition(
    name="summer-night",
    display_name="Summer Night",
    dark=True,
    colors=ThemeColors(
        primary="#00a3d2",
        secondary="#00a9b9",
        accent="#fa5f8b",
        background="#21262f",
        surface="#393e48",
        panel="#292e38",
        foreground="#e2e8f5",
        success="#00ab9a",
        warning="#d08447",
        error="#f06c6f",
    ),
)
