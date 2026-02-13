import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_entity.freezed.dart';
part 'note_entity.g.dart';

@freezed
abstract class NoteEntity with _$NoteEntity {
  const factory NoteEntity({
    required String id,
    required String userId,
    required String type,
    String? title,
    String? content,
    String? extractedText,
    String? sourceUrl,
    String? primaryTopic,
    @Default([]) List<String> topics,
    @Default([]) List<String> mediaAssets,
    @Default(false) bool processed,
    @Default({}) Map<String, dynamic> metadata,
    @Default(0) int wordCount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _NoteEntity;

  factory NoteEntity.fromJson(Map<String, dynamic> json) =>
      _$NoteEntityFromJson(json);
}
