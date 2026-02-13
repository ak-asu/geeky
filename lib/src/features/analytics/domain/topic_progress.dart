import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic_progress.freezed.dart';
part 'topic_progress.g.dart';

@freezed
abstract class TopicProgress with _$TopicProgress {
  const factory TopicProgress({
    required String topic,
    @Default(0) int totalItems,
    @Default(0) int completedItems,
    @Default(0) double mastery,
  }) = _TopicProgress;

  factory TopicProgress.fromJson(Map<String, dynamic> json) =>
      _$TopicProgressFromJson(json);
}
