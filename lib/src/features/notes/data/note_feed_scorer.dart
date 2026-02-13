import '../domain/note_entity.dart';
import '../domain/note_feed_state.dart';

/// Client-side feed scoring for note ordering.
///
/// Factors: recency, read status, skip penalty, topic diversity,
/// time-of-day context (study sessions tend to be evening-biased).
abstract final class NoteFeedScorer {
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

    // 1. Recency bonus — newer notes score higher
    final ageHours = DateTime.now().difference(note.createdAt).inHours;
    score += _recencyScore(ageHours);

    // 2. Unread bonus — unread notes get a significant boost
    final isRead = feedState.readNoteIds.contains(note.id);
    if (!isRead) score += 30;

    // 3. Skip penalty — notes skipped multiple times are demoted
    final skipCount = feedState.skipCounts[note.id] ?? 0;
    score -= skipCount * 8;

    // 4. Topic diversity — penalize notes whose type was recently shown
    final recentTopics = feedState.recentTopics;
    if (recentTopics.contains(note.type)) {
      score -= 10;
    }

    // 5. Time-of-day context — boost longer notes during evening study hours
    final hour = DateTime.now().hour;
    if (hour >= 19 || hour <= 6) {
      // Evening/night: favor longer content
      if (note.wordCount > 200) score += 5;
    } else {
      // Daytime: favor shorter content
      if (note.wordCount <= 200) score += 5;
    }

    // 6. Content completeness — notes with title + content score higher
    if (note.title != null && note.title!.isNotEmpty) score += 5;
    if (note.content != null && note.content!.isNotEmpty) score += 5;

    return score;
  }

  /// Recency: 0-6 hours = 40pts, 6-24h = 30pts, 1-3d = 20pts, 3-7d = 10pts, >7d = 0
  static double _recencyScore(int ageHours) {
    if (ageHours < 6) return 40;
    if (ageHours < 24) return 30;
    if (ageHours < 72) return 20;
    if (ageHours < 168) return 10;
    return 0;
  }
}
