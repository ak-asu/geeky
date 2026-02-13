import 'dart:math';

import '../domain/note_entity.dart';
import '../domain/note_feed_state.dart';

/// Client-side feed scoring for note ordering.
///
/// 8 scoring factors per spec:
/// 1. Recency boost (calendar-based)
/// 2. Read status (unread bonus)
/// 3. Length preference (Gaussian decay vs avg reading length)
/// 4. Skip penalty
/// 5. Retention resurfacing (Fibonacci intervals)
/// 6. Topic diversity
/// 7. Time-of-day context
/// 8. Media bonus
abstract final class NoteFeedScorer {
  /// Fibonacci intervals (days) for retention resurfacing.
  static const _fibonacciDays = [1, 3, 7, 14, 30];

  /// Returns notes sorted by descending score (highest relevance first).
  static List<NoteEntity> rank(
    List<NoteEntity> notes,
    NoteFeedState feedState,
  ) {
    if (notes.isEmpty) return notes;

    final scored = notes.map((note) {
      final score = _computeScore(note, feedState);
      return (note: note, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.note).toList();
  }

  static double _computeScore(NoteEntity note, NoteFeedState feedState) {
    double score = 0;
    final now = DateTime.now();

    // 1. Recency boost — calendar-based buckets
    score += _recencyScore(note.createdAt, now);

    // 2. Unread bonus
    final isRead = feedState.readNoteIds.contains(note.id);
    if (!isRead) score += 4.0;

    // 3. Length preference — Gaussian decay vs user's avg reading length
    if (feedState.avgReadLengthWords > 0) {
      score += _lengthPreferenceScore(
        note.wordCount.toDouble(),
        feedState.avgReadLengthWords,
      );
    }

    // 4. Skip penalty
    final skipCount = feedState.skipCounts[note.id] ?? 0;
    score -= skipCount * 0.7;

    // 5. Retention resurfacing — old read notes resurface at Fibonacci intervals
    if (isRead) {
      score += _retentionResurfacingScore(note.createdAt, now);
    }

    // 6. Topic diversity — penalize notes whose topic was recently shown
    final topic = note.primaryTopic ?? note.type;
    if (feedState.recentTopics.contains(topic)) {
      score -= 1.5;
    }

    // 7. Time-of-day context
    final hour = now.hour;
    if (hour >= 22 || hour <= 5) {
      // Late night / early morning: favor shorter notes
      if (note.wordCount <= 200) score += 0.5;
    } else if (hour >= 19) {
      // Evening study hours: favor longer content
      if (note.wordCount > 200) score += 0.5;
    }

    // 8. Media bonus — notes with images/media get a small boost
    if (note.mediaAssets.isNotEmpty) {
      score += 0.5;
    }

    return score;
  }

  /// Calendar-based recency: Today +3.0, This week +2.0, Month +1.0, Older +0.5
  static double _recencyScore(DateTime createdAt, DateTime now) {
    final ageDays = now.difference(createdAt).inDays;
    if (ageDays < 1) return 3.0;
    if (ageDays < 7) return 2.0;
    if (ageDays < 30) return 1.0;
    return 0.5;
  }

  /// Gaussian decay: score is highest when note length matches user avg.
  /// Peaks at 1.0 when perfect match, decays with distance.
  static double _lengthPreferenceScore(double wordCount, double avgLength) {
    if (avgLength <= 0) return 0;
    final sigma = avgLength * 0.5; // 50% of avg as standard deviation
    final diff = wordCount - avgLength;
    return exp(-(diff * diff) / (2 * sigma * sigma));
  }

  /// Retention resurfacing: gives bonus when a read note is at a Fibonacci
  /// interval (1, 3, 7, 14, 30 days) since creation — ideal review times.
  static double _retentionResurfacingScore(DateTime createdAt, DateTime now) {
    final ageDays = now.difference(createdAt).inDays;
    for (final interval in _fibonacciDays) {
      // Within ±1 day of a Fibonacci interval → boost for review
      if ((ageDays - interval).abs() <= 1) {
        return 2.0;
      }
    }
    return 0;
  }
}
