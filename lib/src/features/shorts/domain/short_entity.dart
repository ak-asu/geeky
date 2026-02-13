import 'package:freezed_annotation/freezed_annotation.dart';

part 'short_entity.freezed.dart';
part 'short_entity.g.dart';

@freezed
abstract class ShortEntity with _$ShortEntity {
  const factory ShortEntity({
    required String id,
    required String userId,
    required String title,
    required String content,
    @Default('') String summary,
    @Default([]) List<String> topics,
    @Default([]) List<String> tags,
    @Default(0.5) double difficulty,
    @Default(1) int level,
    @Default([]) List<String> prerequisites,
    @Default([]) List<String> related,
    @Default([]) List<String> citations,
    @Default([]) List<String> prompts,
    @Default([]) List<String> conceptIds,
    @Default([]) List<String> media,
    @Default({}) Map<String, dynamic> engagement,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ShortEntity;

  factory ShortEntity.fromJson(Map<String, dynamic> json) =>
      _$ShortEntityFromJson(json);
}
