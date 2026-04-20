"""Snapshot tests for Clide UI."""

from clide.app import ClideApp


def test_initial_layout(snap_compare) -> None:
    """Test the initial application layout renders correctly."""
    app = ClideApp(test_mode=True)
    assert snap_compare(app, terminal_size=(120, 40))


def test_layout_without_right_panel(snap_compare) -> None:
    """Test layout with right panel hidden."""

    async def hide_right_panel(pilot):
        await pilot.press("f2")

    app = ClideApp(test_mode=True)
    assert snap_compare(
        app,
        terminal_size=(120, 40),
        run_before=hide_right_panel,
    )


def test_layout_without_left_panel(snap_compare) -> None:
    """Test layout with left panel hidden."""

    async def hide_left_panel(pilot):
        await pilot.press("f1")

    app = ClideApp(test_mode=True)
    assert snap_compare(
        app,
        terminal_size=(120, 40),
        run_before=hide_left_panel,
    )
