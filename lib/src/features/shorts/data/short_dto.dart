import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/short_entity.dart';

abstract final class ShortDto {
  static ShortEntity fromRow(CachedShort row) {
    return ShortEntity(
      id: row.id,
      userId: row.userId,
      title: row.title,
      content: row.content,
      summary: row.summary,
      topics: (jsonDecode(row.topicsJson) as List<dynamic>).cast<String>(),
      tags: (jsonDecode(row.tagsJson) as List<dynamic>).cast<String>(),
      difficulty: row.difficulty,
      level: row.level,
      prerequisites: (jsonDecode(row.prerequisitesJson) as List<dynamic>)
          .cast<String>(),
      related: (jsonDecode(row.relatedJson) as List<dynamic>).cast<String>(),
      citations: (jsonDecode(row.citationsJson) as List<dynamic>)
          .cast<String>(),
      prompts: (jsonDecode(row.promptsJson) as List<dynamic>).cast<String>(),
      conceptIds: (jsonDecode(row.conceptIdsJson) as List<dynamic>)
          .cast<String>(),
      media: (jsonDecode(row.mediaJson) as List<dynamic>).cast<String>(),
      engagement: jsonDecode(row.engagementJson) as Map<String, dynamic>,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static CachedShortsCompanion toCompanion(ShortEntity entity) {
    final now = DateTime.now();
    return CachedShortsCompanion(
      id: Value(entity.id),
      userId: Value(entity.userId),
      title: Value(entity.title),
      content: Value(entity.content),
      summary: Value(entity.summary),
      topicsJson: Value(jsonEncode(entity.topics)),
      tagsJson: Value(jsonEncode(entity.tags)),
      difficulty: Value(entity.difficulty),
      level: Value(entity.level),
      prerequisitesJson: Value(jsonEncode(entity.prerequisites)),
      relatedJson: Value(jsonEncode(entity.related)),
      citationsJson: Value(jsonEncode(entity.citations)),
      promptsJson: Value(jsonEncode(entity.prompts)),
      conceptIdsJson: Value(jsonEncode(entity.conceptIds)),
      mediaJson: Value(jsonEncode(entity.media)),
      engagementJson: Value(jsonEncode(entity.engagement)),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
      cachedAt: Value(now),
    );
  }
}
