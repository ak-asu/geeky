"""TextSanitizer Protocol — contract for input sanitization."""

from __future__ import annotations

from typing import Protocol


class TextSanitizer(Protocol):
    """Strips potentially dangerous content from user-provided text.

    Implementations may use bleach, html-sanitizer, or other libraries.
    """

    def sanitize(self, text: str) -> str:
        """Strip ALL markup, returning plain text only."""
        ...

    def sanitize_markdown(self, text: str) -> str:
        """Allow safe Markdown-compatible tags, strip everything else."""
        ...
