import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/store_module_entity.dart';

/// Mock repository for the Module Store.
/// Loads from assets/mock/store_modules.json.
class StoreRepository {
  final _controller = StreamController<List<StoreModuleEntity>>.broadcast();
  List<StoreModuleEntity> _modules = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/mock/store_modules.json');
    final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
    _modules = jsonList
        .map((json) => _fromMockJson(json as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }

  Stream<List<StoreModuleEntity>> watchAllModules() async* {
    await _ensureLoaded();
    yield _modules;
    yield* _controller.stream;
  }

  Future<List<StoreModuleEntity>> getAllModules() async {
    await _ensureLoaded();
    return List.unmodifiable(_modules);
  }

  StoreModuleEntity? getModuleById(String id) {
    try {
      return _modules.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleDownload(String id) async {
    await _ensureLoaded();
    _modules = _modules.map((m) {
      if (m.id == id) {
        return m.copyWith(
          isDownloaded: !m.isDownloaded,
          downloads: m.isDownloaded ? m.downloads - 1 : m.downloads + 1,
        );
      }
      return m;
    }).toList();
    _controller.add(_modules);
  }

  int get downloadedCount => _modules.where((m) => m.isDownloaded).length;

  void dispose() {
    _controller.close();
  }

  static StoreModuleEntity _fromMockJson(Map<String, dynamic> json) {
    final topicsJson = json['topics_json'] as String? ?? '[]';
    final topics = (jsonDecode(topicsJson) as List<dynamic>).cast<String>();

    return StoreModuleEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      topics: topics,
      author: json['author'] as String? ?? '',
      shortCount: json['short_count'] as int? ?? 0,
      difficulty: 0.5,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      downloads: json['download_count'] as int? ?? 0,
      isDownloaded: false,
    );
  }
}
