"""Workspace panel with Editor, Diff, and Terminal tabs."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import ContentSwitcher, Tab, Tabs

from clide.models.diff import DiffContent
from clide.widgets.components.action_bar import ActionBar, ActionButton
from clide.widgets.components.diff_pane import DiffPane
from clide.widgets.components.editor_pane import EditorPane
from clide.widgets.components.terminal_pane import TerminalPane


class WorkspacePanel(Vertical):
    """Center workspace panel with Editor, Diff, and Terminal tabs.

    Hidden by default. Shows when:
    - File is opened
    - Diff is displayed
    - Terminal is activated
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

    WorkspacePanel ContentSwitcher {
        height: 1fr;
    }

    WorkspacePanel #pane-editor,
    WorkspacePanel #pane-diff,
    WorkspacePanel #pane-terminal {
        height: 100%;
        padding: 0;
    }
    """

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

        pass

    # Reactive state - persisted when hidden
    visible: reactive[bool] = reactive(False)
    active_tab: reactive[str] = reactive("editor")
    maximized: reactive[bool] = reactive(False)

    # Messages for app-level actions
    class MaximizeRequested(Message):
        """Emitted when workspace should be maximized."""

        pass

    class RestoreRequested(Message):
        """Emitted when workspace should be restored from maximized."""

        pass

    def __init__(
        self,
        workdir: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._workdir = workdir or Path.cwd()
        self.id = "panel-workspace"
        self._action_bar: ActionBar | None = None

    def compose(self) -> ComposeResult:
        # Header row with tabs and action bar
        with Horizontal(id="workspace-header"):
            yield Tabs(
                Tab("Editor", id="tab-editor"),
                Tab("Diff", id="tab-diff"),
                Tab("Terminal", id="tab-terminal"),
                id="workspace-tabs",
            )
            self._action_bar = ActionBar(id="workspace-action-bar")
            yield self._action_bar

        # Content area
        with ContentSwitcher(id="workspace-content", initial="pane-editor"):
            with Vertical(id="pane-editor"):
                yield EditorPane(id="editor-pane")
            with Vertical(id="pane-diff"):
                yield DiffPane(id="diff-pane")
            with Vertical(id="pane-terminal"):
                yield TerminalPane(cwd=self._workdir, id="terminal-pane")

    def on_mount(self) -> None:
        """Set initial visibility and configure action bar."""
        self._update_visibility()
        self._setup_action_bar()

    def _setup_action_bar(self) -> None:
        """Set up the action bar with standard buttons."""
        if self._action_bar is None:
            return

        # Register standard buttons using simple ASCII icons
        # Save button (for editor)
        self._action_bar.register_button(
            ActionButton(
                id="save",
                icon="[S]",
                tooltip="Save",
            )
        )

        # Add separator
        self._action_bar.add_separator()

        # Close button
        self._action_bar.register_button(
            ActionButton(
                id="close",
                icon="x",
                tooltip="Close",
            )
        )

        # Minimize button
        self._action_bar.register_button(
            ActionButton(
                id="minimize",
                icon="_",
                tooltip="Minimize",
            )
        )

        # Maximize button
        self._action_bar.register_button(
            ActionButton(
                id="maximize",
                icon="^",
                tooltip="Maximize",
            )
        )

        # Restore button (hidden by default)
        self._action_bar.register_button(
            ActionButton(
                id="restore",
                icon="v",
                tooltip="Restore",
                visible=False,
            )
        )

        # Update button visibility based on current tab
        self._update_action_bar_for_tab(self.active_tab)

    def _update_action_bar_for_tab(self, tab: str) -> None:
        """Update action bar buttons based on active tab."""
        if self._action_bar is None:
            return

        # Save button only visible for editor
        self._action_bar.set_button_visible("save", tab == "editor")

        # Update save button enabled state based on editor modified state
        if tab == "editor":
            try:
                editor = self.query_one("#editor-pane", EditorPane)
                self._action_bar.set_button_enabled("save", editor.modified)
            except Exception:
                self._action_bar.set_button_enabled("save", False)

    def watch_maximized(self, maximized: bool) -> None:
        """Handle maximize state changes."""
        if self._action_bar is None:
            return

        # Toggle maximize/restore button visibility
        self._action_bar.set_button_visible("maximize", not maximized)
        self._action_bar.set_button_visible("restore", maximized)

        # Update CSS class
        if maximized:
            self.add_class("maximized")
        else:
            self.remove_class("maximized")

    def on_action_bar_button_pressed(self, event: ActionBar.ButtonPressed) -> None:
        """Handle action bar button presses."""
        button_id = event.button_id

        if button_id == "save":
            self._action_save()
        elif button_id == "close":
            self._action_close()
        elif button_id == "minimize":
            self._action_minimize()
        elif button_id == "maximize":
            self._action_maximize()
        elif button_id == "restore":
            self._action_restore()

    def _action_save(self) -> None:
        """Save the current file in editor."""
        try:
            editor = self.query_one("#editor-pane", EditorPane)
            editor.save()
        except Exception as e:
            self.app.notify(f"Save failed: {e}", severity="error")

    def _action_close(self) -> None:
        """Close the workspace panel."""
        self.post_message(self.CloseRequested())
        self.hide()

    def _action_minimize(self) -> None:
        """Minimize (hide) the workspace panel."""
        self.hide()

    def _action_maximize(self) -> None:
        """Maximize the workspace panel."""
        self.maximized = True
        self.post_message(self.MaximizeRequested())

    def _action_restore(self) -> None:
        """Restore from maximized state."""
        self.maximized = False
        self.post_message(self.RestoreRequested())

    def on_tabs_tab_activated(self, event: Tabs.TabActivated) -> None:
        """Handle tab switches to update action bar and content."""
        # Extract tab name from tab id (e.g., "tab-editor" -> "editor")
        tab_id = event.tab.id
        if tab_id and tab_id.startswith("tab-"):
            tab_name = tab_id.replace("tab-", "")
            self.active_tab = tab_name
            self._update_action_bar_for_tab(tab_name)

            # Switch content
            try:
                content = self.query_one("#workspace-content", ContentSwitcher)
                content.current = f"pane-{tab_name}"
            except Exception:
                pass

    def watch_visible(self, visible: bool) -> None:
        """Handle visibility changes - hide, don't destroy."""
        self._update_visibility()

    def _update_visibility(self) -> None:
        """Update display based on visibility state."""
        if self.visible:
            self.remove_class("hidden")
        else:
            self.add_class("hidden")

    def show(self, tab: str | None = None) -> None:
        """Show workspace, optionally focusing a specific tab."""
        self.visible = True
        if tab:
            self.focus_tab(tab)

    def hide(self) -> None:
        """Hide workspace (state is preserved)."""
        self.visible = False

    def toggle(self) -> None:
        """Toggle workspace visibility."""
        self.visible = not self.visible

    def focus_tab(self, tab_id: str) -> None:
        """Focus a specific tab."""
        try:
            # Activate the tab
            tabs = self.query_one("#workspace-tabs", Tabs)
            tabs.active = f"tab-{tab_id}"

            # Switch content
            content = self.query_one("#workspace-content", ContentSwitcher)
            content.current = f"pane-{tab_id}"

            self.active_tab = tab_id
            self._update_action_bar_for_tab(tab_id)
        except Exception:
            pass

    # Editor methods
    def open_file(self, path: Path, line: int | None = None) -> None:
        """Open a file in the editor tab."""
        self.show("editor")
        try:
            editor = self.query_one("#editor-pane", EditorPane)
            editor.load_file(path, goto_line=line)
        except Exception:
            pass

    def get_current_file(self) -> Path | None:
        """Get the currently open file."""
        try:
            editor = self.query_one("#editor-pane", EditorPane)
            return editor.current_file
        except Exception:
            return None

    def has_unsaved_changes(self) -> bool:
        """Check if editor has unsaved changes."""
        try:
            editor = self.query_one("#editor-pane", EditorPane)
            return editor.modified
        except Exception:
            return False

    # Diff methods
    def show_diff(
        self,
        diff: DiffContent,
        is_proposal: bool = False,
    ) -> None:
        """Show a diff in the diff tab."""
        self.show("diff")
        try:
            diff_pane = self.query_one("#diff-pane", DiffPane)
            diff_pane.load_diff(diff, is_proposal)
        except Exception:
            pass

    def clear_diff(self) -> None:
        """Clear the diff view."""
        try:
            diff_pane = self.query_one("#diff-pane", DiffPane)
            diff_pane.clear()
        except Exception:
            pass

    # Terminal methods
    def show_terminal(self) -> None:
        """Show and focus the terminal tab."""
        self.show("terminal")
        try:
            terminal = self.query_one("#terminal-pane", TerminalPane)
            terminal.focus_terminal()
        except Exception:
            pass

    # Event forwarding
    def on_editor_pane_file_saved(self, event: EditorPane.FileSaved) -> None:
        """Forward file save event."""
        self.post_message(self.FileSaved(event.path))

    def on_diff_pane_accept_clicked(self, event: DiffPane.AcceptClicked) -> None:
        """Forward diff accept event."""
        self.post_message(self.DiffAccepted(event.file_path))

    def on_diff_pane_reject_clicked(self, event: DiffPane.RejectClicked) -> None:
        """Forward diff reject event."""
        self.post_message(self.DiffRejected(event.file_path))
