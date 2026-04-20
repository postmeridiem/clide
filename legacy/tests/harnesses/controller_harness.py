"""Controller isolation test harness for Clide."""

from typing import TYPE_CHECKING, Any
from unittest.mock import AsyncMock, MagicMock

from textual.message import Message

if TYPE_CHECKING:
    from clide.controllers.base import BaseController


class MockApp:
    """Minimal mock of a Textual App for controller testing."""

    def __init__(self) -> None:
        self.messages: list[Message] = []
        self.post_message = MagicMock(side_effect=self._capture_message)

    def _capture_message(self, message: Message) -> None:
        self.messages.append(message)

    def get_messages(self, message_type: type | None = None) -> list[Message]:
        """Get captured messages, optionally filtered by type."""
        if message_type is None:
            return self.messages.copy()
        return [m for m in self.messages if isinstance(m, message_type)]

    def clear_messages(self) -> None:
        """Clear captured messages."""
        self.messages.clear()


class ControllerHarness:
    """Test harness for isolated controller testing.

    Provides a mock app environment for testing controllers without
    the full Textual application overhead.

    Usage:
        harness = ControllerHarness()
        controller = GitController(harness.mock_app)
        await controller.initialize()
        await controller.refresh_status()
        messages = harness.get_messages()
    """

    def __init__(self) -> None:
        self._mock_app = MockApp()
        self._controllers: list[BaseController] = []
        self._mocks: dict[str, Any] = {}

    @property
    def mock_app(self) -> MockApp:
        """Get the mock app for controller injection."""
        return self._mock_app

    def register_controller(self, controller: "BaseController") -> None:
        """Register a controller for lifecycle management."""
        self._controllers.append(controller)

    async def initialize_all(self) -> None:
        """Initialize all registered controllers."""
        for controller in self._controllers:
            await controller.initialize()

    async def shutdown_all(self) -> None:
        """Shutdown all registered controllers."""
        for controller in self._controllers:
            await controller.shutdown()

    def get_messages(self, message_type: type | None = None) -> list[Message]:
        """Get messages posted to the mock app."""
        return self._mock_app.get_messages(message_type)

    def clear_messages(self) -> None:
        """Clear all captured messages."""
        self._mock_app.clear_messages()

    def add_mock(self, name: str, mock: Any) -> None:
        """Add a named mock for dependency injection.

        Args:
            name: Identifier for the mock
            mock: Mock object or AsyncMock
        """
        self._mocks[name] = mock

    def get_mock(self, name: str) -> Any:
        """Retrieve a named mock."""
        return self._mocks.get(name)

    def create_async_mock(self, return_value: Any = None) -> AsyncMock:
        """Create an AsyncMock with optional return value."""
        mock = AsyncMock()
        if return_value is not None:
            mock.return_value = return_value
        return mock
