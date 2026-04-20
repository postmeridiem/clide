"""tmux session manager: create, attach, list, kill sessions."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING

from clide.models.db import Project, Session
from sqlmodel import Session as DBSession
from sqlmodel import select

if TYPE_CHECKING:
    from clide_web.config import ClideWebSettings

logger = logging.getLogger(__name__)


class TmuxSessionManager:
    """Manages tmux sessions, one per project."""

    def __init__(self, settings: ClideWebSettings) -> None:
        self._settings = settings

    # ------------------------------------------------------------------
    # Project discovery
    # ------------------------------------------------------------------

    def list_projects(self) -> list[str]:
        """List git repos in the projects directory."""
        projects_dir = self._settings.projects_dir
        if not projects_dir.is_dir():
            return []
        return sorted(
            d.name for d in projects_dir.iterdir() if d.is_dir() and (d / ".git").exists()
        )

    def validate_project(self, name: str) -> Path | None:
        """Return project path if valid, else None."""
        project_dir = self._settings.projects_dir / name
        if project_dir.is_dir() and (project_dir / ".git").exists():
            return project_dir
        return None

    # ------------------------------------------------------------------
    # tmux operations
    # ------------------------------------------------------------------

    @staticmethod
    def _session_name(project: str) -> str:
        return f"clide-{project}"

    async def session_exists(self, project: str) -> bool:
        """Check if a tmux session exists for this project."""
        name = self._session_name(project)
        proc = await asyncio.create_subprocess_exec(
            "tmux",
            "has-session",
            "-t",
            name,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()
        return proc.returncode == 0

    async def create_session(self, project: str, db: DBSession) -> str:
        """Create a new tmux session running clide for the given project.

        Returns the tmux session name.
        """
        name = self._session_name(project)
        project_dir = self.validate_project(project)
        if project_dir is None:
            raise ValueError(f"Project '{project}' not found")

        # Check if session already exists
        if await self.session_exists(project):
            logger.info("tmux session %s already exists, reusing", name)
        else:
            clide_bin = _resolve_clide_bin(self._settings.clide_bin)
            env = _build_env(self._settings.term)
            proc = await asyncio.create_subprocess_exec(
                "tmux",
                "new-session",
                "-d",  # detached
                "-s",
                name,  # session name
                "-c",
                str(project_dir),  # working directory
                "-x",
                str(self._settings.default_cols),
                "-y",
                str(self._settings.default_rows),
                clide_bin,  # command to run
                env=env,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE,
            )
            _, stderr = await proc.communicate()
            if proc.returncode != 0:
                raise RuntimeError(f"Failed to create tmux session: {stderr.decode().strip()}")

            # Configure session: hide status bar, auto-respawn on exit
            # pane-died hook: kill the dead pane, clear all history, respawn clean
            respawn_cmd = (
                f"respawn-pane -k -t {name} -c {project_dir} {clide_bin} \\; "
                f"clear-history -t {name}"
            )
            for opt_args in [
                ["set-option", "-t", name, "status", "off"],
                ["set-option", "-t", name, "remain-on-exit", "on"],
                ["set-hook", "-t", name, "pane-died", respawn_cmd],
            ]:
                await asyncio.create_subprocess_exec(
                    "tmux",
                    *opt_args,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )

            logger.info("Created tmux session %s for project %s", name, project)

        # Persist to DB
        _upsert_project(db, project, str(project_dir))
        _upsert_session(db, project, name)

        return name

    async def list_sessions(self) -> list[dict[str, str]]:
        """List active tmux sessions matching clide-* pattern."""
        proc = await asyncio.create_subprocess_exec(
            "tmux",
            "list-sessions",
            "-F",
            "#{session_name}:#{session_created}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
        if proc.returncode != 0:
            return []

        sessions = []
        for line in stdout.decode().strip().splitlines():
            if not line.startswith("clide-"):
                continue
            parts = line.split(":", 1)
            name = parts[0]
            project = name.removeprefix("clide-")
            sessions.append({"name": name, "project": project})
        return sessions

    async def kill_session(self, project: str) -> None:
        """Kill a tmux session for a project."""
        name = self._session_name(project)
        proc = await asyncio.create_subprocess_exec(
            "tmux",
            "kill-session",
            "-t",
            name,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()
        logger.info("Killed tmux session %s", name)

    async def cleanup_dead_sessions(self, db: DBSession) -> None:
        """Sync DB session records with actual tmux state."""
        live = await self.list_sessions()
        live_names = {s["name"] for s in live}

        stmt = select(Session).where(Session.status == "active")
        for session in db.exec(stmt).all():
            if session.tmux_session not in live_names:
                session.status = "dead"
                db.add(session)
        db.commit()


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------


def _build_env(term: str) -> dict[str, str]:
    """Build environment for tmux sessions, inheriting the current env."""
    import os

    env = os.environ.copy()
    env["TERM"] = term
    env["COLORTERM"] = "truecolor"
    return env


def _resolve_clide_bin(clide_bin: str) -> str:
    """Resolve clide binary path to absolute if relative."""
    import shutil

    path = Path(clide_bin)
    if path.is_absolute():
        return clide_bin
    # Relative path — resolve against cwd
    resolved = Path.cwd() / path
    if resolved.is_file():
        return str(resolved)
    # Try to find it on PATH
    found = shutil.which(clide_bin)
    if found:
        return found
    return clide_bin  # Last resort: return as-is


def _upsert_project(db: DBSession, name: str, path: str) -> Project:
    """Create or update a project record."""
    stmt = select(Project).where(Project.name == name)
    project = db.exec(stmt).first()
    if project is None:
        project = Project(name=name, path=path)
    project.last_accessed = datetime.utcnow()
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def _upsert_session(db: DBSession, project_name: str, tmux_session: str) -> Session:
    """Create or update a session record."""
    stmt = select(Session).where(Session.tmux_session == tmux_session)
    session = db.exec(stmt).first()
    if session is None:
        session = Session(project_name=project_name, tmux_session=tmux_session)
    session.status = "active"
    session.last_activity = datetime.utcnow()
    db.add(session)
    db.commit()
    db.refresh(session)
    return session
