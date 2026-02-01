"""Claude Code event detection and parsing.

This module provides event infrastructure for detecting Claude Code actions
from terminal output, enabling tight IDE integration.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Literal

from textual.message import Message


# Event Types
# -----------


@dataclass
class ClaudeEvent:
    """Base class for Claude Code events."""
    pass


@dataclass
class FileReadEvent(ClaudeEvent):
    """Emitted when Claude reads a file."""
    path: Path


@dataclass
class FileEditEvent(ClaudeEvent):
    """Emitted when Claude edits a file."""
    path: Path


@dataclass
class FileWriteEvent(ClaudeEvent):
    """Emitted when Claude creates/writes a file."""
    path: Path


@dataclass
class GlobEvent(ClaudeEvent):
    """Emitted when Claude searches for files."""
    pattern: str


@dataclass
class GrepEvent(ClaudeEvent):
    """Emitted when Claude searches file contents."""
    pattern: str


@dataclass
class ToolStartEvent(ClaudeEvent):
    """Emitted when Claude starts using a tool."""
    tool_name: str


@dataclass
class ToolEndEvent(ClaudeEvent):
    """Emitted when Claude finishes using a tool."""
    tool_name: str


@dataclass
class DiffProposedEvent(ClaudeEvent):
    """Emitted when Claude proposes a diff."""
    content: str


# Textual Messages
# ----------------


class ClaudeEventMessage(Message):
    """Textual message wrapper for Claude events."""

    def __init__(self, event: ClaudeEvent) -> None:
        self.event = event
        super().__init__()


# Pattern Matching
# ----------------

# Patterns for detecting Claude Code output
PATTERNS = {
    # Tool invocations - Claude Code shows these with bullet points
    "tool_read": re.compile(r"● Read\(([^)]+)\)"),
    "tool_edit": re.compile(r"● Edit\(([^)]+)\)"),
    "tool_write": re.compile(r"● Write\(([^)]+)\)"),
    "tool_glob": re.compile(r"● Glob\(([^)]+)\)"),
    "tool_grep": re.compile(r"● Grep\(([^)]+)\)"),

    # Generic tool pattern
    "tool_start": re.compile(r"● (\w+)\("),
    "tool_end": re.compile(r"└─"),

    # Diff headers
    "diff_header": re.compile(r"^@@\s*-\d+(?:,\d+)?\s+\+\d+(?:,\d+)?\s*@@", re.MULTILINE),
    "diff_file": re.compile(r"^(?:---|\+\+\+)\s+([^\s]+)", re.MULTILINE),
}


class ClaudeEventParser:
    """Parses Claude Code terminal output to detect events.

    This parser is designed to work with raw terminal data fed
    through the pyte event callback.
    """

    def __init__(self, callback: Callable[[ClaudeEvent], None] | None = None) -> None:
        """Initialize the event parser.

        Args:
            callback: Optional callback invoked for each detected event.
        """
        self._callback = callback
        self._buffer = ""
        self._current_tool: str | None = None

    def set_callback(self, callback: Callable[[ClaudeEvent], None] | None) -> None:
        """Set the event callback."""
        self._callback = callback

    def feed(self, data: str) -> list[ClaudeEvent]:
        """Feed terminal data and return detected events.

        Args:
            data: Raw terminal data from Claude Code.

        Returns:
            List of detected events.
        """
        events: list[ClaudeEvent] = []

        # Add to buffer for multi-line matching
        self._buffer += data

        # Limit buffer size to prevent memory issues
        if len(self._buffer) > 10000:
            self._buffer = self._buffer[-5000:]

        # Check for tool invocations
        for match in PATTERNS["tool_read"].finditer(data):
            path = Path(match.group(1).strip())
            events.append(FileReadEvent(path=path))

        for match in PATTERNS["tool_edit"].finditer(data):
            path = Path(match.group(1).strip())
            events.append(FileEditEvent(path=path))

        for match in PATTERNS["tool_write"].finditer(data):
            path = Path(match.group(1).strip())
            events.append(FileWriteEvent(path=path))

        for match in PATTERNS["tool_glob"].finditer(data):
            pattern = match.group(1).strip()
            events.append(GlobEvent(pattern=pattern))

        for match in PATTERNS["tool_grep"].finditer(data):
            pattern = match.group(1).strip()
            events.append(GrepEvent(pattern=pattern))

        # Check for generic tool start/end
        for match in PATTERNS["tool_start"].finditer(data):
            tool_name = match.group(1)
            # Don't emit for tools we handle specifically
            if tool_name not in ("Read", "Edit", "Write", "Glob", "Grep"):
                events.append(ToolStartEvent(tool_name=tool_name))
                self._current_tool = tool_name

        if PATTERNS["tool_end"].search(data) and self._current_tool:
            events.append(ToolEndEvent(tool_name=self._current_tool))
            self._current_tool = None

        # Check for diff content
        if PATTERNS["diff_header"].search(self._buffer):
            # Extract diff content (simplified - real impl would be more sophisticated)
            events.append(DiffProposedEvent(content=self._buffer))
            # Clear buffer after detecting diff
            self._buffer = ""

        # Invoke callback for each event
        if self._callback:
            for evt in events:
                try:
                    self._callback(evt)
                except Exception:
                    pass  # Don't let callback errors propagate

        return events

    def reset(self) -> None:
        """Reset parser state."""
        self._buffer = ""
        self._current_tool = None


# Global parser instance for convenience
_event_parser: ClaudeEventParser | None = None


def get_event_parser() -> ClaudeEventParser:
    """Get the global event parser instance."""
    global _event_parser
    if _event_parser is None:
        _event_parser = ClaudeEventParser()
    return _event_parser


def setup_event_parsing(callback: Callable[[ClaudeEvent], None]) -> None:
    """Set up event parsing with the given callback.

    This should be called during app initialization to wire up
    the event parser with the terminal stream.
    """
    from clide.vendor import pyte

    parser = get_event_parser()
    parser.set_callback(callback)

    # Wire up to pyte's event callback
    # The parser.feed returns events but pyte expects None return
    def _feed_wrapper(data: str) -> None:
        parser.feed(data)

    pyte.set_event_callback(_feed_wrapper)
