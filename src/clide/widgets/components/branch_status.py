"""Branch status bar component."""

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.message import Message
from textual.widgets import Button, Label, ListItem, ListView, Static

from clide.models.git import GitBranch


class BranchStatus(Vertical):
    """Branch status bar with popout branch selector."""

    DEFAULT_CSS = """
    BranchStatus {
        height: auto;
        dock: bottom;
    }

    BranchStatus .status-bar {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    BranchStatus .branch-icon {
        width: 2;
    }

    BranchStatus .branch-name {
        width: 1fr;
    }

    BranchStatus .popout {
        display: none;
        height: auto;
        max-height: 15;
        background: $panel;
        border: solid $primary;
        layer: popout;
    }

    BranchStatus .popout.visible {
        display: block;
    }

    BranchStatus .popout-header {
        background: $surface;
        padding: 0 1;
        text-style: bold;
    }

    BranchStatus .popout-actions {
        height: 1;
        padding: 0 1;
    }
    """

    class BranchChanged(Message):
        """Emitted when branch is changed."""

        def __init__(self, branch: str) -> None:
            self.branch = branch
            super().__init__()

    # Alias for backwards compatibility
    BranchChangeRequested = BranchChanged

    class NewBranchRequested(Message):
        """Emitted when new branch creation is requested."""
        pass

    def __init__(
        self,
        current_branch: str = "main",
        branches: list[GitBranch] | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._current = current_branch
        self._branches = branches or []
        self._popout_visible = False

    def compose(self) -> ComposeResult:
        with Horizontal(classes="status-bar"):
            yield Static("⎇", classes="branch-icon")
            yield Static(self._current, classes="branch-name", id="branch-name")
            yield Static("▾", classes="toggle-icon")

        with Vertical(classes="popout", id="branch-popout"):
            yield Label("Recent branches", classes="popout-header")
            yield ListView(
                *[ListItem(Label(b.name)) for b in self._branches[:5]],
                id="branch-list",
            )
            with Horizontal(classes="popout-actions"):
                yield Button("Checkout", id="btn-checkout", variant="primary")
                yield Button("New", id="btn-new")

    @property
    def branch(self) -> str:
        """Get current branch."""
        return self._current

    @branch.setter
    def branch(self, value: str) -> None:
        """Set current branch."""
        self._current = value
        try:
            self.query_one("#branch-name", Static).update(value)
        except Exception:
            pass

    def update_branch(self, branch: str) -> None:
        """Update current branch display."""
        self.branch = branch

    def update_branches(self, branches: list[GitBranch] | list[str]) -> None:
        """Update branches list."""
        self._branches = branches  # type: ignore
        try:
            branch_list = self.query_one("#branch-list", ListView)
            branch_list.clear()
            for branch in branches[:5]:
                if isinstance(branch, str):
                    name = branch
                    is_current = name == self._current
                else:
                    name = branch.name
                    is_current = branch.is_current
                marker = "● " if is_current else "○ "
                branch_list.append(ListItem(Label(f"{marker}{name}")))
        except Exception:
            pass

    def toggle_popout(self) -> None:
        """Toggle popout visibility."""
        self._popout_visible = not self._popout_visible
        popout = self.query_one("#branch-popout")
        if self._popout_visible:
            popout.add_class("visible")
        else:
            popout.remove_class("visible")

    def on_click(self) -> None:
        """Handle click on status bar."""
        self.toggle_popout()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "btn-checkout":
            branch_list = self.query_one("#branch-list", ListView)
            if branch_list.highlighted_child:
                # Get selected branch name
                label = branch_list.highlighted_child.query_one(Label)
                branch = label.renderable.plain.lstrip("● ○ ")
                self.post_message(self.BranchChangeRequested(branch))
                self.toggle_popout()
        elif event.button.id == "btn-new":
            self.post_message(self.NewBranchRequested())
            self.toggle_popout()
