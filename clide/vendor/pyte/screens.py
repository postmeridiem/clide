"""
    pyte.screens
    ~~~~~~~~~~~~

    This module provides classes for terminal screens.

    :copyright: (c) 2011-2012 by Selectel.
    :copyright: (c) 2012-2017 by pyte authors and contributors,
                    see AUTHORS for details.
    :license: LGPL, see LICENSE for more details.

    Vendored for Clide with modifications for diagnostic logging.
"""
from __future__ import annotations

import copy
import json
import math
import os
import sys
import unicodedata
import warnings
from collections import deque, defaultdict
from functools import lru_cache
from typing import Any, Callable, DefaultDict, Dict, Generator, List, NamedTuple, Optional, Set, Sequence, TextIO, TypeVar

from wcwidth import wcwidth as _wcwidth  # type: ignore[import]

from . import (
    charsets as cs,
    control as ctrl,
    graphics as g,
    modes as mo
)
from .streams import Stream

wcwidth: Callable[[str], int] = lru_cache(maxsize=4096)(_wcwidth)

KT = TypeVar("KT")
VT = TypeVar("VT")

# Clide diagnostic logging support
_debug_logger: Optional[Callable[[str], None]] = None


def set_debug_logger(logger: Optional[Callable[[str], None]]) -> None:
    """Set a debug logger function for diagnostic output."""
    global _debug_logger
    _debug_logger = logger


def _log_debug(message: str) -> None:
    """Log a debug message if debug logging is enabled."""
    if _debug_logger is not None:
        _debug_logger(message)


class Margins(NamedTuple):
    """A container for screen's scroll margins."""
    top: int
    bottom: int


class Savepoint(NamedTuple):
    """A container for savepoint, created on :data:`~pyte.escape.DECSC`."""
    cursor: Cursor
    g0_charset: str
    g1_charset: str
    charset: int
    origin: bool
    wrap: bool


class Char(NamedTuple):
    """A single styled on-screen character."""
    data: str
    fg: str = "default"
    bg: str = "default"
    bold: bool = False
    italics: bool = False
    underscore: bool = False
    strikethrough: bool = False
    reverse: bool = False
    blink: bool = False


class Cursor:
    """Screen cursor."""
    __slots__ = ("x", "y", "attrs", "hidden")

    def __init__(self, x: int, y: int, attrs: Char = Char(" ")) -> None:
        self.x = x
        self.y = y
        self.attrs = attrs
        self.hidden = False


class StaticDefaultDict(Dict[KT, VT]):
    """A dict with a static default value."""
    def __init__(self, default: VT) -> None:
        self.default = default

    def __missing__(self, key: KT) -> VT:
        return self.default


_DEFAULT_MODE = set([mo.DECAWM, mo.DECTCEM])


class Screen:
    """A screen is an in-memory matrix of characters."""

    @property
    def default_char(self) -> Char:
        """An empty character with default foreground and background colors."""
        reverse = mo.DECSCNM in self.mode
        return Char(data=" ", fg="default", bg="default", reverse=reverse)

    def __init__(self, columns: int, lines: int) -> None:
        self.savepoints: List[Savepoint] = []
        self.columns = columns
        self.lines = lines
        self.buffer: Dict[int, StaticDefaultDict[int, Char]] = defaultdict(lambda: StaticDefaultDict[int, Char](self.default_char))
        self.dirty: Set[int] = set()
        self.reset()
        self.mode = _DEFAULT_MODE.copy()
        self.margins: Optional[Margins] = None

    def __repr__(self) -> str:
        return ("{0}({1}, {2})".format(self.__class__.__name__,
                                       self.columns, self.lines))

    @property
    def display(self) -> List[str]:
        """A list of screen lines as unicode strings."""
        def render(line: StaticDefaultDict[int, Char]) -> Generator[str, None, None]:
            is_wide_char = False
            for x in range(self.columns):
                if is_wide_char:
                    is_wide_char = False
                    continue
                char = line[x].data
                assert sum(map(wcwidth, char[1:])) == 0
                is_wide_char = wcwidth(char[0]) == 2
                yield char

        return ["".join(render(self.buffer[y])) for y in range(self.lines)]

    def reset(self) -> None:
        """Reset the terminal to its initial state."""
        _log_debug("[SCREEN] reset()")
        self.dirty.update(range(self.lines))
        self.buffer.clear()
        self.margins = None

        self.mode = _DEFAULT_MODE.copy()

        self.title = ""
        self.icon_name = ""

        self.charset = 0
        self.g0_charset = cs.LAT1_MAP
        self.g1_charset = cs.VT100_MAP

        self.tabstops = set(range(8, self.columns, 8))

        self.cursor = Cursor(0, 0)
        self.cursor_position()

        self.saved_columns: Optional[int] = None

    def resize(self, lines: Optional[int] = None, columns: Optional[int] = None) -> None:
        """Resize the screen to the given size."""
        lines = lines or self.lines
        columns = columns or self.columns

        if lines == self.lines and columns == self.columns:
            return

        _log_debug(f"[SCREEN] resize({lines}, {columns})")

        self.dirty.update(range(lines))

        if lines < self.lines:
            self.save_cursor()
            self.cursor_position(0, 0)
            self.delete_lines(self.lines - lines)
            self.restore_cursor()

        if columns < self.columns:
            for line in self.buffer.values():
                for x in range(columns, self.columns):
                    line.pop(x, None)

        self.lines, self.columns = lines, columns
        self.set_margins()

    def set_margins(self, top: Optional[int] = None, bottom: Optional[int] = None) -> None:
        """Select top and bottom margins for the scrolling region."""
        if (top is None or top == 0) and bottom is None:
            self.margins = None
            return

        margins = self.margins or Margins(0, self.lines - 1)

        if top is None:
            top = margins.top
        else:
            top = max(0, min(top - 1, self.lines - 1))
        if bottom is None:
            bottom = margins.bottom
        else:
            bottom = max(0, min(bottom - 1, self.lines - 1))

        if bottom - top >= 1:
            self.margins = Margins(top, bottom)
            self.cursor_position()

    def set_mode(self, *modes: int, **kwargs: Any) -> None:
        """Set (enable) a given list of modes."""
        mode_list = list(modes)
        if kwargs.get("private"):
            mode_list = [mode << 5 for mode in modes]
            if mo.DECSCNM in mode_list:
                self.dirty.update(range(self.lines))

        self.mode.update(mode_list)

        if mo.DECCOLM in mode_list:
            self.saved_columns = self.columns
            self.resize(columns=132)
            self.erase_in_display(2)
            self.cursor_position()

        if mo.DECOM in mode_list:
            self.cursor_position()

        if mo.DECSCNM in mode_list:
            for line in self.buffer.values():
                line.default = self.default_char
                for x in line:
                    line[x] = line[x]._replace(reverse=True)
            self.select_graphic_rendition(7)

        if mo.DECTCEM in mode_list:
            self.cursor.hidden = False

    def reset_mode(self, *modes: int, **kwargs: Any) -> None:
        """Reset (disable) a given list of modes."""
        mode_list = list(modes)
        if kwargs.get("private"):
            mode_list = [mode << 5 for mode in modes]
            if mo.DECSCNM in mode_list:
                self.dirty.update(range(self.lines))

        self.mode.difference_update(mode_list)

        if mo.DECCOLM in mode_list:
            if self.columns == 132 and self.saved_columns is not None:
                self.resize(columns=self.saved_columns)
                self.saved_columns = None
            self.erase_in_display(2)
            self.cursor_position()

        if mo.DECOM in mode_list:
            self.cursor_position()

        if mo.DECSCNM in mode_list:
            for line in self.buffer.values():
                line.default = self.default_char
                for x in line:
                    line[x] = line[x]._replace(reverse=False)
            self.select_graphic_rendition(27)

        if mo.DECTCEM in mode_list:
            self.cursor.hidden = True

    def define_charset(self, code: str, mode: str) -> None:
        """Define G0 or G1 charset."""
        if code in cs.MAPS:
            if mode == "(":
                self.g0_charset = cs.MAPS[code]
            elif mode == ")":
                self.g1_charset = cs.MAPS[code]

    def shift_in(self) -> None:
        """Select G0 character set."""
        self.charset = 0

    def shift_out(self) -> None:
        """Select G1 character set."""
        self.charset = 1

    def draw(self, data: str) -> None:
        """Display decoded characters at the current cursor position."""
        data = data.translate(
            self.g1_charset if self.charset else self.g0_charset)

        for char in data:
            char_width = wcwidth(char)

            # Clide: Log character drawing for debugging
            if _debug_logger is not None and char_width > 0:
                code = ord(char)
                if code > 127 or code < 32:
                    _log_debug(f"[DRAW] char={char!r} code=U+{code:04X} width={char_width} pos=({self.cursor.x},{self.cursor.y})")

            if self.cursor.x == self.columns:
                if mo.DECAWM in self.mode:
                    self.dirty.add(self.cursor.y)
                    self.carriage_return()
                    self.linefeed()
                elif char_width > 0:
                    self.cursor.x -= char_width

            if mo.IRM in self.mode and char_width > 0:
                self.insert_characters(char_width)

            line = self.buffer[self.cursor.y]
            if char_width == 1:
                line[self.cursor.x] = self.cursor.attrs._replace(data=char)
            elif char_width == 2:
                line[self.cursor.x] = self.cursor.attrs._replace(data=char)
                if self.cursor.x + 1 < self.columns:
                    line[self.cursor.x + 1] = self.cursor.attrs._replace(data="")
            elif char_width == 0 and unicodedata.combining(char):
                if self.cursor.x:
                    last = line[self.cursor.x - 1]
                    normalized = unicodedata.normalize("NFC", last.data + char)
                    line[self.cursor.x - 1] = last._replace(data=normalized)
                elif self.cursor.y:
                    last = self.buffer[self.cursor.y - 1][self.columns - 1]
                    normalized = unicodedata.normalize("NFC", last.data + char)
                    self.buffer[self.cursor.y - 1][self.columns - 1] = last._replace(data=normalized)
            else:
                break

            if char_width > 0:
                self.cursor.x = min(self.cursor.x + char_width, self.columns)

        self.dirty.add(self.cursor.y)

    def set_title(self, param: str) -> None:
        """Set terminal title."""
        self.title = param

    def set_icon_name(self, param: str) -> None:
        """Set icon name."""
        self.icon_name = param

    def carriage_return(self) -> None:
        """Move the cursor to the beginning of the current line."""
        self.cursor.x = 0

    def index(self) -> None:
        """Move the cursor down one line in the same column."""
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == bottom:
            self.dirty.update(range(self.lines))
            for y in range(top, bottom):
                self.buffer[y] = self.buffer[y + 1]
            self.buffer.pop(bottom, None)
        else:
            self.cursor_down()

    def reverse_index(self) -> None:
        """Move the cursor up one line in the same column."""
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == top:
            self.dirty.update(range(self.lines))
            for y in range(bottom, top, -1):
                self.buffer[y] = self.buffer[y - 1]
            self.buffer.pop(top, None)
        else:
            self.cursor_up()

    def linefeed(self) -> None:
        """Perform an index and, if LNM is set, a carriage return."""
        self.index()
        if mo.LNM in self.mode:
            self.carriage_return()

    def tab(self) -> None:
        """Move to the next tab space."""
        for stop in sorted(self.tabstops):
            if self.cursor.x < stop:
                column = stop
                break
        else:
            column = self.columns - 1
        self.cursor.x = column

    def backspace(self) -> None:
        """Move cursor to the left one."""
        self.cursor_back()

    def save_cursor(self) -> None:
        """Push the current cursor position onto the stack."""
        self.savepoints.append(Savepoint(copy.copy(self.cursor),
                                         self.g0_charset,
                                         self.g1_charset,
                                         self.charset,
                                         mo.DECOM in self.mode,
                                         mo.DECAWM in self.mode))

    def restore_cursor(self) -> None:
        """Set the current cursor position to whatever cursor is on top of the stack."""
        if self.savepoints:
            savepoint = self.savepoints.pop()
            self.g0_charset = savepoint.g0_charset
            self.g1_charset = savepoint.g1_charset
            self.charset = savepoint.charset
            if savepoint.origin:
                self.set_mode(mo.DECOM)
            if savepoint.wrap:
                self.set_mode(mo.DECAWM)
            self.cursor = savepoint.cursor
            self.ensure_hbounds()
            self.ensure_vbounds(use_margins=True)
        else:
            self.reset_mode(mo.DECOM)
            self.cursor_position()

    def insert_lines(self, count: Optional[int] = None) -> None:
        """Insert the indicated # of lines at line with cursor."""
        count = count or 1
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if top <= self.cursor.y <= bottom:
            self.dirty.update(range(self.cursor.y, self.lines))
            for y in range(bottom, self.cursor.y - 1, -1):
                if y + count <= bottom and y in self.buffer:
                    self.buffer[y + count] = self.buffer[y]
                self.buffer.pop(y, None)
            self.carriage_return()

    def delete_lines(self, count: Optional[int] = None) -> None:
        """Delete the indicated # of lines."""
        count = count or 1
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if top <= self.cursor.y <= bottom:
            self.dirty.update(range(self.cursor.y, self.lines))
            for y in range(self.cursor.y, bottom + 1):
                if y + count <= bottom:
                    if y + count in self.buffer:
                        self.buffer[y] = self.buffer.pop(y + count)
                else:
                    self.buffer.pop(y, None)
            self.carriage_return()

    def insert_characters(self, count: Optional[int] = None) -> None:
        """Insert the indicated # of blank characters at the cursor position."""
        self.dirty.add(self.cursor.y)
        count = count or 1
        line = self.buffer[self.cursor.y]
        for x in range(self.columns, self.cursor.x - 1, -1):
            if x + count <= self.columns:
                line[x + count] = line[x]
            line.pop(x, None)

    def delete_characters(self, count: Optional[int] = None) -> None:
        """Delete the indicated # of characters."""
        self.dirty.add(self.cursor.y)
        count = count or 1
        line = self.buffer[self.cursor.y]
        for x in range(self.cursor.x, self.columns):
            if x + count <= self.columns:
                line[x] = line.pop(x + count, self.default_char)
            else:
                line.pop(x, None)

    def erase_characters(self, count: Optional[int] = None) -> None:
        """Erase the indicated # of characters."""
        self.dirty.add(self.cursor.y)
        count = count or 1
        line = self.buffer[self.cursor.y]
        for x in range(self.cursor.x, min(self.cursor.x + count, self.columns)):
            line[x] = self.cursor.attrs

    def erase_in_line(self, how: int = 0, private: bool = False) -> None:
        """Erase a line in a specific way."""
        self.dirty.add(self.cursor.y)
        if how == 0:
            interval = range(self.cursor.x, self.columns)
        elif how == 1:
            interval = range(self.cursor.x + 1)
        elif how == 2:
            interval = range(self.columns)

        line = self.buffer[self.cursor.y]
        for x in interval:
            line[x] = self.cursor.attrs

    def erase_in_display(self, how: int = 0, *args: Any, **kwargs: Any) -> None:
        """Erases display in a specific way."""
        _log_debug(f"[SCREEN] erase_in_display(how={how})")

        if how == 0:
            interval = range(self.cursor.y + 1, self.lines)
        elif how == 1:
            interval = range(self.cursor.y)
        elif how == 2 or how == 3:
            interval = range(self.lines)

        self.dirty.update(interval)
        for y in interval:
            line = self.buffer[y]
            for x in line:
                line[x] = self.cursor.attrs

        if how == 0 or how == 1:
            self.erase_in_line(how)

    def set_tab_stop(self) -> None:
        """Set a horizontal tab stop at cursor position."""
        self.tabstops.add(self.cursor.x)

    def clear_tab_stop(self, how: int = 0) -> None:
        """Clear a horizontal tab stop."""
        if how == 0:
            self.tabstops.discard(self.cursor.x)
        elif how == 3:
            self.tabstops = set()

    def ensure_hbounds(self) -> None:
        """Ensure the cursor is within horizontal screen bounds."""
        self.cursor.x = min(max(0, self.cursor.x), self.columns - 1)

    def ensure_vbounds(self, use_margins: Optional[bool] = None) -> None:
        """Ensure the cursor is within vertical screen bounds."""
        if (use_margins or mo.DECOM in self.mode) and self.margins is not None:
            top, bottom = self.margins
        else:
            top, bottom = 0, self.lines - 1
        self.cursor.y = min(max(top, self.cursor.y), bottom)

    def cursor_up(self, count: Optional[int] = None) -> None:
        """Move cursor up the indicated # of lines."""
        top, _bottom = self.margins or Margins(0, self.lines - 1)
        self.cursor.y = max(self.cursor.y - (count or 1), top)

    def cursor_up1(self, count: Optional[int] = None) -> None:
        """Move cursor up the indicated # of lines to column 1."""
        self.cursor_up(count)
        self.carriage_return()

    def cursor_down(self, count: Optional[int] = None) -> None:
        """Move cursor down the indicated # of lines."""
        _top, bottom = self.margins or Margins(0, self.lines - 1)
        self.cursor.y = min(self.cursor.y + (count or 1), bottom)

    def cursor_down1(self, count: Optional[int] = None) -> None:
        """Move cursor down the indicated # of lines to column 1."""
        self.cursor_down(count)
        self.carriage_return()

    def cursor_back(self, count: Optional[int] = None) -> None:
        """Move cursor left the indicated # of columns."""
        if self.cursor.x == self.columns:
            self.cursor.x -= 1
        self.cursor.x -= count or 1
        self.ensure_hbounds()

    def cursor_forward(self, count: Optional[int] = None) -> None:
        """Move cursor right the indicated # of columns."""
        self.cursor.x += count or 1
        self.ensure_hbounds()

    def cursor_position(self, line: Optional[int] = None, column: Optional[int] = None) -> None:
        """Set the cursor to a specific line and column."""
        column = (column or 1) - 1
        line = (line or 1) - 1

        if self.margins is not None and mo.DECOM in self.mode:
            line += self.margins.top
            if not self.margins.top <= line <= self.margins.bottom:
                return

        self.cursor.x = column
        self.cursor.y = line
        self.ensure_hbounds()
        self.ensure_vbounds()

    def cursor_to_column(self, column: Optional[int] = None) -> None:
        """Move cursor to a specific column in the current line."""
        self.cursor.x = (column or 1) - 1
        self.ensure_hbounds()

    def cursor_to_line(self, line: Optional[int] = None) -> None:
        """Move cursor to a specific line in the current column."""
        self.cursor.y = (line or 1) - 1
        if mo.DECOM in self.mode:
            assert self.margins is not None
            self.cursor.y += self.margins.top
        self.ensure_vbounds()

    def bell(self, *args: Any) -> None:
        """Bell stub."""
        pass

    def alignment_display(self) -> None:
        """Fills screen with uppercase E's for screen focus and alignment."""
        self.dirty.update(range(self.lines))
        for y in range(self.lines):
            for x in range(self.columns):
                self.buffer[y][x] = self.buffer[y][x]._replace(data="E")

    def select_graphic_rendition(self, *attrs: int) -> None:
        """Set display attributes."""
        replace = {}

        if not attrs or attrs == (0, ):
            self.cursor.attrs = self.default_char
            return

        attrs_list = list(reversed(attrs))

        while attrs_list:
            attr = attrs_list.pop()
            if attr == 0:
                replace.update(self.default_char._asdict())
            elif attr in g.FG_ANSI:
                replace["fg"] = g.FG_ANSI[attr]
            elif attr in g.BG:
                replace["bg"] = g.BG_ANSI[attr]
            elif attr in g.TEXT:
                attr_str = g.TEXT[attr]
                replace[attr_str[1:]] = attr_str.startswith("+")
            elif attr in g.FG_AIXTERM:
                replace.update(fg=g.FG_AIXTERM[attr])
            elif attr in g.BG_AIXTERM:
                replace.update(bg=g.BG_AIXTERM[attr])
            elif attr in (g.FG_256, g.BG_256):
                key = "fg" if attr == g.FG_256 else "bg"
                try:
                    n = attrs_list.pop()
                    if n == 5:
                        m = attrs_list.pop()
                        replace[key] = g.FG_BG_256[m]
                    elif n == 2:
                        replace[key] = "{0:02x}{1:02x}{2:02x}".format(
                            attrs_list.pop(), attrs_list.pop(), attrs_list.pop())
                except IndexError:
                    pass

        self.cursor.attrs = self.cursor.attrs._replace(**replace)

    def report_device_attributes(self, mode: int = 0, **kwargs: bool) -> None:
        """Report terminal identity."""
        if mode == 0 and not kwargs.get("private"):
            self.write_process_input(ctrl.CSI + "?6c")

    def report_device_status(self, mode: int) -> None:
        """Report terminal status or cursor position."""
        if mode == 5:
            self.write_process_input(ctrl.CSI + "0n")
        elif mode == 6:
            x = self.cursor.x + 1
            y = self.cursor.y + 1
            if mo.DECOM in self.mode:
                assert self.margins is not None
                y -= self.margins.top
            self.write_process_input(ctrl.CSI + "{0};{1}R".format(y, x))

    def write_process_input(self, data: str) -> None:
        """Write data to the process running inside the terminal."""
        pass

    def debug(self, *args: Any, **kwargs: Any) -> None:
        """Endpoint for unrecognized escape sequences."""
        if _debug_logger is not None:
            _log_debug(f"[DEBUG] unrecognized: args={args} kwargs={kwargs}")


class DiffScreen(Screen):
    """A screen subclass, which maintains a set of dirty lines. Deprecated."""
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        warnings.warn(
            "The functionality of ``DiffScreen` has been merged into "
            "``Screen`` and will be removed in 0.8.0.", DeprecationWarning)
        super(DiffScreen, self).__init__(*args, **kwargs)


class History(NamedTuple):
    top: deque[StaticDefaultDict[int, Char]]
    bottom: deque[StaticDefaultDict[int, Char]]
    ratio: float
    size: int
    position: int


class HistoryScreen(Screen):
    """A Screen subclass, which keeps track of screen history."""

    _wrapped = set(Stream.events)
    _wrapped.update(["next_page", "prev_page"])

    def __init__(self, columns: int, lines: int, history: int = 100, ratio: float = .5) -> None:
        self.history = History(deque(maxlen=history),
                               deque(maxlen=history),
                               float(ratio),
                               history,
                               history)
        super(HistoryScreen, self).__init__(columns, lines)

    def _make_wrapper(self, event: str, handler: Callable[..., Any]) -> Callable[..., Any]:
        def inner(*args: Any, **kwargs: Any) -> Any:
            self.before_event(event)
            result = handler(*args, **kwargs)
            self.after_event(event)
            return result
        return inner

    def __getattribute__(self, attr: str) -> Callable[..., Any]:
        value = super(HistoryScreen, self).__getattribute__(attr)
        if attr in HistoryScreen._wrapped:
            return HistoryScreen._make_wrapper(self, attr, value)
        else:
            return value  # type: ignore[no-any-return]

    def before_event(self, event: str) -> None:
        """Ensure a screen is at the bottom of the history buffer."""
        if event not in ["prev_page", "next_page"]:
            while self.history.position < self.history.size:
                self.next_page()

    def after_event(self, event: str) -> None:
        """Ensure all lines on a screen have proper width."""
        if event in ["prev_page", "next_page"]:
            for line in self.buffer.values():
                for x in line:
                    if x > self.columns:
                        line.pop(x)

        self.cursor.hidden = not (
            self.history.position == self.history.size and
            mo.DECTCEM in self.mode
        )

    def _reset_history(self) -> None:
        self.history.top.clear()
        self.history.bottom.clear()
        self.history = self.history._replace(position=self.history.size)

    def reset(self) -> None:
        """Overloaded to reset screen history state."""
        super(HistoryScreen, self).reset()
        self._reset_history()

    def erase_in_display(self, how: int = 0, *args: Any, **kwargs: Any) -> None:
        """Overloaded to reset history state."""
        super(HistoryScreen, self).erase_in_display(how, *args, **kwargs)
        if how == 3:
            self._reset_history()

    def index(self) -> None:
        """Overloaded to update top history with the removed lines."""
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == bottom:
            self.history.top.append(self.buffer[top])
        super(HistoryScreen, self).index()

    def reverse_index(self) -> None:
        """Overloaded to update bottom history with the removed lines."""
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == top:
            self.history.bottom.append(self.buffer[bottom])
        super(HistoryScreen, self).reverse_index()

    def prev_page(self) -> None:
        """Move the screen page up through the history buffer."""
        if self.history.position > self.lines and self.history.top:
            mid = min(len(self.history.top),
                      int(math.ceil(self.lines * self.history.ratio)))

            self.history.bottom.extendleft(
                self.buffer[y]
                for y in range(self.lines - 1, self.lines - mid - 1, -1))
            self.history = self.history._replace(position=self.history.position - mid)

            for y in range(self.lines - 1, mid - 1, -1):
                self.buffer[y] = self.buffer[y - mid]
            for y in range(mid - 1, -1, -1):
                self.buffer[y] = self.history.top.pop()

            self.dirty = set(range(self.lines))

    def next_page(self) -> None:
        """Move the screen page down through the history buffer."""
        if self.history.position < self.history.size and self.history.bottom:
            mid = min(len(self.history.bottom),
                      int(math.ceil(self.lines * self.history.ratio)))

            self.history.top.extend(self.buffer[y] for y in range(mid))
            self.history = self.history._replace(position=self.history.position + mid)

            for y in range(self.lines - mid):
                self.buffer[y] = self.buffer[y + mid]
            for y in range(self.lines - mid, self.lines):
                self.buffer[y] = self.history.bottom.popleft()

            self.dirty = set(range(self.lines))


class DebugEvent(NamedTuple):
    """Event dispatched to DebugScreen."""
    name: str
    args: Any
    kwargs: Any

    @staticmethod
    def from_string(line: str) -> DebugEvent:
        return DebugEvent(*json.loads(line))

    def __str__(self) -> str:
        return json.dumps(self)

    def __call__(self, screen: Screen) -> Any:
        """Execute this event on a given screen."""
        return getattr(screen, self.name)(*self.args, **self.kwargs)


class DebugScreen:
    """A screen which dumps a subset of the received events to a file."""

    def __init__(self, to: TextIO = sys.stderr, only: Sequence[str] = ()) -> None:
        self.to = to
        self.only = only

    def only_wrapper(self, attr: str) -> Callable[..., None]:
        def wrapper(*args: Any, **kwargs: Any) -> None:
            self.to.write(str(DebugEvent(attr, args, kwargs)))
            self.to.write(str(os.linesep))
        return wrapper

    def __getattribute__(self, attr: str) -> Callable[..., None]:
        if attr not in Stream.events:
            return super(DebugScreen, self).__getattribute__(attr)  # type: ignore[no-any-return]
        elif not self.only or attr in self.only:
            return self.only_wrapper(attr)
        else:
            return lambda *args, **kwargs: None
