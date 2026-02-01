"""File system watching service for real-time sync.

This module provides file system monitoring capabilities for the Clide IDE,
enabling reactive updates when files change on disk.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING, Literal

if TYPE_CHECKING:
    from collections.abc import Callable

from pydantic import BaseModel, ConfigDict
from textual.message import Message

try:
    from watchdog.events import (
        DirCreatedEvent,
        DirDeletedEvent,
        DirModifiedEvent,
        DirMovedEvent,
        FileCreatedEvent,
        FileDeletedEvent,
        FileModifiedEvent,
        FileMovedEvent,
    )
    from watchdog.events import (
        FileSystemEventHandler as WatchdogHandler,
    )
    from watchdog.observers import Observer as WatchdogObserver

    WATCHDOG_AVAILABLE = True
except ImportError:
    WATCHDOG_AVAILABLE = False
    WatchdogObserver = None  # type: ignore[misc, assignment]
    WatchdogHandler = object  # type: ignore[misc, assignment]
    FileCreatedEvent = None  # type: ignore[misc, assignment]
    FileModifiedEvent = None  # type: ignore[misc, assignment]
    FileDeletedEvent = None  # type: ignore[misc, assignment]
    FileMovedEvent = None  # type: ignore[misc, assignment]
    DirCreatedEvent = None  # type: ignore[misc, assignment]
    DirModifiedEvent = None  # type: ignore[misc, assignment]
    DirDeletedEvent = None  # type: ignore[misc, assignment]
    DirMovedEvent = None  # type: ignore[misc, assignment]


class FileEvent(BaseModel):
    """A file system event.

    Attributes:
        path: The path to the file/directory that changed.
        event_type: The type of change that occurred.
        timestamp: When the event occurred.
        is_directory: Whether this is a directory event.
        old_path: For move events, the original path.
    """

    model_config = ConfigDict(strict=True, frozen=True)

    path: Path
    event_type: Literal["created", "modified", "deleted", "moved"]
    timestamp: datetime
    is_directory: bool = False
    old_path: Path | None = None


class FileEventMessage(Message):
    """Textual message for file events."""

    def __init__(self, event: FileEvent) -> None:
        self.event = event
        super().__init__()


class FileWatcher:
    """Watches a directory for file system changes.

    Uses watchdog for efficient cross-platform file monitoring.
    Emits FileEvent objects to registered handlers.

    Example:
        watcher = FileWatcher(Path.cwd())
        watcher.register_handler(my_handler)
        watcher.start()
        # ... later ...
        watcher.stop()
    """

    def __init__(self, root: Path, ignore_patterns: list[str] | None = None) -> None:
        """Initialize the file watcher.

        Args:
            root: The root directory to watch.
            ignore_patterns: Glob patterns to ignore (e.g., ["*.pyc", "__pycache__"]).
        """
        self._root = root.resolve()
        self._ignore_patterns = ignore_patterns or [
            "*.pyc",
            "__pycache__",
            ".git",
            ".venv",
            "venv",
            "node_modules",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            "*.egg-info",
            ".clide",
            ".claude",
        ]
        self._handlers: list[Callable[[FileEvent], None]] = []
        self._observer: WatchdogObserver | None = None  # type: ignore[valid-type]
        self._running = False

    @property
    def is_available(self) -> bool:
        """Check if watchdog is available."""
        return WATCHDOG_AVAILABLE

    @property
    def is_running(self) -> bool:
        """Check if the watcher is currently running."""
        return self._running

    @property
    def root(self) -> Path:
        """Get the root directory being watched."""
        return self._root

    def register_handler(self, handler: Callable[[FileEvent], None]) -> None:
        """Register a handler for file events.

        Args:
            handler: A callable that accepts a FileEvent.
        """
        if handler not in self._handlers:
            self._handlers.append(handler)

    def unregister_handler(self, handler: Callable[[FileEvent], None]) -> None:
        """Unregister a handler.

        Args:
            handler: The handler to remove.
        """
        if handler in self._handlers:
            self._handlers.remove(handler)

    def _should_ignore(self, path: Path) -> bool:
        """Check if a path should be ignored based on patterns."""
        path_str = str(path)
        for pattern in self._ignore_patterns:
            # Simple pattern matching - could be enhanced with fnmatch
            if pattern.startswith("*"):
                if path_str.endswith(pattern[1:]):
                    return True
            elif pattern in path_str:
                return True
        return False

    def _emit_event(self, event: FileEvent) -> None:
        """Emit an event to all handlers."""
        if self._should_ignore(event.path):
            return

        for handler in self._handlers:
            try:
                handler(event)
            except Exception:
                pass  # Don't let handler errors affect other handlers

    def start(self) -> bool:
        """Start watching for file changes.

        Returns:
            True if started successfully, False if watchdog is not available.
        """
        if not WATCHDOG_AVAILABLE:
            return False

        if self._running:
            return True

        event_handler = _WatchdogHandler(self)
        self._observer = WatchdogObserver()
        self._observer.schedule(event_handler, str(self._root), recursive=True)
        self._observer.start()
        self._running = True
        return True

    def stop(self) -> None:
        """Stop watching for file changes."""
        if self._observer is not None:
            self._observer.stop()
            self._observer.join(timeout=5)
            self._observer = None
        self._running = False


class _WatchdogHandler(WatchdogHandler):  # type: ignore[misc, valid-type]
    """Internal handler for watchdog events."""

    def __init__(self, watcher: FileWatcher) -> None:
        super().__init__()
        self._watcher = watcher

    def _create_event(
        self,
        src_path: str | bytes,
        event_type: Literal["created", "modified", "deleted", "moved"],
        is_directory: bool,
        dest_path: str | bytes | None = None,
    ) -> FileEvent:
        """Create a FileEvent from watchdog event data."""
        # Watchdog can return bytes or str depending on platform
        src = src_path.decode() if isinstance(src_path, bytes) else src_path
        dest = dest_path.decode() if isinstance(dest_path, bytes) else dest_path
        return FileEvent(
            path=Path(dest if dest else src),
            event_type=event_type,
            timestamp=datetime.now(),
            is_directory=is_directory,
            old_path=Path(src) if dest else None,
        )

    def on_created(self, event) -> None:  # type: ignore[no-untyped-def]
        file_event = self._create_event(event.src_path, "created", event.is_directory)
        self._watcher._emit_event(file_event)

    def on_modified(self, event) -> None:  # type: ignore[no-untyped-def]
        file_event = self._create_event(event.src_path, "modified", event.is_directory)
        self._watcher._emit_event(file_event)

    def on_deleted(self, event) -> None:  # type: ignore[no-untyped-def]
        file_event = self._create_event(event.src_path, "deleted", event.is_directory)
        self._watcher._emit_event(file_event)

    def on_moved(self, event) -> None:  # type: ignore[no-untyped-def]
        file_event = self._create_event(
            event.src_path, "moved", event.is_directory, event.dest_path
        )
        self._watcher._emit_event(file_event)


# Global watcher instance
_file_watcher: FileWatcher | None = None


def get_file_watcher(root: Path | None = None) -> FileWatcher:
    """Get or create the global file watcher.

    Args:
        root: The root directory to watch. Only used on first call.

    Returns:
        The FileWatcher instance.
    """
    global _file_watcher
    if _file_watcher is None:
        _file_watcher = FileWatcher(root or Path.cwd())
    return _file_watcher


def setup_file_watching(
    root: Path,
    handlers: list[Callable[[FileEvent], None]] | None = None,
) -> FileWatcher:
    """Set up file watching with optional initial handlers.

    Args:
        root: The root directory to watch.
        handlers: Optional list of handlers to register.

    Returns:
        The configured FileWatcher.
    """
    global _file_watcher
    _file_watcher = FileWatcher(root)

    if handlers:
        for handler in handlers:
            _file_watcher.register_handler(handler)

    _file_watcher.start()
    return _file_watcher
