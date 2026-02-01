"""File operations service."""

from pathlib import Path


# Language extension mapping for syntax highlighting
# Maps file extensions to tree-sitter language identifiers
LANGUAGE_MAP: dict[str, str] = {
    # Python
    ".py": "python",
    ".pyi": "python",
    ".pyw": "python",
    # JavaScript/TypeScript
    ".js": "javascript",
    ".mjs": "javascript",
    ".cjs": "javascript",
    ".jsx": "javascript",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".mts": "typescript",
    ".cts": "typescript",
    # Web
    ".html": "html",
    ".htm": "html",
    ".css": "css",
    ".scss": "css",
    ".sass": "css",
    ".less": "css",
    # Dart/Flutter
    ".dart": "dart",
    # Data formats
    ".json": "json",
    ".jsonc": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".toml": "toml",
    ".xml": "xml",
    # Markdown
    ".md": "markdown",
    ".markdown": "markdown",
    # Shell
    ".sh": "bash",
    ".bash": "bash",
    ".zsh": "bash",
    ".fish": "bash",
    # SQL
    ".sql": "sql",
    # Other languages
    ".rs": "rust",
    ".go": "go",
    ".java": "java",
    ".c": "c",
    ".h": "c",
    ".cpp": "cpp",
    ".hpp": "cpp",
    ".cc": "cpp",
    ".cxx": "cpp",
    ".rb": "ruby",
    ".php": "php",
    ".vue": "vue",
    ".svelte": "svelte",
    ".lua": "lua",
    ".r": "r",
    ".R": "r",
    ".swift": "swift",
    ".kt": "kotlin",
    ".kts": "kotlin",
    ".scala": "scala",
    ".ex": "elixir",
    ".exs": "elixir",
}


class FileService:
    """Service for file I/O operations."""

    def __init__(self, project_path: Path) -> None:
        self.project_path = project_path

    # Static methods for simple sync operations (used by EditorPane)
    @staticmethod
    def read_file(path: Path) -> str:
        """Read file contents synchronously.

        Args:
            path: Path to file

        Returns:
            File contents as string
        """
        return path.read_text(encoding="utf-8")

    @staticmethod
    def write_file(path: Path, content: str) -> bool:
        """Write content to file synchronously.

        Args:
            path: Path to file
            content: Content to write

        Returns:
            True if successful
        """
        try:
            path.write_text(content, encoding="utf-8")
            return True
        except OSError:
            return False

    @staticmethod
    def detect_language(path: Path) -> str | None:
        """Detect language from file extension.

        Args:
            path: File path

        Returns:
            Language identifier for tree-sitter or None
        """
        return LANGUAGE_MAP.get(path.suffix.lower())

    # Instance methods for async operations
    async def read_file_async(self, path: Path) -> str:
        """Read file contents asynchronously.

        Args:
            path: Path to file (relative or absolute)

        Returns:
            File contents as string
        """
        full_path = self._resolve_path(path)
        return full_path.read_text(encoding="utf-8")

    async def write_file_async(self, path: Path, content: str) -> None:
        """Write content to file asynchronously.

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
        return LANGUAGE_MAP.get(path.suffix.lower())

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
