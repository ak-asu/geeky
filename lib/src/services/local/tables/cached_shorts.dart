import 'package:drift/drift.dart';

class CachedShorts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get summary => text()();
  TextColumn get topicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  RealColumn get difficulty => real().withDefault(const Constant(0.5))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get prerequisitesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get relatedJson => text().withDefault(const Constant('[]'))();
  TextColumn get citationsJson => text().withDefault(const Constant('[]'))();
  TextColumn get promptsJson => text().withDefault(const Constant('[]'))();
  TextColumn get conceptIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get mediaJson => text().withDefault(const Constant('[]'))();
  TextColumn get engagementJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
