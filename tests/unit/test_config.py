"""Tests for configuration models."""

import pytest
from pydantic import ValidationError

from clide.models.config import ClideSettings, KeybindingsConfig, PanelConfig


class TestClideSettings:
    """Tests for ClideSettings model."""

    def test_default_settings(self) -> None:
        """Default settings should be valid."""
        settings = ClideSettings()
        assert settings.theme == "summer-night"
        assert settings.auto_save is True
        assert settings.confirm_exit is True
        assert settings.jira_enabled is False

    def test_custom_settings(self) -> None:
        """Custom settings should be applied."""
        settings = ClideSettings(
            theme="dracula",
            claude_path="/custom/path/claude",
            auto_save=False,
            jira_enabled=True,
        )
        assert settings.theme == "dracula"
        assert settings.claude_path == "/custom/path/claude"
        assert settings.auto_save is False
        assert settings.jira_enabled is True


class TestPanelConfig:
    """Tests for PanelConfig model."""

    def test_default_values(self) -> None:
        """Default values should be set correctly."""
        config = PanelConfig()
        assert config.sidebar_visible is True
        assert config.context_visible is True
        assert config.workspace_visible is False
        assert config.sidebar_width_percent == 20
        assert config.context_width_percent == 25

    def test_frozen_model(self) -> None:
        """PanelConfig should be immutable."""
        config = PanelConfig()
        with pytest.raises(ValidationError):
            config.sidebar_visible = False  # type: ignore

    def test_strict_mode(self) -> None:
        """PanelConfig should enforce strict types."""
        with pytest.raises(ValidationError):
            PanelConfig(sidebar_width_percent="30")  # type: ignore


class TestKeybindingsConfig:
    """Tests for KeybindingsConfig model."""

    def test_default_keybindings(self) -> None:
        """Default keybindings should be valid."""
        config = KeybindingsConfig()
        assert config.toggle_sidebar == "ctrl+b"
        assert config.toggle_terminal == "ctrl+`"
        assert config.focus_claude == "ctrl+1"

    def test_custom_keybindings(self) -> None:
        """Custom keybindings should be applied."""
        config = KeybindingsConfig(
            toggle_sidebar="ctrl+shift+s",
            save="cmd+s",
        )
        assert config.toggle_sidebar == "ctrl+shift+s"
        assert config.save == "cmd+s"
