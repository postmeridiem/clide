"""Shared pytest fixtures for Clide tests."""

from collections.abc import AsyncGenerator, Generator
from pathlib import Path

import pytest
from textual.pilot import Pilot

from clide.app import ClideApp
from clide.extensions.manager import ExtensionManager
from clide.models.config import ClideSettings
from tests.harnesses.app_harness import AppHarness
from tests.harnesses.controller_harness import ControllerHarness


@pytest.fixture
def temp_workdir(tmp_path: Path) -> Path:
    """Create a temporary working directory with sample files."""
    # Create sample directory structure
    (tmp_path / "src").mkdir()
    (tmp_path / "tests").mkdir()
    (tmp_path / "src" / "main.py").write_text("# Main file")
    (tmp_path / "README.md").write_text("# Test Project")

    # Initialize git repo
    (tmp_path / ".git").mkdir()

    return tmp_path


@pytest.fixture
def mock_settings() -> ClideSettings:
    """Create test settings with defaults."""
    return ClideSettings(
        theme="dark",
        claude_path="/usr/bin/echo",  # Safe mock
        auto_save=False,
        confirm_exit=False,
    )


@pytest.fixture
def mock_extension_manager() -> ExtensionManager:
    """Create an extension manager without loading external extensions."""
    manager = ExtensionManager()
    # Don't load entry points in tests
    return manager


@pytest.fixture
def app_harness(
    temp_workdir: Path,
    mock_settings: ClideSettings,
    mock_extension_manager: ExtensionManager,
) -> Generator[AppHarness, None, None]:
    """Create a full application test harness."""
    harness = AppHarness(
        workdir=temp_workdir,
        settings=mock_settings,
        extension_manager=mock_extension_manager,
    )
    yield harness


@pytest.fixture
async def running_app(
    app_harness: AppHarness,
) -> AsyncGenerator[tuple[ClideApp, Pilot], None]:
    """Start the app and yield (app, pilot) for interaction."""
    app, pilot = await app_harness.start()
    try:
        yield app, pilot
    finally:
        await app_harness.stop()


@pytest.fixture
def controller_harness() -> ControllerHarness:
    """Create an isolated controller test harness."""
    return ControllerHarness()
