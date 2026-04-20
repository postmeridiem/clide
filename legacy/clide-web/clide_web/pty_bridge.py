"""PTY bridge: fork a PTY running tmux attach, async I/O to WebSocket clients."""

from __future__ import annotations

import asyncio
import fcntl
import os
import pty
import signal
import struct
import termios
from collections.abc import Callable


class PtyBridge:
    """Manages a single PTY connection to a tmux session.

    One PtyBridge per WebSocket connection. The PTY runs `tmux attach -t <session>`.
    When the WebSocket disconnects, the PTY is killed but the tmux session persists.
    """

    def __init__(
        self,
        tmux_session: str,
        on_output: Callable[[bytes], None],
        on_exit: Callable[[], None],
        rows: int = 40,
        cols: int = 120,
    ) -> None:
        self._tmux_session = tmux_session
        self._on_output = on_output
        self._on_exit = on_exit
        self._rows = rows
        self._cols = cols
        self._pid: int | None = None
        self._master_fd: int | None = None
        self._read_task: asyncio.Task | None = None  # type: ignore[type-arg]

    @property
    def is_running(self) -> bool:
        if self._pid is None:
            return False
        try:
            pid, _ = os.waitpid(self._pid, os.WNOHANG)
            return pid == 0
        except ChildProcessError:
            return False

    def start(self) -> None:
        """Fork a PTY and exec tmux attach."""
        pid, master_fd = pty.fork()

        if pid == 0:
            # Child process
            os.environ["TERM"] = "xterm-256color"
            os.environ["COLORTERM"] = "truecolor"
            os.environ["COLUMNS"] = str(self._cols)
            os.environ["LINES"] = str(self._rows)
            os.execvp("tmux", ["tmux", "attach-session", "-t", self._tmux_session])
        else:
            # Parent process
            self._pid = pid
            self._master_fd = master_fd

            # Set non-blocking I/O
            flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
            fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

            # Set initial PTY size
            self._set_pty_size(self._rows, self._cols)

            # Start async read loop
            self._read_task = asyncio.create_task(self._read_output())

    async def _read_output(self) -> None:
        """Read PTY output and forward to callback."""
        if self._master_fd is None:
            return

        loop = asyncio.get_event_loop()
        fd = self._master_fd

        try:
            while True:
                # Wait for data using event loop (more efficient than polling)
                await _wait_for_fd(loop, fd)

                try:
                    data = os.read(fd, 65536)
                    if not data:
                        break
                    self._on_output(data)
                except BlockingIOError:
                    continue
                except OSError:
                    break
        except asyncio.CancelledError:
            pass
        finally:
            self._on_exit()

    def write(self, data: bytes) -> None:
        """Write input data to the PTY."""
        if self._master_fd is not None:
            try:
                os.write(self._master_fd, data)
            except OSError:
                pass

    def resize(self, rows: int, cols: int) -> None:
        """Resize the PTY and notify the child process."""
        self._rows = rows
        self._cols = cols
        if self._master_fd is not None:
            self._set_pty_size(rows, cols)

    def _set_pty_size(self, rows: int, cols: int) -> None:
        """Set PTY window size via ioctl and send SIGWINCH."""
        if self._master_fd is None:
            return
        try:
            winsize = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(self._master_fd, termios.TIOCSWINSZ, winsize)
            if self._pid is not None:
                try:
                    os.kill(self._pid, signal.SIGWINCH)
                except OSError:
                    pass
        except OSError:
            pass

    def stop(self) -> None:
        """Kill the PTY process and clean up."""
        if self._read_task:
            self._read_task.cancel()
            self._read_task = None

        if self._pid is not None:
            try:
                os.kill(self._pid, signal.SIGTERM)
            except OSError:
                pass
            try:
                os.waitpid(self._pid, 0)
            except ChildProcessError:
                pass
            self._pid = None

        if self._master_fd is not None:
            try:
                os.close(self._master_fd)
            except OSError:
                pass
            self._master_fd = None


async def _wait_for_fd(loop: asyncio.AbstractEventLoop, fd: int) -> None:
    """Wait until a file descriptor has data ready to read."""
    future: asyncio.Future[None] = loop.create_future()

    def _ready() -> None:
        if not future.done():
            future.set_result(None)

    loop.add_reader(fd, _ready)
    try:
        await future
    finally:
        loop.remove_reader(fd)
