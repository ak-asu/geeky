import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/content_source_entity.dart';

abstract final class SourceDto {
  static ContentSourceEntity fromRow(CachedSource row) {
    return ContentSourceEntity(
      id: row.id,
      userId: row.userId,
      type: row.type,
      name: row.name,
      url: row.url,
      status: row.status,
      healthScore: row.healthScore,
      lastChecked: row.lastChecked,
      createdAt: row.createdAt,
    );
  }

  static CachedSourcesCompanion toCompanion(ContentSourceEntity entity) {
    final now = DateTime.now();
    return CachedSourcesCompanion(
      id: Value(entity.id),
      userId: Value(entity.userId),
      type: Value(entity.type),
      name: Value(entity.name),
      url: Value(entity.url),
      status: Value(entity.status),
      healthScore: Value(entity.healthScore),
      lastChecked: Value(entity.lastChecked),
      createdAt: Value(entity.createdAt),
      cachedAt: Value(now),
    );
  }
}
