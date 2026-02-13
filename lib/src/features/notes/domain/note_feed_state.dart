import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_feed_state.freezed.dart';
part 'note_feed_state.g.dart';

@freezed
abstract class NoteFeedState with _$NoteFeedState {
  const factory NoteFeedState({
    @Default({}) Map<String, int> skipCounts,
    @Default({}) Map<String, String> lastSeen,
    @Default([]) List<String> readNoteIds,
    @Default([]) List<String> bookmarkedNoteIds,
    @Default([]) List<String> recentTopics,
    @Default(0) double avgReadLengthWords,
  }) = _NoteFeedState;

  factory NoteFeedState.fromJson(Map<String, dynamic> json) =>
      _$NoteFeedStateFromJson(json);
}
