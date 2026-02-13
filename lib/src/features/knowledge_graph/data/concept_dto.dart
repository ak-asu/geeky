import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/concept_entity.dart';

abstract final class ConceptDto {
  static ConceptEntity fromRow(CachedConcept row) {
    return ConceptEntity(
      id: row.id,
      name: row.name,
      description: row.description,
      level: row.level,
      aliases: (jsonDecode(row.aliasesJson) as List<dynamic>).cast<String>(),
      articleIds: (jsonDecode(row.articleIdsJson) as List<dynamic>)
          .cast<String>(),
      importanceScore: row.importanceScore,
      createdAt: row.createdAt,
    );
  }

  static CachedConceptsCompanion toCompanion(ConceptEntity entity) {
    return CachedConceptsCompanion(
      id: Value(entity.id),
      name: Value(entity.name),
      description: Value(entity.description),
      level: Value(entity.level),
      aliasesJson: Value(jsonEncode(entity.aliases)),
      articleIdsJson: Value(jsonEncode(entity.articleIds)),
      importanceScore: Value(entity.importanceScore),
      createdAt: Value(entity.createdAt),
    );
  }
}
