import 'dart:math';

import '../domain/quiz_card_entity.dart';

/// Simplified FSRS grade — maps to self-grading buttons.
enum FSRSGrade { again, hard, good, easy }

/// Simplified FSRS scheduler for spaced repetition.
/// Implements core FSRS logic: stability growth, difficulty adjustment,
/// and interval calculation based on desired retention rate.
abstract final class FSRSScheduler {
  static const _desiredRetention = 0.9;

  /// Schedule a card after grading.
  static QuizCardEntity schedule(QuizCardEntity card, FSRSGrade grade) {
    final now = DateTime.now();

    // Update difficulty (constrained 0.1 - 1.0)
    final diffDelta = switch (grade) {
      FSRSGrade.again => 0.1,
      FSRSGrade.hard => 0.05,
      FSRSGrade.good => -0.02,
      FSRSGrade.easy => -0.08,
    };
    final newDifficulty = (card.difficulty + diffDelta).clamp(0.1, 1.0);

    // Handle "again" — reset to learning
    if (grade == FSRSGrade.again) {
      return card.copyWith(
        stability: max(0.5, card.stability * 0.5),
        difficulty: newDifficulty,
        dueDate: now.add(const Duration(minutes: 10)),
        lapses: card.lapses + 1,
        state: CardState.relearning,
        lastReviewDate: now,
      );
    }

    // Stability growth factor
    final growthFactor = switch (grade) {
      FSRSGrade.hard => 1.2,
      FSRSGrade.good => 2.5,
      FSRSGrade.easy => 3.5,
      FSRSGrade.again => 0.5, // unreachable due to early return
    };

    final newStability = card.stability * growthFactor * (1.1 - newDifficulty);
    final clampedStability = max(0.5, newStability);

    // Calculate interval from stability and desired retention
    final interval = _stabilityToInterval(clampedStability);
    final dueDate = now.add(Duration(days: interval.round()));

    // Determine new state
    final newState = card.reps >= 1 ? CardState.review : CardState.learning;

    return card.copyWith(
      stability: clampedStability,
      difficulty: newDifficulty,
      dueDate: dueDate,
      reps: card.reps + 1,
      state: newState,
      lastReviewDate: now,
    );
  }

  /// Convert stability to days interval using desired retention.
  static double _stabilityToInterval(double stability) {
    // FSRS formula: I = S * (-ln(R) / ln(2))^(1/w)
    // Simplified: I ≈ S * 9 * (1/R - 1) for R near 0.9
    return stability * (9.0 * (1.0 / _desiredRetention - 1.0) + 1.0);
  }
}
