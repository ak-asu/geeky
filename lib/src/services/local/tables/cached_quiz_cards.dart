import 'package:drift/drift.dart';

class CachedQuizCards extends Table {
  TextColumn get userId => text().withDefault(const Constant(''))();
  TextColumn get articleId => text()();
  RealColumn get stability => real().withDefault(const Constant(1.0))();
  RealColumn get difficulty => real().withDefault(const Constant(0.5))();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('new'))();
  DateTimeColumn get lastReviewDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId, articleId};
}
