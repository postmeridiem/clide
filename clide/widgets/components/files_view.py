"""File browser component using DirectoryTree."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from rich.text import Text
from textual.message import Message
from textual.widgets import DirectoryTree

if TYPE_CHECKING:
    from rich.style import Style
    from textual.widgets._directory_tree import DirEntry
    from textual.widgets._tree import TreeNode


# Minimal Unicode icons (works with any font)
ICON_FOLDER_OPEN = "▾"
ICON_FOLDER_CLOSED = "▸"
ICON_FILE = "◦"


class FilesView(DirectoryTree):
    """File browser widget wrapping DirectoryTree."""

    class FileSelected(Message):
        """Emitted when a file is selected."""

        def __init__(self, node: TreeNode[DirEntry], path: Path) -> None:
            self.node = node
            self.path = path
            super().__init__()

    class DirectorySelected(Message):
        """Emitted when a directory is selected."""

        def __init__(self, node: TreeNode[DirEntry], path: Path) -> None:
            self.node = node
            self.path = path
            super().__init__()

    def __init__(
        self,
        path: Path,
        *,
        name: str | None = None,
        id: str | None = None,
        classes: str | None = None,
    ) -> None:
        super().__init__(
            path,
            name=name,
            id=id,
            classes=classes,
        )

    def render_label(
        self, node: TreeNode[DirEntry], base_style: Style, style: Style
    ) -> Text:
        """Render a label with minimal Unicode icons."""
        path = node.data.path

        if path.is_dir():
            icon = ICON_FOLDER_OPEN if node.is_expanded else ICON_FOLDER_CLOSED
            icon_style = "bold cyan"
        else:
            icon = ICON_FILE
            icon_style = "dim"

        label = Text()
        label.append(f"{icon} ", style=icon_style)
        label.append(path.name, style=style)
        return label

    def filter_paths(self, paths: list[Path]) -> list[Path]:
        """Filter out hidden and ignored paths."""
        return [
            p for p in paths
            if not p.name.startswith(".")
            and p.name not in ("__pycache__", "node_modules", ".git", ".venv", "venv")
        ]


    def refresh_tree(self) -> None:
        """Refresh the directory tree."""
        self.reload()

    def highlight_path(self, path: Path) -> None:
        """Highlight a path in the tree (expand parents and scroll to it).

        Used to show which file Claude is working with.
        """
        # Normalize the path
        try:
            path = path.resolve()
        except Exception:
            return

        # Find and select the node
        def find_node(node, target_path):
            """Recursively find a node by path."""
            if node.data and hasattr(node.data, 'path'):
                if node.data.path.resolve() == target_path:
                    return node
            for child in node.children:
                result = find_node(child, target_path)
                if result:
                    return result
            return None

        target_node = find_node(self.root, path)
        if target_node:
            # Expand all parent nodes
            parent = target_node.parent
            while parent:
                parent.expand()
                parent = parent.parent

            # Select and scroll to the node
            self.select_node(target_node)
            self.scroll_to_node(target_node)

    def on_directory_tree_file_selected(
        self, event: DirectoryTree.FileSelected
    ) -> None:
        """Re-emit file selection as FilesView.FileSelected."""
        event.stop()
        self.post_message(self.FileSelected(node=event.node, path=event.path))
