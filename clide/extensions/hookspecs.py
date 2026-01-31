"""Pluggy hook specifications for Clide extensions."""

from typing import TYPE_CHECKING, Any

import pluggy

if TYPE_CHECKING:
    from textual.app import App
    from textual.widget import Widget

hookspec = pluggy.HookspecMarker("clide")
hookimpl = pluggy.HookimplMarker("clide")


class ClideHookSpec:
    """Hook specifications for Clide extensions.

    Extensions implement these hooks to extend functionality.
    """

    @hookspec
    def clide_register_panel(self) -> dict[str, Any] | None:
        """Register a custom panel for the UI.

        Returns:
            Dictionary with panel configuration:
            - name: Panel identifier
            - widget: Widget class to instantiate
            - position: "left", "right", or "bottom"
            - keybinding: Optional keyboard shortcut
        """

    @hookspec
    def clide_register_commands(self) -> list[dict[str, Any]] | None:
        """Register custom commands for the command palette.

        Returns:
            List of command dictionaries:
            - name: Command display name
            - callback: Async callable to execute
            - description: Help text
        """

    @hookspec
    def clide_on_app_startup(self, app: "App[object]") -> None:
        """Called when the application starts.

        Args:
            app: The Clide application instance
        """

    @hookspec
    def clide_on_app_shutdown(self, app: "App[object]") -> None:
        """Called when the application is shutting down.

        Args:
            app: The Clide application instance
        """

    @hookspec
    def clide_on_file_open(self, path: str) -> None:
        """Called when a file is opened in the file browser.

        Args:
            path: Absolute path to the opened file
        """

    @hookspec
    def clide_modify_widget(self, widget: "Widget") -> "Widget":
        """Modify a widget before it's mounted.

        Args:
            widget: The widget about to be mounted

        Returns:
            The modified (or original) widget
        """
