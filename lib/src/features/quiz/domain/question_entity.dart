import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_entity.freezed.dart';
part 'question_entity.g.dart';

enum QuestionType { multipleChoice, trueFalse, freeResponse }

@freezed
abstract class QuestionEntity with _$QuestionEntity {
  const factory QuestionEntity({
    required String id,
    required String articleId,
    required String questionText,
    required QuestionType type,
    @Default([]) List<String> options,
    required String correctAnswer,
    String? explanation,
    String? topic,
    @Default(0.5) double difficulty,
    required DateTime createdAt,
  }) = _QuestionEntity;

  factory QuestionEntity.fromJson(Map<String, dynamic> json) =>
      _$QuestionEntityFromJson(json);
}
