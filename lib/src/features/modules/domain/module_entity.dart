import 'package:freezed_annotation/freezed_annotation.dart';

part 'module_entity.freezed.dart';
part 'module_entity.g.dart';

@freezed
abstract class ModuleEntity with _$ModuleEntity {
  const factory ModuleEntity({
    required String id,
    required String userId,
    required String name,
    String? description,
    @Default([]) List<String> topics,
    @Default([]) List<String> shortIds,
    @Default('auto') String type,
    @Default(0) int completedShorts,
    @Default(0) int totalShorts,
    @Default(0) int currentPosition,
    @Default(0) double estimatedMinutesRemaining,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ModuleEntity;

  factory ModuleEntity.fromJson(Map<String, dynamic> json) =>
      _$ModuleEntityFromJson(json);
}
