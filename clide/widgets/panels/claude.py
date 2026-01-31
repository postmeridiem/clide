"""Claude panel with embedded terminal running Claude Code."""

from __future__ import annotations

import asyncio
import fcntl
import os
import pty
import shutil
import struct
import termios
import time
from pathlib import Path
from typing import TYPE_CHECKING

import pyte
from rich.text import Text
from textual.containers import Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.strip import Strip
from textual.widget import Widget

if TYPE_CHECKING:
    from textual.app import ComposeResult


class TerminalDisplay(Widget, can_focus=True):
    """A terminal emulator widget using pyte."""

    DEFAULT_CSS = """
    TerminalDisplay {
        height: 100%;
        width: 100%;
        background: $background;
    }
    """

    def __init__(
        self,
        cols: int = 80,
        rows: int = 24,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._cols = cols
        self._rows = rows
        self._screen = pyte.Screen(cols, rows)
        self._stream = pyte.Stream(self._screen)
        self._master_fd: int | None = None
        self._pid: int | None = None
        self._read_task: asyncio.Task | None = None
        self._refresh_task: asyncio.Task | None = None
        self._needs_refresh: bool = False
        self._last_refresh: float = 0

    def on_resize(self, event) -> None:
        """Handle terminal resize."""
        # Get new size from widget
        new_cols = max(event.size.width, 20)
        new_rows = max(event.size.height, 5)

        if new_cols != self._cols or new_rows != self._rows:
            self._cols = new_cols
            self._rows = new_rows
            self._screen.resize(new_rows, new_cols)

            # Update PTY size if running
            if self._master_fd is not None:
                self._set_pty_size(self._master_fd, new_rows, new_cols)

    def _set_pty_size(self, fd: int, rows: int, cols: int) -> None:
        """Set the PTY window size."""
        try:
            winsize = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
        except OSError:
            pass

    def start(self, command: str, cwd: str) -> None:
        """Start a process in the terminal."""
        # Fork a PTY
        pid, master_fd = pty.fork()

        if pid == 0:
            # Child process
            os.chdir(cwd)
            os.environ["TERM"] = "xterm-256color"
            os.environ["COLORTERM"] = "truecolor"
            os.execlp(command, command)
        else:
            # Parent process
            self._pid = pid
            self._master_fd = master_fd

            # Set non-blocking
            flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
            fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

            # Set initial size
            self._set_pty_size(master_fd, self._rows, self._cols)

            # Start reading
            self._read_task = asyncio.create_task(self._read_output())

    def _schedule_refresh(self) -> None:
        """Schedule a throttled refresh to avoid glitching."""
        self._needs_refresh = True
        if self._refresh_task is None or self._refresh_task.done():
            self._refresh_task = asyncio.create_task(self._throttled_refresh())

    async def _throttled_refresh(self) -> None:
        """Refresh at most every 16ms (~60fps) to avoid glitching."""
        min_interval = 0.016  # ~60fps
        while self._needs_refresh:
            now = time.monotonic()
            elapsed = now - self._last_refresh
            if elapsed < min_interval:
                await asyncio.sleep(min_interval - elapsed)
            self._needs_refresh = False
            self._last_refresh = time.monotonic()
            self.refresh()
            # Small delay to batch rapid updates
            await asyncio.sleep(0.008)

    async def _read_output(self) -> None:
        """Read output from the PTY."""
        if self._master_fd is None:
            return

        while True:
            try:
                # Wait for data to be available
                await asyncio.sleep(0.005)

                try:
                    data = os.read(self._master_fd, 65536)
                    if not data:
                        break

                    # Feed data to pyte
                    self._stream.feed(data.decode("utf-8", errors="replace"))
                    self._schedule_refresh()

                except BlockingIOError:
                    # No data available
                    continue
                except OSError:
                    # PTY closed
                    break

            except asyncio.CancelledError:
                break

    def stop(self) -> None:
        """Stop the terminal process."""
        if self._read_task:
            self._read_task.cancel()
            self._read_task = None

        if self._refresh_task:
            self._refresh_task.cancel()
            self._refresh_task = None

        if self._master_fd is not None:
            try:
                os.close(self._master_fd)
            except OSError:
                pass
            self._master_fd = None

        if self._pid is not None:
            try:
                os.kill(self._pid, 9)
                os.waitpid(self._pid, 0)
            except (OSError, ChildProcessError):
                pass
            self._pid = None

    def is_running(self) -> bool:
        """Check if the process is still running."""
        if self._pid is None:
            return False

        try:
            pid, status = os.waitpid(self._pid, os.WNOHANG)
            if pid == 0:
                return True  # Still running
            else:
                self._pid = None
                return False
        except ChildProcessError:
            self._pid = None
            return False

    def send(self, data: str) -> None:
        """Send data to the terminal."""
        if self._master_fd is not None:
            try:
                os.write(self._master_fd, data.encode("utf-8"))
            except OSError:
                pass

    def render_line(self, y: int) -> Strip:
        """Render a line of the terminal."""
        if y >= self._rows:
            return Strip.blank(self._cols)

        line = self._screen.buffer[y]
        text = Text()

        for x in range(self._cols):
            char = line[x]
            char_data = char.data if char.data else " "

            # Build style from pyte character attributes
            style_parts = []

            if char.fg and char.fg != "default":
                style_parts.append(f"color({char.fg})" if char.fg.startswith("#") else char.fg)

            if char.bg and char.bg != "default":
                style_parts.append(f"on color({char.bg})" if char.bg.startswith("#") else f"on {char.bg}")

            if char.bold:
                style_parts.append("bold")
            if char.italics:
                style_parts.append("italic")
            if char.underscore:
                style_parts.append("underline")
            if char.reverse:
                style_parts.append("reverse")

            style = " ".join(style_parts) if style_parts else None
            text.append(char_data, style=style)

        # Render text to segments for Strip
        segments = list(text.render(self.app.console))
        return Strip(segments)

    def on_key(self, event) -> None:
        """Handle key presses."""
        # Map special keys
        key_map = {
            "enter": "\r",
            "tab": "\t",
            "backspace": "\x7f",
            "delete": "\x1b[3~",
            "up": "\x1b[A",
            "down": "\x1b[B",
            "right": "\x1b[C",
            "left": "\x1b[D",
            "home": "\x1b[H",
            "end": "\x1b[F",
            "pageup": "\x1b[5~",
            "pagedown": "\x1b[6~",
            "escape": "\x1b",
        }

        if event.key in key_map:
            self.send(key_map[event.key])
            event.prevent_default()
            event.stop()
        elif event.key == "ctrl+c":
            self.send("\x03")
            event.prevent_default()
            event.stop()
        elif event.key == "ctrl+d":
            self.send("\x04")
            event.prevent_default()
            event.stop()
        elif event.key == "ctrl+z":
            self.send("\x1a")
            event.prevent_default()
            event.stop()
        elif event.key == "ctrl+l":
            self.send("\x0c")
            event.prevent_default()
            event.stop()
        elif event.character and len(event.character) == 1:
            self.send(event.character)
            event.prevent_default()
            event.stop()


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
