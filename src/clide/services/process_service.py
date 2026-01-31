"""Generic subprocess management service."""

import asyncio
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CommandResult:
    """Result of a command execution."""

    returncode: int
    stdout: str
    stderr: str

    @property
    def success(self) -> bool:
        """Check if command succeeded."""
        return self.returncode == 0


class ProcessService:
    """Service for running subprocess commands."""

    def __init__(self, cwd: Path | None = None) -> None:
        self.cwd = cwd or Path.cwd()

    async def run(
        self,
        *args: str,
        cwd: Path | None = None,
        timeout: float | None = 30.0,
        env: dict[str, str] | None = None,
    ) -> CommandResult:
        """Run a command asynchronously.

        Args:
            *args: Command and arguments
            cwd: Working directory (defaults to service cwd)
            timeout: Timeout in seconds
            env: Environment variables to add

        Returns:
            CommandResult with stdout, stderr, and returncode
        """
        working_dir = cwd or self.cwd

        try:
            process = await asyncio.create_subprocess_exec(
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=working_dir,
                env=env,
            )

            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=timeout,
            )

            return CommandResult(
                returncode=process.returncode or 0,
                stdout=stdout.decode("utf-8", errors="replace"),
                stderr=stderr.decode("utf-8", errors="replace"),
            )
        except asyncio.TimeoutError:
            process.kill()
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr="Command timed out",
            )
        except Exception as e:
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr=str(e),
            )

    def run_sync(
        self,
        *args: str,
        cwd: Path | None = None,
        timeout: float | None = 30.0,
    ) -> CommandResult:
        """Run a command synchronously (for use in threads).

        Args:
            *args: Command and arguments
            cwd: Working directory
            timeout: Timeout in seconds

        Returns:
            CommandResult with stdout, stderr, and returncode
        """
        working_dir = cwd or self.cwd

        try:
            result = subprocess.run(
                args,
                capture_output=True,
                cwd=working_dir,
                timeout=timeout,
                text=True,
            )
            return CommandResult(
                returncode=result.returncode,
                stdout=result.stdout,
                stderr=result.stderr,
            )
        except subprocess.TimeoutExpired:
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr="Command timed out",
            )
        except Exception as e:
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr=str(e),
            )
