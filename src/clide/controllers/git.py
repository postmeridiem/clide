"""Git controller for managing git operations."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.models.git import GitBranch, GitCommit, GitStatus
from clide.services.git_service import GitService


@controller
class GitController:
    """Controller for git operations."""

    class StatusUpdated(Message):
        """Emitted when git status changes."""

        def __init__(self, status: GitStatus) -> None:
            self.status = status
            super().__init__()

    class BranchesUpdated(Message):
        """Emitted when branches list changes."""

        def __init__(self, branches: list[GitBranch]) -> None:
            self.branches = branches
            super().__init__()

    class LogUpdated(Message):
        """Emitted when commit log is refreshed."""

        def __init__(self, commits: list[GitCommit]) -> None:
            self.commits = commits
            super().__init__()

    class FileStaged(Message):
        """Emitted when a file is staged."""

        def __init__(self, path: str) -> None:
            self.path = path
            super().__init__()

    class FileUnstaged(Message):
        """Emitted when a file is unstaged."""

        def __init__(self, path: str) -> None:
            self.path = path
            super().__init__()

    def __init__(self, repo_path: Path) -> None:
        self._service = GitService(repo_path)
        self._status: GitStatus | None = None
        self._branches: list[GitBranch] = []
        self._commits: list[GitCommit] = []

    @property
    def status(self) -> GitStatus | None:
        """Get current git status."""
        return self._status

    @property
    def branches(self) -> list[GitBranch]:
        """Get list of branches."""
        return self._branches

    @property
    def commits(self) -> list[GitCommit]:
        """Get commit log."""
        return self._commits

    @property
    def current_branch(self) -> str:
        """Get current branch name."""
        return self._status.branch if self._status else "unknown"

    async def refresh_status(self) -> GitStatus:
        """Refresh git status.

        Returns:
            Updated GitStatus
        """
        self._status = await self._service.get_status()
        return self._status

    async def get_status(self) -> GitStatus | None:
        """Get git status (refreshes if needed)."""
        return await self.refresh_status()

    async def refresh_branches(self) -> list[GitBranch]:
        """Refresh branches list.

        Returns:
            Updated list of branches
        """
        self._branches = await self._service.get_branches()
        return self._branches

    async def get_branches(self) -> list[GitBranch]:
        """Get branches list (refreshes if needed)."""
        return await self.refresh_branches()

    async def refresh_log(self, max_count: int = 50) -> list[GitCommit]:
        """Refresh commit log.

        Args:
            max_count: Maximum commits to fetch

        Returns:
            Updated list of commits
        """
        self._commits = await self._service.get_log(max_count)
        return self._commits

    async def get_log(self, limit: int = 50) -> list[GitCommit]:
        """Get commit log (refreshes if needed)."""
        return await self.refresh_log(limit)

    async def stage_file(self, path: str) -> bool:
        """Stage a file.

        Args:
            path: File path to stage

        Returns:
            True if successful
        """
        success = await self._service.stage_file(path)
        if success:
            await self.refresh_status()
        return success

    async def unstage_file(self, path: str) -> bool:
        """Unstage a file.

        Args:
            path: File path to unstage

        Returns:
            True if successful
        """
        success = await self._service.unstage_file(path)
        if success:
            await self.refresh_status()
        return success

    async def discard_changes(self, path: str) -> bool:
        """Discard changes to a file.

        Args:
            path: File path

        Returns:
            True if successful
        """
        success = await self._service.discard_changes(path)
        if success:
            await self.refresh_status()
        return success

    async def checkout_branch(self, branch: str) -> bool:
        """Checkout a branch.

        Args:
            branch: Branch name

        Returns:
            True if successful
        """
        success = await self._service.checkout_branch(branch)
        if success:
            await self.refresh_status()
            await self.refresh_branches()
        return success

    async def create_branch(self, name: str) -> bool:
        """Create and checkout a new branch.

        Args:
            name: New branch name

        Returns:
            True if successful
        """
        success = await self._service.create_branch(name)
        if success:
            await self.refresh_status()
            await self.refresh_branches()
        return success

    async def get_file_diff(self, path: str, staged: bool = False) -> str:
        """Get diff for a file.

        Args:
            path: File path
            staged: Whether to get staged diff

        Returns:
            Diff string
        """
        return await self._service.get_diff(path, staged)
