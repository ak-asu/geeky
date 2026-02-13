import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_module_entity.freezed.dart';
part 'store_module_entity.g.dart';

@freezed
abstract class StoreModuleEntity with _$StoreModuleEntity {
  const factory StoreModuleEntity({
    required String id,
    required String name,
    required String description,
    @Default([]) List<String> topics,
    @Default('') String author,
    @Default(0) int shortCount,
    @Default(0.5) double difficulty,
    @Default(0) double rating,
    @Default(0) int downloads,
    @Default(false) bool isDownloaded,
    String? previewImageUrl,
  }) = _StoreModuleEntity;

  factory StoreModuleEntity.fromJson(Map<String, dynamic> json) =>
      _$StoreModuleEntityFromJson(json);
}
