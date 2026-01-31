"""Theme-related Pydantic models."""

import re
from typing import TYPE_CHECKING

from pydantic import BaseModel, ConfigDict, field_validator

if TYPE_CHECKING:
    from textual.theme import Theme


def validate_hex_color(value: str) -> str:
    """Validate hex color format."""
    if not re.match(r"^#[0-9A-Fa-f]{6}$", value):
        raise ValueError(f"Invalid hex color: {value}")
    return value.lower()


class ThemeColors(BaseModel):
    """Color definitions for a theme."""

    model_config = ConfigDict(strict=True, frozen=True)

    # Core colors
    primary: str
    secondary: str
    accent: str

    # Backgrounds
    background: str
    surface: str
    panel: str

    # Text
    foreground: str

    # Status
    success: str
    warning: str
    error: str

    @field_validator("*", mode="before")
    @classmethod
    def validate_colors(cls, v: str) -> str:
        """Validate all color fields are valid hex."""
        return validate_hex_color(v)


class ThemeDefinition(BaseModel):
    """Complete theme definition."""

    model_config = ConfigDict(strict=True)

    name: str  # e.g., "summer-night"
    display_name: str  # e.g., "Summer Night"
    dark: bool  # True for dark themes
    colors: ThemeColors

    def to_textual_colors(self) -> dict[str, str]:
        """Convert to Textual theme color dict."""
        return {
            "primary": self.colors.primary,
            "secondary": self.colors.secondary,
            "accent": self.colors.accent,
            "background": self.colors.background,
            "surface": self.colors.surface,
            "panel": self.colors.panel,
            "foreground": self.colors.foreground,
            "success": self.colors.success,
            "warning": self.colors.warning,
            "error": self.colors.error,
        }

    def to_textual_theme(self) -> "Theme":
        """Convert to a Textual Theme object."""
        from textual.theme import Theme

        return Theme(
            name=self.name,
            primary=self.colors.primary,
            secondary=self.colors.secondary,
            accent=self.colors.accent,
            background=self.colors.background,
            surface=self.colors.surface,
            panel=self.colors.panel,
            foreground=self.colors.foreground,
            success=self.colors.success,
            warning=self.colors.warning,
            error=self.colors.error,
            dark=self.dark,
        )


class ThemeMetadata(BaseModel):
    """Theme metadata for listing themes."""

    model_config = ConfigDict(strict=True, frozen=True)

    name: str
    display_name: str
    dark: bool
    category: str = "custom"  # e.g., "core", "popular", "seasonal", "custom"
