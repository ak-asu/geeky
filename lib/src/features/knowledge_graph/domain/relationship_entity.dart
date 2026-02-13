import 'package:freezed_annotation/freezed_annotation.dart';

part 'relationship_entity.freezed.dart';
part 'relationship_entity.g.dart';

@freezed
abstract class RelationshipEntity with _$RelationshipEntity {
  const factory RelationshipEntity({
    required String id,
    required String sourceId,
    required String targetId,
    required String type,
    @Default(1.0) double strength,
    @Default(false) bool isDynamic,
  }) = _RelationshipEntity;

  factory RelationshipEntity.fromJson(Map<String, dynamic> json) =>
      _$RelationshipEntityFromJson(json);
}
