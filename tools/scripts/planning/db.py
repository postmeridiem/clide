"""SQLite wrapper — opens `.pql/pql.db` at the repo root, applies schema.

Discovery: walk up from CWD looking for a .git/ sibling; the repo root
hosts .pql/pql.db. If .pql/ doesn't exist, it's created on first open.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from .schema import SCHEMA_SQL


def repo_root(start: Path | None = None) -> Path:
    path = (start or Path.cwd()).resolve()
    for parent in (path, *path.parents):
        if (parent / ".git").exists():
            return parent
    raise RuntimeError(f"not inside a git repository (starting from {path})")


def db_path(root: Path | None = None) -> Path:
    root = root or repo_root()
    return root / ".pql" / "pql.db"


def connect(root: Path | None = None) -> sqlite3.Connection:
    path = db_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA_SQL)
    return conn
