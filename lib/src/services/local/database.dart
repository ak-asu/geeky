import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'tables/cached_shorts.dart';
import 'tables/cached_notes.dart';
import 'tables/cached_modules.dart';
import 'tables/cached_concepts.dart';
import 'tables/cached_relationships.dart';
import 'tables/cached_bookmarks.dart';
import 'tables/cached_quiz_cards.dart';
import 'tables/pending_interactions.dart';
import 'tables/note_feed_state_table.dart';
import 'tables/user_preferences_table.dart';
import 'tables/cached_sources.dart';
import 'tables/cached_store_modules.dart';
import 'tables/cached_notifications.dart';

import 'daos/shorts_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/modules_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/note_feed_dao.dart';
import 'daos/bookmarks_dao.dart';
import 'daos/quiz_dao.dart';
import 'daos/kg_dao.dart';
import 'daos/sources_dao.dart';
import 'daos/store_dao.dart';
import 'daos/notifications_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    CachedShorts,
    CachedNotes,
    CachedModules,
    CachedConcepts,
    CachedRelationships,
    CachedBookmarks,
    CachedQuizCards,
    PendingInteractions,
    NoteFeedStateEntries,
    UserPreferencesEntries,
    CachedSources,
    CachedStoreModules,
    CachedNotifications,
  ],
  daos: [
    ShortsDao,
    NotesDao,
    ModulesDao,
    SyncDao,
    NoteFeedDao,
    BookmarksDao,
    QuizDao,
    KgDao,
    SourcesDao,
    StoreDao,
    NotificationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  /// Deletes all cached content for [userId].
  ///
  /// User-scoped tables are filtered by [userId]. The store catalogue
  /// (`cachedStoreModules`) is a global cache and is cleared entirely.
  /// [UserPreferencesEntries] is excluded — those are user settings
  /// (theme, font size, etc.), not content cache.
  Future<void> deleteAllUserData(String userId) async {
    await transaction(() async {
      // ── User-scoped tables (filtered by userId) ──────────────────────
      await (delete(cachedNotes)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedShorts)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedModules)..where((t) => t.userId.equals(userId))).go();
      await (delete(
        cachedBookmarks,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        cachedQuizCards,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        pendingInteractions,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        noteFeedStateEntries,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedSources)..where((t) => t.userId.equals(userId))).go();
      await (delete(
        cachedNotifications,
      )..where((t) => t.userId.equals(userId))).go();

      // ── KG tables (user-scoped — filter by userId) ───────────────────
      await (delete(
        cachedConcepts,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        cachedRelationships,
      )..where((t) => t.userId.equals(userId))).go();

      // ── Global cache tables (no userId — clear all rows) ─────────────
      // Store catalogue is a global content cache shared across users.
      await delete(cachedStoreModules).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'geeky.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
