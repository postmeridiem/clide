"""Extension manager for loading and managing Clide extensions."""

from importlib.metadata import entry_points
from pathlib import Path
from typing import TYPE_CHECKING, Any

import pluggy

from clide.extensions.hookspecs import ClideHookSpec

if TYPE_CHECKING:
    from textual.app import App

    from clide.services.file_watcher import FileEvent

EXTENSION_NAMESPACE = "clide.extensions"


class ExtensionManager:
    """Manages loading and lifecycle of Clide extensions."""

    def __init__(self) -> None:
        self._pm = pluggy.PluginManager("clide")
        self._pm.add_hookspecs(ClideHookSpec)
        self._loaded: list[str] = []

    @property
    def hook(self) -> pluggy.HookRelay:
        """Access the hook relay for calling hooks."""
        return self._pm.hook

    def load_extensions(self) -> None:
        """Load all extensions from entry points."""
        eps = entry_points(group=EXTENSION_NAMESPACE)
        for ep in eps:
            try:
                plugin = ep.load()
                self._pm.register(plugin, name=ep.name)
                self._loaded.append(ep.name)
            except Exception as e:
                # Log but don't crash on extension load failure
                print(f"Failed to load extension {ep.name}: {e}")

    def register_plugin(self, plugin: object, name: str) -> None:
        """Manually register a plugin instance.

        Args:
            plugin: Plugin object with hookimpl methods
            name: Unique name for the plugin
        """
        self._pm.register(plugin, name=name)
        self._loaded.append(name)

    def unregister_plugin(self, name: str) -> None:
        """Unregister a plugin by name.

        Args:
            name: Name of the plugin to unregister
        """
        plugin = self._pm.get_plugin(name)
        if plugin:
            self._pm.unregister(plugin)
            self._loaded.remove(name)

    def list_extensions(self) -> list[str]:
        """Get list of loaded extension names."""
        return self._loaded.copy()

    async def trigger_app_startup(self, app: "App[object]") -> None:
        """Trigger startup hooks for all extensions.

        Args:
            app: The Clide application instance
        """
        self.hook.clide_on_app_startup(app=app)

    async def trigger_app_shutdown(self, app: "App[object]") -> None:
        """Trigger shutdown hooks for all extensions.

        Args:
            app: The Clide application instance
        """
        self.hook.clide_on_app_shutdown(app=app)

    def trigger_file_changed(self, event: "FileEvent") -> None:
        """Trigger file change hooks for all extensions.

        Args:
            event: The file event with path, type, and timestamp
        """
        self.hook.clide_on_file_changed(event=event)

    def trigger_file_saved(self, path: Path) -> None:
        """Trigger file saved hooks for all extensions.

        Args:
            path: Path to the saved file
        """
        self.hook.clide_on_file_saved(path=path)

    def trigger_claude_event(self, event_type: str, data: dict[str, Any]) -> None:
        """Trigger Claude event hooks for all extensions.

        Args:
            event_type: Type of event (e.g., "file_read", "file_edit")
            data: Event-specific data
        """
        self.hook.clide_on_claude_event(event_type=event_type, data=data)
