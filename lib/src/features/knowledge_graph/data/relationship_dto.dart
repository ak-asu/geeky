import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/relationship_entity.dart';

abstract final class RelationshipDto {
  static RelationshipEntity fromRow(CachedRelationship row) {
    return RelationshipEntity(
      id: row.id,
      sourceId: row.sourceId,
      targetId: row.targetId,
      type: row.type,
      strength: row.strength,
      isDynamic: row.isDynamic,
    );
  }

  static CachedRelationshipsCompanion toCompanion(RelationshipEntity entity) {
    return CachedRelationshipsCompanion(
      id: Value(entity.id),
      sourceId: Value(entity.sourceId),
      targetId: Value(entity.targetId),
      type: Value(entity.type),
      strength: Value(entity.strength),
      isDynamic: Value(entity.isDynamic),
    );
  }
}
