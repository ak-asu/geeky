import 'package:drift/drift.dart';

class CachedNotes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get extractedText => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get mediaAssetsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get processed => boolean().withDefault(const Constant(false))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
