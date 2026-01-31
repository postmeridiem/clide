"""Extension system for Clide using pluggy."""

from clide.extensions.hookspecs import ClideHookSpec, hookimpl, hookspec
from clide.extensions.manager import ExtensionManager

__all__ = ["ClideHookSpec", "ExtensionManager", "hookimpl", "hookspec"]
