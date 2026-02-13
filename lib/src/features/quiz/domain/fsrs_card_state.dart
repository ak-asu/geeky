import 'package:freezed_annotation/freezed_annotation.dart';

part 'fsrs_card_state.freezed.dart';
part 'fsrs_card_state.g.dart';

/// FSRS (Free Spaced Repetition Scheduler) state for a single card.
/// Separated from QuizCardEntity to allow independent state tracking
/// and algorithm updates without touching the card model.
@freezed
abstract class FSRSCardState with _$FSRSCardState {
  const factory FSRSCardState({
    required String cardId,
    @Default(1.0) double stability,
    @Default(0.5) double difficulty,
    required DateTime dueDate,
    @Default(0) int reps,
    @Default(0) int lapses,
    @Default(FSRSPhase.newCard) FSRSPhase phase,
    DateTime? lastReviewDate,
    @Default(0) int elapsedDaysSinceLastReview,
  }) = _FSRSCardState;

  factory FSRSCardState.fromJson(Map<String, dynamic> json) =>
      _$FSRSCardStateFromJson(json);
}

/// FSRS scheduling phases — mirrors the algorithm's state machine.
enum FSRSPhase { newCard, learning, review, relearning }
