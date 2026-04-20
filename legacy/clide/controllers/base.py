"""Base controller utilities using decorator pattern."""

from functools import wraps
from typing import TYPE_CHECKING

from textual.message import Message

if TYPE_CHECKING:
    from textual.app import App


def controller[T](cls: type[T]) -> type[T]:
    """Decorator to add controller capabilities to a class.

    Adds:
    - _app attribute for parent application reference
    - set_app() method to set the application
    - post_message() method to emit messages
    - initialize() and shutdown() lifecycle hooks (if not defined)

    Usage:
        @controller
        class GitController:
            def __init__(self, workdir: Path) -> None:
                self.workdir = workdir

            async def get_status(self) -> GitStatus:
                ...
    """
    original_init = cls.__init__

    @wraps(original_init)
    def new_init(self, *args, **kwargs):
        self._app = None
        original_init(self, *args, **kwargs)

    cls.__init__ = new_init

    def set_app(self, app: "App[object]") -> None:
        """Set the parent application."""
        self._app = app

    def post_message(self, message: Message) -> None:
        """Post a message to the application's message queue."""
        if self._app:
            self._app.post_message(message)

    async def initialize(self) -> None:
        """Initialize the controller. Called after app mount."""
        pass

    async def shutdown(self) -> None:
        """Clean up resources. Called before app exit."""
        pass

    # Only add methods if they don't exist
    if not hasattr(cls, "set_app"):
        cls.set_app = set_app
    if not hasattr(cls, "post_message"):
        cls.post_message = post_message
    if not hasattr(cls, "initialize"):
        cls.initialize = initialize
    if not hasattr(cls, "shutdown"):
        cls.shutdown = shutdown

    return cls


class ControllerMixin:
    """Mixin alternative for controller capabilities.

    Use this if you prefer inheritance over decorators.

    Usage:
        class GitController(ControllerMixin):
            def __init__(self, workdir: Path) -> None:
                self.workdir = workdir
    """

    _app: "App[object] | None" = None

    def set_app(self, app: "App[object]") -> None:
        """Set the parent application."""
        self._app = app

    @property
    def app(self) -> "App[object] | None":
        """Get the parent application."""
        return self._app

    def post_message(self, message: Message) -> None:
        """Post a message to the application's message queue."""
        if self._app:
            self._app.post_message(message)

    async def initialize(self) -> None:
        """Initialize the controller. Called after app mount."""
        pass

    async def shutdown(self) -> None:
        """Clean up resources. Called before app exit."""
        pass
