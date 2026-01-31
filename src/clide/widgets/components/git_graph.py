"""Git graph visualization component."""

from textual.app import ComposeResult
from textual.message import Message
from textual.widgets import RichLog, Static
from textual.containers import Vertical

from clide.models.git import GitCommit


class GitGraphView(Vertical):
    """View for git commit graph visualization."""

    DEFAULT_CSS = """
    GitGraphView {
        height: 100%;
    }

    GitGraphView RichLog {
        height: 100%;
        scrollbar-size: 1 1;
    }

    GitGraphView .commit-line {
        height: auto;
    }
    """

    # Graph drawing characters
    COMMIT = "●"
    MERGE = "◆"
    LINE = "│"
    BRANCH = "├"
    JOIN = "┴"

    class CommitSelected(Message):
        """Emitted when a commit is selected."""

        def __init__(self, commit: GitCommit) -> None:
            self.commit = commit
            super().__init__()

    def __init__(self, commits: list[GitCommit] | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._commits = commits or []

    def compose(self) -> ComposeResult:
        yield RichLog(id="graph-log", highlight=True, markup=True)

    def on_mount(self) -> None:
        """Render initial graph."""
        self._render_graph()

    def update_commits(self, commits: list[GitCommit]) -> None:
        """Update the commit list."""
        self._commits = commits
        self._render_graph()

    def _render_graph(self) -> None:
        """Render the commit graph."""
        log = self.query_one("#graph-log", RichLog)
        log.clear()

        for commit in self._commits:
            line = self._format_commit_line(commit)
            log.write(line)

    def _format_commit_line(self, commit: GitCommit) -> str:
        """Format a single commit line."""
        # Choose commit symbol
        symbol = self.MERGE if commit.is_merge else self.COMMIT

        # Format refs (branches, tags)
        refs_str = ""
        if commit.refs:
            refs = ", ".join(commit.refs)
            refs_str = f" [bold cyan]({refs})[/]"

        # Truncate message
        message = commit.message[:50]
        if len(commit.message) > 50:
            message += "..."

        return (
            f"[bold yellow]{symbol}[/] "
            f"[dim]{commit.short_hash}[/]"
            f"{refs_str} "
            f"{message} "
            f"[dim]- {commit.author}, {commit.date}[/]"
        )
