import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/store_module_entity.dart';

abstract final class StoreModuleDto {
  static StoreModuleEntity fromRow(CachedStoreModule row) {
    return StoreModuleEntity(
      id: row.id,
      name: row.name,
      description: row.description,
      topics: (jsonDecode(row.topicsJson) as List<dynamic>).cast<String>(),
      author: row.author,
      shortCount: row.shortCount,
      difficulty: row.difficulty,
      rating: row.rating,
      downloads: row.downloads,
      isDownloaded: row.isDownloaded,
      previewImageUrl: row.previewImageUrl,
    );
  }

  static CachedStoreModulesCompanion toCompanion(StoreModuleEntity entity) {
    final now = DateTime.now();
    return CachedStoreModulesCompanion(
      id: Value(entity.id),
      name: Value(entity.name),
      description: Value(entity.description),
      topicsJson: Value(jsonEncode(entity.topics)),
      author: Value(entity.author),
      shortCount: Value(entity.shortCount),
      difficulty: Value(entity.difficulty),
      rating: Value(entity.rating),
      downloads: Value(entity.downloads),
      isDownloaded: Value(entity.isDownloaded),
      previewImageUrl: Value(entity.previewImageUrl),
      createdAt: Value(now),
      cachedAt: Value(now),
    );
  }
}
