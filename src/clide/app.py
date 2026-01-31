"""Main Textual Application for Clide."""

from pathlib import Path
from typing import ClassVar

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.reactive import reactive
from textual.widgets import Footer, Header

from clide.controllers.diff import DiffController
from clide.controllers.editor import EditorController
from clide.controllers.git import GitController
from clide.controllers.jira import JiraController
from clide.controllers.problems import ProblemsController
from clide.controllers.todos import TodosController
from clide.extensions.manager import ExtensionManager
from clide.models.config import ClideSettings
from clide.themes.registry import get_all_themes, get_theme
from clide.widgets.panels.claude import ClaudePanel
from clide.widgets.panels.context import ContextPanel
from clide.widgets.panels.sidebar import SidebarPanel
from clide.widgets.panels.workspace import WorkspacePanel


class ClideApp(App[None]):
    """Clide TUI Application - Claude Code IDE.

    Panel architecture:
    - Sidebar (left): Files, Git, Tree tabs + branch status
    - Center: Workspace (Editor/Diff/Terminal) + Claude panel
    - Context (right): Problems, TODOs, Jira tabs

    Workspace is hidden by default. Claude takes full height when
    workspace is hidden, 40% when visible.
    """

    TITLE = "Clide"
    SUB_TITLE = "Claude Code IDE"

    CSS: ClassVar[str] = """
    /* Main layout */
    Screen {
        layout: horizontal;
    }

    #main-container {
        width: 100%;
        height: 100%;
        layout: horizontal;
    }

    #center-column {
        width: 1fr;
        height: 100%;
        layout: vertical;
    }

    /* Panel styling */
    SidebarPanel {
        width: 20%;
        min-width: 25;
    }

    ContextPanel {
        width: 25%;
        min-width: 30;
    }

    /* Workspace + Claude layout */
    WorkspacePanel {
        height: 60%;
    }

    WorkspacePanel.hidden {
        display: none;
    }

    ClaudePanel {
        height: 100%;
    }

    ClaudePanel.with-workspace {
        height: 40%;
    }

    /* Compact mode - applied when .compact class is on #main-container */
    #main-container.compact SidebarPanel {
        display: none;
    }

    #main-container.compact ContextPanel {
        display: none;
    }

    /* Fullscreen mode */
    .fullscreen {
        dock: top;
        width: 100%;
        height: 100%;
        layer: fullscreen;
    }
    """

    # VSCode-style keybindings
    BINDINGS: ClassVar[list[Binding]] = [
        # Global
        Binding("ctrl+q", "quit", "Quit"),
        Binding("ctrl+shift+p", "command_palette", "Commands"),
        Binding("ctrl+p", "quick_open", "Quick Open"),
        Binding("ctrl+b", "toggle_sidebar", "Toggle Sidebar"),
        Binding("ctrl+shift+b", "toggle_context", "Toggle Context"),
        Binding("ctrl+`", "toggle_terminal", "Toggle Terminal"),
        Binding("ctrl+shift+c", "toggle_compact", "Compact Mode"),
        Binding("f11", "toggle_fullscreen", "Fullscreen"),
        Binding("escape", "escape", "Escape", show=False),
        # Navigation
        Binding("ctrl+1", "focus_claude", "Focus Claude", show=False),
        Binding("ctrl+2", "focus_editor", "Focus Editor", show=False),
        Binding("ctrl+3", "focus_terminal", "Focus Terminal", show=False),
        Binding("ctrl+0", "focus_sidebar", "Focus Sidebar", show=False),
        Binding("ctrl+w", "close_tab", "Close Tab", show=False),
        # Git
        Binding("ctrl+shift+g", "open_git", "Git", show=False),
        # Problems
        Binding("ctrl+shift+m", "open_problems", "Problems", show=False),
        Binding("f8", "next_problem", "Next Problem", show=False),
        Binding("shift+f8", "prev_problem", "Prev Problem", show=False),
        # Editor
        Binding("ctrl+s", "save_file", "Save", show=False),
        Binding("ctrl+g", "goto_line", "Go to Line", show=False),
        # Theme
        Binding("ctrl+k ctrl+t", "select_theme", "Select Theme", show=False),
    ]

    # Reactive state
    current_file: reactive[Path | None] = reactive(None)
    workspace_visible: reactive[bool] = reactive(False)
    compact_mode: reactive[bool] = reactive(False)
    fullscreen_panel: reactive[str | None] = reactive(None)

    def __init__(
        self,
        workdir: Path | None = None,
        settings: ClideSettings | None = None,
        test_mode: bool = False,
    ) -> None:
        super().__init__()
        self.workdir = workdir or Path.cwd()
        self.settings = settings or ClideSettings()
        self._test_mode = test_mode

        # Extension manager
        self.extension_manager = ExtensionManager()

        # Controllers
        self.git_controller = GitController(self.workdir)
        self.editor_controller = EditorController()
        self.diff_controller = DiffController(self.workdir)
        self.problems_controller = ProblemsController(self.workdir)
        self.todos_controller = TodosController(self.workdir)
        self.jira_controller = JiraController(
            enabled=self.settings.jira_enabled,
        )

        # Register themes
        self._register_themes()

    def _register_themes(self) -> None:
        """Register all themes with Textual."""
        for theme_meta in get_all_themes():
            theme_def = get_theme(theme_meta.name)
            if theme_def:
                self.register_theme(theme_def.to_textual_theme())

        # Set initial theme
        self.theme = self.settings.theme

    def compose(self) -> ComposeResult:
        """Create the main layout."""
        yield Header()

        with Horizontal(id="main-container"):
            # Left sidebar
            yield SidebarPanel(workdir=self.workdir)

            # Center column with workspace and claude
            with Vertical(id="center-column"):
                yield WorkspacePanel(workdir=self.workdir)
                yield ClaudePanel(
                    workdir=self.workdir,
                    auto_start=not self._test_mode,
                )

            # Right context panel
            yield ContextPanel(
                jira_enabled=self.settings.jira_enabled,
            )

        yield Footer()

    async def on_mount(self) -> None:
        """Initialize application on mount."""
        # Load extensions
        self.extension_manager.load_extensions()
        await self.extension_manager.trigger_app_startup(self)

        # Initial data refresh
        await self._refresh_git()
        await self._refresh_problems()
        await self._refresh_todos()
        if self.settings.jira_enabled:
            await self._refresh_jira()

        # Focus Claude panel
        self.action_focus_claude()

    # Reactive watchers
    def watch_workspace_visible(self, visible: bool) -> None:
        """Update panels when workspace visibility changes."""
        workspace = self.query_one(WorkspacePanel)
        claude = self.query_one(ClaudePanel)

        workspace.visible = visible
        claude.workspace_visible = visible

    def watch_compact_mode(self, compact: bool) -> None:
        """Toggle compact mode class."""
        container = self.query_one("#main-container")
        if compact:
            container.add_class("compact")
        else:
            container.remove_class("compact")

    # Data refresh methods
    async def _refresh_git(self) -> None:
        """Refresh git status."""
        status = await self.git_controller.get_status()
        if status:
            sidebar = self.query_one(SidebarPanel)
            sidebar.update_git_status(status.staged, status.unstaged)
            sidebar.current_branch = status.branch

        branches = await self.git_controller.get_branches()
        if branches:
            sidebar = self.query_one(SidebarPanel)
            sidebar.update_branches([b.name for b in branches])

        commits = await self.git_controller.get_log(limit=50)
        if commits:
            sidebar = self.query_one(SidebarPanel)
            sidebar.update_git_graph(commits)

    async def _refresh_problems(self) -> None:
        """Refresh linter problems."""
        problems = await self.problems_controller.run_all()
        context = self.query_one(ContextPanel)
        context.update_problems(problems)

    async def _refresh_todos(self) -> None:
        """Refresh TODOs."""
        todos = await self.todos_controller.scan()
        context = self.query_one(ContextPanel)
        context.update_todos(todos)

    async def _refresh_jira(self) -> None:
        """Refresh Jira content."""
        context = self.query_one(ContextPanel)
        context.set_jira_loading()
        content = await self.jira_controller.get_content()
        if content:
            context.update_jira(content)
        else:
            context.set_jira_error("Failed to load Jira content")

    # Action methods
    def action_toggle_sidebar(self) -> None:
        """Toggle sidebar visibility."""
        sidebar = self.query_one(SidebarPanel)
        sidebar.visible = not sidebar.visible

    def action_toggle_context(self) -> None:
        """Toggle context panel visibility."""
        context = self.query_one(ContextPanel)
        context.visible = not context.visible

    def action_toggle_terminal(self) -> None:
        """Toggle terminal (shows workspace with terminal tab)."""
        workspace = self.query_one(WorkspacePanel)
        if self.workspace_visible and workspace.active_tab == "terminal":
            self.workspace_visible = False
        else:
            workspace.show_terminal()
            self.workspace_visible = True

    def action_toggle_compact(self) -> None:
        """Toggle compact mode."""
        self.compact_mode = not self.compact_mode

    def action_toggle_fullscreen(self) -> None:
        """Toggle fullscreen for focused panel."""
        # TODO: Implement fullscreen toggle
        pass

    def action_escape(self) -> None:
        """Handle escape key."""
        if self.fullscreen_panel:
            self.fullscreen_panel = None
        elif self.workspace_visible:
            workspace = self.query_one(WorkspacePanel)
            if not workspace.has_unsaved_changes():
                self.workspace_visible = False

    def action_focus_claude(self) -> None:
        """Focus Claude panel."""
        claude = self.query_one(ClaudePanel)
        claude.focus_terminal()

    def action_focus_editor(self) -> None:
        """Focus editor."""
        self.workspace_visible = True
        workspace = self.query_one(WorkspacePanel)
        workspace.focus_tab("editor")

    def action_focus_terminal(self) -> None:
        """Focus terminal."""
        self.workspace_visible = True
        workspace = self.query_one(WorkspacePanel)
        workspace.show_terminal()

    def action_focus_sidebar(self) -> None:
        """Focus sidebar."""
        sidebar = self.query_one(SidebarPanel)
        sidebar.visible = True
        sidebar.focus()

    def action_close_tab(self) -> None:
        """Close current tab/editor."""
        # TODO: Implement tab closing
        pass

    def action_open_git(self) -> None:
        """Open git panel."""
        sidebar = self.query_one(SidebarPanel)
        sidebar.visible = True
        sidebar.focus_tab("sidebar-git")

    def action_open_problems(self) -> None:
        """Open problems panel."""
        context = self.query_one(ContextPanel)
        context.visible = True
        context.focus_problems()

    def action_next_problem(self) -> None:
        """Go to next problem."""
        # TODO: Implement problem navigation
        pass

    def action_prev_problem(self) -> None:
        """Go to previous problem."""
        # TODO: Implement problem navigation
        pass

    def action_save_file(self) -> None:
        """Save current file."""
        workspace = self.query_one(WorkspacePanel)
        # EditorPane handles save internally
        pass

    def action_goto_line(self) -> None:
        """Go to line dialog."""
        # TODO: Implement go to line
        pass

    def action_quick_open(self) -> None:
        """Quick file open."""
        # TODO: Implement quick open
        pass

    def action_select_theme(self) -> None:
        """Open theme selector."""
        # TODO: Implement theme selector via command palette
        pass

    # Event handlers for panel messages
    async def on_sidebar_panel_file_selected(
        self,
        event: SidebarPanel.FileSelected,
    ) -> None:
        """Handle file selection from sidebar."""
        self.current_file = event.path
        self.workspace_visible = True
        workspace = self.query_one(WorkspacePanel)
        workspace.open_file(event.path)

    async def on_sidebar_panel_git_file_selected(
        self,
        event: SidebarPanel.GitFileSelected,
    ) -> None:
        """Handle git file selection - show diff."""
        diff = await self.diff_controller.get_file_diff(
            str(event.path),
            staged=event.staged,
        )
        if diff:
            self.workspace_visible = True
            workspace = self.query_one(WorkspacePanel)
            workspace.show_diff(diff)

    async def on_sidebar_panel_branch_changed(
        self,
        event: SidebarPanel.BranchChanged,
    ) -> None:
        """Handle branch change."""
        success = await self.git_controller.checkout_branch(event.branch)
        if success:
            await self._refresh_git()

    async def on_context_panel_problem_clicked(
        self,
        event: ContextPanel.ProblemClicked,
    ) -> None:
        """Handle problem click - open file at line."""
        problem = event.problem
        self.workspace_visible = True
        workspace = self.query_one(WorkspacePanel)
        workspace.open_file(problem.file_path, line=problem.line)

    async def on_context_panel_todo_clicked(
        self,
        event: ContextPanel.TodoClicked,
    ) -> None:
        """Handle TODO click - open file at line."""
        item = event.item
        self.workspace_visible = True
        workspace = self.query_one(WorkspacePanel)
        workspace.open_file(item.file_path, line=item.line)

    async def on_context_panel_jira_refresh_requested(
        self,
        event: ContextPanel.JiraRefreshRequested,
    ) -> None:
        """Handle Jira refresh request."""
        await self._refresh_jira()

    async def on_workspace_panel_file_saved(
        self,
        event: WorkspacePanel.FileSaved,
    ) -> None:
        """Handle file save - refresh problems and git."""
        await self._refresh_git()
        await self._refresh_problems()

    async def on_workspace_panel_diff_accepted(
        self,
        event: WorkspacePanel.DiffAccepted,
    ) -> None:
        """Handle diff accept."""
        await self.diff_controller.accept_proposal(event.file_path)
        await self._refresh_git()
        await self._refresh_problems()

    async def on_workspace_panel_diff_rejected(
        self,
        event: WorkspacePanel.DiffRejected,
    ) -> None:
        """Handle diff reject."""
        await self.diff_controller.reject_proposal(event.file_path)
        workspace = self.query_one(WorkspacePanel)
        workspace.clear_diff()

    async def on_workspace_panel_command_submitted(
        self,
        event: WorkspacePanel.CommandSubmitted,
    ) -> None:
        """Handle terminal command - run and show output."""
        from clide.services.process_service import ProcessService

        workspace = self.query_one(WorkspacePanel)
        result = await ProcessService.run_async(
            event.command,
            cwd=self.workdir,
            shell=True,
        )
        if result.stdout:
            workspace.write_terminal_output(result.stdout)
        if result.stderr:
            workspace.write_terminal_error(result.stderr)

        # Refresh after command
        await self._refresh_git()

    def on_claude_panel_claude_started(
        self,
        event: ClaudePanel.ClaudeStarted,
    ) -> None:
        """Handle Claude Code started."""
        self.notify("Claude Code started", severity="information")

    def on_claude_panel_claude_exited(
        self,
        event: ClaudePanel.ClaudeExited,
    ) -> None:
        """Handle Claude Code exited."""
        if event.return_code != 0:
            self.notify(f"Claude Code exited with code {event.return_code}", severity="warning")
