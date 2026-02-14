import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import '../shorts/domain/short_entity.dart';
import '../shorts/providers.dart';
import 'data/search_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) {
  return SearchRepository(ref.read(appDatabaseProvider));
}

/// The current search query text. Updated with 300ms debounce.
@riverpod
class SearchQuery extends _$SearchQuery {
  Timer? _debounce;

  @override
  String build() => '';

  void update(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = query;
    });
  }

  void clear() {
    _debounce?.cancel();
    state = '';
  }
}

/// Active topic filter for search results.
@riverpod
class SearchTopicFilter extends _$SearchTopicFilter {
  @override
  String? build() => null;

  void set(String? topic) => state = topic;
}

/// Active difficulty filter for search results.
@riverpod
class SearchDifficultyFilter extends _$SearchDifficultyFilter {
  @override
  String? build() => null;

  void set(String? difficulty) => state = difficulty;
}

/// Search results based on current query and filters.
@riverpod
Future<List<ShortEntity>> searchResults(Ref ref) async {
  final query = ref.watch(searchQueryProvider);
  final topicFilter = ref.watch(searchTopicFilterProvider);
  final difficultyFilter = ref.watch(searchDifficultyFilterProvider);
  final doneIds = ref.watch(shortsFeedProvider);

  if (query.isEmpty) return [];

  return ref
      .read(searchRepositoryProvider)
      .searchShorts(
        query: query,
        topicFilter: topicFilter,
        difficultyFilter: difficultyFilter,
        doneIds: doneIds,
      );
}

/// Topic suggestions for autocomplete.
@riverpod
Future<List<String>> searchSuggestions(Ref ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(searchRepositoryProvider).suggestTopics(query);
}

/// All available topics for filter chips.
@riverpod
Future<List<String>> availableTopics(Ref ref) async {
  return ref.read(searchRepositoryProvider).getAllTopics();
}

/// Recent search queries (in-memory for now).
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  static const _maxRecent = 10;

  @override
  List<String> build() => [];

  void add(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query, ...state.where((q) => q != query)];
    state = updated.take(_maxRecent).toList();
  }

  void remove(String query) {
    state = state.where((q) => q != query).toList();
  }

  void clear() => state = [];
}
