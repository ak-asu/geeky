import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analytics/data/analytics_repository.dart';
import '../analytics/domain/topic_progress.dart';
import '../analytics/providers.dart';
import '../auth/providers.dart';
import '../auth/domain/user_entity.dart';

part 'providers.g.dart';

/// The current user's profile data, derived from auth state.
@riverpod
UserEntity? userProfile(Ref ref) {
  return ref.watch(currentUserProvider);
}

/// Topic expertise data for the radar chart on profile.
@riverpod
Future<List<TopicProgress>> profileExpertise(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getTopicProgress();
}

/// Profile stats summary.
@riverpod
Future<AnalyticsStats> profileStats(Ref ref) {
  return ref.read(analyticsRepositoryProvider).getStats();
}
