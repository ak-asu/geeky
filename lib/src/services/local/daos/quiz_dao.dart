import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_quiz_cards.dart';

part 'quiz_dao.g.dart';

@DriftAccessor(tables: [CachedQuizCards])
class QuizDao extends DatabaseAccessor<AppDatabase> with _$QuizDaoMixin {
  QuizDao(super.db);

  Future<List<CachedQuizCard>> getAllCards() => select(cachedQuizCards).get();

  Future<List<CachedQuizCard>> getDueCards() =>
      (select(cachedQuizCards)
            ..where((t) => t.dueDate.isSmallerOrEqualValue(DateTime.now()))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  Future<CachedQuizCard?> getCardForArticle(String articleId) => (select(
    cachedQuizCards,
  )..where((t) => t.articleId.equals(articleId))).getSingleOrNull();

  Future<void> upsertCard(CachedQuizCardsCompanion entry) =>
      into(cachedQuizCards).insertOnConflictUpdate(entry);

  Future<void> deleteCard(String articleId) => (delete(
    cachedQuizCards,
  )..where((t) => t.articleId.equals(articleId))).go();
}
