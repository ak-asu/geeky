import 'package:drift/drift.dart';

class CachedStoreModules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get topicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get author => text().withDefault(const Constant(''))();
  IntColumn get shortCount => integer().withDefault(const Constant(0))();
  RealColumn get difficulty => real().withDefault(const Constant(0.5))();
  RealColumn get rating => real().withDefault(const Constant(0))();
  IntColumn get downloads => integer().withDefault(const Constant(0))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  TextColumn get previewImageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
