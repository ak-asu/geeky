import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/fsrs_scheduler.dart';
import 'data/quiz_repository.dart';
import 'domain/quiz_card_entity.dart';
import 'domain/quiz_session_state.dart';

export 'domain/quiz_session_state.dart' show QuizSessionState, QuizResult;

part 'providers.g.dart';

@Riverpod(keepAlive: true)
QuizRepository quizRepository(Ref ref) {
  return QuizRepository(ref.read(appDatabaseProvider));
}

/// All quiz cards.
@riverpod
Future<List<QuizCardEntity>> allQuizCards(Ref ref) {
  return ref.watch(quizRepositoryProvider).getAllCards();
}

/// Due cards for spaced review.
@riverpod
Future<List<QuizCardEntity>> dueQuizCards(Ref ref) {
  return ref.watch(quizRepositoryProvider).getDueCards();
}

/// Manages quiz session state.
@riverpod
class QuizSession extends _$QuizSession {
  @override
  QuizSessionState build() => const QuizSessionState();

  void startSession(List<QuizCardEntity> cards) {
    state = QuizSessionState(cards: cards, currentIndex: 0, results: []);
  }

  void recordGrade(FSRSGrade grade) {
    if (state.isComplete) return;

    final currentCard = state.currentCard;
    if (currentCard == null) return;

    final result = QuizResult(card: currentCard, grade: grade);

    final newResults = [...state.results, result];
    final nextIndex = state.currentIndex + 1;

    state = state.copyWith(currentIndex: nextIndex, results: newResults);

    // Apply the grade via repository
    ref.read(quizRepositoryProvider).gradeCard(currentCard, grade);
  }
}
