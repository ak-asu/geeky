import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/notes_dao.dart';
import '../../../services/local/daos/note_feed_dao.dart';
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

  Future<List<NoteEntity>> getAllNotes() async {
    try {
      final notes = await _api.getList(
        ApiConstants.notes,
        (json) => NoteEntity.fromJson(json as Map<String, dynamic>),
      );
      await _notesDao.insertNotes(notes.map(NoteDto.toCompanion).toList());
      return notes;
    } catch (_) {
      final rows = await _notesDao.getAllNotes();
      return rows.map(NoteDto.fromRow).toList();
    }
  }

  Stream<List<NoteEntity>> watchAllNotes() {
    return _notesDao.watchAllNotes().map(
      (rows) => rows.map(NoteDto.fromRow).toList(),
    );
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

  Future<void> saveNote(NoteEntity note) async {
    try {
      await _api.post(ApiConstants.notes, note.toJson(), (json) => json);
    } catch (_) {
      // Will be synced later via offline queue
    }
    await _notesDao.insertNote(NoteDto.toCompanion(note));
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

  Future<int> countNotes() => _notesDao.countNotes();

  // --- Feed State (local-only) ---

  Future<NoteFeedState> getFeedState() async {
    final row = await _feedDao.getFeedState();
    return row != null ? NoteFeedStateDto.fromRow(row) : const NoteFeedState();
  }

  Future<void> saveFeedState(NoteFeedState feedState) async {
    await _feedDao.saveFeedState(NoteFeedStateDto.toCompanion(feedState));
  }
}
