"""SQLite database engine and session management.

Used by both standalone Clide and clide-web. The database file
defaults to ~/.clide/clide.db but is configurable.
"""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

from sqlmodel import Session as DBSession
from sqlmodel import SQLModel, create_engine

_engine = None

DEFAULT_DB_PATH = Path.home() / ".clide" / "clide.db"


def get_engine(db_path: Path | None = None):
    """Create or return the SQLAlchemy engine."""
    global _engine
    if _engine is None:
        path = db_path or DEFAULT_DB_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        _engine = create_engine(
            f"sqlite:///{path}",
            echo=False,
            connect_args={"check_same_thread": False},
        )
    return _engine


def init_db(db_path: Path | None = None) -> None:
    """Create all tables if they don't exist."""
    # Import models so SQLModel registers them
    import clide.models.db  # noqa: F401

    engine = get_engine(db_path)
    SQLModel.metadata.create_all(engine)


def get_db() -> Generator[DBSession, None, None]:
    """Yield a database session. Usable as a FastAPI dependency or context manager."""
    if _engine is None:
        raise RuntimeError("Database not initialized — call init_db() first")
    with DBSession(_engine) as session:
        yield session
