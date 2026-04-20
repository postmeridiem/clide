"""Jira controller for Jira CLI integration."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.services.process_service import ProcessService


@controller
class JiraController:
    """Controller for Jira CLI integration."""

    class JiraOutputUpdated(Message):
        """Emitted when Jira output is updated."""

        def __init__(self, output: str) -> None:
            self.output = output
            super().__init__()

    class JiraError(Message):
        """Emitted when Jira command fails."""

        def __init__(self, error: str) -> None:
            self.error = error
            super().__init__()

    def __init__(
        self,
        project_path: Path | None = None,
        jira_cli_path: str = "jira",
        enabled: bool = False,
    ) -> None:
        self._project_path = project_path or Path.cwd()
        self._jira_cli = jira_cli_path
        self._enabled = enabled
        self._last_output: str = ""
        self._last_error: str = ""

    @property
    def enabled(self) -> bool:
        """Check if Jira integration is enabled."""
        return self._enabled

    @property
    def last_output(self) -> str:
        """Get last Jira output."""
        return self._last_output

    @property
    def last_error(self) -> str:
        """Get last error message."""
        return self._last_error

    def enable(self) -> None:
        """Enable Jira integration."""
        self._enabled = True

    def disable(self) -> None:
        """Disable Jira integration."""
        self._enabled = False

    async def run_command(self, *args: str) -> str:
        """Run a Jira CLI command.

        Args:
            *args: Command arguments

        Returns:
            Command output
        """
        if not self._enabled:
            return "Jira integration is disabled"

        process = ProcessService(cwd=self._project_path)
        result = await process.run(self._jira_cli, *args)

        if result.success:
            self._last_output = result.stdout
            self._last_error = ""
            return result.stdout
        else:
            self._last_error = result.stderr
            return f"Error: {result.stderr}"

    async def list_issues(self, project: str | None = None) -> str:
        """List Jira issues.

        Args:
            project: Optional project key

        Returns:
            Formatted issue list
        """
        args = ["issue", "list"]
        if project:
            args.extend(["--project", project])

        return await self.run_command(*args)

    async def get_issue(self, issue_key: str) -> str:
        """Get a specific issue.

        Args:
            issue_key: Issue key (e.g., PROJ-123)

        Returns:
            Issue details
        """
        return await self.run_command("issue", "view", issue_key)

    async def get_my_issues(self) -> str:
        """Get issues assigned to current user.

        Returns:
            Formatted issue list
        """
        return await self.run_command("issue", "list", "--assignee", "@me")

    async def get_sprint_issues(self) -> str:
        """Get issues in current sprint.

        Returns:
            Formatted issue list
        """
        return await self.run_command("sprint", "list", "--current")

    async def refresh(self) -> str:
        """Refresh Jira data (get my issues).

        Returns:
            Updated output
        """
        return await self.get_my_issues()

    async def check_available(self) -> bool:
        """Check if Jira CLI is available.

        Returns:
            True if available
        """
        process = ProcessService(cwd=self._project_path)
        result = await process.run(self._jira_cli, "--version")
        return result.success

    async def get_content(self) -> str | None:
        """Get Jira content for display.

        Returns:
            Markdown content or None
        """
        if not self._enabled:
            return None
        try:
            return await self.get_my_issues()
        except Exception:
            return None
