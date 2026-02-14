import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/module_entity.dart';

abstract final class ModuleDto {
  static ModuleEntity fromRow(CachedModule row) {
    return ModuleEntity(
      id: row.id,
      userId: row.userId,
      name: row.name,
      description: row.description,
      topics: (jsonDecode(row.topicsJson) as List<dynamic>).cast<String>(),
      shortIds: (jsonDecode(row.shortIdsJson) as List<dynamic>).cast<String>(),
      type: row.type,
      completedShorts: row.completedShorts,
      totalShorts: row.totalShorts,
      currentPosition: row.currentPosition,
      estimatedMinutesRemaining: row.estimatedMinutesRemaining,
      isFree: row.isFree,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static CachedModulesCompanion toCompanion(ModuleEntity entity) {
    final now = DateTime.now();
    return CachedModulesCompanion(
      id: Value(entity.id),
      userId: Value(entity.userId),
      name: Value(entity.name),
      description: Value(entity.description),
      topicsJson: Value(jsonEncode(entity.topics)),
      shortIdsJson: Value(jsonEncode(entity.shortIds)),
      type: Value(entity.type),
      completedShorts: Value(entity.completedShorts),
      totalShorts: Value(entity.totalShorts),
      currentPosition: Value(entity.currentPosition),
      estimatedMinutesRemaining: Value(entity.estimatedMinutesRemaining),
      isFree: Value(entity.isFree),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
      cachedAt: Value(now),
    );
  }
}
