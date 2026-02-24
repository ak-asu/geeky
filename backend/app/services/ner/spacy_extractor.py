"""spaCy-based NER extractor and LLM-based edge classifier.

SpacyNERExtractor uses spaCy for named entity recognition on text content.
LLMEdgeClassifier uses LLMProvider to classify relationships between entity pairs.
"""
from __future__ import annotations

import asyncio
import logging
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from app.services.ner.base import EdgeType, Entity, EntityType, Relation

if TYPE_CHECKING:
    from app.services.llm.base import LLMProvider

logger = logging.getLogger(__name__)

# Map spaCy NER labels to our EntityType
_SPACY_TO_ENTITY_TYPE: dict[str, EntityType] = {
    "PERSON": EntityType.PERSON,
    "ORG": EntityType.ORGANIZATION,
    "GPE": EntityType.LOCATION,   # Geopolitical entity (country, city, state)
    "LOC": EntityType.LOCATION,   # Non-GPE locations (mountains, rivers, etc.)
    "PRODUCT": EntityType.TECHNOLOGY,
    "WORK_OF_ART": EntityType.THEORY,
    "LAW": EntityType.THEORY,
    "EVENT": EntityType.CONCEPT,
    "NORP": EntityType.CONCEPT,
    "FAC": EntityType.CONCEPT,
    "LANGUAGE": EntityType.TECHNOLOGY,
}

# spaCy labels that represent geographic locations
_LOCATION_LABELS: frozenset[str] = frozenset({"GPE", "LOC"})

# Noun-chunk based entities are concepts by default
_DEFAULT_ENTITY_TYPE = EntityType.CONCEPT


class SpacyNERExtractor:
    """NER extractor using spaCy's transformer-based pipeline.

    Extracts both spaCy NER entities and noun-chunk concepts for
    comprehensive knowledge graph coverage.
    """

    def __init__(self, model: str = "en_core_web_sm") -> None:
        self._model_name = model
        self._nlp = None

    def _get_nlp(self):
        """Lazy-load the spaCy model."""
        if self._nlp is None:
            import spacy  # noqa: PLC0415
            self._nlp = spacy.load(self._model_name)
        return self._nlp

    async def extract_entities(self, text: str) -> list[Entity]:
        """Extract entities from text using spaCy NER + noun chunks."""
        nlp = self._get_nlp()
        doc = await asyncio.to_thread(nlp, text)

        seen_names: set[str] = set()
        entities: list[Entity] = []

        # 1. Named entities from spaCy NER
        for ent in doc.ents:
            name = ent.text.strip()
            name_lower = name.lower()
            if not name or name_lower in seen_names or len(name) < 2:
                continue
            seen_names.add(name_lower)

            entity_type = _SPACY_TO_ENTITY_TYPE.get(ent.label_, _DEFAULT_ENTITY_TYPE)
            entities.append(Entity(
                name=name,
                type=entity_type,
                start_char=ent.start_char,
                end_char=ent.end_char,
                confidence=0.9,
            ))

        # 2. Noun chunks as concept candidates (lower confidence)
        for chunk in doc.noun_chunks:
            name = chunk.root.text.strip()
            name_lower = name.lower()
            if (
                not name
                or name_lower in seen_names
                or len(name) < 3
                or chunk.root.pos_ not in ("NOUN", "PROPN")
            ):
                continue
            seen_names.add(name_lower)

            entities.append(Entity(
                name=name,
                type=EntityType.CONCEPT,
                start_char=chunk.start_char,
                end_char=chunk.end_char,
                confidence=0.6,
            ))

        return entities

    async def extract_relations(self, text: str, entities: list[Entity]) -> list[Relation]:
        """Extract relations based on sentence co-occurrence and dependency parsing."""
        if len(entities) < 2:
            return []

        nlp = self._get_nlp()
        doc = await asyncio.to_thread(nlp, text)

        # Build entity name -> Entity lookup
        entity_map = {e.name.lower(): e for e in entities}
        relations: list[Relation] = []
        seen_pairs: set[tuple[str, str]] = set()

        # Co-occurrence within sentences implies relatedness
        for sent in doc.sents:
            sent_text = sent.text.lower()
            found_in_sent = [
                e for e in entities
                if e.name.lower() in sent_text
            ]

            for i, src in enumerate(found_in_sent):
                for tgt in found_in_sent[i + 1:]:
                    pair = (src.name.lower(), tgt.name.lower())
                    if pair in seen_pairs or pair[::-1] in seen_pairs:
                        continue
                    seen_pairs.add(pair)

                    relations.append(Relation(
                        source=src,
                        target=tgt,
                        edge_type=EdgeType.RELATED,
                        confidence=0.6,
                        context=sent.text[:200],
                    ))

        return relations

    async def extract_location_entities(self, text: str) -> list[str]:
        """Extract geographic location labels (GPE/LOC) from text.

        Returns a deduplicated list of location name strings (not Entity objects)
        for lightweight storage on ShortDocument.location_entities.

        Examples: ["Arizona", "Phoenix", "United States", "Silicon Valley"]
        """
        nlp = self._get_nlp()
        doc = await asyncio.to_thread(nlp, text)

        seen: set[str] = set()
        locations: list[str] = []
        for ent in doc.ents:
            if ent.label_ not in _LOCATION_LABELS:
                continue
            name = ent.text.strip()
            if not name or len(name) < 2:
                continue
            # Deduplicate case-insensitively, preserve original casing
            key = name.lower()
            if key not in seen:
                seen.add(key)
                locations.append(name)

        return locations


class _ClassifiedEdgeResponse(BaseModel):
    """Structured response from LLM edge classification."""
    edge_type: str = Field(default="related", alias="edgeType")
    confidence: float = 0.7
    evidence: str = ""
    model_config = {"populate_by_name": True}


class LLMEdgeClassifier:
    """Edge classifier that uses an LLM to determine relationship types.

    Given two entity names and optional context, classifies the relationship
    with evidence grounding (KG-03).
    """

    def __init__(self, llm: LLMProvider) -> None:
        self._llm = llm

    async def classify(
        self,
        source_name: str,
        target_name: str,
        context: str | None = None,
    ) -> EdgeType:
        """Classify the relationship between two entities."""
        result = await self.classify_with_evidence(source_name, target_name, context)
        return result.edge_type

    async def classify_with_evidence(
        self,
        source_name: str,
        target_name: str,
        context: str | None = None,
    ) -> Relation:
        """Classify with full evidence and confidence scores."""
        valid_types = ", ".join(t.value for t in EdgeType)

        prompt = (
            f"Classify the relationship between these two concepts:\n"
            f"Source: {source_name}\n"
            f"Target: {target_name}\n"
        )
        if context:
            prompt += f"Context: {context[:500]}\n"

        prompt += (
            f"\nValid relationship types: {valid_types}\n"
            f"Choose the most specific applicable type. "
            f"'prerequisite' means source must be learned before target. "
            f"'part_of' means source is a component of target. "
            f"'subtopic' means source is a narrower topic under target. "
            f"'example_of' means source is a concrete example of target. "
            f"'broader' means source is a more general topic than target. "
            f"'deeper' means source goes deeper into the same topic as target. "
            f"'similar' means they cover overlapping material. "
            f"'related' is the fallback for any other connection."
        )

        try:
            result = await self._llm.generate_structured(
                prompt,
                _ClassifiedEdgeResponse,
                system="You are an expert educator classifying knowledge relationships. Be precise.",
                temperature=0.2,
            )

            # Validate the edge type
            try:
                edge_type = EdgeType(result.edge_type)
            except ValueError:
                edge_type = EdgeType.RELATED

            return Relation(
                source=Entity(name=source_name, type=EntityType.CONCEPT),
                target=Entity(name=target_name, type=EntityType.CONCEPT),
                edge_type=edge_type,
                confidence=result.confidence,
                context=result.evidence or context,
            )

        except Exception:
            logger.warning(
                "LLM edge classification failed for %s -> %s, defaulting to RELATED",
                source_name, target_name,
            )
            return Relation(
                source=Entity(name=source_name, type=EntityType.CONCEPT),
                target=Entity(name=target_name, type=EntityType.CONCEPT),
                edge_type=EdgeType.RELATED,
                confidence=0.3,
                context=context,
            )
