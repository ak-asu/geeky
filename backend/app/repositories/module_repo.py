"""Module repository."""
from __future__ import annotations
from typing import Any
from app.models.module import ModuleDocument
from app.repositories.base import FirestoreBaseRepository

class ModuleRepository(FirestoreBaseRepository[ModuleDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "modules", ModuleDocument)
