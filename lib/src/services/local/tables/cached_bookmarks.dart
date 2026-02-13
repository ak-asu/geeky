import 'package:drift/drift.dart';

class CachedBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get shortId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
