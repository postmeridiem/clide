"""Tests for extension system."""

import pytest

from clide.extensions import hookimpl
from clide.extensions.manager import ExtensionManager


class SampleExtension:
    """Sample extension for testing."""

    @hookimpl
    def clide_on_app_startup(self, app: object) -> None:
        """Track that startup was called."""
        self.startup_called = True
        self.received_app = app


class TestExtensionManager:
    """Tests for ExtensionManager."""

    def test_register_plugin(self) -> None:
        """Plugins can be registered manually."""
        manager = ExtensionManager()
        extension = SampleExtension()

        manager.register_plugin(extension, "sample")

        assert "sample" in manager.list_extensions()

    def test_unregister_plugin(self) -> None:
        """Plugins can be unregistered."""
        manager = ExtensionManager()
        extension = SampleExtension()
        manager.register_plugin(extension, "sample")

        manager.unregister_plugin("sample")

        assert "sample" not in manager.list_extensions()

    @pytest.mark.asyncio
    async def test_trigger_startup_hook(self) -> None:
        """Startup hooks are triggered for all extensions."""
        manager = ExtensionManager()
        extension = SampleExtension()
        manager.register_plugin(extension, "sample")
        mock_app = object()

        await manager.trigger_app_startup(mock_app)

        assert extension.startup_called is True
        assert extension.received_app is mock_app
