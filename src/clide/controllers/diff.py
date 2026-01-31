"""Diff controller for viewing and managing diffs."""

from pathlib import Path

from textual.message import Message

from clide.controllers.base import controller
from clide.models.diff import ChangeType, DiffContent, DiffHunk, DiffLine, DiffViewState
from clide.services.git_service import GitService


@controller
class DiffController:
    """Controller for diff viewing and Claude-proposed changes."""

    class DiffLoaded(Message):
        """Emitted when a diff is loaded."""

        def __init__(self, diff: DiffContent) -> None:
            self.diff = diff
            super().__init__()

    class HunkAccepted(Message):
        """Emitted when a hunk is accepted."""

        def __init__(self, hunk_index: int) -> None:
            self.hunk_index = hunk_index
            super().__init__()

    class HunkRejected(Message):
        """Emitted when a hunk is rejected."""

        def __init__(self, hunk_index: int) -> None:
            self.hunk_index = hunk_index
            super().__init__()

    class AllChangesAccepted(Message):
        """Emitted when all changes are accepted."""
        pass

    class AllChangesRejected(Message):
        """Emitted when all changes are rejected."""
        pass

    def __init__(self, repo_path: Path) -> None:
        self._git_service = GitService(repo_path)
        self._state = DiffViewState()

    @property
    def state(self) -> DiffViewState:
        """Get diff view state."""
        return self._state

    @property
    def diff(self) -> DiffContent | None:
        """Get current diff content."""
        return self._state.diff

    @property
    def is_proposal(self) -> bool:
        """Check if current diff is a Claude proposal."""
        return self._state.is_proposal

    async def load_git_diff(self, path: str, staged: bool = False) -> DiffContent | None:
        """Load diff from git.

        Args:
            path: File path
            staged: Whether to load staged diff

        Returns:
            DiffContent or None if no diff
        """
        diff_text = await self._git_service.get_diff(path, staged)
        if not diff_text:
            return None

        diff = self._parse_diff(path, diff_text)
        self._state.diff = diff
        self._state.is_proposal = False
        self._state.accepted_hunks = set()
        self._state.rejected_hunks = set()

        return diff

    def load_proposal(self, path: str, old_content: str, new_content: str) -> DiffContent:
        """Load a Claude-proposed change as a diff.

        Args:
            path: File path
            old_content: Original content
            new_content: Proposed content

        Returns:
            DiffContent of the proposal
        """
        diff = self._create_diff_from_content(path, old_content, new_content)
        self._state.diff = diff
        self._state.is_proposal = True
        self._state.accepted_hunks = set()
        self._state.rejected_hunks = set()

        return diff

    def accept_hunk(self, index: int) -> None:
        """Accept a specific hunk.

        Args:
            index: Hunk index
        """
        self._state.accepted_hunks.add(index)
        self._state.rejected_hunks.discard(index)

    def reject_hunk(self, index: int) -> None:
        """Reject a specific hunk.

        Args:
            index: Hunk index
        """
        self._state.rejected_hunks.add(index)
        self._state.accepted_hunks.discard(index)

    def accept_all(self) -> None:
        """Accept all hunks."""
        if self._state.diff:
            for i in range(len(self._state.diff.hunks)):
                self._state.accepted_hunks.add(i)
            self._state.rejected_hunks.clear()

    def reject_all(self) -> None:
        """Reject all hunks."""
        if self._state.diff:
            for i in range(len(self._state.diff.hunks)):
                self._state.rejected_hunks.add(i)
            self._state.accepted_hunks.clear()

    def clear(self) -> None:
        """Clear current diff."""
        self._state.diff = None
        self._state.is_proposal = False
        self._state.accepted_hunks = set()
        self._state.rejected_hunks = set()

    def toggle_side_by_side(self) -> bool:
        """Toggle side-by-side view.

        Returns:
            New side_by_side value
        """
        self._state.side_by_side = not self._state.side_by_side
        return self._state.side_by_side

    def _parse_diff(self, path: str, diff_text: str) -> DiffContent:
        """Parse git diff output into DiffContent."""
        hunks: list[DiffHunk] = []
        current_hunk_lines: list[DiffLine] = []
        current_header = ""
        old_start = old_count = new_start = new_count = 0

        for line in diff_text.split("\n"):
            if line.startswith("@@"):
                # Save previous hunk
                if current_hunk_lines:
                    hunks.append(DiffHunk(
                        header=current_header,
                        old_start=old_start,
                        old_count=old_count,
                        new_start=new_start,
                        new_count=new_count,
                        lines=tuple(current_hunk_lines),
                    ))
                    current_hunk_lines = []

                # Parse hunk header
                current_header = line
                # Format: @@ -old_start,old_count +new_start,new_count @@
                import re
                match = re.match(r"@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@", line)
                if match:
                    old_start = int(match.group(1))
                    old_count = int(match.group(2)) if match.group(2) else 1
                    new_start = int(match.group(3))
                    new_count = int(match.group(4)) if match.group(4) else 1

            elif line.startswith("+") and not line.startswith("+++"):
                current_hunk_lines.append(DiffLine(
                    change_type=ChangeType.ADDED,
                    content=line[1:],
                    new_line_num=new_start + len([l for l in current_hunk_lines if l.change_type != ChangeType.REMOVED]),
                ))
            elif line.startswith("-") and not line.startswith("---"):
                current_hunk_lines.append(DiffLine(
                    change_type=ChangeType.REMOVED,
                    content=line[1:],
                    old_line_num=old_start + len([l for l in current_hunk_lines if l.change_type != ChangeType.ADDED]),
                ))
            elif line.startswith(" "):
                old_num = old_start + len([l for l in current_hunk_lines if l.change_type != ChangeType.ADDED])
                new_num = new_start + len([l for l in current_hunk_lines if l.change_type != ChangeType.REMOVED])
                current_hunk_lines.append(DiffLine(
                    change_type=ChangeType.CONTEXT,
                    content=line[1:],
                    old_line_num=old_num,
                    new_line_num=new_num,
                ))

        # Save last hunk
        if current_hunk_lines:
            hunks.append(DiffHunk(
                header=current_header,
                old_start=old_start,
                old_count=old_count,
                new_start=new_start,
                new_count=new_count,
                lines=tuple(current_hunk_lines),
            ))

        return DiffContent(
            file_path=path,
            hunks=tuple(hunks),
        )

    async def get_file_diff(self, path: str, staged: bool = False) -> DiffContent | None:
        """Get diff for a file (alias for load_git_diff).

        Args:
            path: File path
            staged: Whether to get staged diff

        Returns:
            DiffContent or None
        """
        return await self.load_git_diff(path, staged)

    async def accept_proposal(self, file_path: str) -> bool:
        """Accept a proposed change and apply it.

        Args:
            file_path: Path to the file

        Returns:
            True if successful
        """
        if not self._state.diff or not self._state.is_proposal:
            return False

        self.accept_all()
        # TODO: Apply the changes to the file
        self.clear()
        return True

    async def reject_proposal(self, file_path: str) -> bool:
        """Reject a proposed change.

        Args:
            file_path: Path to the file

        Returns:
            True if successful
        """
        self.reject_all()
        self.clear()
        return True

    def _create_diff_from_content(self, path: str, old: str, new: str) -> DiffContent:
        """Create diff from old and new content."""
        import difflib

        old_lines = old.splitlines(keepends=True)
        new_lines = new.splitlines(keepends=True)

        diff_lines: list[DiffLine] = []
        old_num = new_num = 1

        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, old_lines, new_lines).get_opcodes():
            if tag == "equal":
                for line in old_lines[i1:i2]:
                    diff_lines.append(DiffLine(
                        change_type=ChangeType.CONTEXT,
                        content=line.rstrip("\n"),
                        old_line_num=old_num,
                        new_line_num=new_num,
                    ))
                    old_num += 1
                    new_num += 1
            elif tag == "delete":
                for line in old_lines[i1:i2]:
                    diff_lines.append(DiffLine(
                        change_type=ChangeType.REMOVED,
                        content=line.rstrip("\n"),
                        old_line_num=old_num,
                    ))
                    old_num += 1
            elif tag == "insert":
                for line in new_lines[j1:j2]:
                    diff_lines.append(DiffLine(
                        change_type=ChangeType.ADDED,
                        content=line.rstrip("\n"),
                        new_line_num=new_num,
                    ))
                    new_num += 1
            elif tag == "replace":
                for line in old_lines[i1:i2]:
                    diff_lines.append(DiffLine(
                        change_type=ChangeType.REMOVED,
                        content=line.rstrip("\n"),
                        old_line_num=old_num,
                    ))
                    old_num += 1
                for line in new_lines[j1:j2]:
                    diff_lines.append(DiffLine(
                        change_type=ChangeType.ADDED,
                        content=line.rstrip("\n"),
                        new_line_num=new_num,
                    ))
                    new_num += 1

        hunk = DiffHunk(
            header="@@ -1 +1 @@",
            old_start=1,
            old_count=len(old_lines),
            new_start=1,
            new_count=len(new_lines),
            lines=tuple(diff_lines),
        )

        return DiffContent(
            file_path=path,
            hunks=(hunk,),
        )
