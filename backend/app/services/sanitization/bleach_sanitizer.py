"""BleachSanitizer — bleach-based implementation of TextSanitizer."""

from __future__ import annotations

import bleach


# Tags safe for Markdown rendering (no <script>, <iframe>, <object>, etc.)
_SAFE_MARKDOWN_TAGS = [
    "p", "br", "b", "i", "em", "strong", "u", "s",
    "ul", "ol", "li",
    "code", "pre", "blockquote",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "a", "img",
    "table", "thead", "tbody", "tr", "th", "td",
    "hr", "sup", "sub",
]

_SAFE_MARKDOWN_ATTRS: dict[str, list[str]] = {
    "a": ["href", "title"],
    "img": ["src", "alt", "title"],
    "td": ["align"],
    "th": ["align"],
}


class BleachSanitizer:
    """Sanitises user text using the ``bleach`` library.

    Satisfies the :class:`TextSanitizer` Protocol.
    """

    def sanitize(self, text: str) -> str:
        """Strip ALL HTML tags, returning plain text."""
        return bleach.clean(text, tags=[], strip=True)

    def sanitize_markdown(self, text: str) -> str:
        """Allow safe Markdown-compatible tags, strip dangerous ones."""
        return bleach.clean(
            text,
            tags=_SAFE_MARKDOWN_TAGS,
            attributes=_SAFE_MARKDOWN_ATTRS,
            strip=True,
        )
