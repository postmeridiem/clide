"""Terminal pane component."""

from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Input, RichLog, Static


class TerminalPane(Vertical):
    """Simple terminal/command runner pane."""

    DEFAULT_CSS = """
    TerminalPane {
        height: 100%;
    }

    TerminalPane .terminal-header {
        height: 1;
        background: $surface;
        padding: 0 1;
    }

    TerminalPane RichLog {
        height: 1fr;
        background: $background;
    }

    TerminalPane Input {
        dock: bottom;
        height: 1;
    }

    TerminalPane .prompt {
        color: $primary;
    }

    TerminalPane .output {
        color: $foreground;
    }

    TerminalPane .error {
        color: $error;
    }
    """

    class CommandSubmitted(Message):
        """Emitted when a command is submitted."""

        def __init__(self, command: str) -> None:
            self.command = command
            super().__init__()

    def __init__(self, cwd: Path | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._cwd = cwd or Path.cwd()
        self._history: list[str] = []
        self._history_index = 0

    def compose(self) -> ComposeResult:
        yield Static(f"Terminal - {self._cwd}", classes="terminal-header")
        yield RichLog(id="terminal-log", highlight=True, markup=True)
        yield Input(placeholder="Enter command...", id="terminal-input")

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

    def write_output(self, text: str, style: str = "output") -> None:
        """Write output to terminal.

        Args:
            text: Text to write
            style: Style class (output, error, prompt)
        """
        log = self.query_one("#terminal-log", RichLog)
        if style == "error":
            log.write(f"[red]{text}[/]")
        elif style == "prompt":
            log.write(f"[bold cyan]$ {text}[/]")
        else:
            log.write(text)

    def write_command(self, command: str) -> None:
        """Write a command to terminal (with prompt)."""
        self.write_output(command, "prompt")

    def write_error(self, error: str) -> None:
        """Write an error to terminal."""
        self.write_output(error, "error")

    def clear(self) -> None:
        """Clear terminal output."""
        log = self.query_one("#terminal-log", RichLog)
        log.clear()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle command submission."""
        command = event.value.strip()
        if not command:
            return

        # Add to history
        self._history.append(command)
        self._history_index = len(self._history)

        # Clear input
        event.input.clear()

        # Write command to output
        self.write_command(command)

        # Post message for handling
        self.post_message(self.CommandSubmitted(command))

    def history_up(self) -> None:
        """Navigate history up."""
        if self._history and self._history_index > 0:
            self._history_index -= 1
            input_widget = self.query_one("#terminal-input", Input)
            input_widget.value = self._history[self._history_index]

    def history_down(self) -> None:
        """Navigate history down."""
        input_widget = self.query_one("#terminal-input", Input)
        if self._history_index < len(self._history) - 1:
            self._history_index += 1
            input_widget.value = self._history[self._history_index]
        else:
            self._history_index = len(self._history)
            input_widget.clear()
