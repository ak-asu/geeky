import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../domain/achievement.dart';
import '../domain/learning_streak.dart';
import '../domain/topic_progress.dart';

/// Analytics repository — fetches from backend when online,
/// falls back to local empty/computed state when offline.
class AnalyticsRepository {
  AnalyticsRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  ShortsDao get _shortsDao => _db.shortsDao;

  Future<LearningStreak> getStreak() async {
    try {
      return await _api.get(
        '${ApiConstants.analytics}/streak',
        (json) => LearningStreak.fromJson(json as Map<String, dynamic>),
      );
    } catch (_) {
      // Offline: return empty streak — real data comes from backend only
    }
    return const LearningStreak();
  }

  Future<AnalyticsStats> getStats(String userId) async {
    try {
      final dashboard = await _api.get(
        '${ApiConstants.analytics}/dashboard',
        (json) => json as Map<String, dynamic>,
      );
      return AnalyticsStats(
        totalShortsCompleted:
            (dashboard['totalShortsCompleted'] as num?)?.toInt() ?? 0,
        totalTopicsCovered:
            (dashboard['totalTopicsCovered'] as num?)?.toInt() ?? 0,
        totalTimeMinutes: (dashboard['totalTimeMinutes'] as num?)?.toInt() ?? 0,
        learningVelocity:
            (dashboard['learningVelocity'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      // Offline: compute what we can from local cache
    }

    final rows = await _shortsDao.getAllShorts(userId);
    final topicSet = <String>{};
    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      topicSet.addAll(topics);
    }

    return AnalyticsStats(
      totalShortsCompleted: 0,
      totalTopicsCovered: topicSet.length,
      totalTimeMinutes: 0,
      learningVelocity: 0.0,
    );
  }

  Future<List<TopicProgress>> getTopicProgress(String userId) async {
    try {
      final mastery = await _api.get(
        '${ApiConstants.analytics}/mastery',
        (json) => json as Map<String, dynamic>,
      );
      if (mastery['topics'] is List) {
        return (mastery['topics'] as List)
            .map((t) => TopicProgress.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Offline: compute topic list from local cache, mastery unknown
    }

    final rows = await _shortsDao.getAllShorts(userId);
    final topicCounts = <String, int>{};
    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      for (final topic in topics) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }
    }

    return topicCounts.entries.map((e) {
      return TopicProgress(
        topic: e.key,
        totalItems: e.value,
        completedItems: 0,
        mastery: 0.0,
      );
    }).toList()..sort((a, b) => b.totalItems.compareTo(a.totalItems));
  }

  Future<List<Achievement>> getAchievements() async {
    try {
      final result = await _api.get(
        '${ApiConstants.analytics}/achievements',
        (json) => json as Map<String, dynamic>,
      );
      if (result['achievements'] is List) {
        return (result['achievements'] as List)
            .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Offline: no achievements available without backend
    }
    return [];
  }

  /// Weekly engagement data for chart.
  Future<List<DailyEngagement>> getWeeklyEngagement() async {
    try {
      final dashboard = await _api.get(
        '${ApiConstants.analytics}/dashboard',
        (json) => json as Map<String, dynamic>,
      );
      if (dashboard['weeklyEngagement'] is List) {
        return (dashboard['weeklyEngagement'] as List).map((d) {
          final map = d as Map<String, dynamic>;
          return DailyEngagement(
            date: DateTime.parse(map['date'] as String),
            minutesSpent: (map['minutesSpent'] as num?)?.toInt() ?? 0,
            shortsCompleted: (map['shortsCompleted'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (_) {
      // Offline: return zeroed days for the past week
    }

    final now = DateTime.now();
    return List.generate(7, (i) {
      return DailyEngagement(
        date: now.subtract(Duration(days: 6 - i)),
        minutesSpent: 0,
        shortsCompleted: 0,
      );
    });
  }
}

class AnalyticsStats {
  const AnalyticsStats({
    required this.totalShortsCompleted,
    required this.totalTopicsCovered,
    required this.totalTimeMinutes,
    required this.learningVelocity,
  });

  final int totalShortsCompleted;
  final int totalTopicsCovered;
  final int totalTimeMinutes;
  final double learningVelocity;
}

class DailyEngagement {
  const DailyEngagement({
    required this.date,
    required this.minutesSpent,
    required this.shortsCompleted,
  });

  final DateTime date;
  final int minutesSpent;
  final int shortsCompleted;
}
