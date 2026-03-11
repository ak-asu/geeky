"""Processing task repository.

Processing tasks are stored at the top level: processing_tasks/{taskId}
(not user-scoped subcollection) because they may be queried by workers.

NOTE: firebase_admin returns a sync Firestore client; all SDK calls are wrapped
with asyncio.to_thread() to avoid blocking the event loop.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore_v1 import FieldFilter

from app.models.processing_task import ProcessingTaskDocument

logger = logging.getLogger(__name__)


class ProcessingTaskRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _collection(self):
        return self._db.collection("processing_tasks")

    async def get(self, task_id: str) -> ProcessingTaskDocument | None:
        doc = await asyncio.to_thread(self._collection().document(task_id).get)
        if not doc.exists:
            return None
        data = doc.to_dict()
        data["id"] = doc.id
        return ProcessingTaskDocument.model_validate(data)

    async def create(self, data: ProcessingTaskDocument) -> str:
        doc_data = data.model_dump(exclude_none=True, mode="json", by_alias=True)
        doc_data["createdAt"] = datetime.now(timezone.utc)
        doc_data["updatedAt"] = datetime.now(timezone.utc)
        _, doc_ref = await asyncio.to_thread(self._collection().add, doc_data)
        return doc_ref.id

    async def update_status(self, task_id: str, status: str, error: str | None = None) -> None:
        update_data: dict[str, Any] = {
            "status": status,
            "updatedAt": datetime.now(timezone.utc),
        }
        if error:
            update_data["error"] = error
        await asyncio.to_thread(self._collection().document(task_id).update, update_data)

    async def update_stage(self, task_id: str, stage: str, stage_status: dict) -> None:
        await asyncio.to_thread(
            self._collection().document(task_id).update,
            {
                f"stages.{stage}": stage_status,
                "updatedAt": datetime.now(timezone.utc),
            },
        )

    async def get_by_note(self, user_id: str, note_id: str) -> ProcessingTaskDocument | None:
        # Avoid composite index requirement by omitting order_by; sort in Python.
        query = (
            self._collection()
            .where(filter=FieldFilter("userId", "==", user_id))
            .where(filter=FieldFilter("noteId", "==", note_id))
        )
        docs = await asyncio.to_thread(lambda: list(query.stream()))
        if not docs:
            return None
        docs.sort(key=lambda d: d.to_dict().get("createdAt") or datetime.min, reverse=True)
        data = docs[0].to_dict()
        data["id"] = docs[0].id
        return ProcessingTaskDocument.model_validate(data)
