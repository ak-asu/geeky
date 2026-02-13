import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/note_entity.dart';

abstract final class NoteDto {
  static NoteEntity fromRow(CachedNote row) {
    return NoteEntity(
      id: row.id,
      userId: row.userId,
      type: row.type,
      title: row.title,
      content: row.content,
      extractedText: row.extractedText,
      sourceUrl: row.sourceUrl,
      mediaAssets: (jsonDecode(row.mediaAssetsJson) as List<dynamic>)
          .cast<String>(),
      processed: row.processed,
      metadata: jsonDecode(row.metadataJson) as Map<String, dynamic>,
      wordCount: row.wordCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static CachedNotesCompanion toCompanion(NoteEntity entity) {
    return CachedNotesCompanion(
      id: Value(entity.id),
      userId: Value(entity.userId),
      type: Value(entity.type),
      title: Value(entity.title),
      content: Value(entity.content),
      extractedText: Value(entity.extractedText),
      sourceUrl: Value(entity.sourceUrl),
      mediaAssetsJson: Value(jsonEncode(entity.mediaAssets)),
      processed: Value(entity.processed),
      metadataJson: Value(jsonEncode(entity.metadata)),
      wordCount: Value(entity.wordCount),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }
}
