"""Document parser Protocol — abstracts text extraction from various formats."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Protocol

@dataclass
class ParsedDocument:
    text: str
    title: str | None = None
    metadata: dict = field(default_factory=dict)
    content_type: str = "text/plain"
    sections: list[ParsedSection] = field(default_factory=list)

@dataclass
class ParsedSection:
    heading: str | None
    content: str
    level: int = 0

class DocumentParser(Protocol):
    async def parse(self, content: bytes, content_type: str, filename: str | None = None) -> ParsedDocument: ...
    def supported_types(self) -> list[str]: ...
