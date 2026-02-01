"""Syntax highlighting service for additional language support.

Textual 7.x includes built-in support for many languages when tree-sitter
packages are installed. This module provides utilities for checking and
registering additional languages.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

# Languages supported by Textual's TextArea with tree-sitter packages
SUPPORTED_LANGUAGES = {
    # Core web languages
    "python",
    "javascript",
    "typescript",
    "html",
    "css",
    "json",
    # Markup/config
    "markdown",
    "yaml",
    "toml",
    "xml",
    # Shell
    "bash",
    # SQL
    "sql",
    # Systems languages
    "rust",
    "go",
    "java",
    # Regex
    "regex",
}

# Additional languages that may be registered if packages are available
OPTIONAL_LANGUAGES = [
    "dart",
    "kotlin",
    "swift",
    "scala",
    "ruby",
    "php",
    "lua",
    "c",
    "cpp",
    "csharp",
    "elixir",
    "haskell",
    "ocaml",
    "zig",
    "nim",
    "vue",
    "svelte",
]


def register_languages() -> list[str]:
    """Register additional languages with Textual's TextArea.

    In Textual 7.x, languages are automatically registered when tree-sitter
    packages are installed. This function registers additional languages
    that need special handling (like TypeScript which has separate functions).

    Returns:
        List of successfully registered language names
    """
    try:
        from textual.widgets import TextArea
    except ImportError:
        logger.warning("Textual not available")
        return []

    registered = []

    # Register TypeScript and TSX (they have special language function names)
    try:
        import tree_sitter_typescript as tst

        # Register TypeScript
        try:
            TextArea.register_language(tst.language_typescript(), "typescript")
            registered.append("typescript")
            logger.debug("Registered language: typescript")
        except Exception as e:
            logger.debug(f"Could not register typescript: {e}")

        # Register TSX
        try:
            TextArea.register_language(tst.language_tsx(), "tsx")
            registered.append("tsx")
            logger.debug("Registered language: tsx")
        except Exception as e:
            logger.debug(f"Could not register tsx: {e}")

    except ImportError:
        logger.debug("tree-sitter-typescript not installed")

    # Register other optional languages with standard API
    for lang_name in OPTIONAL_LANGUAGES:
        try:
            # Try to import the tree-sitter package for this language
            module_name = f"tree_sitter_{lang_name}"
            module = __import__(module_name)

            # Get the language function
            if hasattr(module, "language"):
                language = module.language()

                # Try to get a highlight query if available
                highlight_query = None
                if hasattr(module, "HIGHLIGHTS_QUERY"):
                    highlight_query = module.HIGHLIGHTS_QUERY

                # Register with Textual
                try:
                    TextArea.register_language(language, lang_name, highlight_query)
                    registered.append(lang_name)
                    logger.debug(f"Registered language: {lang_name}")
                except Exception as e:
                    logger.debug(f"Could not register language '{lang_name}': {e}")

        except ImportError:
            # Package not installed, skip
            pass
        except Exception as e:
            logger.debug(f"Error processing language '{lang_name}': {e}")

    return registered


def get_available_languages() -> list[str]:
    """Get list of all available languages for syntax highlighting.

    Returns:
        List of language names that can be used with TextArea
    """
    try:
        from textual.widgets import TextArea

        # Create a temporary instance to check available languages
        ta = TextArea()
        return sorted(ta.available_languages)
    except ImportError:
        return sorted(SUPPORTED_LANGUAGES)
    except Exception:
        return sorted(SUPPORTED_LANGUAGES)


def is_syntax_highlighting_available() -> bool:
    """Check if syntax highlighting is available.

    Returns:
        True if tree-sitter is installed and syntax highlighting works
    """
    try:
        from textual.widgets import TextArea

        ta = TextArea("test", language="python")
        return ta.is_syntax_aware
    except Exception:
        return False
