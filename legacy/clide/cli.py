"""Typer CLI entry point for Clide."""

from pathlib import Path
from typing import Annotated

import typer

from clide import __version__

app = typer.Typer(
    name="clide",
    help="A TUI CLI IDE for Claude Code CLI",
    add_completion=True,
    no_args_is_help=False,
)


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if value:
        typer.echo(f"clide {__version__}")
        raise typer.Exit()


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    _version: Annotated[
        bool | None,
        typer.Option("--version", "-v", callback=version_callback, is_eager=True),
    ] = None,
    workdir: Annotated[
        Path | None,
        typer.Option("--workdir", "-w", help="Working directory to open"),
    ] = None,
) -> None:
    """Launch Clide TUI application."""
    if ctx.invoked_subcommand is None:
        from clide.app import ClideApp

        app_instance = ClideApp(workdir=workdir)
        app_instance.run()


@app.command()
def config() -> None:
    """Open configuration editor."""
    typer.echo("Configuration editor not yet implemented")


@app.command()
def extensions() -> None:
    """List installed extensions."""
    typer.echo("Extension manager not yet implemented")


@app.command()
def update(
    check_only: Annotated[
        bool,
        typer.Option("--check", "-c", help="Only check for updates, don't install"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Force update even if already on latest"),
    ] = False,
) -> None:
    """Check for and install updates.

    Updates are downloaded from git.schweitz.net releases.
    User settings in ~/.clide/ are preserved across updates.
    """
    _ = force  # TODO: Implement force update functionality
    from clide.services.update_service import check_for_updates, perform_update

    typer.echo(f"Current version: {__version__}")
    typer.echo("Checking for updates...")

    if check_only:
        result = check_for_updates()
        if result.error:
            typer.echo(f"Error: {result.error}", err=True)
            raise typer.Exit(1)

        if result.update_available:
            typer.echo(f"Update available: {result.latest_version}")
            if result.release_info and result.release_info.release_notes:
                typer.echo("\nRelease notes:")
                typer.echo(result.release_info.release_notes[:500])
        else:
            typer.echo("Already running the latest version.")
        return

    # Perform update with progress indication
    def progress_callback(downloaded: int, total: int) -> None:
        if total > 0:
            pct = (downloaded / total) * 100
            typer.echo(f"\rDownloading: {pct:.1f}%", nl=False)

    success, message = perform_update(progress_callback)
    typer.echo("")  # Newline after progress
    typer.echo(message)

    if not success:
        raise typer.Exit(1)
