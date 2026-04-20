"""Settings persistence service for user preferences."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from pydantic import BaseModel


class UserSettings(BaseModel):
    """User settings that persist across sessions.

    Stored in ~/.clide/settings.json
    """

    # Appearance
    theme: str = "summer-night"

    # Panel state
    sidebar_visible: bool = True
    context_visible: bool = True

    # Window
    compact_mode: bool = False

    # Behavior
    auto_save: bool = True
    confirm_exit: bool = True

    # Integrations
    jira_enabled: bool = False

    # Debug
    terminal_debug: bool = False  # Verbose terminal/pyte logging to ~/.clide/terminal_debug.log


class SettingsService:
    """Service for loading and saving user settings.

    Settings are stored in ~/.clide/settings.json
    """

    def __init__(self, settings_dir: Path | None = None) -> None:
        """Initialize the settings service.

        Args:
            settings_dir: Override the settings directory (default: ~/.clide)
        """
        self._settings_dir = settings_dir or Path.home() / ".clide"
        self._settings_file = self._settings_dir / "settings.json"
        self._settings: UserSettings | None = None

    @property
    def settings_dir(self) -> Path:
        """Get the settings directory path."""
        return self._settings_dir

    @property
    def settings_file(self) -> Path:
        """Get the settings file path."""
        return self._settings_file

    def load(self) -> UserSettings:
        """Load settings from disk, creating defaults if needed.

        Returns:
            The loaded or default UserSettings
        """
        if self._settings is not None:
            return self._settings

        if self._settings_file.exists():
            try:
                data = json.loads(self._settings_file.read_text())
                self._settings = UserSettings.model_validate(data)
            except (json.JSONDecodeError, ValueError):
                # Invalid JSON or schema, use defaults
                self._settings = UserSettings()
        else:
            self._settings = UserSettings()

        return self._settings

    def save(self) -> None:
        """Save current settings to disk."""
        if self._settings is None:
            return

        # Ensure directory exists
        self._settings_dir.mkdir(parents=True, exist_ok=True)

        # Write settings as formatted JSON
        data = self._settings.model_dump(mode="json")
        self._settings_file.write_text(
            json.dumps(data, indent=2, sort_keys=True) + "\n"
        )

    def get(self, key: str, default: Any = None) -> Any:
        """Get a setting value.

        Args:
            key: The setting key (attribute name)
            default: Default value if key doesn't exist

        Returns:
            The setting value or default
        """
        settings = self.load()
        return getattr(settings, key, default)

    def set(self, key: str, value: Any, *, save: bool = True) -> None:
        """Set a setting value.

        Args:
            key: The setting key (attribute name)
            value: The value to set
            save: Whether to save immediately (default: True)
        """
        settings = self.load()
        if hasattr(settings, key):
            # Create new settings with updated value
            data = settings.model_dump()
            data[key] = value
            self._settings = UserSettings.model_validate(data)

            if save:
                self.save()

    def update(self, **kwargs: Any) -> None:
        """Update multiple settings at once.

        Args:
            **kwargs: Key-value pairs to update
        """
        settings = self.load()
        data = settings.model_dump()

        for key, value in kwargs.items():
            if hasattr(settings, key):
                data[key] = value

        self._settings = UserSettings.model_validate(data)
        self.save()

    def reset(self) -> None:
        """Reset settings to defaults."""
        self._settings = UserSettings()
        self.save()


# Global instance for convenience
_settings_service: SettingsService | None = None


def get_settings_service() -> SettingsService:
    """Get the global settings service instance."""
    global _settings_service
    if _settings_service is None:
        _settings_service = SettingsService()
    return _settings_service
