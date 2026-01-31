"""Typer CLI entry point for Clide."""

from pathlib import Path
from typing import Annotated, Optional

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
    version: Annotated[
        Optional[bool],
        typer.Option("--version", "-v", callback=version_callback, is_eager=True),
    ] = None,
    workdir: Annotated[
        Optional[Path],
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
