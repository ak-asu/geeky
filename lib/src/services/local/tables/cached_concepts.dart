import 'package:drift/drift.dart';

class CachedConcepts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get articleIdsJson => text().withDefault(const Constant('[]'))();
  RealColumn get importanceScore => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
