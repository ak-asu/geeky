import '../../../core/utils/time_of_day_context.dart';
import '../../location/domain/location_context.dart';
import '../domain/short_entity.dart';

/// Client-side feed scoring for the shorts main feed.
///
/// Only applied when the full unfiltered feed is shown. Module feeds
/// (filtered by [ShortsFeedParams.filterShortIds]) preserve their curated
/// order and bypass this scorer entirely.
///
/// Scoring factors:
///  1. Undone bonus          — prioritise content the user hasn't finished
///  2. Recency               — recently added shorts surface higher
///  3. Time-of-day window    — explicit difficulty field matched to current phase
///  4. Topic diversity       — penalise shorts whose topics were seen this session
///  5. Location boost        — boost when topics/tags/title overlap with region
abstract final class ShortFeedScorer {
  static const _locationBoostPerToken = 1.5;
  static const _topicDiversityPenalty = 1.5;

  /// Returns [shorts] sorted by descending score.
  ///
  /// [doneIds] — set of short IDs the user has already marked done.
  /// [recentSessionTopics] — topics seen this session for diversity control.
  /// [locationContext] — optional region for location boost; null = no boost.
  static List<ShortEntity> rank(
    List<ShortEntity> shorts,
    Set<String> doneIds, {
    Set<String> recentSessionTopics = const {},
    LocationContext? locationContext,
  }) {
    if (shorts.isEmpty) return shorts;

    final now = DateTime.now();
    final phase = TimeOfDayContext.currentPhase();
    final window = TimeOfDayContext.difficultyWindow(phase);

    final scored = shorts.map((s) {
      final score = _score(
        s,
        now,
        doneIds,
        window,
        recentSessionTopics,
        locationContext,
      );
      return (short: s, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.short).toList();
  }

  static double _score(
    ShortEntity short,
    DateTime now,
    Set<String> doneIds,
    (double, double) window,
    Set<String> recentSessionTopics,
    LocationContext? locationContext,
  ) {
    double score = 0;

    // 1. Undone bonus — done shorts move toward the bottom but aren't hidden
    if (!doneIds.contains(short.id)) score += 3.0;

    // 2. Recency — prefer recently published content
    final ageDays = now.difference(short.createdAt).inDays;
    if (ageDays < 1) {
      score += 2.0;
    } else if (ageDays < 7) {
      score += 1.5;
    } else if (ageDays < 30) {
      score += 0.5;
    }

    // 3. Time-of-day difficulty window
    //    ShortEntity has an explicit difficulty field [0.0, 1.0].
    score += TimeOfDayContext.windowScore(short.difficulty, window);

    // 4. Topic diversity — penalise if any topic was seen this session.
    //    Only penalise once per short regardless of how many topics match.
    if (short.topics.any(recentSessionTopics.contains)) {
      score -= _topicDiversityPenalty;
    }

    // 5. Location boost — +1.5 per matching region token
    if (locationContext != null && !locationContext.isEmpty) {
      score += _locationScore(short, locationContext);
    }

    return score;
  }

  /// Returns +1.5 per region token found in topics, tags, or title.
  static double _locationScore(ShortEntity short, LocationContext ctx) {
    final tokens = ctx.tokens;
    if (tokens.isEmpty) return 0;

    final searchText = [
      short.title,
      ...short.topics,
      ...short.tags,
    ].join(' ').toLowerCase();

    final matchCount = tokens
        .where((t) => searchText.contains(t.toLowerCase()))
        .length;

    return matchCount * _locationBoostPerToken;
  }
}
