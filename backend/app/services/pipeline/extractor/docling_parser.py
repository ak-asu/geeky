"""Docling document parser — implements DocumentParser Protocol.

Uses docling for PDF/DOCX/PPTX parsing. Falls back to plain text
extraction for unsupported formats.
"""

from __future__ import annotations

import asyncio
import logging
import tempfile
from pathlib import Path

from app.exceptions import ExtractionError
from app.services.pipeline.extractor.base import ParsedDocument, ParsedSection

logger = logging.getLogger(__name__)

_SUPPORTED_TYPES = [
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "text/plain",
    "text/markdown",
    "text/html",
]

_EXTENSION_MAP = {
    "application/pdf": ".pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": ".pptx",
    "text/plain": ".txt",
    "text/markdown": ".md",
    "text/html": ".html",
}


class DoclingParser:
    """Document parser backed by docling library.

    Handles PDF, DOCX, PPTX, and plain text/markdown.
    """

    def supported_types(self) -> list[str]:
        return list(_SUPPORTED_TYPES)

    async def parse(
        self,
        content: bytes,
        content_type: str,
        filename: str | None = None,
    ) -> ParsedDocument:
        """Parse document content into structured text with sections."""
        if content_type in ("text/plain", "text/markdown"):
            return self._parse_text(content, content_type)

        if content_type not in _SUPPORTED_TYPES:
            raise ExtractionError(f"Unsupported content type: {content_type}")

        return await self._parse_with_docling(content, content_type, filename)

    def _parse_text(self, content: bytes, content_type: str) -> ParsedDocument:
        """Direct text extraction for plain text / markdown."""
        text = content.decode("utf-8", errors="replace")
        sections = _extract_markdown_sections(text) if content_type == "text/markdown" else []

        return ParsedDocument(
            text=text,
            title=None,
            metadata={"content_type": content_type},
            content_type=content_type,
            sections=sections,
        )

    async def _parse_with_docling(
        self,
        content: bytes,
        content_type: str,
        filename: str | None,
    ) -> ParsedDocument:
        """Parse binary documents using docling in a thread."""
        ext = _EXTENSION_MAP.get(content_type, "")
        suffix = ext or (Path(filename).suffix if filename else "")

        try:
            result = await asyncio.to_thread(self._docling_convert, content, suffix)
            return result
        except Exception as exc:
            logger.error("Docling parsing failed for %s: %s", content_type, exc)
            raise ExtractionError(f"Failed to parse {content_type}: {exc}") from exc

    def _docling_convert(self, content: bytes, suffix: str) -> ParsedDocument:
        """Run docling conversion in a blocking thread."""
        from docling.document_converter import DocumentConverter  # noqa: PLC0415

        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name

        try:
            converter = DocumentConverter()
            result = converter.convert(tmp_path)
            doc = result.document

            full_text = doc.export_to_markdown()
            sections: list[ParsedSection] = []

            for item in doc.iterate_items():
                element = item[0] if isinstance(item, tuple) else item
                label = getattr(element, "label", None)
                text_content = getattr(element, "text", "")
                if not text_content:
                    continue

                if label and "heading" in str(label).lower():
                    level = _heading_level(str(label))
                    sections.append(ParsedSection(heading=text_content, content="", level=level))
                elif sections:
                    sections[-1].content += text_content + "\n"
                else:
                    sections.append(ParsedSection(heading=None, content=text_content + "\n", level=0))

            title = sections[0].heading if sections and sections[0].heading else None

            return ParsedDocument(
                text=full_text,
                title=title,
                metadata={"parser": "docling"},
                content_type="text/markdown",
                sections=sections,
            )
        finally:
            Path(tmp_path).unlink(missing_ok=True)


def _extract_markdown_sections(text: str) -> list[ParsedSection]:
    """Extract sections from markdown headings."""
    sections: list[ParsedSection] = []
    current_content: list[str] = []

    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("#"):
            if current_content and sections:
                sections[-1].content = "\n".join(current_content).strip()
                current_content = []
            elif current_content:
                sections.append(ParsedSection(heading=None, content="\n".join(current_content).strip(), level=0))
                current_content = []

            level = len(stripped) - len(stripped.lstrip("#"))
            heading = stripped.lstrip("# ").strip()
            sections.append(ParsedSection(heading=heading, content="", level=level))
        else:
            current_content.append(line)

    if current_content:
        if sections:
            sections[-1].content = "\n".join(current_content).strip()
        else:
            sections.append(ParsedSection(heading=None, content="\n".join(current_content).strip(), level=0))

    return sections


def _heading_level(label: str) -> int:
    """Extract heading level from docling label."""
    for i in range(6, 0, -1):
        if str(i) in label:
            return i
    return 1
