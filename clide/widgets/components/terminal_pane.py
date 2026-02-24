"""Terminal pane component with full PTY support."""

import os
from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.widgets import Static

from clide.widgets.components.terminal_display import TerminalDisplay


class TerminalPane(Vertical):
    """Full PTY terminal pane running an interactive shell."""

    DEFAULT_CSS = """
    TerminalPane {
        height: 100%;
    }

    TerminalPane .terminal-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    TerminalPane TerminalDisplay {
        height: 1fr;
    }
    """

    def __init__(self, cwd: Path | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._cwd = cwd or Path.cwd()
        self._terminal: TerminalDisplay | None = None
        self._shell = os.environ.get("SHELL", "/bin/bash")

    def compose(self) -> ComposeResult:
        yield Static(f"Terminal - {self._cwd}", classes="terminal-header")
        self._terminal = TerminalDisplay(id="terminal-display")
        yield self._terminal

    def on_mount(self) -> None:
        """Start the shell when mounted."""
        if self._terminal:
            self._terminal.start(self._shell, str(self._cwd))

    @property
    def cwd(self) -> Path:
        """Get current working directory."""
        return self._cwd

    @cwd.setter
    def cwd(self, path: Path) -> None:
        """Set current working directory."""
        self._cwd = path
        header = self.query_one(".terminal-header", Static)
        header.update(f"Terminal - {path}")

    def focus_terminal(self) -> None:
        """Focus the terminal display."""
        if self._terminal:
            self._terminal.focus()

    def stop(self) -> None:
        """Stop the terminal process."""
        if self._terminal:
            self._terminal.stop()

    def restart(self) -> None:
        """Restart the shell."""
        if self._terminal:
            self._terminal.stop()
            self._terminal.start(self._shell, str(self._cwd))
