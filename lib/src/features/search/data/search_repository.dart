import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../../shorts/data/short_dto.dart';
import '../../shorts/domain/short_entity.dart';

/// Search repository — delegates to backend hybrid search when online,
/// falls back to local substring match when offline.
class SearchRepository {
  SearchRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  ShortsDao get _shortsDao => _db.shortsDao;

  /// Searches shorts — tries backend hybrid search first, falls back to local.
  Future<List<ShortEntity>> searchShorts({
    required String query,
    String? topicFilter,
    String? difficultyFilter,
    bool? readFilter,
    Set<String> doneIds = const {},
  }) async {
    if (query.trim().isEmpty) return [];

    // Try backend hybrid search (semantic + keyword)
    try {
      final result = await _api.get(
        ApiConstants.search,
        (json) => json,
        queryParams: {
          'q': query,
          if (topicFilter != null) 'topic': topicFilter,
          'limit': 20,
        },
      );
      if (result is Map<String, dynamic> && result['results'] is List) {
        final shorts = (result['results'] as List)
            .map((r) => ShortEntity.fromJson(r as Map<String, dynamic>))
            .toList();
        return shorts;
      }
    } catch (_) {
      // Fallback to local search
    }

    return _localSearch(
      query: query,
      topicFilter: topicFilter,
      difficultyFilter: difficultyFilter,
      readFilter: readFilter,
      doneIds: doneIds,
    );
  }

  /// Returns topic suggestions matching the query prefix.
  Future<List<String>> suggestTopics(String query) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final rows = await _shortsDao.getAllShorts();
    final topicSet = <String>{};

    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      for (final topic in topics) {
        if (topic.toLowerCase().contains(lowerQuery)) {
          topicSet.add(topic);
        }
      }
    }

    return topicSet.toList()..sort();
  }

  /// Returns all unique topics from the shorts collection.
  Future<List<String>> getAllTopics() async {
    final rows = await _shortsDao.getAllShorts();
    final topicSet = <String>{};

    for (final row in rows) {
      final topics = (jsonDecode(row.topicsJson) as List<dynamic>)
          .cast<String>();
      topicSet.addAll(topics);
    }

    return topicSet.toList()..sort();
  }

  // --- Local fallback search ---

  Future<List<ShortEntity>> _localSearch({
    required String query,
    String? topicFilter,
    String? difficultyFilter,
    bool? readFilter,
    Set<String> doneIds = const {},
  }) async {
    final lowerQuery = query.toLowerCase();
    final rows = await _shortsDao.getAllShorts();
    final shorts = rows.map(ShortDto.fromRow).toList();

    final scored = <_ScoredShort>[];
    for (final short in shorts) {
      final score = _scoreMatch(short, lowerQuery);
      if (score <= 0) continue;

      if (topicFilter != null && topicFilter.isNotEmpty) {
        final hasTopicMatch = short.topics.any(
          (t) => t.toLowerCase() == topicFilter.toLowerCase(),
        );
        if (!hasTopicMatch) continue;
      }

      if (difficultyFilter != null) {
        final diffRange = _difficultyRange(difficultyFilter);
        if (diffRange != null) {
          if (short.difficulty < diffRange.$1 ||
              short.difficulty > diffRange.$2) {
            continue;
          }
        }
      }

      if (readFilter != null) {
        final isDone = doneIds.contains(short.id);
        if (readFilter && !isDone) continue;
        if (!readFilter && isDone) continue;
      }

      scored.add(_ScoredShort(short, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.short).toList();
  }

  double _scoreMatch(ShortEntity short, String lowerQuery) {
    double score = 0;

    if (short.title.toLowerCase().contains(lowerQuery)) {
      score += 3.0;
      if (short.title.toLowerCase().startsWith(lowerQuery)) {
        score += 1.0;
      }
    }

    for (final topic in short.topics) {
      if (topic.toLowerCase().contains(lowerQuery)) {
        score += 2.0;
      }
    }

    for (final tag in short.tags) {
      if (tag.toLowerCase().contains(lowerQuery)) {
        score += 1.5;
      }
    }

    if (short.summary.toLowerCase().contains(lowerQuery)) {
      score += 0.5;
    }

    if (short.content.toLowerCase().contains(lowerQuery)) {
      score += 0.25;
    }

    return score;
  }

  (double, double)? _difficultyRange(String difficulty) {
    return switch (difficulty) {
      'beginner' => (0.0, 0.35),
      'intermediate' => (0.35, 0.65),
      'advanced' => (0.65, 1.0),
      _ => null,
    };
  }
}

class _ScoredShort {
  const _ScoredShort(this.short, this.score);
  final ShortEntity short;
  final double score;
}
