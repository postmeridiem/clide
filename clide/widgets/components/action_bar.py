"""Action bar widget for contextual toolbar buttons."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import Button, Static


@dataclass
class ActionButton:
    """Definition for an action button.

    Attributes:
        id: Unique identifier for the button
        icon: Unicode icon to display
        tooltip: Hover text / description
        callback: Function to call when clicked (or None for message-based)
        visible: Whether button is currently visible
        enabled: Whether button is currently enabled
    """

    id: str
    icon: str
    tooltip: str
    callback: Callable[[], None] | None = None
    visible: bool = True
    enabled: bool = True


class ActionBarButton(Static):
    """A compact action bar button using Static for cleaner rendering."""

    DEFAULT_CSS = """
    ActionBarButton {
        width: auto;
        height: 1;
        padding: 0 1;
        margin: 0;
        color: $text-muted;
    }

    ActionBarButton:hover {
        background: $surface-lighten-1;
        color: $text;
    }

    ActionBarButton.-active {
        color: $primary;
    }

    ActionBarButton.-disabled {
        color: $text-disabled;
    }
    """

    can_focus = True

    def __init__(
        self,
        icon: str,
        tooltip: str,
        action_id: str,
        disabled: bool = False,
        **kwargs,
    ) -> None:
        super().__init__(icon, **kwargs)
        self.tooltip = tooltip
        self.action_id = action_id
        self._disabled = disabled
        if disabled:
            self.add_class("-disabled")

    @property
    def disabled(self) -> bool:
        return self._disabled

    @disabled.setter
    def disabled(self, value: bool) -> None:
        self._disabled = value
        if value:
            self.add_class("-disabled")
        else:
            self.remove_class("-disabled")

    def on_click(self, event) -> None:
        """Handle click events."""
        if not self._disabled:
            # Post a button pressed message
            self.post_message(Button.Pressed(self))


class ActionBar(Horizontal):
    """Contextual action bar for workspace panels.

    Displays action buttons that can be dynamically added/removed
    based on the active context (editor, diff, terminal, etc.).

    Example:
        action_bar = ActionBar()
        action_bar.register_button(ActionButton(
            id="save",
            icon="💾",
            tooltip="Save file",
            callback=self.save_file,
        ))
    """

    DEFAULT_CSS = """
    ActionBar {
        width: auto;
        height: auto;
        padding: 0;
    }

    ActionBar .action-separator {
        width: 1;
        height: 1;
        margin: 0;
        color: $text-muted;
    }
    """

    class ButtonPressed(Message):
        """Emitted when an action button is pressed."""

        def __init__(self, button_id: str) -> None:
            self.button_id = button_id
            super().__init__()

    # Track maximized state
    maximized: reactive[bool] = reactive(False)

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._buttons: dict[str, ActionButton] = {}
        self._button_order: list[str] = []

    def compose(self) -> ComposeResult:
        """Compose the action bar - buttons added dynamically."""
        # Initially empty, buttons added via register_button
        yield from []

    def register_button(
        self,
        button: ActionButton,
        *,
        position: int | None = None,
    ) -> None:
        """Register an action button.

        Args:
            button: The button definition
            position: Optional position in the bar (default: end)
        """
        self._buttons[button.id] = button

        if position is not None:
            self._button_order.insert(position, button.id)
        else:
            self._button_order.append(button.id)

        # Create and mount the button widget
        btn_widget = ActionBarButton(
            icon=button.icon,
            tooltip=button.tooltip,
            action_id=button.id,
            id=f"action-{button.id}",
            disabled=not button.enabled,
        )

        if not button.visible:
            btn_widget.display = False

        self.mount(btn_widget)

    def unregister_button(self, button_id: str) -> None:
        """Remove an action button.

        Args:
            button_id: ID of the button to remove
        """
        if button_id in self._buttons:
            del self._buttons[button_id]
            self._button_order.remove(button_id)

            try:
                btn = self.query_one(f"#action-{button_id}", ActionBarButton)
                btn.remove()
            except Exception:
                pass

    def set_button_visible(self, button_id: str, visible: bool) -> None:
        """Show or hide a button.

        Args:
            button_id: ID of the button
            visible: Whether to show the button
        """
        if button_id in self._buttons:
            self._buttons[button_id].visible = visible
            try:
                btn = self.query_one(f"#action-{button_id}", ActionBarButton)
                btn.display = visible
            except Exception:
                pass

    def set_button_enabled(self, button_id: str, enabled: bool) -> None:
        """Enable or disable a button.

        Args:
            button_id: ID of the button
            enabled: Whether to enable the button
        """
        if button_id in self._buttons:
            self._buttons[button_id].enabled = enabled
            try:
                btn = self.query_one(f"#action-{button_id}", ActionBarButton)
                btn.disabled = not enabled
            except Exception:
                pass

    def set_button_active(self, button_id: str, active: bool) -> None:
        """Set a button's active state (visual highlight).

        Args:
            button_id: ID of the button
            active: Whether button should appear active
        """
        try:
            btn = self.query_one(f"#action-{button_id}", ActionBarButton)
            if active:
                btn.add_class("-active")
            else:
                btn.remove_class("-active")
        except Exception:
            pass

    def update_button_icon(self, button_id: str, icon: str) -> None:
        """Update a button's icon.

        Args:
            button_id: ID of the button
            icon: New icon to display
        """
        if button_id in self._buttons:
            self._buttons[button_id].icon = icon
            try:
                btn = self.query_one(f"#action-{button_id}", ActionBarButton)
                btn.label = icon
            except Exception:
                pass

    def add_separator(self) -> None:
        """Add a visual separator."""
        sep = Static("│", classes="action-separator")
        self.mount(sep)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press."""
        if isinstance(event.button, ActionBarButton):
            button_id = event.button.action_id

            # Call the callback if defined
            if button_id in self._buttons:
                button = self._buttons[button_id]
                if button.callback:
                    button.callback()

            # Also emit a message for flexible handling
            self.post_message(self.ButtonPressed(button_id))

    def clear(self) -> None:
        """Remove all buttons."""
        for btn_id in list(self._buttons.keys()):
            self.unregister_button(btn_id)

        # Also remove any separators
        for sep in self.query(".action-separator"):
            sep.remove()


# Standard action button definitions for common operations
STANDARD_BUTTONS = {
    "save": ActionButton(
        id="save",
        icon="💾",
        tooltip="Save (Alt+S)",
    ),
    "close": ActionButton(
        id="close",
        icon="✕",
        tooltip="Close",
    ),
    "minimize": ActionButton(
        id="minimize",
        icon="▽",
        tooltip="Minimize",
    ),
    "maximize": ActionButton(
        id="maximize",
        icon="□",
        tooltip="Maximize",
    ),
    "restore": ActionButton(
        id="restore",
        icon="❐",
        tooltip="Restore",
        visible=False,  # Hidden by default, shown when maximized
    ),
    "split": ActionButton(
        id="split",
        icon="⊞",
        tooltip="Split terminal",
    ),
}
