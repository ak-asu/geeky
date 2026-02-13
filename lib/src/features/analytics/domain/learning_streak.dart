import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_streak.freezed.dart';
part 'learning_streak.g.dart';

@freezed
abstract class LearningStreak with _$LearningStreak {
  const factory LearningStreak({
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    DateTime? lastActiveDate,
    @Default({}) Map<String, int> weeklyActivity,
  }) = _LearningStreak;

  factory LearningStreak.fromJson(Map<String, dynamic> json) =>
      _$LearningStreakFromJson(json);
}
