import 'package:freezed_annotation/freezed_annotation.dart';

part 'quiz_card_entity.freezed.dart';
part 'quiz_card_entity.g.dart';

enum CardState { newCard, learning, review, relearning }

@freezed
abstract class QuizCardEntity with _$QuizCardEntity {
  const factory QuizCardEntity({
    required String articleId,
    @Default(1.0) double stability,
    @Default(0.5) double difficulty,
    required DateTime dueDate,
    @Default(0) int reps,
    @Default(0) int lapses,
    @Default(CardState.newCard) CardState state,
    DateTime? lastReviewDate,
  }) = _QuizCardEntity;

  factory QuizCardEntity.fromJson(Map<String, dynamic> json) =>
      _$QuizCardEntityFromJson(json);
}
