"""Unit tests for SpacyNERExtractor."""
from __future__ import annotations

import pytest

from app.services.ner.base import EdgeType, Entity, EntityType, Relation


class MockNLPDoc:
    """Minimal mock for spaCy Doc for testing without spaCy installed."""

    def __init__(self, text: str, ents=None, noun_chunks=None, sents=None):
        self.text = text
        self.ents = ents or []
        self.noun_chunks = noun_chunks or []
        self.sents = sents or [self]

    def __iter__(self):
        return iter([])


class MockEnt:
    def __init__(self, text, label_, start_char=0, end_char=0):
        self.text = text
        self.label_ = label_
        self.start_char = start_char
        self.end_char = end_char


class MockChunk:
    def __init__(self, text, root_text, root_pos, start_char=0, end_char=0):
        self.text = text
        self.root = type("Root", (), {"text": root_text, "pos_": root_pos})()
        self.start_char = start_char
        self.end_char = end_char


class MockSent:
    def __init__(self, text):
        self.text = text


class TestSpacyNERExtractor:
    """Tests using MockNERExtractor from test mocks (no real spaCy needed)."""

    @pytest.fixture
    def extractor(self):
        from tests.mocks.mock_ner import MockNERExtractor
        return MockNERExtractor()

    @pytest.mark.asyncio
    async def test_extract_entities_returns_entities(self, extractor):
        text = "Machine learning uses neural networks for classification tasks"
        entities = await extractor.extract_entities(text)
        assert len(entities) > 0
        assert all(isinstance(e, Entity) for e in entities)

    @pytest.mark.asyncio
    async def test_extract_entities_are_concepts(self, extractor):
        text = "Python is a programming language"
        entities = await extractor.extract_entities(text)
        for entity in entities:
            assert entity.type == EntityType.CONCEPT

    @pytest.mark.asyncio
    async def test_extract_relations_from_entities(self, extractor):
        text = "Machine learning uses neural networks"
        entities = await extractor.extract_entities(text)
        relations = await extractor.extract_relations(text, entities)
        assert all(isinstance(r, Relation) for r in relations)

    @pytest.mark.asyncio
    async def test_extract_relations_empty_for_single_entity(self, extractor):
        entities = [Entity(name="Python", type=EntityType.CONCEPT)]
        relations = await extractor.extract_relations("Python", entities)
        assert relations == []

    @pytest.mark.asyncio
    async def test_extract_relations_connects_sequential_entities(self, extractor):
        entities = [
            Entity(name="Python", type=EntityType.CONCEPT),
            Entity(name="Machine", type=EntityType.CONCEPT),
            Entity(name="Learning", type=EntityType.CONCEPT),
        ]
        relations = await extractor.extract_relations("text", entities)
        assert len(relations) == 2
        assert relations[0].source.name == "Python"
        assert relations[0].target.name == "Machine"


class TestMockEdgeClassifier:
    """Tests for MockEdgeClassifier."""

    @pytest.fixture
    def classifier(self):
        from tests.mocks.mock_ner import MockEdgeClassifier
        return MockEdgeClassifier()

    @pytest.mark.asyncio
    async def test_classify_returns_edge_type(self, classifier):
        result = await classifier.classify("Python", "Java")
        assert isinstance(result, EdgeType)

    @pytest.mark.asyncio
    async def test_classify_default_is_related(self, classifier):
        result = await classifier.classify("A", "B")
        assert result == EdgeType.RELATED

    @pytest.mark.asyncio
    async def test_classify_with_context(self, classifier):
        result = await classifier.classify("Python", "Java", context="Both are programming languages")
        assert result == EdgeType.RELATED
