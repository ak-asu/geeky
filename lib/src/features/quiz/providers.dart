import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/fsrs_scheduler.dart';
import 'data/quiz_repository.dart';
import 'domain/quiz_card_entity.dart';

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
    state = QuizSessionState(
      cards: cards,
      currentIndex: 0,
      results: [],
    );
  }

  void recordGrade(FSRSGrade grade) {
    if (state.isComplete) return;

    final currentCard = state.currentCard;
    if (currentCard == null) return;

    final result = QuizResult(
      card: currentCard,
      grade: grade,
    );

    final newResults = [...state.results, result];
    final nextIndex = state.currentIndex + 1;

    state = state.copyWith(
      currentIndex: nextIndex,
      results: newResults,
    );

    // Apply the grade via repository
    ref.read(quizRepositoryProvider).gradeCard(currentCard, grade);
  }
}

class QuizSessionState {
  const QuizSessionState({
    this.cards = const [],
    this.currentIndex = 0,
    this.results = const [],
  });

  final List<QuizCardEntity> cards;
  final int currentIndex;
  final List<QuizResult> results;

  bool get isComplete => currentIndex >= cards.length;
  QuizCardEntity? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;
  int get totalCards => cards.length;
  int get answeredCards => results.length;

  QuizSessionState copyWith({
    List<QuizCardEntity>? cards,
    int? currentIndex,
    List<QuizResult>? results,
  }) {
    return QuizSessionState(
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      results: results ?? this.results,
    );
  }
}

class QuizResult {
  const QuizResult({required this.card, required this.grade});

  final QuizCardEntity card;
  final FSRSGrade grade;
}
