import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark_entity.freezed.dart';
part 'bookmark_entity.g.dart';

@freezed
abstract class BookmarkEntity with _$BookmarkEntity {
  const factory BookmarkEntity({
    required String id,
    required String shortId,
    required String userId,
    required DateTime createdAt,
  }) = _BookmarkEntity;

  factory BookmarkEntity.fromJson(Map<String, dynamic> json) =>
      _$BookmarkEntityFromJson(json);
}
