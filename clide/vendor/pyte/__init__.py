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
    "Screen",
    "DiffScreen",
    "HistoryScreen",
    "DebugScreen",
    "Stream",
    "ByteStream",
    # Clide additions
    "set_debug_logger",
    "get_debug_logger",
    "set_event_callback",
)

import io

# Re-export submodules for compatibility
from . import screens
from .screens import DebugScreen, DiffScreen, HistoryScreen, Screen
from .screens import set_debug_logger as _set_screen_logger
from .streams import ByteStream, Stream, set_event_callback
from .streams import set_debug_logger as _set_stream_logger


def set_debug_logger(logger):
    """Set debug logger for both streams and screens.

    Args:
        logger: A callable that accepts a string message, or None to disable.
    """
    _set_stream_logger(logger)
    _set_screen_logger(logger)


def get_debug_logger():
    """Get the current debug logger (if set).

    Returns:
        The current debug logger callable, or None if not set.
    """
    return screens._debug_logger


if __debug__:

    def dis(chars: bytes | str) -> None:
        """A :func:`dis.dis` for terminals."""
        if isinstance(chars, str):
            chars = chars.encode("utf-8")

        with io.StringIO() as buf:
            ByteStream(DebugScreen(to=buf)).feed(chars)
            print(buf.getvalue())
