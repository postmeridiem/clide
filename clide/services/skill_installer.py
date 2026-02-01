"""Skill installer service for Claude Code skills.

This module provides functionality to install skill templates
into the user's Claude Code configuration.
"""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Literal

# Path to bundled skill templates within Clide package
TEMPLATES_DIR = Path(__file__).parent.parent / "templates" / "skills"

# Default installation locations
USER_SKILLS_DIR = Path.home() / ".claude" / "skills"


class SkillInstaller:
    """Installs Claude Code skills from templates.

    Skills can be installed to:
    - User level: ~/.claude/skills/ (available globally)
    - Project level: .claude/skills/ (available in project only)

    Example:
        installer = SkillInstaller()

        # Check if skill exists
        if not installer.is_installed("git-workflow"):
            installer.install("git-workflow")

        # Install to project instead of user
        installer.install("git-workflow", scope="project")
    """

    def __init__(
        self,
        templates_dir: Path | None = None,
        project_dir: Path | None = None,
    ) -> None:
        """Initialize the skill installer.

        Args:
            templates_dir: Override the templates directory.
            project_dir: Project directory for project-scoped skills.
        """
        self._templates_dir = templates_dir or TEMPLATES_DIR
        self._project_dir = project_dir or Path.cwd()

    @property
    def templates_dir(self) -> Path:
        """Get the templates directory."""
        return self._templates_dir

    @property
    def user_skills_dir(self) -> Path:
        """Get the user skills directory."""
        return USER_SKILLS_DIR

    @property
    def project_skills_dir(self) -> Path:
        """Get the project skills directory."""
        return self._project_dir / ".claude" / "skills"

    def list_available_templates(self) -> list[str]:
        """List all available skill templates.

        Returns:
            List of skill names that can be installed.
        """
        if not self._templates_dir.exists():
            return []

        return [
            d.name
            for d in self._templates_dir.iterdir()
            if d.is_dir() and (d / "SKILL.md").exists()
        ]

    def list_installed_skills(
        self,
        scope: Literal["user", "project", "all"] = "all",
    ) -> list[dict[str, str]]:
        """List installed skills.

        Args:
            scope: Which skills to list - user, project, or all.

        Returns:
            List of dicts with 'name', 'scope', and 'path' keys.
        """
        skills = []

        if scope in ("user", "all"):
            if self.user_skills_dir.exists():
                for d in self.user_skills_dir.iterdir():
                    if d.is_dir() and (d / "SKILL.md").exists():
                        skills.append(
                            {
                                "name": d.name,
                                "scope": "user",
                                "path": str(d),
                            }
                        )

        if scope in ("project", "all"):
            if self.project_skills_dir.exists():
                for d in self.project_skills_dir.iterdir():
                    if d.is_dir() and (d / "SKILL.md").exists():
                        skills.append(
                            {
                                "name": d.name,
                                "scope": "project",
                                "path": str(d),
                            }
                        )

        return skills

    def is_installed(
        self,
        skill_name: str,
        scope: Literal["user", "project", "any"] = "any",
    ) -> bool:
        """Check if a skill is installed.

        Args:
            skill_name: The skill name to check.
            scope: Where to check - user, project, or any.

        Returns:
            True if the skill is installed.
        """
        if scope in ("user", "any"):
            user_skill = self.user_skills_dir / skill_name / "SKILL.md"
            if user_skill.exists():
                return True

        if scope in ("project", "any"):
            project_skill = self.project_skills_dir / skill_name / "SKILL.md"
            if project_skill.exists():
                return True

        return False

    def get_skill_path(
        self,
        skill_name: str,
        scope: Literal["user", "project", "any"] = "any",
    ) -> Path | None:
        """Get the path to an installed skill.

        Args:
            skill_name: The skill name.
            scope: Where to look - user, project, or any (project takes priority).

        Returns:
            Path to the skill directory, or None if not found.
        """
        # Project scope takes priority when scope is "any"
        if scope in ("project", "any"):
            project_skill = self.project_skills_dir / skill_name
            if (project_skill / "SKILL.md").exists():
                return project_skill

        if scope in ("user", "any"):
            user_skill = self.user_skills_dir / skill_name
            if (user_skill / "SKILL.md").exists():
                return user_skill

        return None

    def install(
        self,
        skill_name: str,
        scope: Literal["user", "project"] = "user",
        overwrite: bool = False,
    ) -> Path:
        """Install a skill from templates.

        Args:
            skill_name: The skill name to install.
            scope: Where to install - user or project level.
            overwrite: Whether to overwrite existing installation.

        Returns:
            Path to the installed skill.

        Raises:
            ValueError: If skill template doesn't exist.
            FileExistsError: If skill exists and overwrite is False.
        """
        # Check template exists
        template_dir = self._templates_dir / skill_name
        if not template_dir.exists() or not (template_dir / "SKILL.md").exists():
            raise ValueError(f"Skill template '{skill_name}' not found")

        # Determine target directory
        if scope == "user":
            target_dir = self.user_skills_dir / skill_name
        else:
            target_dir = self.project_skills_dir / skill_name

        # Check if already exists
        if target_dir.exists():
            if not overwrite:
                raise FileExistsError(f"Skill '{skill_name}' already installed at {target_dir}")
            shutil.rmtree(target_dir)

        # Create parent directory
        target_dir.parent.mkdir(parents=True, exist_ok=True)

        # Copy template
        shutil.copytree(template_dir, target_dir)

        return target_dir

    def uninstall(
        self,
        skill_name: str,
        scope: Literal["user", "project"] = "user",
    ) -> bool:
        """Uninstall a skill.

        Args:
            skill_name: The skill name to uninstall.
            scope: Where to uninstall from - user or project level.

        Returns:
            True if skill was uninstalled, False if it wasn't installed.
        """
        if scope == "user":
            skill_dir = self.user_skills_dir / skill_name
        else:
            skill_dir = self.project_skills_dir / skill_name

        if skill_dir.exists():
            shutil.rmtree(skill_dir)
            return True

        return False

    def ensure_installed(
        self,
        skill_name: str,
        scope: Literal["user", "project"] = "project",
    ) -> Path:
        """Ensure a skill is installed, installing if needed.

        Args:
            skill_name: The skill name.
            scope: Where to install if not present (default: project).

        Returns:
            Path to the skill directory.

        Raises:
            ValueError: If skill template doesn't exist.
        """
        existing = self.get_skill_path(skill_name)
        if existing:
            return existing

        return self.install(skill_name, scope=scope)


# Global instance
_skill_installer: SkillInstaller | None = None


def get_skill_installer(project_dir: Path | None = None) -> SkillInstaller:
    """Get or create the global skill installer.

    Args:
        project_dir: Project directory (only used on first call).

    Returns:
        The SkillInstaller instance.
    """
    global _skill_installer
    if _skill_installer is None:
        _skill_installer = SkillInstaller(project_dir=project_dir)
    return _skill_installer
