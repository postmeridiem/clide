"""Workspace panel with Editor, Diff, and Terminal tabs."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import TabbedContent, TabPane

from clide.models.diff import DiffContent
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

    WorkspacePanel TabbedContent {
        height: 100%;
    }

    WorkspacePanel TabPane {
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

    class CommandSubmitted(Message):
        """Emitted when a terminal command is submitted."""

        def __init__(self, command: str) -> None:
            self.command = command
            super().__init__()

    class CloseRequested(Message):
        """Emitted when workspace should be hidden."""
        pass

    # Reactive state - persisted when hidden
    visible: reactive[bool] = reactive(False)
    active_tab: reactive[str] = reactive("editor")

    def __init__(
        self,
        workdir: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._workdir = workdir or Path.cwd()
        self.id = "panel-workspace"

    def compose(self) -> ComposeResult:
        with TabbedContent(id="workspace-tabs"):
            with TabPane("Editor", id="workspace-editor"):
                yield EditorPane(id="editor-pane")
            with TabPane("Diff", id="workspace-diff"):
                yield DiffPane(id="diff-pane")
            with TabPane("Terminal", id="workspace-terminal"):
                yield TerminalPane(cwd=self._workdir, id="terminal-pane")

    def on_mount(self) -> None:
        """Set initial visibility."""
        self._update_visibility()

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
        tabs = self.query_one("#workspace-tabs", TabbedContent)
        tabs.active = f"workspace-{tab_id}"
        self.active_tab = tab_id

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
            terminal_input = terminal.query_one("#terminal-input")
            terminal_input.focus()
        except Exception:
            pass

    def write_terminal_output(self, text: str, style: str = "output") -> None:
        """Write output to terminal."""
        try:
            terminal = self.query_one("#terminal-pane", TerminalPane)
            terminal.write_output(text, style)
        except Exception:
            pass

    def write_terminal_error(self, error: str) -> None:
        """Write error to terminal."""
        try:
            terminal = self.query_one("#terminal-pane", TerminalPane)
            terminal.write_error(error)
        except Exception:
            pass

    def clear_terminal(self) -> None:
        """Clear terminal output."""
        try:
            terminal = self.query_one("#terminal-pane", TerminalPane)
            terminal.clear()
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

    def on_terminal_pane_command_submitted(
        self,
        event: TerminalPane.CommandSubmitted,
    ) -> None:
        """Forward terminal command event."""
        self.post_message(self.CommandSubmitted(event.command))
