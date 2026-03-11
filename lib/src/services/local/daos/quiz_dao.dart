import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_quiz_cards.dart';

part 'quiz_dao.g.dart';

@DriftAccessor(tables: [CachedQuizCards])
class QuizDao extends DatabaseAccessor<AppDatabase> with _$QuizDaoMixin {
  QuizDao(super.db);

  Future<List<CachedQuizCard>> getAllCards(String userId) =>
      (select(cachedQuizCards)..where((t) => t.userId.equals(userId))).get();

  Future<List<CachedQuizCard>> getDueCards(String userId) =>
      (select(cachedQuizCards)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.dueDate.isSmallerOrEqualValue(DateTime.now()),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  Future<CachedQuizCard?> getCardForArticle(String userId, String articleId) =>
      (select(cachedQuizCards)..where(
            (t) => t.userId.equals(userId) & t.articleId.equals(articleId),
          ))
          .getSingleOrNull();

  Future<void> upsertCard(CachedQuizCardsCompanion entry) =>
      into(cachedQuizCards).insertOnConflictUpdate(entry);

  Future<void> deleteCard(String userId, String articleId) =>
      (delete(cachedQuizCards)..where(
            (t) => t.userId.equals(userId) & t.articleId.equals(articleId),
          ))
          .go();
}
