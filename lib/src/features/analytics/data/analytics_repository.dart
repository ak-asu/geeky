import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../domain/achievement.dart';
import '../domain/learning_streak.dart';
import '../domain/topic_progress.dart';

/// Analytics repository — fetches from backend when online,
/// falls back to local mock data when offline.
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
      // Fallback to mock
    }
    return LearningStreak(
      currentStreak: 7,
      longestStreak: 14,
      lastActiveDate: DateTime.now(),
      weeklyActivity: {
        'Mon': 3,
        'Tue': 5,
        'Wed': 2,
        'Thu': 4,
        'Fri': 6,
        'Sat': 1,
        'Sun': 3,
      },
    );
  }

  Future<AnalyticsStats> getStats() async {
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
      // Fallback to local computation
    }

    final rows = await _shortsDao.getAllShorts();
    final topicSet = <String>{};
    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      topicSet.addAll(topics);
    }

    return AnalyticsStats(
      totalShortsCompleted: 23,
      totalTopicsCovered: topicSet.length,
      totalTimeMinutes: 145,
      learningVelocity: 3.3,
    );
  }

  Future<List<TopicProgress>> getTopicProgress() async {
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
      // Fallback to local computation
    }

    final rows = await _shortsDao.getAllShorts();
    final topicCounts = <String, int>{};
    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      for (final topic in topics) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }
    }

    final mockMastery = {
      'Machine Learning': 0.72,
      'Neural Networks': 0.65,
      'Deep Learning': 0.58,
      'Natural Language Processing': 0.45,
      'CSS': 0.80,
      'JavaScript': 0.75,
      'Web Development': 0.70,
      'Data Science': 0.62,
      'Python': 0.85,
      'Spaced Repetition': 0.90,
      'Mathematics': 0.55,
      'Statistics': 0.50,
    };

    return topicCounts.entries.map((e) {
      final mastery = mockMastery[e.key] ?? 0.4;
      final completed = (e.value * mastery).round();
      return TopicProgress(
        topic: e.key,
        totalItems: e.value,
        completedItems: completed,
        mastery: mastery,
      );
    }).toList()..sort((a, b) => b.mastery.compareTo(a.mastery));
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
      // Fallback to local assets
    }

    final raw = await rootBundle.loadString('assets/mock/achievements.json');
    final items = jsonDecode(raw) as List<dynamic>;

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      return Achievement(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String,
        isUnlocked: map['unlocked'] as bool? ?? false,
        unlockedAt: map['unlocked_at'] != null
            ? DateTime.tryParse(map['unlocked_at'] as String)
            : null,
        category: map['category'] as String? ?? 'general',
      );
    }).toList();
  }

  /// Weekly engagement data for chart.
  Future<List<DailyEngagement>> getWeeklyEngagement() async {
    // Backend dashboard includes this data; parse if available
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
      // Fallback to mock
    }

    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final values = [12, 18, 8, 22, 15, 5, 10];
      return DailyEngagement(
        date: day,
        minutesSpent: values[i],
        shortsCompleted: (values[i] / 4).round(),
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
