"""Configuration for clide-web using Pydantic Settings + DB preferences."""

from __future__ import annotations

import logging
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)

DB_PATH = Path.home() / ".clide" / "clide.db"


class ClideWebSettings(BaseSettings):
    """Web server settings.

    Priority: env vars > .env file > DB preferences > defaults.
    """

    model_config = SettingsConfigDict(
        env_prefix="CLIDE_WEB_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Server
    host: str = "0.0.0.0"
    port: int = 8888

    # Paths
    projects_dir: Path = Path("/mnt/media/Projects")
    clide_bin: str = "clide"

    # Database
    db_path: Path = DB_PATH

    # Sessions
    session_timeout_seconds: int = 3600
    session_cleanup_interval_seconds: int = 60

    # Terminal
    default_cols: int = 120
    default_rows: int = 40
    term: str = "xterm-256color"

    # UI
    font_family: str = "JetBrains Mono, monospace"
    font_size: int = 14
    default_theme: str = "summer-night"


def load_settings() -> ClideWebSettings:
    """Load settings, overlaying DB preferences onto defaults.

    Env vars still take highest priority (Pydantic handles that).
    DB preferences override hardcoded defaults for fields not set via env.
    """
    import os

    # First load from env/defaults
    settings = ClideWebSettings()

    # Then overlay DB preferences for fields not explicitly set via env
    try:
        prefs = _load_db_preferences(settings.db_path)
    except Exception:
        logger.debug("Could not load DB preferences (DB may not exist yet)")
        return settings

    env_prefix = "CLIDE_WEB_"
    field_map = {
        "projects_dir": ("projects_dir", Path),
        "clide_bin": ("clide_bin", str),
        "port": ("port", int),
        "font_size": ("font_size", int),
        "default_theme": ("default_theme", str),
        "font_family": ("font_family", str),
        "host": ("host", str),
    }

    for pref_key, (field_name, field_type) in field_map.items():
        env_var = f"{env_prefix}{field_name.upper()}"
        # Only apply DB pref if env var is NOT set
        if env_var not in os.environ and pref_key in prefs:
            try:
                setattr(settings, field_name, field_type(prefs[pref_key]))
            except (ValueError, TypeError):
                pass

    return settings


def _load_db_preferences(db_path: Path) -> dict[str, str]:
    """Read UserPreference records from the database."""
    if not db_path.exists():
        return {}

    from clide.models.db import UserPreference
    from clide.services.database import get_engine
    from sqlmodel import Session as DBSession
    from sqlmodel import select

    engine = get_engine(db_path)
    with DBSession(engine) as db:
        stmt = select(UserPreference)
        return {p.key: p.value for p in db.exec(stmt).all()}
