import 'package:freezed_annotation/freezed_annotation.dart';

part 'concept_entity.freezed.dart';
part 'concept_entity.g.dart';

@freezed
abstract class ConceptEntity with _$ConceptEntity {
  const factory ConceptEntity({
    required String id,
    required String name,
    String? description,
    @Default(1) int level,
    @Default([]) List<String> aliases,
    @Default([]) List<String> articleIds,
    @Default(0) double importanceScore,
    required DateTime createdAt,
  }) = _ConceptEntity;

  factory ConceptEntity.fromJson(Map<String, dynamic> json) =>
      _$ConceptEntityFromJson(json);
}
