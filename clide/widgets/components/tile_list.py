"""Reusable tile/card list components for consistent styling."""

from textual.containers import Vertical
from textual.widgets import ListItem


class TileItem(ListItem):
    """A styled tile/card list item.

    Subclass this and override compose() to create custom tiles.
    The tile will automatically get alternating background colors
    and hover effects from TileListView.
    """

    pass


class TileListView(Vertical):
    """A list view with tile/card styling.

    Provides:
    - Alternating row colors using theme colors
    - Hover effects
    - Consistent padding and spacing
    - Scrollbar styling

    Usage:
        class MyTileItem(TileItem):
            def __init__(self, data: MyData) -> None:
                super().__init__()
                self.data = data

            def compose(self) -> ComposeResult:
                yield Static(f"[bold]{self.data.title}[/]\\n[dim]{self.data.subtitle}[/]", markup=True)

        class MyView(TileListView):
            def compose(self) -> ComposeResult:
                yield ListView(*[MyTileItem(d) for d in self.items], id="my-list")
    """

    DEFAULT_CSS = """
    TileListView {
        height: 1fr;
        background: $background;
    }

    TileListView ListView {
        height: 1fr;
        scrollbar-size: 1 1;
        background: $background;
    }

    TileListView ListItem {
        height: auto;
        padding: 1 1;
    }

    TileListView ListItem:even {
        background: $background;
    }

    TileListView ListItem:odd {
        background: $panel;
    }

    TileListView ListItem:hover {
        background: $surface;
    }

    TileListView ListItem:focus {
        background: $surface;
    }

    TileListView ListItem Static {
        width: 100%;
    }

    TileListView .tile-header {
        background: $surface;
        padding: 0 1;
        height: 1;
        text-style: bold;
        border-bottom: solid $primary;
    }

    TileListView .empty-message {
        padding: 2;
        text-align: center;
        color: $secondary;
    }
    """


# CSS that can be included in other components for tile styling
TILE_LIST_CSS = """
    /* Tile list styling - include in your component's DEFAULT_CSS */

    ListView {
        height: 1fr;
        scrollbar-size: 1 1;
        background: $background;
    }

    ListItem {
        height: auto;
        padding: 1 1;
    }

    ListItem:even {
        background: $background;
    }

    ListItem:odd {
        background: $panel;
    }

    ListItem:hover {
        background: $surface;
    }

    ListItem:focus {
        background: $surface;
    }

    ListItem Static {
        width: 100%;
    }
"""
