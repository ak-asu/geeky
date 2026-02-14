import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../domain/achievement.dart';
import '../domain/learning_streak.dart';
import '../domain/topic_progress.dart';

/// Mock analytics repository — computes stats from local Drift data
/// and loads achievements from assets. Will be replaced by backend
/// GET /analytics/dashboard when live.
class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  ShortsDao get _shortsDao => _db.shortsDao;

  Future<LearningStreak> getStreak() async {
    // Mock streak data
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
    final rows = await _shortsDao.getAllShorts();

    // Collect unique topics
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
    final rows = await _shortsDao.getAllShorts();

    // Count shorts per topic
    final topicCounts = <String, int>{};
    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      for (final topic in topics) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }
    }

    // Mock mastery levels per topic
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

  /// Mock weekly engagement data for chart.
  Future<List<DailyEngagement>> getWeeklyEngagement() async {
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
