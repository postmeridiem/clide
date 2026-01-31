"""File operations service."""

from pathlib import Path


class FileService:
    """Service for file I/O operations."""

    def __init__(self, project_path: Path) -> None:
        self.project_path = project_path

    async def read_file(self, path: Path) -> str:
        """Read file contents.

        Args:
            path: Path to file (relative or absolute)

        Returns:
            File contents as string
        """
        full_path = self._resolve_path(path)
        return full_path.read_text(encoding="utf-8")

    async def write_file(self, path: Path, content: str) -> None:
        """Write content to file.

        Args:
            path: Path to file
            content: Content to write
        """
        full_path = self._resolve_path(path)
        full_path.write_text(content, encoding="utf-8")

    async def file_exists(self, path: Path) -> bool:
        """Check if file exists.

        Args:
            path: Path to check

        Returns:
            True if file exists
        """
        full_path = self._resolve_path(path)
        return full_path.exists() and full_path.is_file()

    async def get_language(self, path: Path) -> str | None:
        """Detect language from file extension.

        Args:
            path: File path

        Returns:
            Language identifier or None
        """
        extension_map = {
            ".py": "python",
            ".js": "javascript",
            ".ts": "typescript",
            ".jsx": "jsx",
            ".tsx": "tsx",
            ".html": "html",
            ".css": "css",
            ".scss": "scss",
            ".json": "json",
            ".yaml": "yaml",
            ".yml": "yaml",
            ".toml": "toml",
            ".md": "markdown",
            ".rs": "rust",
            ".go": "go",
            ".java": "java",
            ".c": "c",
            ".cpp": "cpp",
            ".h": "c",
            ".hpp": "cpp",
            ".rb": "ruby",
            ".php": "php",
            ".sh": "bash",
            ".bash": "bash",
            ".sql": "sql",
            ".xml": "xml",
            ".vue": "vue",
            ".svelte": "svelte",
        }
        return extension_map.get(path.suffix.lower())

    def _resolve_path(self, path: Path) -> Path:
        """Resolve path relative to project root.

        Args:
            path: Path to resolve

        Returns:
            Absolute path
        """
        if path.is_absolute():
            return path
        return self.project_path / path

    def list_directory(self, path: Path | None = None) -> list[Path]:
        """List directory contents.

        Args:
            path: Directory path (defaults to project root)

        Returns:
            List of paths in directory
        """
        dir_path = self._resolve_path(path) if path else self.project_path
        if not dir_path.is_dir():
            return []

        entries = []
        for entry in sorted(dir_path.iterdir()):
            # Skip hidden files and common excludes
            if entry.name.startswith("."):
                continue
            if entry.name in ("__pycache__", "node_modules", ".git"):
                continue
            entries.append(entry)

        # Sort: directories first, then files
        entries.sort(key=lambda p: (not p.is_dir(), p.name.lower()))
        return entries
