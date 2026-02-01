"""Git operations service."""

from pathlib import Path

from clide.models.git import (
    ChangeStatus,
    GitBranch,
    GitChange,
    GitCommit,
    GitStatus,
)
from clide.services.process_service import ProcessService


class GitService:
    """Service for git operations."""

    def __init__(self, repo_path: Path) -> None:
        self.repo_path = repo_path
        self._process = ProcessService(cwd=repo_path)

    async def get_status(self) -> GitStatus:
        """Get current git status.

        Returns:
            GitStatus with staged/unstaged changes
        """
        # Get porcelain status
        result = await self._process.run("git", "status", "--porcelain", "-z")

        staged: list[GitChange] = []
        unstaged: list[GitChange] = []
        untracked: list[str] = []

        if result.success and result.stdout:
            entries = result.stdout.split("\0")
            for entry in entries:
                if not entry or len(entry) < 3:
                    continue

                index_status = entry[0]
                worktree_status = entry[1]
                path = entry[3:]

                # Parse status
                if index_status == "?":
                    # Untracked files go in both untracked list and unstaged
                    untracked.append(path)
                    unstaged.append(
                        GitChange(
                            path=path,
                            status=ChangeStatus.UNTRACKED,
                            staged=False,
                        )
                    )
                else:
                    if index_status != " ":
                        staged.append(
                            GitChange(
                                path=path,
                                status=self._parse_status(index_status),
                                staged=True,
                            )
                        )
                    if worktree_status != " ":
                        unstaged.append(
                            GitChange(
                                path=path,
                                status=self._parse_status(worktree_status),
                                staged=False,
                            )
                        )

        # Get current branch
        branch_result = await self._process.run("git", "branch", "--show-current")
        branch = branch_result.stdout.strip() if branch_result.success else "HEAD"

        # Get ahead/behind
        ahead, behind = await self._get_ahead_behind(branch)

        return GitStatus(
            branch=branch,
            ahead=ahead,
            behind=behind,
            staged=tuple(staged),
            unstaged=tuple(unstaged),
            untracked=tuple(untracked),
        )

    async def _get_ahead_behind(self, branch: str) -> tuple[int, int]:
        """Get commits ahead/behind upstream."""
        result = await self._process.run(
            "git", "rev-list", "--left-right", "--count", f"{branch}...@{{upstream}}"
        )
        if result.success:
            parts = result.stdout.strip().split()
            if len(parts) == 2:
                return int(parts[0]), int(parts[1])
        return 0, 0

    def _parse_status(self, char: str) -> ChangeStatus:
        """Parse git status character to ChangeStatus."""
        mapping = {
            "A": ChangeStatus.ADDED,
            "M": ChangeStatus.MODIFIED,
            "D": ChangeStatus.DELETED,
            "R": ChangeStatus.RENAMED,
            "C": ChangeStatus.COPIED,
            "?": ChangeStatus.UNTRACKED,
            "!": ChangeStatus.IGNORED,
            "U": ChangeStatus.UNMERGED,
        }
        return mapping.get(char, ChangeStatus.MODIFIED)

    async def stage_file(self, path: str) -> bool:
        """Stage a file.

        Args:
            path: File path to stage

        Returns:
            True if successful
        """
        result = await self._process.run("git", "add", path)
        return result.success

    async def unstage_file(self, path: str) -> bool:
        """Unstage a file.

        Args:
            path: File path to unstage

        Returns:
            True if successful
        """
        result = await self._process.run("git", "restore", "--staged", path)
        return result.success

    async def discard_changes(self, path: str) -> bool:
        """Discard changes to a file.

        Args:
            path: File path to discard

        Returns:
            True if successful
        """
        result = await self._process.run("git", "restore", path)
        return result.success

    async def get_branches(self) -> list[GitBranch]:
        """Get list of branches.

        Returns:
            List of GitBranch objects
        """
        result = await self._process.run(
            "git",
            "branch",
            "-a",
            "--format",
            "%(HEAD)%(refname:short)|%(upstream:short)|%(objectname:short)|%(subject)",
        )

        branches: list[GitBranch] = []
        if result.success:
            for line in result.stdout.strip().split("\n"):
                if not line:
                    continue
                is_current = line.startswith("*")
                parts = line[1:].split("|")
                if len(parts) >= 4:
                    name = parts[0].strip()
                    branches.append(
                        GitBranch(
                            name=name,
                            is_current=is_current,
                            is_remote=name.startswith("remotes/"),
                            tracking=parts[1] or None,
                            commit_hash=parts[2],
                            commit_message=parts[3],
                        )
                    )

        return branches

    async def checkout_branch(self, branch: str) -> bool:
        """Checkout a branch.

        Args:
            branch: Branch name to checkout

        Returns:
            True if successful
        """
        result = await self._process.run("git", "checkout", branch)
        return result.success

    async def create_branch(self, name: str, start_point: str | None = None) -> bool:
        """Create a new branch.

        Args:
            name: New branch name
            start_point: Optional starting commit/branch

        Returns:
            True if successful
        """
        args = ["git", "checkout", "-b", name]
        if start_point:
            args.append(start_point)
        result = await self._process.run(*args)
        return result.success

    async def get_diff(self, path: str, staged: bool = False) -> str:
        """Get diff for a file.

        Args:
            path: File path
            staged: Whether to get staged diff

        Returns:
            Diff output string
        """
        args = ["git", "diff"]
        if staged:
            args.append("--cached")
        args.append("--")
        args.append(path)

        result = await self._process.run(*args)
        return result.stdout if result.success else ""

    async def get_log(self, max_count: int = 50) -> list[GitCommit]:
        """Get commit log.

        Args:
            max_count: Maximum number of commits to return

        Returns:
            List of GitCommit objects
        """
        result = await self._process.run(
            "git",
            "log",
            f"--max-count={max_count}",
            "--format=%H|%h|%s|%an|%ar|%P|%D",
            "--all",
        )

        commits: list[GitCommit] = []
        if result.success:
            for line in result.stdout.strip().split("\n"):
                if not line:
                    continue
                parts = line.split("|")
                if len(parts) >= 7:
                    parents = tuple(parts[5].split()) if parts[5] else ()
                    refs = tuple(r.strip() for r in parts[6].split(",")) if parts[6] else ()
                    commits.append(
                        GitCommit(
                            hash=parts[0],
                            short_hash=parts[1],
                            message=parts[2],
                            author=parts[3],
                            date=parts[4],
                            is_merge=len(parents) > 1,
                            parents=parents,
                            refs=refs,
                        )
                    )

        return commits
