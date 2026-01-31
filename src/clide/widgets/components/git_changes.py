"""Git changes view component."""

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Label, ListItem, ListView, Static

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

    def __init__(self, change: GitChange) -> None:
        super().__init__()
        self.change = change

    def compose(self) -> ComposeResult:
        icon = self.STATUS_ICONS.get(self.change.status, "?")
        status_class = self.change.status.value
        yield Static(
            f"[{status_class}]{icon}[/] {self.change.path}",
            markup=True,
        )


class GitChangesView(Vertical):
    """View for staged and unstaged git changes."""

    DEFAULT_CSS = """
    GitChangesView {
        height: 100%;
    }

    GitChangesView .section-header {
        background: $surface;
        padding: 0 1;
        text-style: bold;
    }

    GitChangesView ListView {
        height: auto;
        max-height: 50%;
    }

    GitChangesView .added { color: $success; }
    GitChangesView .modified { color: $warning; }
    GitChangesView .deleted { color: $error; }
    GitChangesView .untracked { color: $accent; }
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
