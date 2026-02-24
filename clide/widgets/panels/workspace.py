"""Workspace panel with dynamic tabbed Editor, Diff, and Terminal panes."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from textual import events
from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Static, Tab, Tabs

from clide.models.workspace import TAB_ICONS, TabInfo, TabType
from clide.widgets.components.action_bar import ActionBar, ActionButton
from clide.widgets.components.diff_pane import DiffPane
from clide.widgets.components.editor_pane import EditorPane
from clide.widgets.components.terminal_pane import TerminalPane

if TYPE_CHECKING:
    from clide.models.diff import DiffContent


class ClosableTab(Tab):
    """Tab with a type icon prefix and close button."""

    class CloseClicked(Message):
        """Posted when the close region of a tab is clicked."""

        def __init__(self, tab_id: str) -> None:
            self.tab_id = tab_id
            super().__init__()

    def __init__(
        self,
        label: str,
        *,
        tab_type: TabType | None = None,
        closable: bool = True,
        id: str | None = None,
        **kwargs,
    ) -> None:
        self._base_label = label
        self._tab_type = tab_type
        self._closable = closable
        display_label = self._build_label(label, tab_type, closable)
        super().__init__(display_label, id=id, **kwargs)

    @staticmethod
    def _build_label(label: str, tab_type: TabType | None, closable: bool) -> str:
        """Build the display label with icon prefix and close indicator."""
        parts: list[str] = []
        if tab_type:
            icon = TAB_ICONS.get(tab_type, "")
            if icon:
                parts.append(icon)
        parts.append(label)
        if closable:
            parts.append("×")
        return " ".join(parts)

    def update_label(self, label: str) -> None:
        """Update the tab label, preserving icon and close button."""
        self._base_label = label
        self.label = self._build_label(label, self._tab_type, self._closable)

    def _on_click(self, event: events.Click) -> None:
        """Detect click on the close region (rightmost 2 chars)."""
        if self._closable and event.x >= self.size.width - 3:
            event.stop()
            self.post_message(self.CloseClicked(self.id or ""))
        else:
            super()._on_click()


class NewTabButton(Static):
    """A + button for creating new tabs."""

    DEFAULT_CSS = """
    NewTabButton {
        width: 3;
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }

    NewTabButton:hover {
        color: $text;
        background: $surface;
    }
    """

    class Clicked(Message):
        """Posted when the new tab button is clicked."""

    def __init__(self, **kwargs) -> None:
        super().__init__("+", **kwargs)

    def on_click(self) -> None:
        self.post_message(self.Clicked())


class WorkspacePanel(Vertical):
    """Center workspace panel with dynamic tabbed panes.

    Supports multiple editor, terminal, and diff tabs. Hidden by default.
    Shows when a file is opened, diff is displayed, or terminal is activated.
    """

    DEFAULT_CSS = """
    WorkspacePanel {
        height: 60%;
        background: $background;
    }

    WorkspacePanel.hidden {
        display: none;
    }

    WorkspacePanel.maximized {
        height: 100%;
    }

    /* Header row with tabs and action bar */
    WorkspacePanel #workspace-header {
        height: auto;
        width: 100%;
        background: $surface;
    }

    WorkspacePanel #workspace-header Tabs {
        width: 1fr;
    }

    WorkspacePanel #workspace-header #workspace-action-bar {
        width: auto;
        height: auto;
        padding: 0 1;
    }

    WorkspacePanel #workspace-header ActionBarButton {
        height: 1;
        min-width: 3;
        margin: 0;
        padding: 0;
    }

    WorkspacePanel #workspace-content {
        height: 1fr;
    }

    WorkspacePanel #workspace-content > * {
        height: 100%;
        padding: 0;
    }
    """

    # -- Messages --

    class FileSaved(Message):
        """Emitted when a file is saved."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    class DiffAccepted(Message):
        """Emitted when a diff is accepted."""

        def __init__(self, file_path: str) -> None:
            self.file_path = file_path
            super().__init__()

    class DiffRejected(Message):
        """Emitted when a diff is rejected."""

        def __init__(self, file_path: str) -> None:
            self.file_path = file_path
            super().__init__()

    class CloseRequested(Message):
        """Emitted when workspace should be hidden."""

    class MaximizeRequested(Message):
        """Emitted when workspace should be maximized."""

    class RestoreRequested(Message):
        """Emitted when workspace should be restored from maximized."""

    # -- Reactive state --

    visible: reactive[bool] = reactive(False)
    maximized: reactive[bool] = reactive(False)

    def __init__(
        self,
        workdir: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._workdir = workdir or Path.cwd()
        self.id = "panel-workspace"
        self._action_bar: ActionBar | None = None

        # Tab management
        self._tab_counter: int = 0
        self._tab_registry: dict[str, TabInfo] = {}
        self._file_to_tab: dict[Path, str] = {}  # resolved path → tab_id
        self._terminal_count: int = 0
        self._pane_widgets: dict[str, Widget] = {}  # tab_id → pane widget

    # -- Compose --

    def compose(self) -> ComposeResult:
        with Horizontal(id="workspace-header"):
            yield Tabs(id="workspace-tabs")
            yield NewTabButton(id="new-tab-btn")
            self._action_bar = ActionBar(id="workspace-action-bar")
            yield self._action_bar

        yield Container(id="workspace-content")

    def on_mount(self) -> None:
        """Set initial visibility and configure action bar."""
        self._update_visibility()
        self._setup_action_bar()

    # -- Action bar --

    def _setup_action_bar(self) -> None:
        """Set up the action bar with window control buttons only."""
        if self._action_bar is None:
            return

        self._action_bar.register_button(ActionButton(id="minimize", icon="_", tooltip="Minimize"))
        self._action_bar.register_button(ActionButton(id="maximize", icon="^", tooltip="Maximize"))
        self._action_bar.register_button(
            ActionButton(id="restore", icon="v", tooltip="Restore", visible=False)
        )
        self._action_bar.register_button(
            ActionButton(id="close", icon="x", tooltip="Close workspace")
        )

    def on_action_bar_button_pressed(self, event: ActionBar.ButtonPressed) -> None:
        """Handle action bar button presses."""
        actions = {
            "close": self._action_close,
            "minimize": self._action_minimize,
            "maximize": self._action_maximize,
            "restore": self._action_restore,
        }
        action = actions.get(event.button_id)
        if action:
            action()

    # -- Tab management internals --

    def _generate_tab_id(self, tab_type: TabType) -> str:
        self._tab_counter += 1
        return f"ws-{tab_type.value}-{self._tab_counter}"

    def _add_tab(
        self,
        tab_type: TabType,
        label: str,
        pane_widget: Widget,
        *,
        file_path: Path | None = None,
        is_proposal: bool = False,
        diff_file_path: str | None = None,
    ) -> str:
        """Create a new tab and mount its pane widget."""
        tab_id = self._generate_tab_id(tab_type)

        # Register metadata
        info = TabInfo(
            tab_id=tab_id,
            tab_type=tab_type,
            label=label,
            file_path=file_path,
            is_proposal=is_proposal,
            diff_file_path=diff_file_path,
        )
        self._tab_registry[tab_id] = info
        self._pane_widgets[tab_id] = pane_widget

        if file_path:
            self._file_to_tab[file_path.resolve()] = tab_id

        # Create the tab widget
        tab = ClosableTab(label, tab_type=tab_type, id=tab_id)
        tabs = self.query_one("#workspace-tabs", Tabs)
        tabs.add_tab(tab)

        # Mount the pane (hidden by default)
        pane_widget.display = False
        content = self.query_one("#workspace-content", Container)
        content.mount(pane_widget)

        # Activate this tab
        tabs.active = tab_id
        return tab_id

    def _remove_tab(self, tab_id: str) -> None:
        """Remove a tab and destroy its pane widget."""
        if tab_id not in self._tab_registry:
            return

        info = self._tab_registry.pop(tab_id)
        pane = self._pane_widgets.pop(tab_id, None)

        # Clean up file index
        if info.file_path:
            resolved = info.file_path.resolve()
            if resolved in self._file_to_tab:
                del self._file_to_tab[resolved]

        # Stop terminal PTY before removal
        if info.tab_type == TabType.TERMINAL and pane:
            try:
                terminal = pane if isinstance(pane, TerminalPane) else None
                if terminal:
                    terminal.stop()
            except Exception:
                pass

        # Remove the tab from the tab bar
        try:
            tabs = self.query_one("#workspace-tabs", Tabs)
            tabs.remove_tab(tab_id)
        except Exception:
            pass

        # Remove and destroy the pane widget
        if pane:
            try:
                pane.remove()
            except Exception:
                pass

        # If no tabs remain, hide workspace
        if not self._tab_registry:
            self.hide()
            self.post_message(self.CloseRequested())

    def _activate_tab(self, tab_id: str) -> None:
        """Activate a specific tab."""
        if tab_id not in self._tab_registry:
            return
        try:
            tabs = self.query_one("#workspace-tabs", Tabs)
            tabs.active = tab_id
        except Exception:
            pass

    def _get_pane(self, tab_id: str) -> Widget | None:
        """Get the pane widget for a tab."""
        return self._pane_widgets.get(tab_id)

    # -- Tab events --

    def on_tabs_tab_activated(self, event: Tabs.TabActivated) -> None:
        """Handle tab switches: show active pane, hide others."""
        tab_id = event.tab.id
        if not tab_id or tab_id not in self._tab_registry:
            return

        # Show only the active pane
        for tid, pane in self._pane_widgets.items():
            pane.display = tid == tab_id

        # Focus terminal if it's a terminal tab
        info = self._tab_registry[tab_id]
        if info.tab_type == TabType.TERMINAL:
            pane = self._pane_widgets.get(tab_id)
            if isinstance(pane, TerminalPane):
                pane.focus_terminal()

    def on_closable_tab_close_clicked(self, event: ClosableTab.CloseClicked) -> None:
        """Handle tab close button clicks."""
        self._remove_tab(event.tab_id)

    def on_new_tab_button_clicked(self, _event: NewTabButton.Clicked) -> None:
        """Handle + button: create a new terminal tab."""
        self.new_terminal()

    # -- Visibility --

    def watch_visible(self, visible: bool) -> None:
        """Handle visibility changes - hide, don't destroy."""
        self._update_visibility()

    def _update_visibility(self) -> None:
        if self.visible:
            self.remove_class("hidden")
        else:
            self.add_class("hidden")

    def watch_maximized(self, maximized: bool) -> None:
        """Handle maximize state changes."""
        if self._action_bar:
            self._action_bar.set_button_visible("maximize", not maximized)
            self._action_bar.set_button_visible("restore", maximized)
        if maximized:
            self.add_class("maximized")
        else:
            self.remove_class("maximized")

    # -- Window actions --

    def _action_close(self) -> None:
        self.post_message(self.CloseRequested())
        self.hide()

    def _action_minimize(self) -> None:
        self.hide()

    def _action_maximize(self) -> None:
        self.maximized = True
        self.post_message(self.MaximizeRequested())

    def _action_restore(self) -> None:
        self.maximized = False
        self.post_message(self.RestoreRequested())

    # -- Public API --

    def show(self, tab: str | None = None) -> None:
        """Show workspace, optionally activating a tab by ID."""
        self.visible = True
        if tab and tab in self._tab_registry:
            self._activate_tab(tab)

    def hide(self) -> None:
        """Hide workspace (all state preserved)."""
        self.visible = False

    def toggle(self) -> None:
        """Toggle workspace visibility."""
        self.visible = not self.visible

    def open_file(self, path: Path, line: int | None = None) -> str:
        """Open a file in an editor tab. Reuses existing tab for same path."""
        self.visible = True

        resolved = path.resolve()
        if resolved in self._file_to_tab:
            tab_id = self._file_to_tab[resolved]
            self._activate_tab(tab_id)
            if line is not None:
                pane = self._pane_widgets.get(tab_id)
                if isinstance(pane, EditorPane):
                    from textual.widgets import TextArea

                    try:
                        textarea = pane.query_one(TextArea)
                        textarea.cursor_location = (line - 1, 0)
                    except Exception:
                        pass
            return tab_id

        editor = EditorPane()
        tab_id = self._add_tab(
            TabType.EDITOR,
            label=path.name,
            pane_widget=editor,
            file_path=resolved,
        )
        self.call_after_refresh(lambda: editor.load_file(path, goto_line=line))
        return tab_id

    def show_diff(self, diff: DiffContent, is_proposal: bool = False) -> str:
        """Open a diff in a new tab."""
        self.visible = True

        diff_pane = DiffPane(diff=diff, is_proposal=is_proposal)
        label = f"Diff: {Path(diff.file_path).name}"
        tab_id = self._add_tab(
            TabType.DIFF,
            label=label,
            pane_widget=diff_pane,
            is_proposal=is_proposal,
            diff_file_path=diff.file_path,
        )
        return tab_id

    def show_terminal(self) -> str:
        """Show existing terminal or create first one."""
        self.visible = True

        # Find an existing terminal tab
        for tab_id, info in self._tab_registry.items():
            if info.tab_type == TabType.TERMINAL:
                self._activate_tab(tab_id)
                return tab_id

        return self.new_terminal()

    def new_terminal(self) -> str:
        """Create a new terminal tab."""
        self.visible = True
        self._terminal_count += 1

        terminal = TerminalPane(cwd=self._workdir)
        label = f"Terminal {self._terminal_count}" if self._terminal_count > 1 else "Terminal"
        tab_id = self._add_tab(
            TabType.TERMINAL,
            label=label,
            pane_widget=terminal,
        )
        return tab_id

    def close_tab(self, tab_id: str | None = None) -> None:
        """Close a tab. If tab_id is None, close the active tab."""
        if tab_id is None:
            try:
                tabs = self.query_one("#workspace-tabs", Tabs)
                tab_id = tabs.active
            except Exception:
                return
        if tab_id:
            self._remove_tab(tab_id)

    def get_active_tab_type(self) -> str | None:
        """Get the type of the active tab."""
        try:
            tabs = self.query_one("#workspace-tabs", Tabs)
            active = tabs.active
            if active and active in self._tab_registry:
                return self._tab_registry[active].tab_type.value
        except Exception:
            pass
        return None

    def get_current_file(self) -> Path | None:
        """Get the file in the active editor tab."""
        try:
            tabs = self.query_one("#workspace-tabs", Tabs)
            active = tabs.active
            if active and active in self._tab_registry:
                info = self._tab_registry[active]
                if info.tab_type == TabType.EDITOR:
                    return info.file_path
        except Exception:
            pass
        return None

    def has_unsaved_changes(self) -> bool:
        """Check if any editor tab has unsaved changes."""
        for tab_id, info in self._tab_registry.items():
            if info.tab_type == TabType.EDITOR:
                pane = self._pane_widgets.get(tab_id)
                if isinstance(pane, EditorPane) and pane.modified:
                    return True
        return False

    def save_active_editor(self) -> None:
        """Save the active editor tab."""
        try:
            tabs = self.query_one("#workspace-tabs", Tabs)
            active = tabs.active
            if active and active in self._tab_registry:
                info = self._tab_registry[active]
                if info.tab_type == TabType.EDITOR:
                    pane = self._pane_widgets.get(active)
                    if isinstance(pane, EditorPane):
                        pane.save()
        except Exception:
            pass

    def focus_last_editor(self) -> None:
        """Focus the most recent editor tab."""
        for tab_id in reversed(list(self._tab_registry)):
            info = self._tab_registry[tab_id]
            if info.tab_type == TabType.EDITOR:
                self._activate_tab(tab_id)
                return

    def focus_tab(self, tab_id: str) -> None:
        """Focus a specific tab by ID. Legacy compat."""
        self._activate_tab(tab_id)

    def clear_diff(self) -> None:
        """Close all non-proposal diff tabs."""
        to_remove = [
            tab_id
            for tab_id, info in self._tab_registry.items()
            if info.tab_type == TabType.DIFF and not info.is_proposal
        ]
        for tab_id in to_remove:
            self._remove_tab(tab_id)

    # -- Event forwarding --

    def on_editor_pane_file_saved(self, event: EditorPane.FileSaved) -> None:
        """Forward file save and update tab label."""
        self.post_message(self.FileSaved(event.path))
        # Update the tab label (remove modified indicator)
        resolved = event.path.resolve()
        if resolved in self._file_to_tab:
            tab_id = self._file_to_tab[resolved]
            try:
                tab = self.query_one(f"#{tab_id}", ClosableTab)
                tab.update_label(event.path.name)
            except Exception:
                pass

    def on_editor_pane_content_changed(self, event: EditorPane.ContentChanged) -> None:
        """Update tab label with modified indicator when content changes."""
        resolved = event.path.resolve()
        if resolved in self._file_to_tab:
            tab_id = self._file_to_tab[resolved]
            try:
                tab = self.query_one(f"#{tab_id}", ClosableTab)
                tab.update_label(f"● {event.path.name}")
            except Exception:
                pass

    def on_diff_pane_accept_clicked(self, event: DiffPane.AcceptClicked) -> None:
        """Forward diff accept and close the diff tab."""
        self.post_message(self.DiffAccepted(event.file_path))
        # Find and close the diff tab
        for tab_id, info in list(self._tab_registry.items()):
            if info.tab_type == TabType.DIFF and info.diff_file_path == event.file_path:
                self._remove_tab(tab_id)
                break

    def on_diff_pane_reject_clicked(self, event: DiffPane.RejectClicked) -> None:
        """Forward diff reject and close the diff tab."""
        self.post_message(self.DiffRejected(event.file_path))
        for tab_id, info in list(self._tab_registry.items()):
            if info.tab_type == TabType.DIFF and info.diff_file_path == event.file_path:
                self._remove_tab(tab_id)
                break
