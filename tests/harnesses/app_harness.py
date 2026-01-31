"""Full application test harness for Clide."""

from pathlib import Path

from textual.pilot import Pilot

from clide.app import ClideApp
from clide.extensions.manager import ExtensionManager
from clide.models.config import ClideSettings


class AppHarness:
    """Test harness for running the full Clide application.

    Provides a controlled environment for integration testing with
    mocked services and isolated file systems.

    Usage:
        harness = AppHarness(workdir=tmp_path)
        app, pilot = await harness.start()
        await pilot.press("ctrl+q")
        await harness.stop()
    """

    def __init__(
        self,
        workdir: Path,
        settings: ClideSettings | None = None,
        extension_manager: ExtensionManager | None = None,
    ) -> None:
        self.workdir = workdir
        self.settings = settings or ClideSettings()
        self.extension_manager = extension_manager or ExtensionManager()
        self._app: ClideApp | None = None
        self._pilot: Pilot | None = None

    async def start(self) -> tuple[ClideApp, Pilot]:
        """Start the application and return app and pilot for testing.

        Returns:
            Tuple of (ClideApp instance, Pilot for simulating input)
        """
        self._app = ClideApp(workdir=self.workdir)
        # Inject test dependencies
        self._app.extension_manager = self.extension_manager

        # Start app in test mode
        async with self._app.run_test() as pilot:
            self._pilot = pilot
            return self._app, pilot

    async def stop(self) -> None:
        """Clean shutdown of the application."""
        if self._app:
            await self._app.action_quit()
        self._app = None
        self._pilot = None

    @property
    def app(self) -> ClideApp:
        """Get the running app instance."""
        if self._app is None:
            raise RuntimeError("App not started. Call start() first.")
        return self._app

    @property
    def pilot(self) -> Pilot:
        """Get the pilot for simulating user input."""
        if self._pilot is None:
            raise RuntimeError("App not started. Call start() first.")
        return self._pilot

    async def press_keys(self, *keys: str) -> None:
        """Simulate pressing a sequence of keys."""
        await self.pilot.press(*keys)

    async def click(self, selector: str) -> None:
        """Click on a widget by CSS selector."""
        await self.pilot.click(selector)

    async def wait_for_animation(self) -> None:
        """Wait for any running animations to complete."""
        await self.pilot.pause()
