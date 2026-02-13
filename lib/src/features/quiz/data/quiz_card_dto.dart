import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/quiz_card_entity.dart';

abstract final class QuizCardDto {
  static QuizCardEntity fromRow(CachedQuizCard row) {
    return QuizCardEntity(
      articleId: row.articleId,
      stability: row.stability,
      difficulty: row.difficulty,
      dueDate: row.dueDate,
      reps: row.reps,
      lapses: row.lapses,
      state: _parseCardState(row.state),
      lastReviewDate: row.lastReviewDate,
    );
  }

  static CachedQuizCardsCompanion toCompanion(QuizCardEntity entity) {
    return CachedQuizCardsCompanion(
      articleId: Value(entity.articleId),
      stability: Value(entity.stability),
      difficulty: Value(entity.difficulty),
      dueDate: Value(entity.dueDate),
      reps: Value(entity.reps),
      lapses: Value(entity.lapses),
      state: Value(_cardStateToString(entity.state)),
      lastReviewDate: Value(entity.lastReviewDate),
    );
  }

  static CardState _parseCardState(String value) {
    return switch (value) {
      'new' => CardState.newCard,
      'learning' => CardState.learning,
      'review' => CardState.review,
      'relearning' => CardState.relearning,
      _ => CardState.newCard,
    };
  }

  static String _cardStateToString(CardState state) {
    return switch (state) {
      CardState.newCard => 'new',
      CardState.learning => 'learning',
      CardState.review => 'review',
      CardState.relearning => 'relearning',
    };
  }
}
