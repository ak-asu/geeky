import 'dart:math';

import '../../../core/utils/time_of_day_context.dart';
import '../../location/domain/location_context.dart';
import '../domain/note_entity.dart';
import '../domain/note_feed_state.dart';

/// Client-side feed scoring for note ordering.
///
/// Scoring factors:
///  1. Recency boost (calendar-based)
///  2. Read status (unread bonus)
///  3. Length preference (Gaussian decay vs avg reading length)
///  4. Skip penalty
///  5. Retention resurfacing (Fibonacci intervals)
///  6. Topic diversity
///  7. Time-of-day difficulty window (replaces previous length-based check)
///  8. Media bonus
///  9. Location boost (new — topics/title matched against region tokens)
abstract final class NoteFeedScorer {
  /// Fibonacci intervals (days) for retention resurfacing.
  static const _fibonacciDays = [1, 3, 7, 14, 30];

  /// Returns notes sorted by descending score (highest relevance first).
  static List<NoteEntity> rank(
    List<NoteEntity> notes,
    NoteFeedState feedState, {
    LocationContext? locationContext,
  }) {
    if (notes.isEmpty) return notes;

    final scored = notes.map((note) {
      final score = _computeScore(note, feedState, locationContext);
      return (note: note, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.note).toList();
  }

  static double _computeScore(
    NoteEntity note,
    NoteFeedState feedState,
    LocationContext? locationContext,
  ) {
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

    // 7. Time-of-day difficulty window
    //    Notes have no explicit difficulty field; word count serves as a proxy.
    //    difficulty ≈ wordCount / 2000, clamped to [0.0, 1.0].
    final phase = TimeOfDayContext.currentPhase();
    final window = TimeOfDayContext.difficultyWindow(phase);
    final noteDifficulty = TimeOfDayContext.notesDifficultyProxy(note.wordCount);
    score += TimeOfDayContext.windowScore(noteDifficulty, window);

    // 8. Media bonus — notes with images/media get a small boost
    if (note.mediaAssets.isNotEmpty) {
      score += 0.5;
    }

    // 9. Location boost — boost notes whose topics/title overlap with the
    //    user's current region (city, state, country).
    if (locationContext != null && !locationContext.isEmpty) {
      score += _locationScore(note, locationContext);
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
      if ((ageDays - interval).abs() <= 1) {
        return 2.0;
      }
    }
    return 0;
  }

  /// Location boost: +1.5 per region token (city / state / country) found
  /// in the note's title, primary topic, or topics list.
  /// Max: +4.5 when all three tokens match.
  static double _locationScore(NoteEntity note, LocationContext ctx) {
    final tokens = ctx.tokens;
    if (tokens.isEmpty) return 0;

    final searchText = [
      note.title,
      if (note.primaryTopic != null) note.primaryTopic!,
      ...note.topics,
    ].join(' ').toLowerCase();

    final matchCount = tokens.where(
      (t) => searchText.contains(t.toLowerCase()),
    ).length;

    return matchCount * 1.5;
  }
}
