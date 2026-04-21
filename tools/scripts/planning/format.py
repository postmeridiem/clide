"""Output formatting — table (default for TTY), json (for scripting)."""
from __future__ import annotations

import json
import sqlite3
import sys
from typing import Iterable, Mapping, Sequence


def _is_tty() -> bool:
    return sys.stdout.isatty()


def rows_to_dicts(rows: Iterable[sqlite3.Row]) -> list[dict]:
    return [dict(r) for r in rows]


def emit(data, *, mode: str | None = None) -> None:
    """Emit `data` as either JSON or a human table.

    `mode` is "json" | "table" | None (auto: table on TTY, json otherwise).
    """
    if mode is None:
        mode = "table" if _is_tty() else "json"
    if mode == "json":
        print(json.dumps(data, indent=2, default=str))
        return
    # table
    if isinstance(data, dict) and "rows" in data:
        _print_table(data["rows"])
        return
    if isinstance(data, list):
        _print_table(data)
        return
    if isinstance(data, dict):
        for k, v in data.items():
            print(f"{k}: {v}")
        return
    print(data)


def _print_table(rows: Sequence[Mapping]) -> None:
    if not rows:
        print("(no rows)")
        return
    cols = list(rows[0].keys())
    widths = {c: len(c) for c in cols}
    for r in rows:
        for c in cols:
            widths[c] = max(widths[c], len(str(r.get(c, ""))))
    header = "  ".join(c.ljust(widths[c]) for c in cols)
    print(header)
    print("  ".join("-" * widths[c] for c in cols))
    for r in rows:
        print("  ".join(str(r.get(c, "")).ljust(widths[c]) for c in cols))


def emit_board(columns: dict[str, list[sqlite3.Row]], *, mode: str | None = None) -> None:
    if mode is None:
        mode = "table" if _is_tty() else "json"
    if mode == "json":
        print(json.dumps(
            {status: rows_to_dicts(rows) for status, rows in columns.items()},
            indent=2,
            default=str,
        ))
        return
    for status, rows in columns.items():
        print(f"== {status.upper()} ({len(rows)}) ==")
        if not rows:
            print("  (empty)")
            continue
        for row in rows:
            prio = row["priority"] or "medium"
            who = row["assigned_to"] or "-"
            print(f"  {row['id']}  [{prio:8}]  @{who:10}  {row['title']}")
        print()
