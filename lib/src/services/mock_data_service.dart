import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import 'local/database.dart';

/// Reads JSON fixtures from assets and seeds them into Drift on first launch.
class MockDataService {
  MockDataService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  bool get _alreadySeeded =>
      _prefs.getBool(StorageKeys.mockDataSeeded) ?? false;

  Future<void> seedIfNeeded() async {
    if (_alreadySeeded) return;

    await _seedNotes();
    await _seedShorts();
    await _seedModules();
    await _seedConcepts();
    await _seedRelationships();

    await _prefs.setBool(StorageKeys.mockDataSeeded, true);
  }

  Future<List<dynamic>> _loadJson(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> _seedNotes() async {
    final items = await _loadJson('assets/mock/notes.json');
    final now = DateTime.now();
    await _db.batch((batch) {
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        batch.insert(
          _db.cachedNotes,
          CachedNotesCompanion.insert(
            id: map['id'] as String,
            userId: map['user_id'] as String,
            type: map['type'] as String,
            title: Value(map['title'] as String?),
            content: Value(map['content'] as String?),
            extractedText: Value(map['extracted_text'] as String?),
            sourceUrl: Value(map['source_url'] as String?),
            mediaAssetsJson: Value(map['media_assets_json'] as String? ?? '[]'),
            processed: Value(map['processed'] as bool? ?? false),
            metadataJson: Value(map['metadata_json'] as String? ?? '{}'),
            wordCount: Value(map['word_count'] as int? ?? 0),
            createdAt:
                DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
            updatedAt:
                DateTime.tryParse(map['updated_at'] as String? ?? '') ?? now,
          ),
        );
      }
    });
  }

  Future<void> _seedShorts() async {
    final items = await _loadJson('assets/mock/shorts.json');
    final now = DateTime.now();
    await _db.batch((batch) {
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        batch.insert(
          _db.cachedShorts,
          CachedShortsCompanion.insert(
            id: map['id'] as String,
            userId: map['user_id'] as String,
            title: map['title'] as String,
            content: map['content'] as String,
            summary: map['summary'] as String? ?? '',
            topicsJson: Value(map['topics_json'] as String? ?? '[]'),
            tagsJson: Value(map['tags_json'] as String? ?? '[]'),
            difficulty: Value(_parseDifficulty(map['difficulty'])),
            level: Value(map['level'] as int? ?? 1),
            prerequisitesJson: Value(
              map['prerequisites_json'] as String? ?? '[]',
            ),
            relatedJson: Value(map['related_json'] as String? ?? '[]'),
            citationsJson: Value(map['citations_json'] as String? ?? '[]'),
            promptsJson: Value(map['prompts_json'] as String? ?? '[]'),
            conceptIdsJson: Value(map['concept_ids_json'] as String? ?? '[]'),
            mediaJson: Value(map['media_json'] as String? ?? '[]'),
            engagementJson: Value(map['engagement_json'] as String? ?? '{}'),
            createdAt:
                DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
            updatedAt:
                DateTime.tryParse(map['updated_at'] as String? ?? '') ?? now,
            cachedAt: now,
            version: Value(map['version'] as int? ?? 1),
          ),
        );
      }
    });
  }

  Future<void> _seedModules() async {
    final items = await _loadJson('assets/mock/modules.json');
    final now = DateTime.now();
    await _db.batch((batch) {
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        batch.insert(
          _db.cachedModules,
          CachedModulesCompanion.insert(
            id: map['id'] as String,
            userId: map['user_id'] as String,
            name: map['name'] as String,
            description: Value(map['description'] as String?),
            topicsJson: Value(map['topics_json'] as String? ?? '[]'),
            shortIdsJson: Value(map['short_ids_json'] as String? ?? '[]'),
            type: Value(map['type'] as String? ?? 'auto'),
            completedShorts: Value(map['completed_shorts'] as int? ?? 0),
            totalShorts: Value(map['total_shorts'] as int? ?? 0),
            currentPosition: Value(map['current_position'] as int? ?? 0),
            estimatedMinutesRemaining: Value(
              (map['estimated_minutes_remaining'] as num?)?.toDouble() ?? 0,
            ),
            createdAt:
                DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
            updatedAt:
                DateTime.tryParse(map['updated_at'] as String? ?? '') ?? now,
            cachedAt: now,
          ),
        );
      }
    });
  }

  Future<void> _seedConcepts() async {
    final items = await _loadJson('assets/mock/concepts.json');
    final now = DateTime.now();
    await _db.batch((batch) {
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        batch.insert(
          _db.cachedConcepts,
          CachedConceptsCompanion.insert(
            id: map['id'] as String,
            name: map['name'] as String,
            description: Value(map['description'] as String?),
            level: Value(map['level'] as int? ?? 1),
            aliasesJson: Value(map['aliases_json'] as String? ?? '[]'),
            articleIdsJson: Value(map['article_ids_json'] as String? ?? '[]'),
            importanceScore: Value(
              (map['importance_score'] as num?)?.toDouble() ?? 0,
            ),
            createdAt:
                DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
          ),
        );
      }
    });
  }

  static double _parseDifficulty(dynamic value) {
    if (value is num) return value.toDouble();
    return switch (value) {
      'beginner' => 0.3,
      'intermediate' => 0.5,
      'advanced' => 0.8,
      _ => 0.5,
    };
  }

  Future<void> _seedRelationships() async {
    final items = await _loadJson('assets/mock/relationships.json');
    await _db.batch((batch) {
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        batch.insert(
          _db.cachedRelationships,
          CachedRelationshipsCompanion.insert(
            id: map['id'] as String,
            sourceId: map['source_id'] as String,
            targetId: map['target_id'] as String,
            type: map['type'] as String,
            strength: Value((map['strength'] as num?)?.toDouble() ?? 1.0),
            isDynamic: Value(map['is_dynamic'] as bool? ?? false),
          ),
        );
      }
    });
  }
}
