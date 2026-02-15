import 'dart:async';

import '../domain/content_source_entity.dart';

/// Mock repository for content sources.
/// Uses in-memory data since there's no Drift table for sources yet.
class SourcesRepository {
  final _controller = StreamController<List<ContentSourceEntity>>.broadcast();
  List<ContentSourceEntity> _sources = List.from(_mockSources);

  Stream<List<ContentSourceEntity>> watchAllSources() {
    // Emit current state immediately then listen for changes
    _controller.add(_sources);
    return _controller.stream;
  }

  List<ContentSourceEntity> getAllSources() => List.unmodifiable(_sources);

  ContentSourceEntity? getSourceById(String id) {
    try {
      return _sources.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void addSource(ContentSourceEntity source) {
    _sources = [..._sources, source];
    _controller.add(_sources);
  }

  void removeSource(String id) {
    _sources = _sources.where((s) => s.id != id).toList();
    _controller.add(_sources);
  }

  void dispose() {
    _controller.close();
  }

  static final _mockSources = [
    ContentSourceEntity(
      id: 'source-001',
      userId: 'user-001',
      type: 'url',
      name: 'Stanford CS229 Notes',
      url: 'https://cs229.stanford.edu/notes',
      status: 'active',
      healthScore: 0.95,
      lastChecked: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime(2025, 12, 1),
    ),
    ContentSourceEntity(
      id: 'source-002',
      userId: 'user-001',
      type: 'url',
      name: 'MDN Web Docs',
      url: 'https://developer.mozilla.org',
      status: 'active',
      healthScore: 1.0,
      lastChecked: DateTime.now().subtract(const Duration(hours: 1)),
      createdAt: DateTime(2025, 12, 10),
    ),
    ContentSourceEntity(
      id: 'source-003',
      userId: 'user-001',
      type: 'file',
      name: 'Bayesian Statistics Textbook',
      status: 'active',
      healthScore: 0.88,
      lastChecked: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime(2026, 1, 5),
    ),
  ];
}
