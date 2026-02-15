import 'package:drift/drift.dart';

class CachedSources extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get url => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  RealColumn get healthScore => real().nullable()();
  DateTimeColumn get lastChecked => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
