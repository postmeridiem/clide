"""Git graph visualization component."""

from rich.markup import escape
from textual.app import ComposeResult
from textual.message import Message
from textual.widgets import ListView, Static

from clide.models.git import GitCommit
from clide.widgets.components.tile_list import TileItem, TileListView


class CommitItem(TileItem):
    """A single commit item displayed as a tile."""

    COMMIT = "●"
    MERGE = "◆"

    def __init__(self, commit: GitCommit) -> None:
        super().__init__()
        self.commit = commit

    def compose(self) -> ComposeResult:
        symbol = self.MERGE if self.commit.is_merge else self.COMMIT

        # Format refs (branches, tags)
        refs_str = ""
        if self.commit.refs:
            refs = ", ".join(self.commit.refs)
            refs_str = f" [bold cyan]({escape(refs)})[/]"

        # Truncate message
        message = self.commit.message[:60]
        if len(self.commit.message) > 60:
            message += "..."

        # Multi-line tile format
        yield Static(
            f"[bold yellow]{symbol}[/] [bold]{escape(message)}[/]{refs_str}\n"
            f"  [dim]{self.commit.short_hash} · {escape(self.commit.author)} · {self.commit.date}[/]",
            markup=True,
        )


class GitGraphView(TileListView):
    """View for git commit graph visualization."""

    class CommitSelected(Message):
        """Emitted when a commit is selected."""

        def __init__(self, commit: GitCommit) -> None:
            self.commit = commit
            super().__init__()

    def __init__(self, commits: list[GitCommit] | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._commits = commits or []

    def compose(self) -> ComposeResult:
        yield ListView(
            *[CommitItem(c) for c in self._commits],
            id="commit-list",
        )

    def update_commits(self, commits: list[GitCommit]) -> None:
        """Update the commit list."""
        self._commits = commits
        try:
            commit_list = self.query_one("#commit-list", ListView)
            commit_list.clear()
            for commit in commits:
                commit_list.append(CommitItem(commit))
        except Exception:
            pass

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle commit selection."""
        if isinstance(event.item, CommitItem):
            self.post_message(self.CommitSelected(event.item.commit))
