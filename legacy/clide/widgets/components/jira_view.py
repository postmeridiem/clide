"""Jira view component for Jira CLI output."""

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Button, Markdown, Static


class JiraView(Vertical):
    """View for Jira CLI output."""

    DEFAULT_CSS = """
    JiraView {
        height: 1fr;
        background: $surface;
    }

    JiraView .jira-header {
        height: 1;
        background: $surface;
        padding: 0 1;
        border-bottom: solid $primary;
    }

    JiraView Markdown {
        height: 1fr;
        padding: 1;
        background: $background;
    }

    JiraView .jira-actions {
        height: auto;
        padding: 1;
        background: $surface;
        border-top: solid $primary;
    }

    JiraView .disabled-message {
        padding: 2;
        text-align: center;
        color: $warning;
        background: $panel;
    }
    """

    class RefreshRequested(Message):
        """Emitted when refresh is requested."""

        pass

    class IssueClicked(Message):
        """Emitted when an issue is clicked."""

        def __init__(self, issue_key: str) -> None:
            self.issue_key = issue_key
            super().__init__()

    def __init__(
        self,
        content: str = "",
        enabled: bool = True,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._content = content
        self._enabled = enabled

    def compose(self) -> ComposeResult:
        yield Static("Jira", classes="jira-header")

        if self._enabled:
            yield Markdown(self._content or "*Loading...*", id="jira-content")
            yield Button("↻ Refresh", id="btn-refresh", classes="jira-actions")
        else:
            yield Static(
                "Jira integration is disabled.\n\n"
                "Enable it in settings with CLIDE_JIRA_ENABLED=true",
                classes="disabled-message",
            )

    def update_content(self, content: str) -> None:
        """Update Jira output content."""
        self._content = content
        try:
            markdown = self.query_one("#jira-content", Markdown)
            markdown.update(content)
        except Exception:
            pass

    def set_loading(self) -> None:
        """Show loading state."""
        self.update_content("*Loading...*")

    def set_error(self, error: str) -> None:
        """Show error state."""
        self.update_content(f"**Error:** {error}")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "btn-refresh":
            self.set_loading()
            self.post_message(self.RefreshRequested())
