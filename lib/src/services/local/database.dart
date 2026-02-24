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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'geeky.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
