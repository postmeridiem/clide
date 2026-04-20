"""Sidebar panel with Files, Git, and Tree tabs."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import TabbedContent, TabPane

from clide.widgets.components.branch_status import BranchStatus
from clide.widgets.components.files_view import FilesView
from clide.widgets.components.git_changes import GitChangesView
from clide.widgets.components.git_graph import GitGraphView


class SidebarPanel(Vertical):
    """Left sidebar panel with file browser, git changes, and git graph."""

    DEFAULT_CSS = """
    SidebarPanel {
        width: 20%;
        min-width: 25;
        height: 100%;
        background: $surface;
    }

    SidebarPanel TabbedContent {
        height: 1fr;
    }

    SidebarPanel .sidebar-content {
        height: 1fr;
    }

    SidebarPanel TabbedContent {
        height: 1fr;
    }

    SidebarPanel TabPane {
        height: 1fr;
        padding: 0;
    }

    SidebarPanel BranchStatus {
        dock: bottom;
        height: auto;
    }
    """

    class FileSelected(Message):
        """Emitted when a file is selected from the file browser."""

        def __init__(self, path: Path) -> None:
            self.path = path
            super().__init__()

    class GitFileSelected(Message):
        """Emitted when a file is selected from git changes."""

        def __init__(self, path: Path, staged: bool) -> None:
            self.path = path
            self.staged = staged
            super().__init__()

    class BranchChanged(Message):
        """Emitted when the branch is changed."""

        def __init__(self, branch: str) -> None:
            self.branch = branch
            super().__init__()

    class ClaudeCommandRequested(Message):
        """Emitted when a Claude command is requested (e.g., /commit)."""

        def __init__(self, command: str) -> None:
            self.command = command
            super().__init__()

    # Reactive state
    current_branch: reactive[str] = reactive("main")
    visible: reactive[bool] = reactive(True)

    def __init__(
        self,
        workdir: Path | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._workdir = workdir or Path.cwd()
        self.id = "panel-sidebar"

    def compose(self) -> ComposeResult:
        with Container(classes="sidebar-content"), TabbedContent(id="sidebar-tabs"):
            with TabPane("Files", id="sidebar-files"):
                yield FilesView(path=self._workdir)
            with TabPane("Git", id="sidebar-git"):
                yield GitChangesView()
            with TabPane("Tree", id="sidebar-tree"):
                yield GitGraphView()
        yield BranchStatus(current_branch=self.current_branch)

    def watch_visible(self, visible: bool) -> None:
        """Handle visibility changes."""
        self.display = visible

    def watch_current_branch(self, branch: str) -> None:
        """Update branch status when branch changes."""
        try:
            branch_status = self.query_one(BranchStatus)
            branch_status.branch = branch
        except Exception:
            pass

    def update_git_status(
        self,
        staged: list,
        unstaged: list,
    ) -> None:
        """Update git changes view and branch stats."""
        try:
            git_view = self.query_one(GitChangesView)
            git_view.update_changes(staged, unstaged)
        except Exception:
            pass

        # Update branch status with staged/unstaged counts
        try:
            branch_status = self.query_one(BranchStatus)
            branch_status.update_stats(len(staged), len(unstaged))
        except Exception:
            pass

    def update_git_graph(self, commits: list) -> None:
        """Update git graph view."""
        try:
            graph = self.query_one(GitGraphView)
            graph.update_commits(commits)
        except Exception:
            pass

    def update_branches(self, branches: list[str]) -> None:
        """Update available branches."""
        try:
            branch_status = self.query_one(BranchStatus)
            branch_status.update_branches(branches)
        except Exception:
            pass

    def refresh_files(self) -> None:
        """Refresh file browser."""
        try:
            files_view = self.query_one(FilesView)
            files_view.reload()
        except Exception:
            pass

    def highlight_file(self, path: Path) -> None:
        """Highlight a file in the file browser.

        Used to show which file Claude is working with.
        """
        try:
            files_view = self.query_one(FilesView)
            files_view.highlight_path(path)
        except Exception:
            pass

    def focus_tab(self, tab_id: str) -> None:
        """Focus a specific tab."""
        tabs = self.query_one("#sidebar-tabs", TabbedContent)
        tabs.active = tab_id

    def on_files_view_file_selected(self, event: FilesView.FileSelected) -> None:
        """Forward file selection."""
        self.post_message(self.FileSelected(event.path))

    def on_git_changes_view_file_clicked(
        self,
        event: GitChangesView.FileClicked,
    ) -> None:
        """Forward git file selection."""
        self.post_message(self.GitFileSelected(Path(event.change.path), event.change.staged))

    def on_branch_status_branch_changed(
        self,
        event: BranchStatus.BranchChanged,
    ) -> None:
        """Forward branch change."""
        self.current_branch = event.branch
        self.post_message(self.BranchChanged(event.branch))

    def on_git_changes_view_claude_action_requested(
        self,
        event: GitChangesView.ClaudeActionRequested,
    ) -> None:
        """Forward Claude action request (commit, stash, pull, push)."""
        # Convert action to Claude skill command
        command = f"/{event.action}"
        self.post_message(self.ClaudeCommandRequested(command))
