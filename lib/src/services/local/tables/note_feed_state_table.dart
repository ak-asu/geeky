import 'package:drift/drift.dart';

class NoteFeedStateEntries extends Table {
  TextColumn get userId => text()();
  TextColumn get skipCountsJson => text().withDefault(const Constant('{}'))();
  TextColumn get lastSeenJson => text().withDefault(const Constant('{}'))();
  TextColumn get readNoteIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get recentTopicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get bookmarkedNoteIdsJson =>
      text().withDefault(const Constant('[]'))();
  RealColumn get avgReadLengthWords => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {userId};
}
