"""Auto-update service for Clide.

Checks for updates from the release server and handles self-updating.
User settings in ~/.clide/ are preserved across updates.
"""

from __future__ import annotations

import json
import logging
import os
import platform
import shutil
import stat
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

logger = logging.getLogger(__name__)

# Update server configuration
UPDATE_SERVER = "https://git.schweitz.net"
REPO_OWNER = "jeroen"  # TODO: Update with actual owner
REPO_NAME = "clide"  # TODO: Update with actual repo name

# Current version (injected at build time or read from package)
try:
    from clide import __version__ as CURRENT_VERSION
except ImportError:
    CURRENT_VERSION = "0.0.0"


@dataclass
class ReleaseInfo:
    """Information about a release."""

    version: str
    tag_name: str
    download_url: str
    release_notes: str
    published_at: str


@dataclass
class UpdateCheckResult:
    """Result of checking for updates."""

    update_available: bool
    current_version: str
    latest_version: str | None
    release_info: ReleaseInfo | None
    error: str | None = None


def get_platform_asset_name() -> str:
    """Get the expected asset name for the current platform."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    if system == "darwin":
        return "macos.dmg"
    elif system == "linux":
        # Normalize architecture names
        if machine in ("x86_64", "amd64"):
            arch = "x86_64"
        elif machine in ("aarch64", "arm64"):
            arch = "aarch64"
        else:
            arch = machine
        return f"linux-{arch}.AppImage"
    elif system == "windows":
        return "windows-setup.exe"
    else:
        raise RuntimeError(f"Unsupported platform: {system}")


def parse_version(version: str) -> tuple[int, ...]:
    """Parse a version string into a tuple for comparison."""
    # Remove 'v' prefix if present
    version = version.lstrip("v")
    # Split and convert to integers
    parts = []
    for part in version.split("."):
        # Handle versions like "1.0.0-beta"
        num_part = ""
        for char in part:
            if char.isdigit():
                num_part += char
            else:
                break
        parts.append(int(num_part) if num_part else 0)
    return tuple(parts)


def is_newer_version(current: str, latest: str) -> bool:
    """Check if latest version is newer than current."""
    return parse_version(latest) > parse_version(current)


def check_for_updates() -> UpdateCheckResult:
    """Check the release server for available updates.

    Returns:
        UpdateCheckResult with update status and release info.
    """
    try:
        # Gitea API endpoint for releases
        api_url = f"{UPDATE_SERVER}/api/v1/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"

        request = Request(api_url)
        request.add_header("Accept", "application/json")
        request.add_header("User-Agent", f"Clide/{CURRENT_VERSION}")

        with urlopen(request, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))

        tag_name = data.get("tag_name", "")
        latest_version = tag_name.lstrip("v")

        # Find the download URL for current platform
        platform_asset = get_platform_asset_name()
        download_url = None

        for asset in data.get("assets", []):
            if platform_asset in asset.get("name", ""):
                download_url = asset.get("browser_download_url")
                break

        if not download_url:
            # Try constructing URL from release
            download_url = f"{UPDATE_SERVER}/{REPO_OWNER}/{REPO_NAME}/releases/download/{tag_name}/Clide-{tag_name}-{platform_asset}"

        release_info = ReleaseInfo(
            version=latest_version,
            tag_name=tag_name,
            download_url=download_url,
            release_notes=data.get("body", ""),
            published_at=data.get("published_at", ""),
        )

        update_available = is_newer_version(CURRENT_VERSION, latest_version)

        return UpdateCheckResult(
            update_available=update_available,
            current_version=CURRENT_VERSION,
            latest_version=latest_version,
            release_info=release_info,
        )

    except URLError as e:
        logger.error(f"Failed to check for updates: {e}")
        return UpdateCheckResult(
            update_available=False,
            current_version=CURRENT_VERSION,
            latest_version=None,
            release_info=None,
            error=f"Network error: {e.reason}",
        )
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse update response: {e}")
        return UpdateCheckResult(
            update_available=False,
            current_version=CURRENT_VERSION,
            latest_version=None,
            release_info=None,
            error="Invalid response from update server",
        )
    except Exception as e:
        logger.error(f"Unexpected error checking for updates: {e}")
        return UpdateCheckResult(
            update_available=False,
            current_version=CURRENT_VERSION,
            latest_version=None,
            release_info=None,
            error=str(e),
        )


def download_update(release_info: ReleaseInfo, progress_callback=None) -> Path:
    """Download the update to a temporary location.

    Args:
        release_info: Release information with download URL.
        progress_callback: Optional callback(bytes_downloaded, total_bytes).

    Returns:
        Path to the downloaded file.

    Raises:
        RuntimeError: If download fails.
    """
    try:
        request = Request(release_info.download_url)
        request.add_header("User-Agent", f"Clide/{CURRENT_VERSION}")

        # Create temp file with appropriate extension
        suffix = Path(release_info.download_url).suffix or ""
        fd, temp_path = tempfile.mkstemp(suffix=suffix, prefix="clide_update_")
        os.close(fd)

        with urlopen(request, timeout=300) as response:
            total_size = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            chunk_size = 8192

            with open(temp_path, "wb") as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback:
                        progress_callback(downloaded, total_size)

        return Path(temp_path)

    except Exception as e:
        logger.error(f"Failed to download update: {e}")
        raise RuntimeError(f"Download failed: {e}") from e


def get_executable_path() -> Path:
    """Get the path to the current executable."""
    if getattr(sys, "frozen", False):
        # Running as compiled executable
        return Path(sys.executable)
    else:
        # Running as Python script
        return Path(sys.argv[0]).resolve()


def apply_update(downloaded_file: Path) -> bool:
    """Apply the downloaded update.

    This replaces the current executable with the new version.
    On macOS/Linux, this can happen while the app is running.
    On Windows, we need to use a helper script.

    Args:
        downloaded_file: Path to the downloaded update file.

    Returns:
        True if update was applied successfully.
    """
    system = platform.system().lower()
    current_exe = get_executable_path()

    try:
        if system == "darwin":
            # macOS: For DMG, just inform user to install manually
            # For direct binary updates, we can replace in-place
            if downloaded_file.suffix == ".dmg":
                logger.info(f"DMG downloaded to: {downloaded_file}")
                return True  # User needs to install manually

            # Direct binary replacement
            backup_path = current_exe.with_suffix(".backup")
            shutil.copy2(current_exe, backup_path)
            shutil.copy2(downloaded_file, current_exe)
            current_exe.chmod(
                current_exe.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH,
            )
            backup_path.unlink()
            return True

        elif system == "linux":
            # Linux: AppImage can be replaced directly
            if downloaded_file.suffix == ".AppImage":
                backup_path = current_exe.with_suffix(".backup")
                shutil.copy2(current_exe, backup_path)
                shutil.copy2(downloaded_file, current_exe)
                current_exe.chmod(
                    current_exe.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH,
                )
                backup_path.unlink()
                return True
            return False

        elif system == "windows":
            # Windows: Can't replace running executable directly
            # Create a batch script to replace after exit
            batch_script = current_exe.parent / "update_clide.bat"
            new_exe = downloaded_file

            script_content = f"""@echo off
echo Updating Clide...
timeout /t 2 /nobreak >nul
copy /y "{new_exe}" "{current_exe}"
del "{new_exe}"
del "%~f0"
echo Update complete!
"""
            batch_script.write_text(script_content)
            logger.info(f"Update script created: {batch_script}")
            logger.info("Please restart Clide to complete the update.")
            return True

        return False

    except Exception as e:
        logger.error(f"Failed to apply update: {e}")
        return False
    finally:
        # Clean up downloaded file if it still exists and wasn't moved
        if downloaded_file.exists() and system != "windows":
            try:
                downloaded_file.unlink()
            except Exception:
                pass


def perform_update(progress_callback=None) -> tuple[bool, str]:
    """Check for and perform an update.

    Args:
        progress_callback: Optional callback for download progress.

    Returns:
        Tuple of (success, message).
    """
    # Check for updates
    result = check_for_updates()

    if result.error:
        return False, f"Failed to check for updates: {result.error}"

    if not result.update_available:
        return True, f"Already running the latest version ({result.current_version})"

    if not result.release_info:
        return False, "No release information available"

    # Download update
    try:
        downloaded_file = download_update(result.release_info, progress_callback)
    except RuntimeError as e:
        return False, str(e)

    # Apply update
    if apply_update(downloaded_file):
        system = platform.system().lower()
        if system == "windows":
            return True, f"Update to {result.latest_version} downloaded. Restart Clide to complete."
        elif system == "darwin" and downloaded_file.suffix == ".dmg":
            return (
                True,
                f"Update {result.latest_version} downloaded to {downloaded_file}. Please install manually.",
            )
        else:
            return (
                True,
                f"Updated to {result.latest_version}. Restart Clide to use the new version.",
            )
    else:
        return False, "Failed to apply update"
