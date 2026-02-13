import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/note_feed_state.dart';

abstract final class NoteFeedStateDto {
  static NoteFeedState fromRow(NoteFeedStateEntry row) {
    return NoteFeedState(
      skipCounts: (jsonDecode(row.skipCountsJson) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
      lastSeen: (jsonDecode(row.lastSeenJson) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
      readNoteIds: (jsonDecode(row.readNoteIdsJson) as List<dynamic>)
          .cast<String>(),
      bookmarkedNoteIds:
          (jsonDecode(row.bookmarkedNoteIdsJson) as List<dynamic>)
              .cast<String>(),
      recentTopics: (jsonDecode(row.recentTopicsJson) as List<dynamic>)
          .cast<String>(),
      avgReadLengthWords: row.avgReadLengthWords,
    );
  }

  static NoteFeedStateEntriesCompanion toCompanion(NoteFeedState state) {
    return NoteFeedStateEntriesCompanion(
      id: const Value(1),
      skipCountsJson: Value(jsonEncode(state.skipCounts)),
      lastSeenJson: Value(jsonEncode(state.lastSeen)),
      readNoteIdsJson: Value(jsonEncode(state.readNoteIds)),
      bookmarkedNoteIdsJson: Value(jsonEncode(state.bookmarkedNoteIds)),
      recentTopicsJson: Value(jsonEncode(state.recentTopics)),
      avgReadLengthWords: Value(state.avgReadLengthWords),
    );
  }
}
