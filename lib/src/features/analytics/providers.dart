import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import 'data/analytics_repository.dart';
import 'domain/achievement.dart';
import 'domain/learning_streak.dart';
import 'domain/topic_progress.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AnalyticsRepository analyticsRepository(Ref ref) {
  return AnalyticsRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

@riverpod
Future<LearningStreak> learningStreak(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getStreak();
}

@riverpod
Future<AnalyticsStats> analyticsStats(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.read(analyticsRepositoryProvider).getStats(userId);
}

@riverpod
Future<List<TopicProgress>> topicProgress(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.read(analyticsRepositoryProvider).getTopicProgress(userId);
}

@riverpod
Future<List<Achievement>> achievements(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getAchievements();
}

@riverpod
Future<List<DailyEngagement>> weeklyEngagement(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getWeeklyEngagement();
}
