"""Diff pane component for viewing diffs."""

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.message import Message
from textual.widgets import Button, RichLog, Static

from clide.models.diff import ChangeType, DiffContent, DiffHunk


class DiffPane(Vertical):
    """Diff viewer pane with accept/reject for proposals."""

    DEFAULT_CSS = """
    DiffPane {
        height: 100%;
    }

    DiffPane .diff-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    DiffPane .diff-content {
        height: 1fr;
    }

    DiffPane .diff-actions {
        height: auto;
        padding: 1;
        background: $panel;
    }

    DiffPane .added {
        background: #1e3a1e;
        color: #4ec9b0;
    }

    DiffPane .removed {
        background: #3a1e1e;
        color: #f14c4c;
    }

    DiffPane .hunk-header {
        color: $accent;
        text-style: bold;
    }
    """

    class AcceptClicked(Message):
        """Emitted when accept is clicked."""

        def __init__(self, file_path: str) -> None:
            self.file_path = file_path
            super().__init__()

    class RejectClicked(Message):
        """Emitted when reject is clicked."""

        def __init__(self, file_path: str) -> None:
            self.file_path = file_path
            super().__init__()

    def __init__(
        self,
        diff: DiffContent | None = None,
        is_proposal: bool = False,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._diff = diff
        self._is_proposal = is_proposal

    def compose(self) -> ComposeResult:
        if self._diff:
            yield Static(f"Diff: {self._diff.file_path}", classes="diff-header")
        else:
            yield Static("No diff loaded", classes="diff-header")

        yield RichLog(id="diff-log", highlight=True, markup=True, classes="diff-content")

        if self._is_proposal:
            with Horizontal(classes="diff-actions"):
                yield Button("Accept", id="btn-accept", variant="success")
                yield Button("Reject", id="btn-reject", variant="error")

    def on_mount(self) -> None:
        """Render diff on mount."""
        self._render_diff()

    def load_diff(self, diff: DiffContent, is_proposal: bool = False) -> None:
        """Load a diff into the viewer."""
        self._diff = diff
        self._is_proposal = is_proposal

        # Update header
        header = self.query_one(".diff-header", Static)
        header.update(f"Diff: {diff.file_path}")

        # Show/hide action buttons
        try:
            actions = self.query_one(".diff-actions")
            actions.display = is_proposal
        except Exception:
            pass

        self._render_diff()

    def _render_diff(self) -> None:
        """Render the diff content."""
        log = self.query_one("#diff-log", RichLog)
        log.clear()

        if not self._diff:
            log.write("[dim]No diff to display[/]")
            return

        for hunk in self._diff.hunks:
            # Hunk header
            log.write(f"[hunk-header]{hunk.header}[/]")

            for line in hunk.lines:
                if line.change_type == ChangeType.ADDED:
                    log.write(f"[green]+{line.content}[/]")
                elif line.change_type == ChangeType.REMOVED:
                    log.write(f"[red]-{line.content}[/]")
                else:
                    log.write(f" {line.content}")

    def clear(self) -> None:
        """Clear the diff viewer."""
        self._diff = None
        log = self.query_one("#diff-log", RichLog)
        log.clear()

        header = self.query_one(".diff-header", Static)
        header.update("No diff loaded")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if not self._diff:
            return

        if event.button.id == "btn-accept":
            self.post_message(self.AcceptClicked(self._diff.file_path))
        elif event.button.id == "btn-reject":
            self.post_message(self.RejectClicked(self._diff.file_path))
