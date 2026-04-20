"""Claude panel with embedded terminal running Claude Code."""

from __future__ import annotations

import asyncio
import shutil
from pathlib import Path
from typing import TYPE_CHECKING

from textual.containers import Vertical
from textual.message import Message
from textual.reactive import reactive

from clide.widgets.components.terminal_display import TerminalDisplay

if TYPE_CHECKING:
    from textual.app import ComposeResult


class ClaudePanel(Vertical):
    """Terminal panel running Claude Code CLI.

    Automatically starts Claude Code and restarts when it exits.
    Takes 100% height when workspace is hidden, 40% when visible.
    """

    DEFAULT_CSS = """
    ClaudePanel {
        height: 100%;
        background: $background;
    }

    ClaudePanel.with-workspace {
        height: 40%;
        border-top: solid $surface;
    }

    ClaudePanel TerminalDisplay {
        height: 100%;
    }
    """

    class ClaudeExited(Message):
        """Emitted when Claude Code process exits."""

        def __init__(self, return_code: int) -> None:
            self.return_code = return_code
            super().__init__()

    class ClaudeStarted(Message):
        """Emitted when Claude Code process starts."""

        pass

    # Reactive state
    workspace_visible: reactive[bool] = reactive(False)

    def __init__(
        self,
        workdir: Path | None = None,
        auto_start: bool = True,
        restart_on_exit: bool = True,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self.id = "panel-claude"
        self._workdir = workdir or Path.cwd()
        self._auto_start = auto_start
        self._restart_on_exit = restart_on_exit
        self._claude_command = self._find_claude_command()
        self._terminal: TerminalDisplay | None = None
        self._monitor_task: asyncio.Task | None = None

    def _find_claude_command(self) -> str:
        """Find the Claude Code CLI command."""
        # Check common locations
        claude_paths = [
            "claude",  # In PATH
            str(Path.home() / ".claude" / "local" / "claude"),
            str(Path.home() / ".local" / "bin" / "claude"),
            "/usr/local/bin/claude",
        ]

        for path in claude_paths:
            if path and shutil.which(path):
                return path

        # Fallback to 'claude' and hope it's in PATH
        return "claude"

    def compose(self) -> ComposeResult:
        self._terminal = TerminalDisplay(id="claude-terminal")
        yield self._terminal

    def on_mount(self) -> None:
        """Start Claude Code when mounted."""
        if self._auto_start:
            self.call_later(self.start_claude)

    def watch_workspace_visible(self, visible: bool) -> None:
        """Adjust height based on workspace visibility."""
        if visible:
            self.add_class("with-workspace")
        else:
            self.remove_class("with-workspace")

    def start_claude(self) -> None:
        """Start the Claude Code CLI in the terminal."""
        if self._terminal is None:
            return

        # Start Claude Code with the working directory
        self._terminal.start(
            self._claude_command,
            str(self._workdir),
        )

        self.post_message(self.ClaudeStarted())

        # Start monitoring for exit
        if self._monitor_task:
            self._monitor_task.cancel()
        self._monitor_task = asyncio.create_task(self._monitor_claude())

    async def _monitor_claude(self) -> None:
        """Monitor Claude process and restart if needed."""
        if self._terminal is None:
            return

        # Wait for the terminal process to exit
        while True:
            await asyncio.sleep(1)

            # Check if process has exited
            if not self._terminal.is_running():
                self.post_message(self.ClaudeExited(0))

                if self._restart_on_exit:
                    # Wait a moment before restarting
                    await asyncio.sleep(0.5)
                    self.start_claude()
                break

    def stop_claude(self) -> None:
        """Stop the Claude Code CLI."""
        if self._terminal:
            self._terminal.stop()

        if self._monitor_task:
            self._monitor_task.cancel()
            self._monitor_task = None

    def send_input(self, text: str) -> None:
        """Send input to the Claude terminal."""
        if self._terminal:
            self._terminal.send(text)

    def send_interrupt(self) -> None:
        """Send Ctrl+C interrupt to Claude."""
        if self._terminal:
            self._terminal.send("\x03")  # Ctrl+C

    def focus_terminal(self) -> None:
        """Focus the terminal."""
        if self._terminal:
            self._terminal.focus()

    @property
    def workdir(self) -> Path:
        """Get the working directory."""
        return self._workdir

    @workdir.setter
    def workdir(self, path: Path) -> None:
        """Set the working directory (requires restart)."""
        self._workdir = path

    def set_restart_on_exit(self, restart: bool) -> None:
        """Set whether to restart Claude when it exits."""
        self._restart_on_exit = restart
