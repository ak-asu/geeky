import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/analytics_repository.dart';
import 'domain/achievement.dart';
import 'domain/learning_streak.dart';
import 'domain/topic_progress.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AnalyticsRepository analyticsRepository(Ref ref) {
  return AnalyticsRepository(ref.read(appDatabaseProvider));
}

@riverpod
Future<LearningStreak> learningStreak(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getStreak();
}

@riverpod
Future<AnalyticsStats> analyticsStats(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getStats();
}

@riverpod
Future<List<TopicProgress>> topicProgress(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getTopicProgress();
}

@riverpod
Future<List<Achievement>> achievements(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getAchievements();
}

@riverpod
Future<List<DailyEngagement>> weeklyEngagement(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getWeeklyEngagement();
}
