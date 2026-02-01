"""
    pyte
    ~~~~

    `pyte` implements a mix of VT100, VT220 and VT520 specification,
    and aims to support most of the `TERM=linux` functionality.

    :copyright: (c) 2011-2012 by Selectel.
    :copyright: (c) 2012-2017 by pyte authors and contributors,
                    see AUTHORS for details.
    :license: LGPL, see LICENSE for more details.

    Vendored for Clide with modifications for diagnostic logging.
"""

__all__ = (
    "Screen", "DiffScreen", "HistoryScreen", "DebugScreen",
    "Stream", "ByteStream",
    # Clide additions
    "set_debug_logger", "set_event_callback",
)

import io
from typing import Union

from .screens import Screen, DiffScreen, HistoryScreen, DebugScreen
from .screens import set_debug_logger as _set_screen_logger
from .streams import Stream, ByteStream
from .streams import set_debug_logger as _set_stream_logger
from .streams import set_event_callback

# Re-export submodules for compatibility
from . import modes
from . import screens


def set_debug_logger(logger):
    """Set debug logger for both streams and screens.

    Args:
        logger: A callable that accepts a string message, or None to disable.
    """
    _set_stream_logger(logger)
    _set_screen_logger(logger)


if __debug__:
    def dis(chars: Union[bytes, str]) -> None:
        """A :func:`dis.dis` for terminals."""
        if isinstance(chars, str):
            chars = chars.encode("utf-8")

        with io.StringIO() as buf:
            ByteStream(DebugScreen(to=buf)).feed(chars)
            print(buf.getvalue())
