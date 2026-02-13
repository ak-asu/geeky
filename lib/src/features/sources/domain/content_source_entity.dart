import 'package:freezed_annotation/freezed_annotation.dart';

part 'content_source_entity.freezed.dart';
part 'content_source_entity.g.dart';

@freezed
abstract class ContentSourceEntity with _$ContentSourceEntity {
  const factory ContentSourceEntity({
    required String id,
    required String userId,
    required String type,
    required String name,
    String? url,
    @Default('active') String status,
    double? healthScore,
    DateTime? lastChecked,
    required DateTime createdAt,
  }) = _ContentSourceEntity;

  factory ContentSourceEntity.fromJson(Map<String, dynamic> json) =>
      _$ContentSourceEntityFromJson(json);
}
