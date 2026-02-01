"""Claude panel with embedded terminal running Claude Code."""

from __future__ import annotations

import asyncio
import codecs
import fcntl
import os
import pty
import re
import shutil
import struct
import termios
import time
from pathlib import Path
from typing import TYPE_CHECKING

from rich.text import Text
from textual.containers import Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.strip import Strip
from textual.widget import Widget

from clide.services.settings_service import get_settings_service

# Use vendored pyte with diagnostic logging support
from clide.vendor import pyte

if TYPE_CHECKING:
    from textual.app import ComposeResult


def _setup_terminal_debug_logging() -> None:
    """Set up terminal debug logging if enabled in settings."""
    settings = get_settings_service()
    if not settings.get("terminal_debug", False):
        return

    # Create log file in settings directory
    log_path = settings.settings_dir / "terminal_debug.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    # Open log file (append mode)
    log_file = open(log_path, "a", encoding="utf-8")

    def debug_logger(message: str) -> None:
        """Log debug message with timestamp."""
        import datetime

        timestamp = datetime.datetime.now().isoformat()
        log_file.write(f"[{timestamp}] {message}\n")
        log_file.flush()

    # Set up pyte debug logging
    pyte.set_debug_logger(debug_logger)


class TerminalDisplay(Widget, can_focus=True):
    """A terminal emulator widget using pyte."""

    DEFAULT_CSS = """
    TerminalDisplay {
        height: 100%;
        width: 100%;
        background: $background;
    }
    """

    # Internal padding (rendered as part of terminal content, uses terminal bg)
    PADDING_LEFT = 1
    PADDING_RIGHT = 1

    def __init__(
        self,
        cols: int = 80,
        rows: int = 24,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._cols = cols
        self._rows = rows

        # Set up debug logging before creating pyte objects
        _setup_terminal_debug_logging()

        self._screen = pyte.HistoryScreen(cols, rows, history=1000)
        self._screen.set_mode(pyte.modes.LNM)  # Line feed mode
        self._stream = pyte.Stream(self._screen)
        self._master_fd: int | None = None
        self._pid: int | None = None
        self._read_task: asyncio.Task | None = None
        self._refresh_task: asyncio.Task | None = None
        self._needs_refresh: bool = False
        self._last_refresh: float = 0
        self._pending_start: tuple[str, str] | None = None
        # Incremental UTF-8 decoder to handle partial sequences at buffer boundaries
        self._decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        # Scroll offset for viewing history (0 = at bottom/current, positive = scrolled up)
        self._scroll_offset: int = 0

    def on_mount(self) -> None:
        """Initialize terminal size from widget dimensions."""
        # Get actual widget size, accounting for internal padding
        size = self.size
        if size.width > 0 and size.height > 0:
            self._cols = max(size.width - self.PADDING_LEFT - self.PADDING_RIGHT, 20)
            self._rows = size.height
            self._screen.resize(self._rows, self._cols)

        # If start was called before mount, do it now
        if self._pending_start:
            command, cwd = self._pending_start
            self._pending_start = None
            self._do_start(command, cwd)

    def on_resize(self, event) -> None:
        """Handle terminal resize."""
        # Get new size from widget, accounting for internal padding
        new_cols = max(self.size.width - self.PADDING_LEFT - self.PADDING_RIGHT, 20)
        new_rows = max(self.size.height, 5)

        if new_cols != self._cols or new_rows != self._rows:
            old_cols = self._cols

            # Update dimensions first
            self._cols = new_cols
            self._rows = new_rows

            # Resize pyte screen - this will preserve content where possible
            self._screen.resize(new_rows, new_cols)

            # If screen got wider, clear the new columns to avoid stale data
            # pyte's resize should handle this, but let's be defensive
            if new_cols > old_cols:
                for y in range(new_rows):
                    line = self._screen.buffer[y]
                    for x in range(old_cols, new_cols):
                        # Clear any stale data in new columns
                        line[x] = pyte.screens.Char(" ")

            # Update PTY size if running - Claude will redraw
            if self._master_fd is not None:
                self._set_pty_size(self._master_fd, new_rows, new_cols)

            # Force a full refresh
            self.refresh()

    def _set_pty_size(self, fd: int, rows: int, cols: int) -> None:
        """Set the PTY window size and notify the child process."""
        try:
            winsize = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)

            # Send SIGWINCH to notify the child process of resize
            if self._pid is not None:
                import signal

                try:
                    os.kill(self._pid, signal.SIGWINCH)
                except OSError:
                    pass
        except OSError:
            pass

    def start(self, command: str, cwd: str) -> None:
        """Start a process in the terminal."""
        # If not mounted yet, defer start
        if not self.is_mounted:
            self._pending_start = (command, cwd)
            return

        self._do_start(command, cwd)

    def _do_start(self, command: str, cwd: str) -> None:
        """Actually start the process in the terminal."""
        # Reset decoder state for new process
        self._decoder.reset()

        # Get current widget size, accounting for internal padding
        size = self.size
        if size.width > 0 and size.height > 0:
            self._cols = max(size.width - self.PADDING_LEFT - self.PADDING_RIGHT, 20)
            self._rows = size.height
            self._screen.resize(self._rows, self._cols)

        # Fork a PTY
        pid, master_fd = pty.fork()

        if pid == 0:
            # Child process
            os.chdir(cwd)
            os.environ["TERM"] = "xterm-256color"
            os.environ["COLORTERM"] = "truecolor"
            os.environ["COLUMNS"] = str(self._cols)
            os.environ["LINES"] = str(self._rows)
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

    # Regex to filter escape sequences that pyte doesn't handle
    # Kitty keyboard protocol, bracketed paste mode queries, etc.
    _UNSUPPORTED_ESCAPES = re.compile(
        r"\x1b\[[\=\>\<][0-9;]*[a-zA-Z]"  # Kitty keyboard protocol (=, >, or < prefix)
        r"|\x1b\[\?[0-9;]*u"  # Kitty keyboard query
        r"|\x1b\[\?[0-9;]*c"  # Device attributes query
        r"|\x1b\[>[0-9;]*c"  # Secondary device attributes
        r"|\x1b\]\d+;[^\x07\x1b]*(?:\x07|\x1b\\)"  # OSC sequences (title, etc.)
        r"|\x1b\[\?2026[hl]"  # Synchronized update mode (not used by pyte)
    )

    def _filter_unsupported_escapes(self, data: str) -> str:
        """Filter out escape sequences that pyte doesn't handle."""
        return self._UNSUPPORTED_ESCAPES.sub("", data)

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

                    # Use incremental decoder to handle partial UTF-8 sequences
                    # at buffer boundaries (prevents box-drawing chars getting corrupted)
                    text = self._decoder.decode(data)
                    if not text:
                        continue  # Still waiting for more bytes to complete a sequence
                    text = self._filter_unsupported_escapes(text)

                    # Feed data to pyte
                    self._stream.feed(text)
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

    # ANSI 256-color palette (standard 16 colors)
    ANSI_COLORS = {
        "black": "#000000",
        "red": "#cd0000",
        "green": "#00cd00",
        "yellow": "#cdcd00",
        "blue": "#0000ee",
        "magenta": "#cd00cd",
        "cyan": "#00cdcd",
        "white": "#e5e5e5",
        "brightblack": "#7f7f7f",
        "brightred": "#ff0000",
        "brightgreen": "#00ff00",
        "brightyellow": "#ffff00",
        "brightblue": "#5c5cff",
        "brightmagenta": "#ff00ff",
        "brightcyan": "#00ffff",
        "brightwhite": "#ffffff",
    }

    def _convert_color(self, color: str, is_bg: bool = False) -> str | None:
        """Convert pyte color to Rich color string."""
        if not color or color == "default":
            return None

        # Handle hex colors (with or without # prefix)
        if color.startswith("#"):
            return color

        # Check if it's a hex color without # (pyte returns "ff0000" not "#ff0000")
        if len(color) == 6 and all(c in "0123456789abcdefABCDEF" for c in color):
            return f"#{color}"

        # Handle named ANSI colors
        color_lower = color.lower()
        if color_lower in self.ANSI_COLORS:
            return self.ANSI_COLORS[color_lower]

        # Handle 256-color palette (numeric)
        try:
            num = int(color)
            if 0 <= num <= 255:
                return f"color({num})"
        except ValueError:
            pass

        # Fallback: try to use the color name directly
        return color

    def _get_line_at(self, y: int):
        """Get the line at display position y, accounting for scroll offset.

        When scrolled, we show lines from history mixed with current buffer.
        scroll_offset=0 means showing current screen.
        scroll_offset=N means the top of display shows N lines back in history.
        """
        history = self._screen.history.top
        history_len = len(history)

        if self._scroll_offset == 0:
            # Not scrolled - show current buffer
            return self._screen.buffer[y]

        # Calculate which line to show
        # Display line 0 should show history[history_len - scroll_offset]
        # Display line N should show history[history_len - scroll_offset + N]
        # If that index >= history_len, we're into the current buffer

        history_index = history_len - self._scroll_offset + y

        if history_index < 0:
            # Before start of history - return blank
            return None
        elif history_index < history_len:
            # In history
            return history[history_index]
        else:
            # In current buffer
            buffer_index = history_index - history_len
            if buffer_index < self._rows:
                return self._screen.buffer[buffer_index]
            return None

    def render_line(self, y: int) -> Strip:
        """Render a line of the terminal."""
        # Screen buffer dimensions (what pyte has)
        screen_cols = self._cols
        screen_rows = self._rows

        # Widget display dimensions (what we need to output)
        output_width = (
            self.size.width
            if self.size.width > 0
            else screen_cols + self.PADDING_LEFT + self.PADDING_RIGHT
        )

        if y >= screen_rows:
            return Strip.blank(output_width)

        # Get the line to render, accounting for scroll offset
        line = self._get_line_at(y)
        if line is None:
            return Strip.blank(output_width)

        text = Text()

        # Add left padding (uses terminal background)
        text.append(" " * self.PADDING_LEFT)

        # Only access indices within the screen buffer
        cols_to_render = min(screen_cols, output_width - self.PADDING_LEFT - self.PADDING_RIGHT)

        # Debug logging for render pipeline
        debug_logger = pyte.get_debug_logger()
        log_this_line = False

        for x in range(cols_to_render):
            char = line[x]
            char_data = char.data if char.data else " "

            # Check for box-drawing and other potentially problematic characters
            if len(char_data) == 1:
                code = ord(char_data)
                # Log box-drawing characters (U+2500-U+257F)
                if 0x2500 <= code <= 0x257F:
                    log_this_line = True
                    if debug_logger:
                        debug_logger(
                            f"RENDER y={y} x={x}: box-drawing U+{code:04X} char='{char_data}'"
                        )

            # Handle characters that may not render correctly
            if len(char_data) == 1:
                code = ord(char_data)
                # Control characters (except space)
                if code < 32 and code != 0 or 127 <= code <= 159:
                    char_data = " "
                # Braille patterns (U+2800-U+28FF) - used for spinners
                # Replace with simple ASCII spinner chars or spaces
                elif 0x2800 <= code <= 0x28FF:
                    # Map braille spinner to simple dots
                    char_data = "·"

            # Build style from pyte character attributes
            style_parts = []

            # Foreground color
            fg = self._convert_color(char.fg)
            if fg:
                style_parts.append(fg)

            # Background color
            bg = self._convert_color(char.bg, is_bg=True)
            if bg:
                style_parts.append(f"on {bg}")

            # Text attributes
            if char.bold:
                style_parts.append("bold")
            if char.italics:
                style_parts.append("italic")
            if char.underscore:
                style_parts.append("underline")
            if char.strikethrough:
                style_parts.append("strike")
            if char.reverse:
                style_parts.append("reverse")

            style = " ".join(style_parts) if style_parts else None
            text.append(char_data, style=style)

        # Pad with spaces to fill remaining width (includes right padding)
        content_width = self.PADDING_LEFT + cols_to_render
        if output_width > content_width:
            text.append(" " * (output_width - content_width))

        # Debug: log the Rich Text content before rendering
        if log_this_line and debug_logger:
            debug_logger(f"RENDER y={y}: Rich Text plain='{text.plain[:80]}...'")

        # Render text to segments for Strip
        segments = list(text.render(self.app.console))

        # Debug: log segments if we had box-drawing chars
        if log_this_line and debug_logger:
            for i, seg in enumerate(segments[:10]):  # First 10 segments
                seg_text = seg.text if hasattr(seg, "text") else str(seg)
                if len(seg_text) <= 5:
                    debug_logger(f"RENDER y={y} seg[{i}]: '{seg_text}' (repr: {repr(seg_text)})")

        strip = Strip(segments)

        # Ensure strip is exactly the output width
        if strip.cell_length != output_width:
            strip = strip.crop_extend(0, output_width, None)

        return strip

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
        elif event.key == "shift+pageup":
            # Scroll up in history
            self._scroll_up(self._rows // 2)
            event.prevent_default()
            event.stop()
        elif event.key == "shift+pagedown":
            # Scroll down in history
            self._scroll_down(self._rows // 2)
            event.prevent_default()
            event.stop()
        elif event.key == "shift+home":
            # Scroll to top of history
            self._scroll_to_top()
            event.prevent_default()
            event.stop()
        elif event.key == "shift+end":
            # Scroll to bottom (current)
            self._scroll_to_bottom()
            event.prevent_default()
            event.stop()
        elif event.character and len(event.character) == 1:
            # Any typing scrolls to bottom
            self._scroll_to_bottom()
            self.send(event.character)
            event.prevent_default()
            event.stop()

    def on_mouse_scroll_up(self, event) -> None:
        """Handle mouse scroll up (view older content)."""
        self._scroll_up(3)
        event.prevent_default()
        event.stop()

    def on_mouse_scroll_down(self, event) -> None:
        """Handle mouse scroll down (view newer content)."""
        self._scroll_down(3)
        event.prevent_default()
        event.stop()

    def _scroll_up(self, lines: int) -> None:
        """Scroll up (back in history) by given number of lines."""
        max_scroll = len(self._screen.history.top)
        new_offset = min(self._scroll_offset + lines, max_scroll)
        if new_offset != self._scroll_offset:
            self._scroll_offset = new_offset
            self.refresh()

    def _scroll_down(self, lines: int) -> None:
        """Scroll down (forward toward current) by given number of lines."""
        new_offset = max(self._scroll_offset - lines, 0)
        if new_offset != self._scroll_offset:
            self._scroll_offset = new_offset
            self.refresh()

    def _scroll_to_top(self) -> None:
        """Scroll to the top of history."""
        max_scroll = len(self._screen.history.top)
        if self._scroll_offset != max_scroll:
            self._scroll_offset = max_scroll
            self.refresh()

    def _scroll_to_bottom(self) -> None:
        """Scroll to the bottom (current screen)."""
        if self._scroll_offset != 0:
            self._scroll_offset = 0
            self.refresh()

    @property
    def history_size(self) -> int:
        """Get the number of lines in scrollback history."""
        return len(self._screen.history.top)


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
