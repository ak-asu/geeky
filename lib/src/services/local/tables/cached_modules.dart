import 'package:drift/drift.dart';

class CachedModules extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get topicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get shortIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get type => text().withDefault(const Constant('auto'))();
  IntColumn get completedShorts => integer().withDefault(const Constant(0))();
  IntColumn get totalShorts => integer().withDefault(const Constant(0))();
  IntColumn get currentPosition => integer().withDefault(const Constant(0))();
  RealColumn get estimatedMinutesRemaining =>
      real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
