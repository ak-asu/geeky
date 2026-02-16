"""Notes CRUD API routes.

POST   /notes          — Create note (text/file upload), dispatch pipeline
GET    /notes          — List with cursor pagination
GET    /notes/{id}     — Get single note (verify ownership)
PUT    /notes/{id}     — Update note, trigger re-processing
DELETE /notes/{id}     — Delete note + cascade
GET    /notes/{id}/status — Processing pipeline status
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, UploadFile

from app.api.middleware.auth import CurrentUserId
from app.dependencies import (
    get_note_repository,
    get_processing_task_repository,
)
from app.exceptions import NoteNotFoundError
from app.models.common import NoteType, PaginatedResponse, PaginationMeta, ProcessingStatus
from app.models.note import NoteDocument, NoteUpdate
from app.models.processing_task import ProcessingTaskDocument

router = APIRouter(prefix="/notes", tags=["notes"])


@router.post("/")
async def create_note(
    user_id: CurrentUserId,
    content: str = Form(...),
    title: str | None = Form(default=None),
    note_type: NoteType = Form(default=NoteType.TEXT, alias="type"),
    source_url: str | None = Form(default=None),
    topics: str = Form(default=""),
    file: UploadFile | None = File(default=None),
    note_repo=Depends(get_note_repository),
    task_repo=Depends(get_processing_task_repository),
) -> dict:
    """Create a new note from text content or file upload.

    Dispatches async pipeline processing via Celery.
    Returns the note and processing task ID.
    """
    topic_list = [t.strip() for t in topics.split(",") if t.strip()] if topics else []

    actual_content = content
    if file:
        file_bytes = await file.read()
        actual_content = file_bytes.decode("utf-8", errors="replace")

    note_doc = NoteDocument(
        type=note_type,
        title=title,
        content=actual_content,
        source_url=source_url,
        topics=topic_list,
        processed=False,
    )

    note_id = await note_repo.create(user_id, note_doc)

    # Create processing task
    task_doc = ProcessingTaskDocument(
        user_id=user_id,
        note_id=note_id,
        status=ProcessingStatus.PENDING,
    )
    task_id = await task_repo.create(task_doc)

    await note_repo.update(user_id, note_id, {"processingTaskId": task_id})

    # Dispatch Celery task
    from app.workers.pipeline_tasks import process_note  # noqa: PLC0415

    process_note.delay(user_id, note_id, task_id)

    return {
        "data": {
            "id": note_id,
            "type": note_type.value,
            "title": title,
            "processingTaskId": task_id,
            "processed": False,
        }
    }


@router.get("/")
async def list_notes(
    user_id: CurrentUserId,
    limit: int = 50,
    cursor: str | None = None,
    note_repo=Depends(get_note_repository),
) -> dict:
    """List user notes with cursor-based pagination."""
    items, next_cursor = await note_repo.list(user_id, limit=limit, cursor=cursor)

    return PaginatedResponse(
        data=[item.model_dump(mode="json", by_alias=True) for item in items],
        meta=PaginationMeta(cursor=next_cursor, has_more=next_cursor is not None),
    ).model_dump(mode="json")


@router.get("/{note_id}")
async def get_note(
    note_id: str,
    user_id: CurrentUserId,
    note_repo=Depends(get_note_repository),
) -> dict:
    """Get a single note by ID. Verifies user ownership via subcollection."""
    note = await note_repo.get(user_id, note_id)
    if note is None:
        raise NoteNotFoundError(note_id)

    return {"data": note.model_dump(mode="json", by_alias=True)}


@router.put("/{note_id}")
async def update_note(
    note_id: str,
    user_id: CurrentUserId,
    body: NoteUpdate,
    note_repo=Depends(get_note_repository),
    task_repo=Depends(get_processing_task_repository),
) -> dict:
    """Update an existing note. Triggers re-processing pipeline (LM-01)."""
    note = await note_repo.get(user_id, note_id)
    if note is None:
        raise NoteNotFoundError(note_id)

    update_data = body.model_dump(exclude_none=True)
    if not update_data:
        return {"data": note.model_dump(mode="json", by_alias=True)}

    await note_repo.update(user_id, note_id, update_data)

    # If content changed, trigger re-processing
    if "content" in update_data:
        task_doc = ProcessingTaskDocument(
            user_id=user_id,
            note_id=note_id,
            status=ProcessingStatus.PENDING,
        )
        task_id = await task_repo.create(task_doc)
        await note_repo.update(user_id, note_id, {
            "processed": False,
            "processingTaskId": task_id,
        })

        from app.workers.lifecycle_tasks import cascade_note_update  # noqa: PLC0415

        cascade_note_update.delay(user_id, note_id, task_id)

    updated = await note_repo.get(user_id, note_id)
    return {"data": updated.model_dump(mode="json", by_alias=True)}


@router.delete("/{note_id}")
async def delete_note(
    note_id: str,
    user_id: CurrentUserId,
    note_repo=Depends(get_note_repository),
) -> dict:
    """Delete a note and cascade: delete chunks, shorts, embeddings (LM-02, LM-03)."""
    note = await note_repo.get(user_id, note_id)
    if note is None:
        raise NoteNotFoundError(note_id)

    await note_repo.delete(user_id, note_id)

    # Dispatch async cascade cleanup
    from app.workers.lifecycle_tasks import cascade_note_delete  # noqa: PLC0415

    cascade_note_delete.delay(user_id, note_id)

    return {"data": {"id": note_id, "deleted": True}}


@router.get("/{note_id}/status")
async def get_note_processing_status(
    note_id: str,
    user_id: CurrentUserId,
    task_repo=Depends(get_processing_task_repository),
) -> dict:
    """Get the processing pipeline status for a note."""
    task = await task_repo.get_by_note(user_id, note_id)
    if task is None:
        return {"data": {"noteId": note_id, "status": "no_task"}}

    return {"data": task.model_dump(mode="json", by_alias=True)}
