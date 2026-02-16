"""Mock Firebase for testing.

Provides an in-memory Firestore-like interface for unit/integration tests
without requiring a real Firebase connection.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4


class MockDocument:
    """Mock Firestore document snapshot."""

    def __init__(self, doc_id: str, data: dict | None = None) -> None:
        self.id = doc_id
        self._data = data or {}
        self.exists = data is not None

    def to_dict(self) -> dict:
        return dict(self._data)


class MockQuery:
    """Mock Firestore query."""

    def __init__(self, docs: list[MockDocument]) -> None:
        self._docs = docs

    def where(self, field: str, op: str, value: Any) -> MockQuery:
        filtered = []
        for doc in self._docs:
            data = doc.to_dict()
            field_val = data.get(field)
            if op == "==" and field_val == value:
                filtered.append(doc)
            elif op == "!=" and field_val != value:
                filtered.append(doc)
            elif op == "array_contains" and isinstance(field_val, list) and value in field_val:
                filtered.append(doc)
        return MockQuery(filtered)

    def order_by(self, field: str, direction: str = "ASCENDING") -> MockQuery:
        return self

    def limit(self, n: int) -> MockQuery:
        return MockQuery(self._docs[:n])

    def start_after(self, doc: MockDocument) -> MockQuery:
        return self

    def stream(self):
        return iter(self._docs)

    def count(self):
        return MockCountQuery(len(self._docs))


class MockCountQuery:
    def __init__(self, count: int) -> None:
        self._count = count

    def get(self):
        return [[(type("Count", (), {"value": self._count})())]]


class MockCollection:
    """Mock Firestore collection."""

    def __init__(self) -> None:
        self._docs: dict[str, dict] = {}

    def document(self, doc_id: str) -> MockDocumentRef:
        return MockDocumentRef(self, doc_id)

    def add(self, data: dict) -> tuple[Any, MockDocumentRef]:
        doc_id = str(uuid4())
        self._docs[doc_id] = data
        return None, MockDocumentRef(self, doc_id)

    def where(self, field: str, op: str, value: Any) -> MockQuery:
        docs = [MockDocument(k, v) for k, v in self._docs.items()]
        return MockQuery(docs).where(field, op, value)

    def order_by(self, field: str, direction: Any = None) -> MockQuery:
        docs = [MockDocument(k, v) for k, v in self._docs.items()]
        return MockQuery(docs)

    def limit(self, n: int) -> MockQuery:
        docs = [MockDocument(k, v) for k, v in self._docs.items()]
        return MockQuery(docs[:n])

    def stream(self):
        return iter([MockDocument(k, v) for k, v in self._docs.items()])

    def count(self):
        return MockCountQuery(len(self._docs))


class MockDocumentRef:
    """Mock Firestore document reference."""

    def __init__(self, collection: MockCollection, doc_id: str) -> None:
        self._collection = collection
        self.id = doc_id

    def get(self) -> MockDocument:
        data = self._collection._docs.get(self.id)
        return MockDocument(self.id, data)

    def set(self, data: dict) -> None:
        self._collection._docs[self.id] = data

    def update(self, data: dict) -> None:
        if self.id in self._collection._docs:
            self._collection._docs[self.id].update(data)

    def delete(self) -> None:
        self._collection._docs.pop(self.id, None)

    def collection(self, name: str) -> MockCollection:
        # Subcollections stored with composite key
        key = f"{self.id}/{name}"
        if not hasattr(self._collection, "_subcollections"):
            self._collection._subcollections = {}
        if key not in self._collection._subcollections:
            self._collection._subcollections[key] = MockCollection()
        return self._collection._subcollections[key]


class MockFirestoreClient:
    """Mock Firestore client with in-memory storage."""

    def __init__(self) -> None:
        self._collections: dict[str, MockCollection] = {}

    def collection(self, name: str) -> MockCollection:
        if name not in self._collections:
            self._collections[name] = MockCollection()
        return self._collections[name]
