import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/fsrs_scheduler.dart';
import 'quiz_card_entity.dart';

part 'quiz_session_state.freezed.dart';

@freezed
abstract class QuizSessionState with _$QuizSessionState {
  const QuizSessionState._();

  const factory QuizSessionState({
    @Default([]) List<QuizCardEntity> cards,
    @Default(0) int currentIndex,
    @Default([]) List<QuizResult> results,
  }) = _QuizSessionState;

  bool get isComplete => currentIndex >= cards.length;

  QuizCardEntity? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;

  int get totalCards => cards.length;

  int get answeredCards => results.length;
}

@freezed
abstract class QuizResult with _$QuizResult {
  const factory QuizResult({
    required QuizCardEntity card,
    required FSRSGrade grade,
  }) = _QuizResult;
}
