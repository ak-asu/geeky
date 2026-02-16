"""NER extractor and Edge classifier Protocols."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Protocol

class EntityType(str, Enum):
    CONCEPT = "concept"
    PERSON = "person"
    ORGANIZATION = "organization"
    TECHNOLOGY = "technology"
    THEORY = "theory"
    METHOD = "method"
    OTHER = "other"

class EdgeType(str, Enum):
    PREREQUISITE = "prerequisite"
    RELATED = "related"
    SUBTOPIC = "subtopic"
    SIMILAR = "similar"
    DEEPER = "deeper"
    BROADER = "broader"
    EXAMPLE_OF = "example_of"
    PART_OF = "part_of"

@dataclass
class Entity:
    name: str
    type: EntityType
    start_char: int = 0
    end_char: int = 0
    confidence: float = 1.0
    aliases: list[str] = field(default_factory=list)

@dataclass
class Relation:
    source: Entity
    target: Entity
    edge_type: EdgeType
    confidence: float = 1.0
    context: str | None = None

class NERExtractor(Protocol):
    async def extract_entities(self, text: str) -> list[Entity]: ...
    async def extract_relations(self, text: str, entities: list[Entity]) -> list[Relation]: ...

class EdgeClassifier(Protocol):
    async def classify(self, source_name: str, target_name: str, context: str | None = None) -> EdgeType: ...
