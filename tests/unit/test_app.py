"""Tests for ClideApp."""

from pathlib import Path

from clide.models.config import ClideSettings


class TestClideAppInit:
    """Tests for ClideApp initialization."""

    def test_default_initialization(self):
        """Test default initialization."""
        from clide.app import ClideApp

        app = ClideApp()
        assert app.workdir == Path.cwd()
        assert isinstance(app.settings, ClideSettings)
        # Note: reactive properties can't be tested directly without running the app
        # because watchers try to query the DOM

    def test_initialization_with_workdir(self, tmp_path: Path):
        """Test initialization with custom workdir."""
        from clide.app import ClideApp

        app = ClideApp(workdir=tmp_path)
        assert app.workdir == tmp_path

    def test_initialization_with_settings(self):
        """Test initialization with custom settings."""
        from clide.app import ClideApp

        settings = ClideSettings(theme="dracula", jira_enabled=True)
        app = ClideApp(settings=settings)
        assert app.settings.theme == "dracula"
        assert app.settings.jira_enabled is True

    def test_controllers_initialized(self, tmp_path: Path):
        """Test that all controllers are initialized."""
        from clide.app import ClideApp
        from clide.controllers.diff import DiffController
        from clide.controllers.editor import EditorController
        from clide.controllers.git import GitController
        from clide.controllers.jira import JiraController
        from clide.controllers.problems import ProblemsController
        from clide.controllers.todos import TodosController

        app = ClideApp(workdir=tmp_path)
        assert isinstance(app.git_controller, GitController)
        assert isinstance(app.editor_controller, EditorController)
        assert isinstance(app.diff_controller, DiffController)
        assert isinstance(app.problems_controller, ProblemsController)
        assert isinstance(app.todos_controller, TodosController)
        assert isinstance(app.jira_controller, JiraController)

    def test_jira_controller_enabled_from_settings(self):
        """Test Jira controller uses settings."""
        from clide.app import ClideApp

        settings = ClideSettings(jira_enabled=True)
        app = ClideApp(settings=settings)
        assert app.jira_controller.enabled is True

        settings_disabled = ClideSettings(jira_enabled=False)
        app_disabled = ClideApp(settings=settings_disabled)
        assert app_disabled.jira_controller.enabled is False


class TestClideAppBindings:
    """Tests for ClideApp keybindings."""

    def test_bindings_defined(self):
        """Test that keybindings are defined."""
        from clide.app import ClideApp

        app = ClideApp()
        bindings = {b.key for b in app.BINDINGS}

        # Check key bindings exist (alt-based per CLAUDE.md design)
        assert "alt+q" in bindings  # Quit
        assert "alt+b" in bindings  # Toggle sidebar
        assert "alt+p" in bindings  # Command palette
        assert "alt+`" in bindings  # Toggle terminal
        assert "alt+1" in bindings  # Focus Claude
        assert "f11" in bindings  # Fullscreen
        assert "escape" in bindings  # Exit fullscreen


class TestClideAppMeta:
    """Tests for ClideApp metadata."""

    def test_title(self):
        """Test app title."""
        from clide.app import ClideApp

        app = ClideApp()
        assert app.TITLE == "Clide"
        assert app.SUB_TITLE == "Claude Code IDE"

    def test_css_defined(self):
        """Test CSS is defined."""
        from clide.app import ClideApp

        assert ClideApp.CSS
        assert "#main-container" in ClideApp.CSS
        assert "SidebarPanel" in ClideApp.CSS
        assert "ContextPanel" in ClideApp.CSS
        assert "WorkspacePanel" in ClideApp.CSS
        assert "ClaudePanel" in ClideApp.CSS


class TestClideAppReactive:
    """Tests for ClideApp reactive properties.

    Note: Most reactive property tests require running the app
    because accessing them triggers watchers that query the DOM.
    These tests verify the property definitions exist.
    """

    def test_reactive_properties_defined(self):
        """Test that reactive properties are defined."""
        from clide.app import ClideApp

        # Check the reactive descriptors exist on the class
        assert hasattr(ClideApp, "workspace_visible")
        assert hasattr(ClideApp, "compact_mode")
        assert hasattr(ClideApp, "fullscreen_panel")
        assert hasattr(ClideApp, "current_file")


class TestClideAppThemes:
    """Tests for ClideApp theme registration."""

    def test_themes_registered(self):
        """Test that themes are registered."""
        from clide.app import ClideApp

        app = ClideApp()
        # Default theme should be set
        assert app.theme == "summer-night"

    def test_custom_theme_from_settings(self):
        """Test that custom theme from settings is applied."""
        from clide.app import ClideApp

        settings = ClideSettings(theme="dracula")
        app = ClideApp(settings=settings)
        assert app.theme == "dracula"


class TestClideAppActions:
    """Tests for ClideApp action methods.

    Note: Action methods that modify reactive properties or
    query the DOM cannot be fully tested without running the app.
    """

    def test_action_methods_exist(self):
        """Test that action methods are defined."""
        from clide.app import ClideApp

        app = ClideApp()
        # Verify action methods exist
        assert hasattr(app, "action_toggle_compact")
        assert hasattr(app, "action_toggle_sidebar")
        assert hasattr(app, "action_toggle_context")
        assert hasattr(app, "action_toggle_terminal")
        assert hasattr(app, "action_focus_claude")
        assert callable(app.action_toggle_compact)


class TestClideSettings:
    """Tests for ClideSettings."""

    def test_default_settings(self):
        """Test default settings values."""
        settings = ClideSettings()
        assert settings.theme == "summer-night"
        assert settings.jira_enabled is False

    def test_custom_settings(self):
        """Test custom settings values."""
        settings = ClideSettings(theme="nord", jira_enabled=True)
        assert settings.theme == "nord"
        assert settings.jira_enabled is True
