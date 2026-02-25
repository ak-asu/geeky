import 'package:drift/drift.dart';

class CachedRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get sourceId => text()();
  TextColumn get targetId => text()();
  TextColumn get type => text()();
  RealColumn get strength => real().withDefault(const Constant(1.0))();
  BoolColumn get isDynamic => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
