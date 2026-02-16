"""Processing task repository.

Processing tasks are stored at the top level: processing_tasks/{taskId}
(not user-scoped subcollection) because they may be queried by workers.
"""
from __future__ import annotations
import logging
from datetime import datetime, timezone
from typing import Any
from app.models.processing_task import ProcessingTaskDocument

logger = logging.getLogger(__name__)

class ProcessingTaskRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _collection(self):
        return self._db.collection("processing_tasks")

    async def get(self, task_id: str) -> ProcessingTaskDocument | None:
        doc = self._collection().document(task_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict()
        data["id"] = doc.id
        return ProcessingTaskDocument.model_validate(data)

    async def create(self, data: ProcessingTaskDocument) -> str:
        doc_data = data.model_dump(exclude_none=True, mode="json")
        doc_data["createdAt"] = datetime.now(timezone.utc)
        doc_data["updatedAt"] = datetime.now(timezone.utc)
        _, doc_ref = self._collection().add(doc_data)
        return doc_ref.id

    async def update_status(self, task_id: str, status: str, error: str | None = None) -> None:
        update_data: dict[str, Any] = {
            "status": status,
            "updatedAt": datetime.now(timezone.utc),
        }
        if error:
            update_data["error"] = error
        self._collection().document(task_id).update(update_data)

    async def update_stage(self, task_id: str, stage: str, stage_status: dict) -> None:
        self._collection().document(task_id).update({
            f"stages.{stage}": stage_status,
            "updatedAt": datetime.now(timezone.utc),
        })

    async def get_by_note(self, user_id: str, note_id: str) -> ProcessingTaskDocument | None:
        query = self._collection().where("userId", "==", user_id).where("noteId", "==", note_id).order_by("createdAt", direction="DESCENDING").limit(1)
        docs = list(query.stream())
        if not docs:
            return None
        data = docs[0].to_dict()
        data["id"] = docs[0].id
        return ProcessingTaskDocument.model_validate(data)
