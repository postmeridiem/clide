"""SQLModel table models for persistent storage.

These models serve both the standalone Clide TUI and the clide-web server.
They ARE Pydantic models (SQLModel inherits from BaseModel).
"""

from datetime import datetime

from sqlmodel import Field, SQLModel


class Project(SQLModel, table=True):
    """A project (git repo) that can be opened in Clide."""

    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(unique=True, index=True)
    path: str
    theme: str = "summer-night"
    last_accessed: datetime | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Session(SQLModel, table=True):
    """A tmux session running a Clide instance (used by clide-web)."""

    id: int | None = Field(default=None, primary_key=True)
    project_name: str = Field(index=True)
    tmux_session: str = Field(unique=True)
    pid: int | None = None
    status: str = "active"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_activity: datetime = Field(default_factory=datetime.utcnow)


class UserPreference(SQLModel, table=True):
    """Key-value user preferences persisted across restarts."""

    id: int | None = Field(default=None, primary_key=True)
    key: str = Field(unique=True, index=True)
    value: str


class ConnectionLog(SQLModel, table=True):
    """Audit log of browser connections (used by clide-web)."""

    id: int | None = Field(default=None, primary_key=True)
    project_name: str
    client_ip: str
    connected_at: datetime = Field(default_factory=datetime.utcnow)
    disconnected_at: datetime | None = None
