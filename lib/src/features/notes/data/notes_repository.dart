import '../../../services/local/database.dart';
import '../../../services/local/daos/notes_dao.dart';
import '../../../services/local/daos/note_feed_dao.dart';
import '../domain/note_entity.dart';
import '../domain/note_feed_state.dart';
import 'note_dto.dart';
import 'note_feed_state_dto.dart';

class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  NotesDao get _notesDao => _db.notesDao;
  NoteFeedDao get _feedDao => _db.noteFeedDao;

  // --- Notes CRUD ---

  Future<List<NoteEntity>> getAllNotes() async {
    final rows = await _notesDao.getAllNotes();
    return rows.map(NoteDto.fromRow).toList();
  }

  Stream<List<NoteEntity>> watchAllNotes() {
    return _notesDao.watchAllNotes().map(
      (rows) => rows.map(NoteDto.fromRow).toList(),
    );
  }

  Future<NoteEntity?> getNoteById(String id) async {
    final row = await _notesDao.getNoteById(id);
    return row != null ? NoteDto.fromRow(row) : null;
  }

  Future<void> saveNote(NoteEntity note) async {
    await _notesDao.insertNote(NoteDto.toCompanion(note));
  }

  Future<void> saveNotes(List<NoteEntity> notes) async {
    await _notesDao.insertNotes(notes.map(NoteDto.toCompanion).toList());
  }

  Future<void> deleteNote(String id) async {
    await _notesDao.deleteNote(id);
  }

  Future<int> countNotes() => _notesDao.countNotes();

  // --- Feed State ---

  Future<NoteFeedState> getFeedState() async {
    final row = await _feedDao.getFeedState();
    return row != null ? NoteFeedStateDto.fromRow(row) : const NoteFeedState();
  }

  Future<void> saveFeedState(NoteFeedState feedState) async {
    await _feedDao.saveFeedState(NoteFeedStateDto.toCompanion(feedState));
  }
}
