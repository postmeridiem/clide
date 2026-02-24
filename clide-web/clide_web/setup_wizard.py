"""Interactive setup wizard for clide-web configuration."""

from __future__ import annotations

import shutil
from pathlib import Path

from clide.models.db import UserPreference
from clide.services.database import get_engine, init_db
from sqlmodel import Session as DBSession
from sqlmodel import select


def run_setup() -> None:
    """Run the interactive setup wizard, persisting config to the database."""
    print()
    print("  ╔═══════════════════════════════════════╗")
    print("  ║        clide-web Setup Wizard         ║")
    print("  ╚═══════════════════════════════════════╝")
    print()

    db_path = Path.home() / ".clide" / "clide.db"
    init_db(db_path)
    engine = get_engine(db_path)

    with DBSession(engine) as db:
        # Projects directory
        current = _get_pref(db, "projects_dir")
        default = current or _guess_projects_dir()
        projects_dir = _prompt("Projects directory", default)
        path = Path(projects_dir).expanduser().resolve()
        if not path.is_dir():
            print(f"  Warning: '{path}' does not exist yet")
        _set_pref(db, "projects_dir", str(path))

        # Clide binary
        current = _get_pref(db, "clide_bin")
        default = current or _find_clide_bin()
        clide_bin = _prompt("Clide binary path", default)
        _set_pref(db, "clide_bin", clide_bin)

        # Port
        current = _get_pref(db, "port")
        port = _prompt("Server port", current or "8888")
        _set_pref(db, "port", port)

        # Font size
        current = _get_pref(db, "font_size")
        font_size = _prompt("Terminal font size", current or "14")
        _set_pref(db, "font_size", font_size)

        db.commit()

    print()
    print("  Configuration saved to ~/.clide/clide.db")
    print()
    print("  Run with:  clide-web")
    print()


def _prompt(label: str, default: str) -> str:
    """Prompt the user with a default value."""
    result = input(f"  {label} [{default}]: ").strip()
    return result if result else default


def _get_pref(db: DBSession, key: str) -> str | None:
    """Get a preference from the database."""
    stmt = select(UserPreference).where(UserPreference.key == key)
    pref = db.exec(stmt).first()
    return pref.value if pref else None


def _set_pref(db: DBSession, key: str, value: str) -> None:
    """Set a preference in the database."""
    stmt = select(UserPreference).where(UserPreference.key == key)
    pref = db.exec(stmt).first()
    if pref is None:
        pref = UserPreference(key=key, value=value)
    else:
        pref.value = value
    db.add(pref)


def _guess_projects_dir() -> str:
    """Try to guess a sensible default for projects directory."""
    candidates = [
        Path.home() / "Projects",
        Path.home() / "projects",
        Path.home() / "src",
        Path.home() / "code",
        Path("/mnt/media/Projects"),
    ]
    for p in candidates:
        if p.is_dir():
            return str(p)
    return str(Path.home() / "Projects")


def _find_clide_bin() -> str:
    """Try to find the clide binary."""
    found = shutil.which("clide")
    if found:
        return found
    # Check common venv locations
    candidates = [
        Path.cwd() / ".venv" / "bin" / "clide",
        Path.cwd().parent / ".venv" / "bin" / "clide",
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return "clide"


if __name__ == "__main__":
    run_setup()
