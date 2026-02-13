import 'package:drift/drift.dart';

class PendingInteractions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get articleId => text()();
  TextColumn get type => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get timeSpent => real().withDefault(const Constant(0))();
  RealColumn get scrollDepth => real().withDefault(const Constant(0))();
  TextColumn get feedbackType => text().nullable()();
  TextColumn get navigationDirection => text().nullable()();
  TextColumn get fromArticleId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
