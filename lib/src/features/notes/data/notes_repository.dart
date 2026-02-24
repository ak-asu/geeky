import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/notes_dao.dart';
import '../../../services/local/daos/note_feed_dao.dart';
import '../domain/note_creation_response.dart';
import '../domain/note_entity.dart';
import '../domain/note_feed_state.dart';
import 'note_dto.dart';
import 'note_feed_state_dto.dart';

class NotesRepository {
  NotesRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  NotesDao get _notesDao => _db.notesDao;
  NoteFeedDao get _feedDao => _db.noteFeedDao;

  // --- Notes CRUD ---

  Future<List<NoteEntity>> getAllNotes(String userId) async {
    try {
      final notes = await _api.getList(
        ApiConstants.notes,
        (json) => NoteEntity.fromJson(json as Map<String, dynamic>),
      );
      await _notesDao.insertNotes(notes.map(NoteDto.toCompanion).toList());
      return notes;
    } catch (_) {
      final rows = await _notesDao.getAllNotes(userId);
      return rows.map(NoteDto.fromRow).toList();
    }
  }

  Stream<List<NoteEntity>> watchAllNotes(String userId) {
    return _notesDao
        .watchAllNotes(userId)
        .map((rows) => rows.map(NoteDto.fromRow).toList());
  }

  Future<NoteEntity?> getNoteById(String id) async {
    try {
      final note = await _api.get(
        '${ApiConstants.notes}/$id',
        (json) => NoteEntity.fromJson(json as Map<String, dynamic>),
      );
      await _notesDao.insertNote(NoteDto.toCompanion(note));
      return note;
    } catch (_) {
      final row = await _notesDao.getNoteById(id);
      return row != null ? NoteDto.fromRow(row) : null;
    }
  }

  /// Creates a new note via multipart POST.
  /// Returns the backend-assigned canonical ID, or the temp UUID if offline.
  Future<String> saveNote(NoteEntity note, {String? filePath}) async {
    try {
      final fields = <String, dynamic>{
        'content': note.content ?? '',
        'type': note.type,
        if (note.title != null) 'title': note.title!,
        if (note.sourceUrl != null) 'source_url': note.sourceUrl!,
        if (note.topics.isNotEmpty) 'topics': note.topics.join(','),
      };

      final formData = filePath != null
          ? FormData.fromMap({
              ...fields,
              'file': await MultipartFile.fromFile(filePath),
            })
          : FormData.fromMap(fields);

      final response = await _api.postMultipart(
        ApiConstants.notes,
        formData,
        (json) => NoteCreationResponse.fromJson(json as Map<String, dynamic>),
      );

      // Persist with backend-assigned canonical ID
      final canonical = note.copyWith(id: response.noteId);
      await _notesDao.insertNote(NoteDto.toCompanion(canonical));
      return response.noteId;
    } catch (_) {
      // Offline: persist with temp UUID; sync queue will reconcile later
      await _notesDao.insertNote(NoteDto.toCompanion(note));
      return note.id;
    }
  }

  Future<void> saveNotes(List<NoteEntity> notes) async {
    await _notesDao.insertNotes(notes.map(NoteDto.toCompanion).toList());
  }

  Future<void> deleteNote(String id) async {
    try {
      await _api.delete('${ApiConstants.notes}/$id');
    } catch (_) {
      // Will be synced later
    }
    await _notesDao.deleteNote(id);
  }

  Future<int> countNotes(String userId) => _notesDao.countNotes(userId);

  // --- Feed State (local-only) ---

  Future<NoteFeedState> getFeedState(String userId) async {
    final row = await _feedDao.getFeedState(userId);
    return row != null ? NoteFeedStateDto.fromRow(row) : const NoteFeedState();
  }

  Future<void> saveFeedState(NoteFeedState feedState, String userId) async {
    await _feedDao.saveFeedState(
      NoteFeedStateDto.toCompanion(feedState, userId),
    );
  }
}
