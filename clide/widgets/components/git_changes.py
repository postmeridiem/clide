"""Git changes view component."""

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.message import Message
from textual.widgets import Button, Label, ListItem, ListView, Static

from clide.models.git import ChangeStatus, GitChange


class GitChangeItem(ListItem):
    """A single git change item."""

    STATUS_ICONS = {
        ChangeStatus.ADDED: "+",
        ChangeStatus.MODIFIED: "~",
        ChangeStatus.DELETED: "-",
        ChangeStatus.RENAMED: "→",
        ChangeStatus.UNTRACKED: "?",
        ChangeStatus.COPIED: "C",
        ChangeStatus.UNMERGED: "!",
        ChangeStatus.IGNORED: "I",
    }

    # Map status to Rich color styles
    STATUS_COLORS = {
        ChangeStatus.ADDED: "green",
        ChangeStatus.MODIFIED: "yellow",
        ChangeStatus.DELETED: "red",
        ChangeStatus.RENAMED: "cyan",
        ChangeStatus.UNTRACKED: "magenta",
        ChangeStatus.COPIED: "cyan",
        ChangeStatus.UNMERGED: "red bold",
        ChangeStatus.IGNORED: "dim",
    }

    def __init__(self, change: GitChange) -> None:
        super().__init__()
        self.change = change

    def compose(self) -> ComposeResult:
        from rich.markup import escape

        icon = self.STATUS_ICONS.get(self.change.status, "?")
        color = self.STATUS_COLORS.get(self.change.status, "white")
        safe_path = escape(self.change.path)
        yield Static(
            f"[{color}]{icon}[/] {safe_path}",
            markup=True,
        )


class GitChangesView(Vertical):
    """View for staged and unstaged git changes."""

    DEFAULT_CSS = """
    GitChangesView {
        height: 1fr;
        background: $background;
    }

    GitChangesView .section-header {
        background: $surface;
        padding: 0 1;
        height: 1;
        text-style: bold;
        border-bottom: solid $primary;
    }

    GitChangesView ListView {
        height: 1fr;
        min-height: 3;
        scrollbar-size: 1 1;
        margin-bottom: 1;
    }

    GitChangesView #staged-list {
        background: $panel;
    }

    GitChangesView #staged-list ListItem:even {
        background: $panel;
    }

    GitChangesView #staged-list ListItem:odd {
        background: $surface;
    }

    GitChangesView #unstaged-list {
        background: $background;
    }

    GitChangesView #unstaged-list ListItem:even {
        background: $background;
    }

    GitChangesView #unstaged-list ListItem:odd {
        background: $panel;
    }

    GitChangesView ListItem {
        height: auto;
        padding: 0 1;
    }

    GitChangesView ListItem Static {
        width: 100%;
    }

    GitChangesView .action-bar {
        dock: bottom;
        height: 3;
        padding: 0 1;
        background: $surface;
        border-top: solid $primary;
    }

    GitChangesView .action-bar Button {
        min-width: 6;
    }
    """

    class FileClicked(Message):
        """Emitted when a file is clicked."""

        def __init__(self, change: GitChange) -> None:
            self.change = change
            super().__init__()

    class StageRequested(Message):
        """Emitted when staging is requested."""

        def __init__(self, path: str) -> None:
            self.path = path
            super().__init__()

    class UnstageRequested(Message):
        """Emitted when unstaging is requested."""

        def __init__(self, path: str) -> None:
            self.path = path
            super().__init__()

    class ClaudeActionRequested(Message):
        """Emitted when a Claude git action is requested."""

        def __init__(self, action: str) -> None:
            self.action = action  # "commit", "stash", "pull", "push"
            super().__init__()

    def __init__(
        self,
        staged: list[GitChange] | None = None,
        unstaged: list[GitChange] | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._staged = staged or []
        self._unstaged = unstaged or []

    def compose(self) -> ComposeResult:
        yield Label("Staged Changes", classes="section-header")
        yield ListView(
            *[GitChangeItem(c) for c in self._staged],
            id="staged-list",
        )
        yield Label("Changes", classes="section-header")
        yield ListView(
            *[GitChangeItem(c) for c in self._unstaged],
            id="unstaged-list",
        )
        with Horizontal(classes="action-bar"):
            yield Button("Commit", id="btn-commit", variant="primary")
            yield Button("Stash", id="btn-stash")
            yield Button("Pull", id="btn-pull")
            yield Button("Push", id="btn-push")

    def update_changes(
        self,
        staged: list[GitChange],
        unstaged: list[GitChange],
    ) -> None:
        """Update the changes lists."""
        self._staged = staged
        self._unstaged = unstaged

        staged_list = self.query_one("#staged-list", ListView)
        unstaged_list = self.query_one("#unstaged-list", ListView)

        staged_list.clear()
        for change in staged:
            staged_list.append(GitChangeItem(change))

        unstaged_list.clear()
        for change in unstaged:
            unstaged_list.append(GitChangeItem(change))

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle item selection."""
        if isinstance(event.item, GitChangeItem):
            self.post_message(self.FileClicked(event.item.change))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle action button clicks."""
        button_id = event.button.id
        action_map = {
            "btn-commit": "commit",
            "btn-stash": "stash",
            "btn-pull": "pull",
            "btn-push": "push",
        }
        if button_id in action_map:
            self.post_message(self.ClaudeActionRequested(action_map[button_id]))
